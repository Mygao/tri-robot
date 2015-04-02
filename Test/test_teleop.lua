#!/usr/bin/env luajit
-- (c) 2014 Stephen McGill
pcall(dofile,'fiddle.lua')
pcall(dofile, '../fiddle.lua')

local T = require'Transform'
local K = require'K_ffi'
local sanitize = K.sanitize
local vector = require'vector'

-- Look up tables for the test.lua script (NOTE: global)
code_lut, char_lut, lower_lut = {}, {}, {}

local narm = #Body.get_larm_position()
local selected_arm = 0 -- left to start

local DO_IMMEDIATE = true
local LARM_DIRTY, RARM_DIRTY = false, false
local qLtmp, qL0
local function get_larm(refresh)
	if refresh then qLtmp = hcm.get_teleop_larm() end
	return qLtmp
end
-- Set initial arms in tmp and 0
qL0 = vector.copy(get_larm(true))
local function set_larm(q, do_now)
	if type(q)=='table' and #q==#qLtmp then
		vector.copy(q, qLtmp)
		LARM_DIRTY = true
	end
	if q==true or do_now==true then
		LARM_DIRTY = false
		local curTeleop = hcm.get_teleop_larm()
		if curTeleop~=qL0 then
			print('L Outdated...')
			vector.copy(curTeleop, qL0)
			qLtmp = curTeleop
			return
		end
		hcm.set_teleop_larm(qLtmp)
		vector.copy(qLtmp, qL0)
		arm_ch:send'params'
	end
end
local qRtmp, qR0
local function get_rarm(refresh)
	if refresh then qRtmp = hcm.get_teleop_rarm() end
	return qRtmp
end
-- Set initial arms in tmp and 0
qR0 = vector.copy(get_rarm(true))
local function set_rarm(q, do_now)
	if type(q)=='table' and #q==#qRtmp then
		vector.copy(q, qRtmp)
		RARM_DIRTY = true
	end
	if q==true or do_now==true then
		LARM_DIRTY = false
		local curTeleop = hcm.get_teleop_rarm()
		if curTeleop~=qR0 then
			print('R Outdated...')
			vector.copy(curTeleop, qR0)
			qRtmp = curTeleop
			return
		end
		hcm.set_teleop_rarm(qRtmp)
		vector.copy(qRtmp, qR0)
		arm_ch:send'params'
	end
end
-- Immediately write the changes?
char_lut["'"] = function()
  DO_IMMEDIATE = not DO_IMMEDIATE
end

-- Sync the delayed sending
char_lut[' '] = function()
	if LARM_DIRTY then set_larm(true) end
	if RARM_DIRTY then set_rarm(true) end
end

-- Backspace (Win/Linux) / Delete (OSX)
local USE_COMPENSATION
code_lut[127] = function()
	-- Disable the compensation
	USE_COMPENSATION = hcm.get_teleop_compensation()
	----[[
	USE_COMPENSATION = USE_COMPENSATION + 1
	USE_COMPENSATION = USE_COMPENSATION>2 and 0 or USE_COMPENSATION
	--]]
	USE_COMPENSATION = USE_COMPENSATION==1 and 2 or 1
	hcm.set_teleop_compensation(USE_COMPENSATION)
	arm_ch:send'params'
end

-- Switch to head teleop
local arm_mode = true
char_lut['`'] = function()
  arm_mode = not arm_mode
end

-- State Machine events
char_lut['1'] = function()
  body_ch:send'init'
end
char_lut['2'] = function()
	head_ch:send'teleop'
end
char_lut['3'] = function()
	arm_ch:send'ready'
end
char_lut['4'] = function()
	arm_ch:send'teleop'
end
char_lut['5'] = function()
  --head_ch:send'trackhand'
  body_ch:send'approach'
end
char_lut['6'] = function()
  arm_ch:send'poke'
end

char_lut['8'] = function()
  head_ch:send'teleop'
  motion_ch:send'stand'
	if mcm.get_walk_ismoving()>0 then
		mcm.set_walk_stoprequest(1)
	end
end
char_lut['9'] = function()
  head_ch:send'teleop'
  motion_ch:send'hybridwalk'
end

char_lut['r'] = function()
  if selected_arm==0 then
		local options = hcm.get_teleop_loptions()
		options[1] = math.max(options[1] - DEG_TO_RAD, 0)
		hcm.set_teleop_loptions(options)
		arm_ch:send'params'
		--[[
		local qLArm = get_larm()
    --print('Pre',qLArm*RAD_TO_DEG)
		local tr = K.forward_larm(qLArm)
		local iqArm = K.inverse_larm(tr, qLArm, qLArm[3] - DEG_TO_RAD)
		local itr = K.forward_larm(iqArm)
		sanitize(iqArm, qLArm)
		set_larm(iqArm, DO_IMMEDIATE)
		--]]
  else
		local options = hcm.get_teleop_roptions()
		options[1] = math.min(options[1] - DEG_TO_RAD, 0)
		hcm.set_teleop_roptions(options)
		arm_ch:send'params'
		--[[
    local qRArm = get_rarm()
		local tr = K.forward_rarm(qRArm)
		local iqArm = K.inverse_rarm(tr, qRArm, qRArm[3] - DEG_TO_RAD)
		local itr = K.forward_rarm(iqArm)
		sanitize(iqArm, qRArm)
		set_rarm(iqArm, DO_IMMEDIATE)
		--]]
  end
