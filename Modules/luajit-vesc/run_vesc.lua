#!/usr/bin/env luajit
local stty = require'stty'
local unix = require'unix'
local unpack = unpack or require'table'.unpack
local poll = require'unix'.poll

local racecar = require'racecar'
local vesc = require'vesc'
local ttyname = arg[1] or "/dev/vesc"

local fd_vesc = unix.open(ttyname, unix.O_RDWR + unix.O_NOCTTY + unix.O_NONBLOCK)
assert(fd_vesc > 0, "Bad File descriptor")
stty.raw(fd_vesc)
stty.serial(fd_vesc)
stty.speed(fd_vesc, 115200)

local coro_vesc = coroutine.create(vesc.update)

local pkt_req_values = string.char(unpack(vesc.sensors()))


local t_vesc_req, vesc_ms = -math.huge, 1 / 50
local t_sensor = -math.huge
local t_sensor_last = t_sensor

while racecar.running do
  t_sensor_last = t_sensor
  t_sensor = time()
  local dt_vesc = t_sensor - t_vesc_req
  -- Ask for VESC sensors, read later
  if fd_vesc and (dt_vesc > vesc_ms) then
    t_vesc_req = t_sensor
    unix.write(fd_vesc, pkt_req_values)
    -- stty.drain(fd_vesc)
  end

  local rc, ready = poll({fd_vesc}, 5)
    local t_poll = unix.time()
    local dt_real = t_poll - t_sensor
    if not rc then
      io.stderr:write(string.format(
        "Bad poll: %s\n", tostring(ready)))
      break
    elseif ready then
      local data = unix.read(fd_vesc)
      local status, obj, msg = coroutine.resume(coro_vesc, data)
      while status and obj do
        for k, v in pairs(obj) do
          if type(v) == 'table' then
            print(k, unpack(v))
          else
            print(k, v)
          end
        end
        status, obj, msg = coroutine.resume(coro_vesc)
      end
    end
  coroutine.yield(n_response)
end


unix.close(fd_vesc)
