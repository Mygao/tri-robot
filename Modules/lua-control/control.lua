local lib = {}

local coyield = require'coroutine'.yield
local cos, sin = require'math'.cos, require'math'.sin
local atan2 = require'math'.atan2
local unpack = unpack or require'table'.unpack
local dist = require'vector'.distance
local tf2D = require'transform'.tf2D
local kdtree = require'kdtree'

-- Usage: c
-- L is lookahead distance
-- threshold_close is how far away from the path before we give up
local function pure_pursuit(path, lookahead_time, desired_speed, threshold_close)
  -- Initialization bits
  if type(desired_speed) ~= 'number' then
    desired_speed = 0.1 -- meters per second
  end
  if type(threshold_close) ~= 'number' then
    threshold_close = 0.5 -- meters
  end
  if type(lookahead_time) ~= 'number' then
    lookahead_time = 0.5 -- seconds
  end
  local lookahead = lookahead_time * desired_speed
  -- Two dimensional points
  local tree = kdtree.create(2)
  -- Populate the tree with the points on the path
  for i, p in ipairs(path) do tree:insert(p, i) end
  local p_final = path[#path]
  local id_path_last = 0
  -- Give a function to be created/wrapped by coroutine
  return function(pose_rbt)
    while pose_rbt do
      local d_goal = dist(pose_rbt, p_final)
      -- Now, the update routine
      local x_rbt, y_rbt, th_rbt = unpack(pose_rbt)
      -- Find the lookahead point
      local x_ahead, y_ahead = tf2D(lookahead, 0, th_rbt, x_rbt, y_rbt)
      -- Find this in the path
      local nearby = tree:nearest({x_ahead, y_ahead}, threshold_close)
      if not nearby then
        return false, string.format("Too far: (%.2f, %.2f) %.2f", x_ahead, y_ahead, threshold_close)
      end
      -- The reference point is the nearby one furthest along in the path
      -- TODO: Deal with loops
      -- table.sort(nearby, function(a, b) return a.user > b.user end)
      local p_near = nearby[1]
      local id_path = p_near.user
      -- Check if we are done
      if id_path==#path and d_goal <= lookahead then
        return true
      end
      if id_path - id_path_last > 5 then
        id_path = id_path_last + 1
      end
      id_path_last = math.max(id_path, id_path_last)
      id_path_last = id_path
      -- Generate the heading
      local x_ref, y_ref = unpack(p_near)
      local dx = x_ref - x_rbt
      local dy = y_ref - y_rbt
      local alpha = atan2(dy, dx) - th_rbt
--[[
      if alpha>math.pi then
        alpha = alpha - 2 * math.pi
      elseif alpha < -math.pi then
        alpha = alpha + 2 * math.pi
      end
--]]
      local kappa = 2 * sin(alpha) / lookahead
      local omega = kappa * desired_speed
      -- Give result and take the next pose
      pose_rbt = coyield(omega, id_path)
    end
    return false, "No pose"
  end

end
lib.pure_pursuit = pure_pursuit

return lib
