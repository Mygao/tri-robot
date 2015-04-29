dofile'../../include.lua'
local Body       = require'Body'
local signal     = require'signal'
local carray     = require'carray'
local mp         = require'msgpack'
local util       = require'util'
local simple_ipc = require'simple_ipc'
local libMicrostrain  = require'libMicrostrain'
local vector = require'vector'

local RAD_TO_DEG = Body.RAD_TO_DEG

local imu = libMicrostrain.new_microstrain(
--  '/dev/cu.usbmodem1421', 921600 )
  '/dev/ttyACM0')

if not imu then
  print('No imu present!')
  os.exit()
end

--util.ptable(imu)

-- Print info
print('Opened Microstrain')
print(table.concat(imu.information,'\n'))

-- Set up the defaults:
--libMicrostrain.configure(imu,true)
--os.exit()

-- Change the baud rate to fastest for this session
--libMicrostrain.change_baud(imu)
--os.exit()

-- Turn on the stream
imu:ahrs_on()
local cnt = 0
while true do
  local ret_fd = unix.select( {imu.fd} )
  io.write('READING\n')
  res = unix.read(imu.fd)
  assert(res)
  local response = {string.byte(res,1,-1)}
  for i,b in ipairs(response) do print( string.format('%d: %02X %d',i,b,b) ) end
  local gyr_str = res:sub(7,18)
  local gyro = carray.float( gyr_str:reverse() )
  print( string.format('GYRO: %g %g %g',unpack(gyro:table())))

  local rpy_str = res:sub(21,32)
  local rpy = carray.float( rpy_str:reverse() )
  rpy = vector.new( rpy:table() )
  print( 'RPY:', rpy*RAD_TO_DEG )
--[[
  local acc_str = res:sub(7,18)
  for i,b in ipairs{acc_str:byte(1,-1)} do
    print( string.format('acc %d: %02X %d',i,b,b) )
  end
  local acc = carray.float( acc_str )
  for i=1,#acc do
    print('acc',acc[i])
  end
  local acc_rev = carray.float( acc_str:reverse() )
  for i=1,#acc_rev do
    print('acc_rev',acc_rev[i])
  end
--]]
  cnt = cnt+1
  if false and cnt>5 then
    imu:ahrs_off()
    break
  end
end
print('done!')

-- test 1 sec timeout
local ret_fd = unix.select( {imu.fd}, 1 )
print('timeout!',ret_fd)

imu:close()
os.exit()
