local libLog = {}
local mt_log = {}
local LOG_DIR = '/tmp'
local C, carray
local ok, ffi = pcall(require, "ffi")
if ffi then
	C = ffi.C
	ffi.cdef [[
	typedef struct __IO_FILE FILE;
	size_t fwrite
	(const void *restrict ptr, size_t size, size_t nitems, FILE *restrict stream);
	size_t fread
	(void *restrict ptr, size_t size, size_t nitems, FILE *restrict stream);
	]]
else
	-- TODO: Maybe use a pcall here in case carray not found
	carray = require'carray'
end

local mp = require'msgpack'
--local mp = require'msgpack.MessagePack'

local function stop(self)
	-- Close the files
	self.f_meta:close()
	if self.f_raw then self.f_raw:close() end
end

-- User should pass :data() of a torch object
-- For proper recording
local function record(self,meta,raw,n_raw)
	-- Record the metadata
	local mtype, m_ok = type(meta), false
	if mtype=='string' then
		m_ok = self.f_meta:write(meta)
	elseif mtype then
		local metapack = mp.pack(meta)
		m_ok = self.f_meta:write(metapack)
	end
	-- Record the raw
	local rtype, r_ok = type(raw), false
	if rtype=='userdata' or rtype=='cdata' then
		-- If no FFI, then cannot record usedata
		-- If no number of raw data, then cannot record
		-- TODO: Use carray as FFI fallback
		if not n_raw then return end
		if C then
			local n_written = C.fwrite(raw,1,n_raw,self.f_raw)
			--print('wrote',n_written)
			r_ok = n_written==n_raw
		else
			local data = carray.byte(raw,n_raw)
			r_ok = self.f_raw:write(tostring(data))
		end
	elseif rt=='string' then
		r_ok = self.f_raw:write(raw)
	end
	-- Return the status of the writes
	return m_ok, r_ok
end


-- Factory
function libLog.new(prefix,has_raw)
	-- Set up log file handles
  local filetime = os.date('%m.%d.%Y.%H.%M.%S')
  local meta_filename = string.format('%s/%s_m_%s.log',LOG_DIR,prefix,filetime)
	local raw_filename  = string.format('%s/%s_r_%s.log',LOG_DIR,prefix,filetime)
	local f_meta = io.open(meta_filename,'w')
	local f_raw, f_raw_c
	if has_raw then f_raw = io.open(raw_filename,'w') end
	-- Set up the object
	local t = {}
	t.f_raw = f_raw
	t.f_meta = f_meta
	t.record = record
	t.stop = stop
	return t
end

local function unroll_meta(self)
	-- Read the metadata
	local f_m = io.open(self.m_name,'r')
	-- Must use an unpacker...
	local metadata = {}
	local u = mp.unpacker(2048)
	local buf, nbuf = f_m:read(512),0
	while buf do
		nbuf = nbuf + #buf
		local res,left = u:feed(buf)
		local tbl = u:pull()
		while tbl do
			metadata[#metadata+1] = tbl
			tbl = u:pull()
		end
		buf = f_m:read(left)
	end
	f_m:close()
	return metadata
end

local function log_iter(self,metadata)
	local buf
	if C then
		local BUF_SZ = 153600
		buf = ffi.new('uint8_t[?]',BUF_SZ)
	end
	local f_r = io.open(DIR..'/uvc_r_'..date..'.log','r')
	local i, n = 0, #metadata
	local function iter(param, state)
		i = i + 1
		if i>n then
			f_r:close()
			return nil
		end
		--if not param then return end
		local m = metadata[i]
		if C then
			local n_read = C.fread(buf,1,m.rsz,f_r)
			return i, m, buf
		else
			local data = f_r:read(m.rsz)
			return i, m, data
		end
	end
	return iter
end

function libLog.open(dir,date)
	local t = {}
	t.m_name = dir..'/uvc_m_'..date..'.log'
	t.r_name = dir..'/uvc_r_'..date..'.log'
	t.unroll_meta = unroll_meta
	t.log_iter = log_iter
	return t
end

-- Fill the metatable

return libLog
