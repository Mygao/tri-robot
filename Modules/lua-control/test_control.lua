#!/usr/bin/env luajit
local coroutine = require'coroutine'
local unpack = unpack or require'table'.unpack

local control = require'control'
local transform = require'transform'
local vector = require'vector'

-- Pose is x, y, theta

local lane_outer =  {
  {2.25, 2}, {2.25, 4.25},
  {1.75, 4.75}, {-0.75, 4.75},
  {-1.25, 4.25}, {-1.25, -1.5},
  {-0.75, -2}, {1.75, -2},
  {2.25, -1.5},
  {2.25, 1.5}
}
local lane_inner = {
  {1.5, 1.5}, {1.5, -1},
  {1, -1.5}, {0, -1.5},
  {-0.5, -1}, {-0.5, 3.75},
  {0, 4.25}, {1, 4.25},
  {1.5, 3.75}, {1.5, 2}
}

local lanes = {}
table.insert(lanes, lane_outer)
table.insert(lanes, lane_inner)

-- Take pairs
local path = {}
local ds = 0.05
local my_lane = lane_outer
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
pose_rbt.x = my_lane[1][1]
pose_rbt.y = my_lane[1][2]
pose_rbt.a = math.atan2(my_lane[2][2]-my_lane[1][2], my_lane[2][1]-my_lane[1][1])

local env = {
  viewBox = {-3, -5.5, 7, 9},
  observer = pose_rbt,
  time_interval = 0.1,
  speed = 0.1,
  lanes = lanes
}

local DEG_TO_RAD = math.pi / 180
local RAD_TO_DEG = 180 / math.pi
local speed = 0.1 -- meteres per second
local dt = 0.1
local dheading_max = 90 * DEG_TO_RAD -- radians per second
local iloop = 0
local wheel_base = 0.30

local co = coroutine.create(control.pure_pursuit(path, 0.5, speed))

local racecar = require'racecar'
local usleep = require'unix'.usleep

while iloop < 2000 do
  print(iloop)
  -- print(env)
  print("Pose", pose_rbt)
  local running, dheading, ipath = coroutine.resume(co, pose_rbt)
  if not running then
    break
  elseif not dheading then
    break
  end
  print("Path", ipath, path[ipath])

  -- Move the robot forward
  local dx, dy = transform.rot2D(speed * dt, 0, pose_rbt[3])

  dheading = math.min(math.max(-dheading_max, dheading), dheading_max)

  local da = speed / wheel_base * dheading * dt

  local dpose = vector.pose({dx, dy, da})

  print("dpose", dpose)

  pose_rbt.x = pose_rbt.x + dpose.x
  pose_rbt.y = pose_rbt.y + dpose.y
  pose_rbt.a = pose_rbt.a + dpose.a

  env.observer = pose_rbt
  usleep(1e5)
  racecar.announce("risk", env)

  iloop = iloop + 1
end
