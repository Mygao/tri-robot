dofile'../../include.lua'
require'freenect2'
serial_number, firmware_version = freenect2.init()
print("serial_number, firmware_version:", serial_number, firmware_version)

require'unix'
get_time = unix.time

local c_rgb = require'jpeg'.compressor('rgb')


local meta = {
	serial_number = serial_number,
	firmware_version = firmware_version,
}

local libLog, logger
libLog = require'libLog'
log_rgb = libLog.new('k2_rgb', true)
log_ir = libLog.new('k2_ir', true)
log_depth = libLog.new('k2_depth', true)
-- Log data with libLog
for i=1,120 do
	rgb, depth, ir = freenect2.update()
  if i%5==0 then
		meta.t = get_time()
		--
    j_rgb = c_rgb:compress(rgb.data, rgb.width, rgb.height)
		meta.rsz = #j_rgb
    log_rgb:record(meta, j_rgb)
		--
		meta.rsz = #ir.data
    log_ir:record(meta, ir.data)
		--
		meta.rsz = #depth.data
    log_depth:record(meta, depth.data)
		--
    io.write('Logged ', log_depth.n, '\n')
  end
end
log_rgb:stop()
log_ir:stop()
log_depth:stop()

-- Show the data
print('Process the data', rgb)
print()
print('RGB')
for k, v in pairs(rgb) do
	if k~='data' then print(k,v) else print(k, #v) end
end

print()
print('Depth')
for k, v in pairs(depth) do
  if k~='data' then print(k,v) else print(k, #v) end
end

print()
print('IR')
for k, v in pairs(ir) do
  if k~='data' then print(k,v) else print(k, #v) end
end

print('JPEG save the rgb')
img_jpeg = c_rgb:compress(rgb.data, rgb.width, rgb.height)
f = io.open('rgb.jpeg', 'w')
f:write(img_jpeg)
f:close()
--
f = io.open('rgb.raw', 'w')
f:write(rgb.data)
f:close()

print('RAW save the IR')
f = io.open('ir.raw', 'w')
f:write(ir.data)
f:close()

print('RAW save the Depth')
f = io.open('depth.raw', 'w')
f:write(depth.data)
f:close()

print('Shutting down')
freenect2.shutdown()