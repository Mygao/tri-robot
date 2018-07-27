#!/usr/bin/env luajit

local math = require'math'
if not unpack then
  unpack = require'table'.unpack
end
math.randomseed(1)

local kdtree = require'kdtree'

local nDim = 2
local kd = assert(kdtree.create(nDim))

local lowerBoundVertex = nil
local lowerBoundCost = math.huge

local tree = {}

local start = {costFromRoot=0, costFromParent=0, id=#tree + 1, parent=nil}
for _=1,nDim do table.insert(start, 0) end
local goal = {}
for _=1,nDim do table.insert(goal, 1) end

local interval = {}
for _=1,nDim do table.insert(interval, {-1, 1}) end
local ranges = {}
local centers = {}
for i=1,nDim do
  local a, b = unpack(interval[i])
  table.insert(ranges, b - a)
  table.insert(centers, (a + b)/2)
end
assert(kd:insert(start, start.id))
tree[start.id] = start

local BIAS_THRESHOLD = 0.1 -- Fraction
local GOAL_PERTURBATION = 0.05 -- meters
local function sample()
  local out = {}
  local bias = math.random()
  if bias < BIAS_THRESHOLD then
    for i=1,nDim do
      -- Interval [-2, 1]
      local a, b = unpack(interval[i])
      local perturbation = (math.random() - 0.5) * GOAL_PERTURBATION
      out[i] = math.max(a, math.min(b, goal[i] + perturbation))
    end
  else
    for i=1,nDim do
      -- Interval [-2, 1] has ranges of 3, center of -0.5
      out[i] = (math.random() - 0.5) * ranges[i] + centers[i]
    end
  end
  return out
end

-- Iterate the dimensions
-- Return the distance and each dimensions' distances
local function distState(from, to)
  local diff = {}
  for i=1,#from do diff[i] = from[i] - to[i] end
  local s = 0
  for _, d in ipairs(diff) do s = s + math.pow(d, 2) end
  return math.sqrt(s), diff
end

local function is_collision()
  return false
end

local CLOSE_DISTANCE = 0.01
local function is_near_goal(state)
  return distState(state, goal) < CLOSE_DISTANCE
end

-- local NEAR_RADIUS = 0.01 -- meters
local function get_ball_radius(numVertices, gamma)
  gamma = gamma or 1
  return gamma * math.pow(math.log(numVertices + 1.0)/(numVertices + 1.0), 1.0/nDim)
end

-- Walk from state to goal
local DISCRETIZATION_STEP = 0.005 -- TODO: Unit
-- Returns boolean idicating if we got to the goal state and
-- the final state that we did get to,
-- walking in one direction to the goal
local function extendTo(state, target)
  -- Assume that both to and from are collision-free
  local cost, dists = distState(state, target)
  local incrementTotal = cost / DISCRETIZATION_STEP
  local numSegments = math.floor(incrementTotal)
  local cur = {unpack(state)}
  local exactConnection = true
  for _=1,numSegments do
    if is_collision(cur) then
      exactConnection = false
      break
    end
    for i=1, nDim do
      cur[i] = cur[i] + dists[i]
    end
  end
  return exactConnection, cur
end

-- Returns indicator if we can connect
local function findBestCandidate(state, neighbors)
  -- Which neighbor should be our parent?
  local candidates = {}
  for i, neighbor in ipairs(neighbors) do
    local costFromParent = distState(neighbor, state)
    local costFromRoot = neighbor.costFromRoot + costFromParent
    local parent = tree[neighbor.id]
    candidates[i] = {
      parent = parent,
      costFromRoot = costFromRoot,
      costFromParent = costFromParent,
      unpack(state)
    }
  end
  -- Sort by costFromRoot
  -- TODO: Check increasing v. decreasing
  table.sort(candidates, function(a, b) return a.costFromRoot < b.costFromRoot end)
  -- Now, try to extend this state to the best neighbor
  for _, c in ipairs(candidates) do
    local exactConnection = extendTo(state, c.parent)
    if exactConnection then return true, c end
  end
  return false
end

local function iteration()
  -- // 1. Sample a new state
  local stateRandom
  local n_sample_tries = 0
  repeat
    if n_sample_tries>100 then
      return false, "Number of sample tries exceeded!"
    end
    stateRandom = sample()
    n_sample_tries = n_sample_tries + 1
  until not is_collision(stateRandom)

  -- // 2. Compute the set of all near vertices
  local numVertices = kd:size()
  -- // 3.b Extend the best parent within the near vertices
  local nearby = kd:nearest(stateRandom, get_ball_radius(numVertices))
  local within_ball = type(nearby) == 'table'
  -- // 3.a Extend the nearest
  nearby = nearby or kd:nearest(stateRandom)
  print("Nearby:", #nearby)
  for i=1,#nearby do
    local id = nearby[i].user
    nearby[i] = tree[id]
  end
  -- // 3. Find the best parent and extend from that parent
  local is_exact, candidate = findBestCandidate(stateRandom, nearby)
  if is_exact then
    -- // 3.c add the trajectory from the best parent to the tree
    candidate.id = #tree + 1
    print("Candidate #"..tostring(candidate.id), unpack(candidate))
    assert(kd:insert(candidate, candidate.id))
    io.stderr:write("Adding to the KD tree\n")
    io.stderr:flush()
    tree[candidate.id] = candidate
    -- Check if near the goal
    print("Check if near goal")
    if is_near_goal(candidate) and candidate.costFromRoot < lowerBoundCost then
      lowerBoundVertex = candidate
      lowerBoundCost = candidate.costFromRoot
    end
  else
    print("No candidate!")
  end

  -- // 4. Rewire the tree
  if within_ball then
    -- Rewire
  end
  return true
end

-- Periodically, check to find the best trajectory
-- Should do this within a computational bound

for i=1,1000 do
  local res = assert(iteration())
  print(string.format("Iteration %d | Cost:%0.3f",
                      i, lowerBoundVertex and lowerBoundCost or 0/0))
  -- for _, vertex in ipairs(tree) do print(vertex.id, unpack(vertex)) end
end