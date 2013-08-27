-- Dynamixel Library
-- (c) 2013 Stephen McGill
-- (c) 2013 Daniel D. Lee
-- Support: http://support.robotis.com/en/product/dynamixel_pro/communication/instruction_status_packet.htm

local libDynamixel = {}
local DP1 = require'DynamixelPacket1' -- 1.0 protocol
local DP2 = require'DynamixelPacket2' -- 2.0 protocol
local unix = require'unix'
local stty = require'stty'
local using_status_return = true
-- 75ms default timeout
local READ_TIMEOUT = 0.075

--------------------
-- Convienence functions for reading dynamixel packets
DP1.parse_status_packet = function(pkt) -- 1.0 protocol
   local t = {}
   t.id = pkt:byte(3)
   t.length = pkt:byte(4)
   t.error = pkt:byte(5)
   t.parameter = {pkt:byte(6,t.length+3)}
   t.checksum = pkt:byte(t.length+4)
   return t
end

DP2.parse_status_packet = function(pkt) -- 2.0 protocol
  --print('status pkt',pkt:byte(1,#pkt) )
	local t = {}
	t.id = pkt:byte(5)
	t.length = pkt:byte(6)+2^8*pkt:byte(7)
	t.instruction = pkt:byte(8)
	t.error = pkt:byte(9)
	t.parameter = {pkt:byte(10,t.length+5)}
	t.checksum = string.char( pkt:byte(t.length+6), pkt:byte(t.length+7) );
	return t
end

-- RX (uses 1.0)
-- Format: { Register Address, Register Byte Size}
local rx_registers = {
	['id'] = {3,1},
  ['baud'] = {4,1},
	['delay'] = {5,1},
	['torque_enable'] = {24,1},
	['led'] = {25,1},
	['command_position'] = {30,2},
	['position'] = {36,2},
	['battery'] = {42,2},
	['temperature'] = {43,1},
}
libDynamixel.rx_registers = rx_registers

-- MX
-- http://support.robotis.com/en/product/dynamixel/mx_series/mx-28.htm
-- Convention: {string.char( ADDR_LOW_BYTE, ADDR_HIGH_BYTE ), n_bytes_of_value}
local mx_registers = {
  ['model_num'] = {string.char(0,0),2},
  ['firmware'] = {string.char(2,0),1},
	['id'] = {string.char(3,0),1},
  ['baud'] = {string.char(4,0),1},
	['delay'] = {string.char(5,0),1},
  ['max_torque'] = {string.char(14,0),2},
  ['status_return_level'] = {string.char(16,0),1},
	['torque_enable'] = {string.char(24,0),1},
	['led'] = {string.char(25,0),1},
	
	-- Position PID Gains (position control mode)
	['position_p'] = {string.char(28,0),1},
	['position_i'] = {string.char(27,0),1},
	['position_d'] = {string.char(26,0),1},
	
	['command_position'] = {string.char(30,0),2},
	['velocity'] = {string.char(32,0),2},
	['position'] = {string.char(36,0),2},
  ['speed'] = {string.char(38,0),2},
  ['load'] = {string.char(40,0),2},
  
	['battery'] = {string.char(42,0),2},
	['temperature'] = {string.char(43,0),1},
}
libDynamixel.mx_registers = mx_registers

-- Dynamixel PRO
-- English to Hex Addresses of various commands/information
-- Convention: string.char( LOW_BYTE, HIGH_BYTE )
-- http://support.robotis.com/en/product/dynamixel_pro/control_table.htm
local nx_registers = {
	
	-- New API --
	-- ENTER EEPROM AREA

	-- General Operation information
	['model_num']  = {string.char(0x00,0x00),2},
	['model_info'] = {string.char(0x02,0x00),4},
	['firmware'] =   {string.char(0x06,0x00),1},
	['id'] =   {string.char(0x07,0x00),1},
	-- Baud
	--[[
	0: 2400 ,1: 57600, 2: 115200, 3: 1Mbps, 4: 2Mbps
	5: 3Mbps, 6: 4Mbps, 7: 4.5Mbps, 8: 10.5Mbps
	--]]
	['baud'] = {string.char(0x08,0x00),1},
  -- Delay in us: wish to have zero
  ['delay'] = {string.char(9,0),1},
	
	-- Operation Mode
	-- Mode 0: Torque Control
	-- Mode 1: Velocity Control
	-- Mode 2: Position Control
	-- Mode 3: position-Velocity Control
	['mode'] = {string.char(0x0B,0x00),1},
	
	-- Limits
	['max_temperature'] = {string.char(0x15,0x00,1)},
	['max_voltage'] = {string.char(0x16,0x00),2},
	['min_voltage'] = {string.char(0x18,0x00),2},
	['max_acceleration'] = {string.char(0x1A,0x00),4},
	['max_torque'] = {string.char(0x1E,0x00),2},
	['max_velocity'] = {string.char(0x20,0x00),4},
	['max_position'] = {string.char(0x24,0x00),4},
	['min_position'] = {string.char(0x28,0x00),4},
	['shutdown'] = {string.char(0x30,0x00),1},
	
	-- ENTER RAM AREA
	['torque_enable'] = {string.char(0x32,0x02),1},
	-- Position Options --
	-- Position Commands (position control mode)
	['command_position'] = {string.char(0x54,0x02),4},
	['command_velocity'] = {string.char(0x58,0x02),4},
	['command_acceleration'] = {string.char(0x5E,0x02),4},
	-- Position PID Gains (position control mode)
	['position_p'] = {string.char(0x52,0x02),2},
	['position_i'] = {string.char(0x50,0x02),2},
	['position_d'] = {string.char(0x4E,0x02),2},
	-- Velocity PID Gains (position control mode)
	['velocity_p'] = {string.char(0x46,0x02),2},
	['velocity_i'] = {string.char(0x4A,0x02),2},
	['velocity_d'] = {string.char(0x4C,0x02),2},
	
	-- Low Pass Fitler settings
	['position_lpf'] = {string.char(0x42,0x02),4},
	['velocity_lpf'] = {string.char(0x46,0x02),4},
	-- Feed Forward mechanism
	['acceleration_ff'] = {string.char(0x3A,0x02),4},
	['velocity_ff'] = {string.char(0x3E,0x02),4},
	
	-- Torque options --
	-- Commanded Torque (torque control mode)
	['command_torque'] = {string.char(0x5C,0x02),4},
	-- Current (V=iR) PI Gains (torque control mode)
	['current_p'] = {string.char(0x38,0x02),2},
	['current_i'] = {string.char(0x36,0x02),2},

	-- LED lighting
	['led_red'] = {string.char(0x33,0x02),1},
	['led_green'] = {string.char(0x34,0x02),1},
	['led_blue'] = {string.char(0x35,0x02),1},
	
	-- Present information
	['position'] = {string.char(0x63,0x02),4},
	['velocity'] = {string.char(0x67,0x02),4},
	['current'] = {string.char(0x6D,0x02),2},
	['load'] = {string.char(0x6B,0x02),2},
	['voltage'] = {string.char(0x6F,0x02),2},
	['temperature'] = {string.char(0x71,0x02),1},
  
  -- Status return
  ['status_return_level'] = {string.char(0x7B,0x03),1},
}
libDynamixel.nx_registers = nx_registers

--------------------
-- Convienence functions for constructing Sync Write instructions
local function sync_write_byte(ids, addr, data)
  local all_data = nil
	local nid = #ids
  -- All get the same value
	if type(data)=='number' then 
    all_data = data
  else
    assert(nid==#data,'Incongruent ids and data')
  end
  
	local t = {}
	local n = 1
	local len = 1 -- byte
	for i = 1,nid do
		t[n] = ids[i]
		t[n+1] = all_data or data[i]
		n = n + len + 1
	end
  
	return t
end

local function sync_write_word(ids, addr, data)
	local all_data = nil
  local nid = #ids
	if type(data)=='number' then
		-- All get the same value
		all_data = data
  else
    assert(nid==#data,'Incongruent ids and data')
	end

	local t = {}
	local n = 1
	local len = 2 -- word
	for i = 1,nid do
		t[n] = ids[i];
		local val = all_data or data[i]
		-- Word to byte is the same for both packet types...
		t[n+1],t[n+2] = DP2.word_to_byte(val)
		n = n + len + 1;
	end
	return t
end

local function sync_write_dword(ids, addr, data)
  local all_data = nil
	local nid = #ids
	local len = 4
	if type(data)=='number' then
		-- All get the same value
		all_data = data
  else
    assert(nid==#data,'Incongruent ids and data')
	end
	local t = {};
	local n = 1;
	for i = 1,nid do
		t[n] = ids[i];
		local val = all_data or data[i]
		t[n+1],t[n+2],t[n+3],t[n+4] = DP2.dword_to_byte(val)
		n = n + len + 1;
	end
	return t
end

--------------------
-- Initialize functions for reading/writing to NX motors
local nx_single_write = {}
nx_single_write[1] = DP2.write_byte
nx_single_write[2] = DP2.write_word
nx_single_write[4] = DP2.write_dword

local mx_single_write = {}
mx_single_write[1] = DP2.write_byte
mx_single_write[2] = DP2.write_word
mx_single_write[4] = DP2.write_dword

local rx_single_write = {}
rx_single_write[1] = DP1.write_byte
rx_single_write[2] = DP1.write_word
rx_single_write[4] = DP1.write_dword

local sync_write = {}
sync_write[1] = sync_write_byte
sync_write[2] = sync_write_word
sync_write[4] = sync_write_dword

local byte_to_number = {}
byte_to_number[1] = function(byte)
  return byte
end
byte_to_number[2] = DP2.byte_to_word
byte_to_number[4] = DP2.byte_to_dword
libDynamixel.byte_to_number = byte_to_number

-- Old get status method
local function get_status( fd, npkt, protocol, timeout )
	-- TODO: Is this the best default timeout for the new PRO series?
	timeout = timeout or READ_TIMEOUT
  npkt = npkt or 1

  local DP = DP2
	if protocol==1 then DP = DP1 end

	local t0 = unix.time()
	local status_str = ''
	local pkt_cnt = 0
	local statuses = {}
	while unix.time()-t0<timeout do
		local s = unix.read(fd)
		if s then
			status_str = status_str..s
			local pkts = DP.input(status_str)
      --print('Status sz',#status_str)
			if pkts then
				for p,pkt in ipairs(pkts) do
					local status = DP.parse_status_packet( pkt )
          if npkt==1 then return status end
					table.insert( statuses, status )
				end
				if #statuses==npkt then return statuses end
			end -- if pkts
		end
    unix.select({fd},0.001)
	end
	-- Did we timeout?
	return nil
end

--------------------
-- Set NX functions: returns the command to send on the chain
for k,v in pairs( nx_registers ) do
	libDynamixel['set_nx_'..k] = function( motor_ids, values, bus)
		local addr = v[1]
		local sz = v[2]
		
		-- Construct the instruction (single or sync)
    local single = type(motor_ids)=='number'
		local instruction = nil
		if single then
			instruction = nx_single_write[sz](motor_ids, addr, values)
		else
			local msg = sync_write[sz](motor_ids, addr, values)
			instruction = DP2.sync_write(addr, sz, string.char(unpack(msg)))
		end
		
    if not bus then return instruction end

    -- Clear the reading
    local clr = unix.read(bus.fd)

    -- Write the instruction to the bus 
    local ret = unix.write(bus.fd, instruction)
		
    -- Grab any status returns
    if using_status_return and single then
      return get_status( bus.fd, 1 )
    end
		
	end --function
end

--------------------
-- Get NX functions
for k,v in pairs( nx_registers ) do
	libDynamixel['get_nx_'..k] = function( motor_ids, bus )
		local addr = v[1]
		local sz = v[2]
		
		-- Construct the instruction (single or sync)
		local instruction = nil
		local nids = 1
		if type(motor_ids)=='number' then
      -- Single motor
			instruction = DP2.read_data(motor_ids, addr, sz)
		else
			instruction = DP2.sync_read(string.char(unpack(motor_ids)), addr, sz)
			nids = #motor_ids
		end
		
    if not bus then return instruction end
    
		-- Clear old status packets
    repeat buf = unix.read(bus.fd) until not buf
    
    -- Write the instruction to the bus 
    local ret = unix.write(bus.fd, instruction)
		
    -- Grab the status of the register
    return get_status( bus.fd, nids )
		
	end --function
end

--------------------
-- Set MX functions
for k,v in pairs( mx_registers ) do
	libDynamixel['set_mx_'..k] = function( motor_ids, values, bus )
		local addr = v[1]
		local sz = v[2]
		
		-- Construct the instruction (single or sync)
    local single = type(motor_ids)=='number'
		local instruction = nil
		if single then
			instruction = mx_single_write[sz](motor_ids, addr, values)
		else
			local msg = sync_write[sz](motor_ids, addr, values)
			instruction = DP2.sync_write(addr, sz, string.char(unpack(msg)))
		end
		
    if not bus then return instruction end

    -- Write the instruction to the bus
    local ret = unix.write(bus.fd, instruction)
		
    -- Grab any status returns
    if using_status_return and single then
      local status = get_status( bus.fd )
      local value = byte_to_number[sz]( unpack(status.parameter) )
      return status, value
    end
		
	end --function
end

--------------------
-- Get MX functions
for k,v in pairs( mx_registers ) do
	libDynamixel['get_mx_'..k] = function( motor_ids, bus )
		local addr = v[1]
		local sz = v[2]
		
		-- Construct the instruction (single or sync)
		local instruction = nil
		local nids = 1
		if type(motor_ids)=='number' then
      -- Single motor
			instruction = DP2.read_data(motor_ids, addr, sz)
		else
			instruction = DP2.sync_read(string.char(unpack(motor_ids)), addr, sz)
			nids = #motor_ids
		end
		
    if not bus then return instruction end
    
		-- Clear old status packets
		local clear = unix.read( bus.fd )
    
    -- Write the instruction to the bus 
    local ret = unix.write( bus.fd, instruction)
		
    -- Grab the status of the register
    local status = get_status( bus.fd, nids )
    local values = {}
    for i,s in ipairs(status) do
      table.insert(values,byte_to_number[sz]( unpack(s.parameter) ))
    end
    return status, values
		
	end --function
end

--------------------
-- Set RX functions
for k,v in pairs( rx_registers ) do
	libDynamixel['set_rx_'..k] = function( motor_ids, values, bus)
		local addr = v[1]
		local sz = v[2]
		
		-- Construct the instruction (single or sync)
    local single = type(motor_ids)=='number'
		local instruction = nil
		if single then
			instruction = rx_single_write[sz](motor_ids, addr, values)
		else
			local msg = sync_write[sz](motor_ids, addr, values)
			instruction = DP1.sync_write(addr, sz, string.char(unpack(msg)))
		end
		
    if not bus then return instruction end

    -- Write the instruction to the bus 
    local ret = unix.write(bus.fd, instruction)
		
    -- Grab any status returns
    if using_status_return and single then
      local status = get_status( bus.fd, 1 )
      return status[1]
    end
		
	end --function
end

--------------------
-- Get RX functions
for k,v in pairs( rx_registers ) do
	libDynamixel['get_rx_'..k] = function( motor_ids, bus )
		local addr = v[1]
		local sz = v[2]
		
		-- Construct the instruction (single or sync)
		local instruction = nil
    -- Single motor
		instruction = DP1.read_data(motor_id, addr, sz)

    if not bus then return instruction end
    
		-- Clear old status packets
		local clear = unix.read(bus.fd)
    
    -- Write the instruction to the bus 
    local ret = unix.write(bus.fd, instruction)
		
    -- Grab the status of the register
    local status = get_status( bus.fd, 1, 1 )
    local value = byte_to_number[sz]( unpack(status[1].parameter) )
    return status, value
		
	end --function
end

--------------------
-- Ping functions
libDynamixel.send_ping = function( id, protocol, bus, twait )
	protocol = protocol or 2
	local instruction = nil
	if protocol==1 then
		instruction = DP1.ping(id)
	else
		instruction = DP2.ping(id)
	end
  if not bus then return instruction end

	unix.write(bus.fd, instruction)
  local status = get_status( bus.fd, 1, protocol, twait )
  --print('st',status)
  if status then return status end
end

local function ping_probe(self, protocol, twait)
  local found_ids = {}
	for id = 0,253 do
		local status = 
      libDynamixel.send_ping( id, protocol or 2, self, twait or READ_TIMEOUT )
		if status then
      --print( string.format('Found %d.0 Motor: %d\n',protocol,status.id) )
      table.insert( found_ids, status.id )
		end
    -- Wait 1 ms
    unix.usleep(1e3)
	end
  return found_ids
end

--------------------
-- Generator of a new bus
function libDynamixel.new_bus( ttyname, ttybaud )
	-------------------------------
	-- Find the device
	local baud = ttybaud or 1000000;
	if not ttyname then
		local ttys = unix.readdir("/dev");
		for i=1,#ttys do
			if ttys[i]:find("tty.usb") or ttys[i]:find("ttyUSB") then
				ttyname = "/dev/"..ttys[i]
        -- TODO: Test if in use
				break
			end
		end
	end
	assert(ttyname, "Dynamixel tty not found");
	-------------------------------

	-------------------
	-- Setup serial port
	local fd = unix.open(ttyname, unix.O_RDWR+unix.O_NOCTTY+unix.O_NONBLOCK);
	assert(fd > 2, string.format("Could not open port %s, (%d)", ttyname, fd) );
	stty.raw(fd)
	stty.serial(fd)
	stty.speed(fd, baud)
	-------------------

	-------------------
	-- Object of the Dynamixel
	local obj = {}
	obj.fd = fd
	obj.ttyname = ttyname
	obj.baud = baud
	-- Close out the device
	obj.close = function (self) return unix.close( self.fd )==0 end
	-- Reset the device
	obj.reset = function(self)
		self:close()
		unix.usleep( 1e3 )
		self.fd = libDynamixel.open( self.ttyname )
	end
  obj.ping_probe = ping_probe
	-------------------
	
	-------------------
	-- Add libDynamixel functions
  --[[
	for name,func in pairs( libDynamixel ) do
		obj[name] = func
	end
	-- new_bus not allowed on a current bus
	obj.new_bus = nil
	obj.service = nil
  --]]
	-------------------
  
  -------------------
  -- Read/write properties
  obj.t_last_read = 0
  obj.t_last_write = 0
  obj.instructions = {}
  obj.requests = {}
  obj.is_syncing = true
  obj.nx_on_bus = nil -- ids of nx
  obj.mx_on_bus = nil -- ids of mx
  obj.ids_on_bus = nil --all on the bus
  obj.name = 'Default'
  obj.message = nil
  -------------------
	
	return obj
end

---------------------------
-- Service multiple Dynamixel buses
libDynamixel.service = function( dynamixels, main )
  
  -- Enable the main function as a coroutine thread
  local main_thread = nil
  if main then
    main_thread = coroutine.create( main )
  end

	-- Start the streaming of each dynamixel
  -- Instantiate the dynamixel coroutine thread
  local dynamixel_fds = {}
  local fd_to_dynamixel = {}
	for i,dynamixel in ipairs(dynamixels) do
    -- Set up easy access to select IDs
    table.insert(dynamixel_fds,dynamixel.fd)
    fd_to_dynamixel[dynamixel.fd] = dynamixel
		dynamixel.thread = coroutine.create(
		function()
      
      -- Make a read all NX command
      local DP = DP2
      
      -- The coroutine should never end
      local fd = dynamixel.fd
      local response = nil
			while true do -- read/write loop
        
        local did_something = false
        
        --------------------
        -- Request data from the chain
        if #dynamixel.requests>0 then
          -- Clear the bus with a unix.read()?
          local leftovers = unix.read(fd)
          assert(leftovers~=-1, 'BAD Clearing READ')
          
          -- Pop the request
          local request = table.remove(dynamixel.requests,1)
          
          -- Write the read request instruction to the chain
          local req_ret = unix.write(fd, request[1])
          -- Set a timeout for this request
          dynamixel.timeout = unix.time() + READ_TIMEOUT
          -- If -1 returned, the bus may be detached - throw an error
          assert(req_ret~=-1,string.format('BAD READ REQ on %s',dynamixel.name))
          -- Yield the number of motors read
          -- TODO: Should it just return true? the number of bytes sent to the bus? The number of packets to expect?
          response = coroutine.yield( 1 )

          -- Read the packets and check the returns
          local status_str = ''
          -- Accrue values from the status packets
          local values = {}
          local t = unix.time()
          while t<dynamixel.timeout do

            local new_status_str = unix.read( fd )
            assert(new_status_str~=-1,string.format('BAD READ: %s',dynamixel.name))
            --assert(status_str, string.format('NO READ: %s',dynamixel.name))

            -- Do nothing when receiving nothing
            if not new_status_str then
              assert(#status_str>0,'Two false reads!')
              break
            end
            
            -- Append the new status
            status_str = status_str..new_status_str
            
            -- Process the status string into a packet
            local pkts, done = DP.input( status_str )
            
            -- For each packet, append to the values table
            for p,pkt in ipairs(pkts) do
              local status = DP.parse_status_packet( pkt )
              local read_parser = byte_to_number[ #status.parameter ]
              -- Check if there is a parser
              assert(read_parser, 
              string.format('Status error for %s from %d: %d (%d)',
              request[2],status.id,status.error,#status.parameter) )
              -- Convert the value into a number from bytes
              local value = read_parser( unpack(status.parameter) )
              values[status.id] = value
            end
            
            -- Yield the table of motor values and the register name
            response = coroutine.yield( values, request[2] )
          
            -- Record it only after processing
            --assert(#pkts>0,'no packets found!'..#status_str)
            if #pkts>0 then
              dynamixel.t_diff_read = t - dynamixel.t_last_read
              dynamixel.t_last_read = t
            end
            
            if response then break end
          
          end -- if use read
          
          -- We did something during this resume of the coroutine
          did_something = true
          -- Update the time for the timeout
          t = unix.time()
        end -- while reading responses
        --------------------
        -- Sync write an instruction in the queue
        if #dynamixel.instructions>0 then
          -- Pop the item
          local instruction = table.remove(dynamixel.instructions,1)
          local command_ret = unix.write( fd, instruction )
          -- Save the write time
          local t = unix.time()
          dynamixel.t_diff_write = t - dynamixel.t_last_write
          dynamixel.t_last_write = t
          -- Yield true for syncing
          response = coroutine.yield( true )
          -- We did something
          did_something = true
        end
        
        -- Yield if did nothing
        if not did_something then response = coroutine.yield( false ) end
        
      end -- read/write loop
		end -- coroutine function
		)
	end
  
  -- Loop and select appropriately
  --local status_timeout = 1/120 -- 120Hz timeout
  local status_timeout = 1/60 -- 120Hz timeout
  --local status_timeout = 0 -- Instant timeout
	while #dynamixel_fds>0 do
    
    -- TODO: Use the dynamixel objects somehow to accept more commands...
    -- TODO: Change from position reading to other reading?

    --------------------
    -- Perform Select on all dynamixels
    local status, ready = unix.select( dynamixel_fds, status_timeout )
    local t = unix.time()
    --------------------
    -- Loop through the dynamixel chains
    for i_fd,is_ready in pairs(ready) do
      -- Grab the dynamixel chain
      local who_to_service = fd_to_dynamixel[i_fd]
          --print('checking',who_to_service.name,i_fd,is_ready,who_to_service.is_syncing)
      --print()
      -- Check if the Dynamixel has information available
      if is_ready or who_to_service.is_syncing or t>who_to_service.timeout then
        local response = nil
        if is_ready and who_to_service.is_syncing then
          --print(who_to_service.name,'has more to read but is syncing also!')
          response = 'more'
        end
        --------------------
        -- Resume the thread
        local status_code, param, reg = coroutine.resume(who_to_service.thread,response)
        local param_type = type(param)
        
        --------------------
        -- Check if there were errors in the coroutine
        if not status_code then
          --print( 'Dead dynamixel coroutine!', who_to_service.name, param )
          who_to_service:close()
          who_to_service.message = param
          local i_to_remove = 0
          for i,fd in ipairs(dynamixel_fds) do
            if fd==i_fd then i_to_remove = i end
          end
          table.remove(dynamixel_fds,i_to_remove)
          --error('stopping')
        elseif param_type=='table' then
          who_to_service.is_syncing = true
          -- Process the callback for read data
          if who_to_service.callback then
            who_to_service:callback( param, reg )
          end
        elseif param_type=='string' then
          error( string.format('%s: %s',who_to_service.name, param) )
        elseif param_type=='number' then
          -- Not syncing if reading from a number of motors
          who_to_service.is_syncing = false
        elseif param_type=='boolean' then
          -- Syncing if returns true
          -- false means nothing happened on the coroutine
          -- TODO: This seems like complicated logic...
          --who_to_service.is_syncing = param
          who_to_service.is_syncing = true
        end -- status_code
        
      end -- is_ready 
    end -- pairs(ready)
    
    --------------------
    -- Process the main thread after each coroutine yields
    -- This main loop should update the dynamixel chain commands
    if main_thread then
      local status_code, main_param = coroutine.resume( main_thread )
      if not status_code then 
        print('Dead main coroutine!',main_param)
        main_thread = nil
      end
    end
    
	end -- while servicing
  print'Nothing left to service!'
end

return libDynamixel