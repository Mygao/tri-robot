#!/usr/bin/env luajit
local coroutine = require'coroutine'
local unpack = unpack or require'table'.unpack

local control = require'control'
local racecar = require'racecar'
local vector = require'vector'

-- Pose is x, y, theta
local lane_outer =  {
  {2.25, 1.5}, {2.25, 4.25},
  {1.75, 4.75}, {-0.75, 4.75},
  {-1.25, 4.25}, {-1.25, -1.5},
  {-0.75, -2}, {1.75, -2},
  {2.25, -1.5}, {2.25, 1}
}
local lane_inner = {
  {1.5, 1}, {1.5, -0.75},
  {1, -1.25}, {0, -1.25},
  {-0.5, -0.75}, {-0.5, 3.5},
  {0, 4}, {1, 4},
  {1.5, 3.5}, {1.5, 1.5}
}

local lanes = {}
table.insert(lanes, lane_outer)
table.insert(lanes, lane_inner)

-- Take pairs
local path = {}
local ds = 0.05
local my_lane = lane_inner
for i=1, #my_lane-1 do
  local p_a = vector.new(my_lane[i])
  local p_b = vector.new(my_lane[i+1])
  local dp = p_b - p_a
  local d = vector.norm(dp)
  dp = vector.unit(dp)
  table.insert(path, p_a)
  for step = ds, d-ds, ds do
    table.insert(path, p_a + step * dp)
  end
end

local pose_rbt = vector.pose()

local env = {
  viewBox = {-3, -5.5, 7, 9},
  observer = pose_rbt,
  time_interval = 0.1,
  speed = 0.1,
  lanes = lanes
}

local DEG_TO_RAD = math.pi / 180
local RAD_TO_DEG = 180 / math.pi
local speed = 0.25 -- meteres per second

local co = coroutine.create(control.pure_pursuit(path, 0.25, speed))


local function parse_vicon(msg)
  if not msg.tri1 then return end
  local tri1 = msg.tri1
  pose_rbt = vector.pose{
    tri1.translation[1]/1e3, tri1.translation[2]/1e3, tri1.rotation[3]
  }
  print("==")
  print("Pose", pose_rbt)
----[[
  local running, dheading, ipath = coroutine.resume(co, pose_rbt)
  if not running then
    print("Not running", dheading)
    racecar.announce("control", {
                   dheading = 0,
                   velocity = 0
                   })
    return os.exit()
  elseif dheading==true then
    print("Restarting")
    co = coroutine.create(control.pure_pursuit(path, 0.25, speed))
    return
  elseif type(dheading)~='number' then
    print("Improper", dheading, ipath)
    return
  end
  
  print("Path", ipath, path[ipath])
  print("dHeading", dheading * RAD_TO_DEG)

--]]


  env.observer = pose_rbt
  racecar.announce("risk", env)
----[[
  racecar.announce("control", {
                   dheading = dheading,
                   velocity = 5
                   })
--]]
end

racecar.listen{
  ['vicon'] = parse_vicon
}

