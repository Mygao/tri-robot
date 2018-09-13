#!/usr/bin/env luajit

local unpack = unpack or require'table'.unpack
local ffi = require'ffi'

ffi.cdef[[
int dijkstra_matrix(double* cost_to_go, // output
                    double* costmap, //input
                    unsigned int m, unsigned int n,
                    int iGoal, int jGoal,
                    int nNeighbors);
]]

local neighbors = {
  --// 4-connected
  {-1,0, 1.0}, {1,0, 1.0}, {0,-1, 1.0}, {0,1, 1.0},
  --// 8-connected
  {-1,-1, math.sqrt(2)}, {1,-1, math.sqrt(2)}, {-1,1, math.sqrt(2)}, {1,1, math.sqrt(2)},
  --// 16-connected
  {2,1,math.sqrt(5)}, {1,2,math.sqrt(5)}, {-1,2,math.sqrt(5)}, {-2,1,math.sqrt(5)},
  {-2,-1,math.sqrt(5)}, {-1,-2,math.sqrt(5)}, {1,-2,math.sqrt(5)}, {2,-1,math.sqrt(5)},
};

-- local m, n = 320, 240
local m, n = 10, 12
local costmap = ffi.new('double[?]', m*n)

local cost_to_go = ffi.new('double[?]', m*n)

for i=0,m-1 do
  for j=0,n-1 do
    local cost = math.floor(math.random(100) / 10) + 1
    costmap[i * n + j] = cost
  end
end

local igoal, jgoal = 0, 0
local nNeighbors = 4
local istart, jstart = 10, 10

local dijkstra = ffi.load('dijkstra')
dijkstra.dijkstra_matrix(cost_to_go, costmap,
                         m, n, igoal, jgoal, nNeighbors);


for i=0,m-1 do
  for j=0,n-1 do
    local cost = costmap[i * n + j]
    io.write(cost, ' ')
  end
  io.write('\n')
end

local cost
for i=0,m-1 do
  for j=0,n-1 do
    io.write(cost_to_go[i * n + j], ' ')
  end
  io.write('\n')
end

local path = {}
table.insert(path, {istart, jstart})

local i0, j0 = istart, jstart
local i1, j1
local k
local min_v

while (i0 ~= igoal or j0 ~= jgoal) do
  -- Iterate over neighbor items
  min_v = math.huge
  for k = 1, nNeighbors do
    local di, dj = unpack(neighbors[k])
    i1 = i0 + di
    j1 = j0 + dj
    if i1>=0 and i1<m and j1>=0 and j1<n then
      local ind1 = i1 * n + j1
      local c2g = cost_to_go[ind1]
      if c2g < min_v then
        min_v = c2g
        i0 = i1
        j0 = j1
      end
    end
    -- Grab the cost
  end
  print("path", i0, j0, i1, j1)
  if min_v < math.huge then
    table.insert(path, {i0, j0})
  end
end
print("Path", type(path))
for i, v in ipairs(path) do
  print("Path "..i, unpack(v))
end
