-----------------------------------------------------------------
-- Combined Lidar manager for Team THOR
-- Reads and sends raw lidar data
-- As well as accumulate them as a map
-- and send to UDP/TCP
-- (c) Stephen McGill, Seung Joon Yi, 2013
---------------------------------
-- TODO: Critical section for include
-- Something there is non-reentrant
dofile'../include.lua'
-- Going to be threading this
local simple_ipc = require'simple_ipc'
-- Are we a child?
local IS_CHILD, pair_ch = false, nil
local CTX, metadata = ...
if CTX and type(metadata)=='table' then
	IS_CHILD=true
	simple_ipc.import_context( CTX )
	pair_ch = simple_ipc.new_pair(metadata.ch_name)
	print('CHILD CTX')
end

local lidars = {'lidar0','lidar1'}

-- The main thread's job is to give:
-- joint angles and network request
if not IS_CHILD then
	-- Only the parent communicates with the body
	local Body = require'Body'
	-- TODO: Signal of ctrl-c should kill all threads...
	--local signal = require'signal'
	-- Only the parent accesses shared memory
	require'vcm'
	local poller, threads, channels = nil, {}, {}
	-- Spawn children
	for i,v in ipairs(lidars) do
		local meta = {
			name = v,
			fov = {-60*DEG_TO_RAD,60*DEG_TO_RAD},
			scanlines = {-45*DEG_TO_RAD,45*DEG_TO_RAD},
			density = 10*RAD_TO_DEG, -- #scanlines per radian on actuated motor
			dynrange = {.1,1}, -- Dynamic range of depths when compressing
			c = 'jpeg', -- Type of compression
			t = Body.get_time(),
		}
		local thread, ch = simple_ipc.new_thread('mesh_wizard.lua',v,meta)
		ch.callback = function(s)
			local data, has_more = poller.lut[s]:receive()
			--print('child tread data!',data)
		end
		threads[v] = {thread,ch}
		table.insert(channels,ch)
		-- Start officially
		thread:start()
	end
	-- TODO: Also poll on mesh requests, instead of using net_settings...
	-- This would be a Replier (then people ask for data, or set data)
	-- Instead of changing shared memory a lot...
	local replier = simple_ipc.new_replier'mesh'
	replier.callback = function(s)
		local data, has_more = poller.lut[s]:receive()
		-- Send message to a thread
	end
	table.insert(channels,replier)
	-- Just wait for requests from the children
	poller = simple_ipc.wait_on_channels(channels)
	--poller:start()
	local t_check = 0
	while poller.n>0 do
		local npoll = poller:poll(1e3)
		-- Check if everybody is alive periodically
		--print(npoll,poller.n)
		local t = Body.get_time()
		if t-t_check>1e3 or npoll<1 then
			t_check = t
			for k,v in pairs(threads) do
				local thread, ch = unpack(v)
				if not thread:alive() then
					thread:join()
					poller:clean(ch.socket)
					threads[k] = nil
					print('Mesh |',k,'thread died!')
				else
					ch:send'hello'
				end
			end
		end -- if too long
	end
	return
end

-- Libraries
local torch      = require'torch'
torch.Tensor     = torch.DoubleTensor
local util       = require'util'
local jpeg       = require'jpeg'
jpeg.set_quality( 95 )
local png        = require'png'
local zlib       = require'zlib'
local util       = require'util'
local mp         = require'msgpack'
local carray     = require'carray'
local udp        = require'udp'

-- Globals
-- Output channels
local mesh_udp_ch, mesh_tcp_ch, lidar_ch
-- Input channels
local channel_polls
local channel_timeout = 100 --milliseconds