end

char_lut['t'] = function()
  if selected_arm==0 then
		local options = hcm.get_teleop_loptions()
		options[1] = math.min(options[1] + DEG_TO_RAD, 90*DEG_TO_RAD)
		hcm.set_teleop_loptions(options)
		arm_ch:send'teleop'
		--[[
    local qLArm = get_larm()
		local tr = K.forward_larm(qLArm)
		local iqArm = K.inverse_larm(tr, qLArm, qLArm[3] + DEG_TO_RAD)
		local itr = K.forward_larm(iqArm)
		sanitize(iqArm, qLArm)
		set_larm(iqArm, DO_IMMEDIATE)
		--]]
  else
		local options = hcm.get_teleop_roptions()
		options[1] = math.max(options[1] + DEG_TO_RAD, -90*DEG_TO_RAD)
		hcm.set_teleop_roptions(options)
		arm_ch:send'teleop'
		--[[
    local qRArm = get_rarm()
		local tr = K.forward_rarm(qRArm)
		local iqArm = K.inverse_rarm(tr, qRArm, qRArm[3] + DEG_TO_RAD)
		local itr = K.forward_rarm(iqArm)
		sanitize(iqArm, qRArm)
		set_rarm(iqArm, DO_IMMEDIATE)
		--]]
  end
end

--
code_lut[92] = function()
  -- Backslash
  selected_arm = 1 - selected_arm
end
local selected_joint = 1
char_lut[']'] = function()
  selected_joint = selected_joint + 1
  selected_joint = math.max(1, math.min(selected_joint, narm))
end
char_lut['['] = function()
  selected_joint = selected_joint - 1
  selected_joint = math.max(1, math.min(selected_joint, narm))
end

char_lut['='] = function()
  if selected_arm==0 then
    local pos = get_larm()
    local q0 = pos[selected_joint]
    q0 = q0 + 5 * DEG_TO_RAD
    pos[selected_joint] = q0
		set_larm(pos, DO_IMMEDIATE)
  else
    local pos = get_rarm()
    local q0 = pos[selected_joint]
    q0 = q0 + 5 * DEG_TO_RAD
    pos[selected_joint] = q0
		set_rarm(pos, DO_IMMEDIATE)
  end
end
char_lut['-'] = function()
  if selected_arm==0 then
    local pos = get_larm()
    local q0 = pos[selected_joint]
    q0 = q0 - 5 * DEG_TO_RAD
    pos[selected_joint] = q0
		set_larm(pos, DO_IMMEDIATE)
  else
    local pos = get_rarm()
    local q0 = pos[selected_joint]
    q0 = q0 - 5 * DEG_TO_RAD
    pos[selected_joint] = q0
		set_rarm(pos, DO_IMMEDIATE)
  end
end

--[[
local zyz = T.to_zyz(desired_tr)
print('des zyz:',zyz[1],zyz[2],zyz[3])
--]]
local function apply_pre(d_tr)
	if selected_arm==0 then --left
		local qLArm = get_larm()
		local fkL = K.forward_larm(qLArm)
		local trLGoal = d_tr * fkL
		local iqArm = vector.new(K.inverse_larm(trLGoal, qLArm))
		sanitize(iqArm, qLArm)
		set_larm(iqArm, DO_IMMEDIATE)
	else
		local qRArm = get_rarm()
		local fkR = K.forward_rarm(qRArm)
		local trRGoal = d_tr * fkR
		local iqArm = vector.new(K.inverse_rarm(trRGoal, qRArm))
		sanitize(iqArm, qRArm)
		set_rarm(iqArm, DO_IMMEDIATE)
	end
end

local function apply_post(d_tr)
	if selected_arm==0 then --left
		local qLArm = get_larm()
		local fkL = K.forward_larm(qLArm)
		local trLGoal = fkL * d_tr
		local iqArm = vector.new(K.inverse_larm(trLGoal, qLArm))
		sanitize(iqArm, qLArm)
		set_larm(iqArm, DO_IMMEDIATE)
	else
		local qRArm = get_rarm()
		local fkR = K.forward_rarm(qRArm)
		local trRGoal = fkR * d_tr
		local iqArm = vector.new(K.inverse_rarm(trRGoal, qRArm))
		sanitize(iqArm, qRArm)
		set_rarm(iqArm, DO_IMMEDIATE)
	end
end

-- Translate the end effector
local ds = 0.01
local dr = 3 * DEG_TO_RAD
local pre_arm = {
  u = T.trans(0,0,ds),
  m = T.trans(0,0,-ds),
  i = T.trans(ds,0,0),
  [','] = T.trans(-ds,0,0),
  j = T.trans(0,ds,0),
  l = T.trans(0,-ds,0),
	y = T.rotY(dr),
  n = T.rotY(-dr),
}

