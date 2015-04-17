--------------------------------
-- Humanoid arm state
-- (c) 2013 Stephen McGill, Seung-Joon Yi
--------------------------------
local state = {}
state._NAME = ...

local USE_TR = false
local NO_YAW_FIRST = true

local Body   = require'Body'
local vector = require'vector'
local T = require'Transform'
local movearm = require'movearm'

local t_entry, t_update, t_finish
local timeout = 30.0

--[[
local trLGoal = T.transform6D(Config.arm.trLArm0)
local trRGoal = T.transform6D(Config.arm.trRArm0)
--]]
-- From the IK solution above, in webots
----[[
local qLGoal = Config.demo.arms.dean.qLArm
local qRGoal = Config.demo.arms.dean.qRArm
--]]

local shoulderLGoal, shoulderRGoal = 5*DEG_TO_RAD, -5*DEG_TO_RAD

local lPathIter, rPathIter
local setShoulderYaw

function state.entry()
  print(state._NAME..' Entry' )
  local t_entry_prev = t_entry
  t_entry = Body.get_time()
  t_update = t_entry

	local qL = Body.get_larm_position()
	local qR = Body.get_rarm_position()

  -- To get to the IK solution
	if USE_TR then
  	lPathIter, rPathIter, qLGoal, qRGoal =
			movearm.goto_tr_via_q(trLGoal, trRGoal, {shoulderLGoal}, {shoulderRGoal})
	else
		-- Given the IK solution
		lPathIter, rPathIter = movearm.goto_q(qLGoal, qRGoal)
	end

	-- Ensure we have them
	assert(lPathIter, 'No left iterator')
	assert(rPathIter, 'No right iterator')

  if NO_YAW_FIRST then
    setShoulderYaw = true
  else
    -- First, ignore the shoulderYaw, since it can cause issues of self collision
    qL[3] = -20*DEG_TO_RAD
    qR[3] = 20*DEG_TO_RAD
    lPathIter, rPathIter = movearm.goto_q(qL, qR)
    setShoulderYaw = false
  end

end

function state.update()
	--  print(state._NAME..' Update' )
  local t  = Body.get_time()
  local dt = t - t_update
  t_update = t
  if t-t_entry > timeout then return'timeout' end

	-- Timing necessary
	local qLArm = Body.get_larm_command_position()
	local moreL, q_lWaypoint = lPathIter(qLArm, dt)

	local qRArm = Body.get_rarm_command_position()
	local moreR, q_rWaypoint = rPathIter(qRArm, dt)

	Body.set_larm_command_position(q_lWaypoint)
	Body.set_rarm_command_position(q_rWaypoint)
	-- Check if done
	if not moreL and not moreR then
    --print('setShoulderYaw', setShoulderYaw)
    if setShoulderYaw then
  		return 'done'
    else
			-- ignore sanitization for the init position, which is absolutely known
      lPathIter, rPathIter = movearm.goto_q(qLGoal, qRGoal)
      setShoulderYaw = true
    end
	end

end

function state.exit()
	io.write(state._NAME, ' Exit\n')

	local qcLArm = Body.get_larm_command_position()
	local qcRArm = Body.get_rarm_command_position()
	hcm.set_teleop_larm(qcLArm)
  hcm.set_teleop_rarm(qcRArm)
	hcm.set_teleop_compensation(0)
end

return state