-- Setup metadata and tensors for a lidar mesh
local reading_per_radian, scan_resolution, fov_resolution
local mesh, mesh_byte, mesh_adj, scan_angles, offset_idx
-- LIDAR properties
local n, res, fov = 1081, 1, 270
local current_scanline, current_direction
local function setup_mesh()
  -- Find the resolutions
  local scan_resolution = metadata.density
    * math.abs(metadata.scanlines[2]-metadata.scanlines[1])
  scan_resolution = math.ceil(scan_resolution)
  -- Set our resolution
	-- NOTE: This has been changed in the lidar msgs...
  reading_per_radian = (n-1)/(270*DEG_TO_RAD)
  fov_resolution = reading_per_radian * math.abs(metadata.fov[2]-metadata.fov[1])
  fov_resolution = math.ceil(fov_resolution)
	-- Find the offset for copying lidar readings into the mesh
  -- if fov is from -fov/2 to fov/2 degrees, then offset_idx is zero
  -- if fov is from 0 to fov/2 degrees, then offset_idx is sensor_width/2
  local fov_offset = (n-1)/2+math.ceil( reading_per_radian*metadata.fov[1] )
  offset_idx   = math.floor(fov_offset)
  -- TODO: Pose information
	--[[
  tbl.meta.posex = {}
  tbl.meta.posey = {}
  tbl.meta.posez = {}
  for i=1,scan_resolution do 
    tbl.meta.posex[i],
    tbl.meta.posey[i],
    tbl.meta.posez[i]=0,0,0
  end
	--]]
  -- In-memory mesh
  mesh      = torch.FloatTensor( scan_resolution, fov_resolution ):zero()
  -- Mesh buffers for compressing and sending to the user
	mesh_adj  = torch.FloatTensor( scan_resolution, fov_resolution )
  mesh_byte = torch.ByteTensor( scan_resolution, fov_resolution )
  -- Save the exact actuator angles of every scan
  scan_angles  = torch.DoubleTensor( scan_resolution ):zero()
end

------------------------------
-- Data copying helpers
-- Convert a pan angle to a column of the chest mesh image
local function angle_to_scanlines( rad )
  -- Get the most recent direction the lidar was moving
  local prev_scanline = current_scanline
  -- Get the metadata for calculations
  local meta  = lidar.meta
  local start = meta.scanlines[1]
  local stop  = meta.scanlines[2]
  local res   = meta.resolution[1]
  local ratio = (rad-start)/(stop-start)
  -- Round...? Why??
	-- TODO: Make this simpler/smarter
  local scanline = math.floor(ratio*res+.5)
  -- Return a bounded value
  scanline = math.max( math.min(scanline, res), 1 )

  --SJ: I have no idea why, but this fixes the scanline tilting problem
  if current_direction then
    if lidar.current_direction<0 then        
      scanline = math.max(1,scanline-1)
    else
      scanline = math.min(res,scanline+1)
    end
  end
  -- Save in our table
  current_scanline = scanline
	-- Initialize if no previous scanline
  -- If not moving, assume we are staying in the previous direction
	if not prev_scanline then return {scanline} end
  -- Grab the most recent scanline saved in the mesh
  local prev_direction = lidar.current_direction
  if not prev_direction then
    lidar.current_direction = 1
    return {scanline}
  end
  -- Grab the direction
  local direction
  local diff_scanline = scanline - prev_scanline
  if diff_scanline==0 then
    direction = prev_direction
  else
    direction = util.sign(diff_scanline)
  end
  -- Save the directions
  lidar.current_direction = direction
  lidar.prev_direction = prev_direction
  -- Find the set of scanlines for copying the lidar reading
  local scanlines = {}
  if direction==prev_direction then
    -- fill all lines between previous and now
    for s=prev_scanline+1,scanline,direction do table.insert(scanlines,s) end
  else
    -- Changed directions!
    -- Populate the borders, too
    if direction>0 then
      -- going away from 1 to end
      local start_line = math.min(prev_scanline+1,scanline)
      for s=start_line,res do table.insert(scanlines,i) end
    else
      -- going away from end to 1
      local end_line = math.max(prev_scanline-1,scanline)
      for s=1,end_line do table.insert(scanlines,i) end        
    end
  end
  -- Return for populating
  return scanlines
end

