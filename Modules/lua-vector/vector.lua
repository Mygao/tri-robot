local vector  = {}
local mt      = {}

local sqrt = require'math'.sqrt
local pow = require'math'.pow

function vector.ones(n)
  local t = {}
  for i = 1,(n or 1) do t[i] = 1 end
  return setmetatable(t, mt)
end

local function zeros(n)
  n = n or 0
  local t = {}
  for i = 1, n do t[i] = 0 end
  return setmetatable(t, mt)
end
vector.zeros = zeros

local function new(t)
  local ty = type(t)
  if ty=='number' then
    return zeros(t)
  elseif ty=='userdata' then
    local n = #t
    if type(n)~='number' then n = n[1] end
    local tt = {}
    for i=1,n do tt[i] = t[i] end
    t = tt
  elseif ty~='table' then
    t = {}
  end
  return setmetatable(t, mt)
end
vector.new = new

local function copy(t, tt)
  tt = tt or {}
  for i=1,#t do tt[i] = t[i] end
  return setmetatable(tt, mt)
end
vector.copy = copy

function vector.count(start, n)
  local t = {}
  n = n or 1
  for i = 1,n do t[i] = start+i-1 end
  return setmetatable(t, mt)
end

function vector.slice(v1, istart, iend)
  local v = {}
  istart = istart or 1
  iend = iend or #v1
  if istart==iend then return v1[istart] end
  for i = 1,iend-istart+1 do
    v[i] = v1[istart+i-1] or (0 / 0)
  end
  return setmetatable(v, mt)
end

function vector.contains(v1, num)
  for i=1,#v1 do
    if v1[i]==num then return true end
  end
  return false
end

local function add(v1, v2)
  local v = {}
  for i = 1, #v1 do v[i] = v1[i] + v2[i] end
  return setmetatable(v, mt)
end
-- In-place addition
local function iadd(v1, v2)
  for i = 1, #v1 do v1[i] = v1[i] + v2[i] end
  return v1
end
vector.iadd = iadd

local function norm(v1)
  local s = 0
  for i = 1, #v1 do s = s + pow(v1[i], 2) end
  return sqrt(s)
end
vector.norm = norm
function vector.normsq(v1)
  local s = 0
  for i = 1, #v1 do s = s + pow(v1[i], 2) end
  return s
end

local function sum(v1, w)
  local s
  if type(w)=='table' then
    s = v1[1] * w[1]
    for i = 2, #v1 do s = s + v1[i] * w[i] end
  else
    s = v1[1]
    -- Must copy, in case only one element
    s = type(s)=='table' and copy(s) or s
    for i = 2, #v1 do s = s + v1[i] end
  end
  return s
end
vector.sum = sum
-- Recursive sum
local function rsum(v, idx, initial)
  idx = idx or 1
  initial = initial or 0
  if idx > #v then return initial end
  return rsum(v, idx + 1, v[idx] + initial)
end
vector.rsum = rsum

local function sub(v1, v2)
  local v = {}
  for i = 1, #v1 do v[i] = v1[i] - v2[i] end
  return setmetatable(v, mt)
end
vector.sub = sub

local function mulnum(v1, a)
  local v = {}
  for i = 1, #v1 do v[i] = a * v1[i] end
  return setmetatable(v, mt)
end
vector.mulnum = mulnum

local function divnum(v1, a)
  local v = {}
  for i = 1, #v1 do v[i] = v1[i] / a end
  return setmetatable(v, mt)
end
-- In-place division
local function idivnum(v, a)
  for i = 1, #v do v[i] = v[i] / a end
  return v
end
vector.idivnum = idivnum

function vector.unit(v1)
  local m = norm(v1)
  return (m > 0) and divnum(v1, m) or zeros(#v1)
end


local function dot(v1, v2)
  local s = 0
  for i = 1, #v1 do s = s + v1[i] * v2[i] end
  return s
end
vector.dot = dot

local function mul(v1, v2)
  if type(v2) == "number" then
    return mulnum(v1, v2)
  elseif type(v1) == "number" then
    return mulnum(v2, v1)
  else
    return dot(v1, v2)
  end
end
vector.mul = mul

local function unm(v1)
  return mulnum(v1, -1)
end

local function eq(v1, v2)
	if #v1~=#v2 then return false end
  for i,v in ipairs(v1) do
    if v~=v2[i] then return false end
  end
  return true
end

local function div(v1, v2)
  if type(v2) == "number" then
    return divnum(v1, v2)
  else
    -- pointwise
    local v = {}
    for i,val in ipairs(v1) do v[i] = val / v2[i] end
    return setmetatable(v, mt)
  end
end

local function v_tostring(v1, formatstr)
  formatstr = formatstr or "%g"
  local str = "{"..string.format(formatstr, v1[1] or 0/0)
  for i = 2, #v1 do
    str = str..", "..string.format(formatstr,v1[i])
  end
  str = str.."}"
  return str
end

----[[
-- Metatables for pose vectors
local mt_pose = {}
-- TODO: Use as a utility pose file, too
local function pose_index(p, idx)
  if idx=='x' then
    return p[1]
  elseif idx=='y' then
    return p[2]
  elseif idx=='a' then
    return p[3]
  end
end

local function pose_newindex(p, idx, val)
  if idx=='x' then
    p[1] = val
  elseif idx=='y' then
    p[2] = val
  elseif idx=='a' then
    p[3] = val
  end
end

local function pose_tostring(p)
  return string.format(
    "{x=%g, y=%g, a=%g degrees}",
    p[1], p[2], p[3]*180/math.pi
  )
end

function vector.pose(t)
  if type(t)=='table' and #t>=3 then
    -- good pose
    return setmetatable(t, mt_pose)
  end
  return setmetatable({0,0,0}, mt_pose)
end

-- Ability for a weighted mean of vectors
function vector.mean(t, w)
  local s = zeros(#t[1])
  if type(w)=='table' then
    for i,v in ipairs(t) do
      iadd(s, mulnum(v, w[i]))
    end
  else
    for i=1,#t do iadd(s, t[i]) end
    idivnum(s, #t)
  end
  return setmetatable(s, mt)
end

-- Pose vector
mt_pose.__add = add
mt_pose.__sub = sub
mt_pose.__mul = mul
mt_pose.__div = div
mt_pose.__unm = unm
mt_pose.__index    = pose_index
mt_pose.__newindex = pose_newindex
mt_pose.__tostring = pose_tostring
--]]

-- Regular vector
mt.__eq  = eq
mt.__add = add
mt.__sub = sub
mt.__mul = mul
mt.__div = div
mt.__unm = unm
mt.__tostring = v_tostring

return vector