-- Rotate (locally) the end effector
local post_arm = {
  e = T.rotY(dr),
  ['c'] = T.rotY(-dr),
  a = T.rotZ(dr),
  ['d'] = T.rotZ(-dr),
  ["q"] = T.trans(0,0,ds),
  ['z'] = T.trans(0,0,-ds),
  ["w"] = T.trans(ds,0,0),
  ['x'] = T.trans(-ds,0,0),
}

local dHead = 5*DEG_TO_RAD
local head = {
  w = dHead * vector.new{0,-1},
  a = dHead * vector.new{1, 0},
  s = dHead * vector.new{0,1},
  d = dHead * vector.new{-1, 0},
}
local function apply_head(dHead)
  if not dHead then return end
  local goalBefore = hcm.get_teleop_head()
  local goalAfter = goalBefore + dHead
  hcm.set_teleop_head(goalAfter)
end

local dWalk = 0.05
local daWalk = 5*DEG_TO_RAD
local walk = {
  i = dWalk * vector.new{1, 0, 0},
  [','] = dWalk * vector.new{-1, 0, 0},
  --
  j = dWalk * vector.new{0, 0, 1},
  l = dWalk * vector.new{0, 0, -1},
  --
  h = dWalk * vector.new{0, 1, 0},
  [';'] = dWalk * vector.new{0, -1, 0},
}
local function apply_walk(dWalk)
  if not dWalk then return end
  local goalBefore = mcm.get_walk_vel()
  local goalAfter = goalBefore + dWalk
  mcm.set_walk_vel(goalAfter)
end

-- Add the access to the transforms
setmetatable(char_lut, {
	__index = function(t, k)
    if (not arm_mode) then
      apply_head(head[k])
      if k=='k' then
        mcm.set_walk_vel({0,0,0})
      else
        apply_walk(walk[k])
      end
			return
    elseif pre_arm[k] then
			apply_pre(pre_arm[k])
			return
		elseif post_arm[k] then
			apply_post(post_arm[k])
			return
		end
		print('Unknown char')
	end
})

-- Global status to show (NOTE: global)
local color = require'util'.color
function show_status()
	local qlarm = Body.get_larm_position()
	local qrarm = Body.get_rarm_position()
	local fkL = K.forward_larm(qlarm)
	local fkR = K.forward_rarm(qrarm)
  local l_indicator = vector.zeros(#qlarm)
  l_indicator[selected_joint] = selected_arm==0 and 1 or 0
  local r_indicator = vector.zeros(#qlarm)
  r_indicator[selected_joint] = selected_arm==1 and 1 or 0
	--
  local larm_info = string.format('\n%s %s %s\n%s\n%s\n%s',
    util.color('Left Arm', 'yellow'),
    arm_mode and selected_arm==0 and '*' or '',
		l_indicator,
    'q: '..tostring(qlarm*RAD_TO_DEG),
		'tr: '..tostring(vector.new(T.position6D(fkL))),
		'teleop: '..tostring(qLtmp*RAD_TO_DEG)
  )
  local rarm_info = string.format('\n%s %s %s\n%s\n%s\n%s',
    util.color('Right Arm', 'yellow'),
    arm_mode and selected_arm==1 and '*' or '',
		r_indicator,
    'q: '..tostring(qrarm*RAD_TO_DEG),
    'tr: '..tostring(vector.new(T.position6D(fkR))),
		'teleop: '..tostring(qRtmp*RAD_TO_DEG)
  )
  local head_info = string.format('\n%s %s\n%s',
    util.color('Head', 'yellow'),
    (not arm_mode) and '*' or '',
    'q: '..tostring(Body.get_head_position()*RAD_TO_DEG)
  )
  local walk_info = string.format('\n%s %s\n%s\n%s',
    util.color('Walk', 'yellow'),
    (not arm_mode) and '*' or '',
    'Velocity: '..tostring(mcm.get_walk_vel()),
    'Odometry:'..tostring(mcm.get_status_odometry())
  )
  local info = {
    color('== Teleoperation ==', 'magenta'),
		'1: init, 2: head teleop, 3: armReady, 4: armTeleop, 5: headTrack, 6: poke',
		color(DO_IMMEDIATE and 'Immediate Send' or 'Delayed Send', DO_IMMEDIATE and 'red' or 'yellow'),
		'Compensation: '..tostring(USE_COMPENSATION),
    'BodyFSM: '..color(gcm.get_fsm_Body(), 'green'),
    'ArmFSM: '..color(gcm.get_fsm_Arm(), 'green'),
    'HeadFSM: '..color(gcm.get_fsm_Head(), 'green'),
    'MotionFSM: '..color(gcm.get_fsm_Motion(), 'green'),
    larm_info,
    rarm_info,
    head_info,
    walk_info,
    '\n'
  }
  if not IS_WEBOTS then io.write(table.concat(info,'\n')) end
end

-- Run the generic keypress library
return dofile(HOME..'/Test/test.lua')