local function lidar_cb(s)
	print('Got lidar data!')
  local ch = poller.lut[s]
	-- Send message to a thread
	local meta, ranges
	while true do
		-- Do not block, as we are flushing the buffer
		-- in the worst case of data being backed up
    local data, has_more = ch:receive(true)
		-- If no msg, then process
		if not data then break end
		-- Must have a pair with the range data
		assert(has_more,"metadata and not lidar ranges!")
		ranges, has_more = ch:receive()
		meta = mp.unpack(data)
	end
	-- Update the points
	if meta.n~=n then
		print('LIDAR Properties',n,'=>',meta.n)
		n = meta.n
		setup_mesh()
		current_direction, current_scanline = nil, nil
	end
	-- Save the rpy of the body
	metadata.rpy = meta.rpy
	-- Save the latest lidar timestamp
	metadata.t = meta.t
  -- Save the body pose info
  local px, py, pa = unpack(meta.pose)
  -- Insert into the correct column
  local scanlines = angle_to_scanlines( chest, meta.angle )
  -- Update each outdated scanline in the mesh
  for _,line in ipairs(scanlines) do
		-- Copy lidar readings to the torch object for fast modification
		-- TODO: This must change...
		-- Use string2storage? We only want one copy operation...
		-- Place into storage
		cutil.string2storage(ranges, mesh:select(1,line), mesh:size(2), offset_idx)
		-- Save the pan angle
		chest.scan_angles[line] = angle
    -- Save the pose
    chest.meta.posex[line],
    chest.meta.posey[line],
    chest.meta.posez[line]=
    px, py, pz
  end
end

local function send_mesh(is_reliable)
	-- TODO: Somewhere check that far>near
  local near, far = unpack(metadata.dynrange)
  -- Enhance the dynamic range of the mesh image
  mesh_adj:copy(mesh.mesh):add( -near )
  mesh_adj:mul( 255/(far-near) )
  -- Ensure that we are between 0 and 255
  mesh_adj[torch.lt(mesh_adj,0)] = 0
  mesh_adj[torch.gt(mesh_adj,255)] = 255
  mesh_byte:copy( mesh_adj )
  -- Compression
  local c_mesh 
  local dim = mesh_byte:size()
  if metadata.c=='jpeg' then
    -- jpeg
    c_mesh = jpeg.compress_gray(mesh_byte:storage():pointer(), dim[2], dim[1])
  elseif metadata.c=='png' then
    -- png
    mesh.meta.c = 'png'
    c_mesh = png.compress(mesh_byte:storage():pointer(), dim[2], dim[1], 1)
  elseif metadata.c=='zlib' then
    -- zlib
    c_mesh = zlib.compress(mesh_byte:storage():pointer(), mesh_byte:nElement())
  else
    -- raw data?
		-- Maybe needed for sending a mesh to another process
    return
  end
	-- NOTE: Metadata should be packed only when it changes...
	local metapack = mp.pack(metadata)
	if is_reliable then
		local ret = mesh_tcp_ch:send{metapack,c_mesh}
	else
		local ret, err = mesh_udp_ch:send(metapack..c_mesh)
		if err then print('Mesh | UDP:',err) end
	end
end

-- Initial setup of the mesh from metadata
setup_mesh()
-- Data sending channels
mesh_tcp_ch = simple_ipc.new_publisher(Config.net.reliable_mesh)
mesh_udp_ch = udp.new_sender(Config.net.operator.wired, Config.net.mesh)
-- Poll for the lidar and master thread info
lidar_ch = simple_ipc.new_subscriber(metadata.name)
lidar_ch.callback = lidar_cb
pair_ch.callback = function(s)
	local ch = poller.lut[s]
	local data, has_more = ch:receive()
	--print('Got pair data!',data)
	-- Send message to a thread
	ch:send('what??')
end

local wait_channels = {}
table.insert(wait_channels,lidar_ch)
table.insert(wait_channels,pair_ch)
poller = simple_ipc.wait_on_channels( wait_channels )
print('Child | Start poll')
poller:start()
