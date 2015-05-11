--------------------------------
-- Humanoid arm state
-- (c) 2013 Stephen McGill, Seung-Joon Yi
--------------------------------
local state = {}
state._NAME = ...

local Body   = require'Body'
local vector = require'vector'
local plugins = require'armplugins'

local t_entry, t_update, t_finish
local timeout = 30.0

local pco, lco, rco
local okL, qLWaypoint, qLWaist
local okR, qRWaypoint, qRWaist

local pStatus, lmovement, rmovement

function state.entry()
  io.write(state._NAME, ' Entry\n')
  local t_entry_prev = t_entry
  t_entry = Body.get_time()
  t_update = t_entry

	local model ={
		x = 0.52,
		y = -0.19,
		z = -0.05,
		yaw = 0,
		hinge = -1,
		roll = -math.pi/2,
		hand = 'right'
	}
	pco, lco, rco = plugins.gen('pulldoor', model)
	okL = false
	okR = false

end

function state.update()
	--  io.write(state._NAME,' Update\n')
  local t  = Body.get_time()
  local dt = t - t_update
  t_update = t
  --if t-t_entry > timeout then return'timeout' end

	-- Evaluate the model
	local pStatus = type(pco)=='thread' and coroutine.status(pco)
	if not pStatus then
		-- There may be some error, since pco is not a thread
		print('pco | Failed to start')
		return'teleopraw'
	elseif pStatus=='dead' then
		return 'done'
	elseif pStatus=='suspended' then
		okP, lmovement, rmovement = coroutine.resume(pco)
		-- Check for errors
		if not okP then
			print(state._NAME, 'pco', okL, lmovement)
			return'teleopraw'
		end
		-- Check for new movement via
		if type(lmovement)=='thread' then lco = lmovement end
		if type(rmovement)=='thread' then rco = rmovement end
	end

	local lStatus = type(lco)=='thread' and coroutine.status(lco)
	local rStatus = type(rco)=='thread' and coroutine.status(rco)

	if not lStatus then
		print('lco | Failed to start')
		return'teleopraw'
	end
	if not rStatus then
		print('rco | Failed to start')
		return'teleopraw'
	end

	local qLArm = Body.get_larm_position()
	local qRArm = Body.get_rarm_position()
	local qWaist = Body.get_waist_position()

	if lStatus=='suspended' then
		okL, qLWaypoint, qLWaist =
			coroutine.resume(lco, qLArm, qWaist, unpack(lmovement))
	end
	if not okL then
		print(state._NAME, 'L', okL, qLWaypoint, lco)
		Body.set_larm_command_position(qLArm)
		return'teleopraw'
	end

	if rStatus=='suspended' then
		okR, qRWaypoint, qRWaist =
			coroutine.resume(rco, qRArm, qWaist, unpack(rmovement))
	end
	if not okR then
		print(state._NAME, 'R', okR, qRWaypoint, rco)
		Body.set_rarm_command_position(qRArm)
		return'teleopraw'
	end

	if type(qLWaypoint)=='table'then
		Body.set_larm_command_position(qLWaypoint)
	end
	if type(qRWaypoint)=='table'then
		Body.set_rarm_command_position(qRWaypoint)
	end

	if qLWaist and qRWaist then
		print(state._NAME, 'Conflicting Waist')
	elseif qLWaist then
		Body.set_waist_command_position(qLWaist)
	elseif qRWaist then
		Body.set_waist_command_position(qRWaist)
	end

	-- Always have an active item here?
	if lStatus=='dead' and rStatus=='dead' then
		print(state._NAME, 'No active threads')
		return 'teleopraw'
	end

end

function state.exit()
	io.write(state._NAME, ' Exit\n')

	local qcLArm = Body.get_larm_position()
	local qcRArm = Body.get_rarm_position()
	hcm.set_teleop_larm(qcLArm)
  hcm.set_teleop_rarm(qcRArm)
end

return state
