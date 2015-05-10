--------------------------------
-- Humanoid arm state
-- (c) 2013 Stephen McGill, Seung-Joon Yi
--------------------------------
local state = {}
state._NAME = ...

local Body   = require'Body'
local vector = require'vector'
local movearm = require'movearm'

local t_entry, t_update, t_finish
local timeout = 30.0

local lco, rco
local okL, qLWaypoint
local okR, qRWaypoint

local sequence, s = Config.arm.init

function state.entry()
  io.write(state._NAME, ' Entry\n')
  local t_entry_prev = t_entry
  t_entry = Body.get_time()
  t_update = t_entry

	local qL = Body.get_larm_position()
	local qR = Body.get_rarm_position()

	-- Avoid self collisions. Cannot place into the config, since require reading
	-- to customize the positions
	s = 0
	local stage = {
		left = {
			q = qL, duration = 5, timeout = 7,
			via='jointspace'
		},
		right = {
			q = qR, duration = 5, timeout = 7,
			via='jointspace'
		}
	}

	lco, rco = movearm.goto(stage.left, stage.right)

	okL = false
	okR = false

end

function state.update()
	--  io.write(state._NAME,' Update\n')
  local t  = Body.get_time()
  local dt = t - t_update
  t_update = t
  if t-t_entry > timeout then return'timeout' end

	local lStatus = type(lco)=='thread' and coroutine.status(lco)
	local rStatus = type(rco)=='thread' and coroutine.status(rco)

	local qLArm = Body.get_larm_position()
	local qRArm = Body.get_rarm_position()
	if lStatus=='suspended' then okL, qLWaypoint = coroutine.resume(lco, qLArm) end
	if rStatus=='suspended' then okR, qRWaypoint = coroutine.resume(rco, qRArm) end

	-- Check if errors in either
	if not okL or not okR then
		print(state._NAME, 'L', okL, qLWaypoint, lco)
		print(state._NAME, 'R', okR, qRWaypoint, rco)
		-- Safety
		Body.set_larm_command_position(qLArm)
		Body.set_rarm_command_position(qRArm)
		return'teleopraw'
	end

	if type(qLWaypoint)=='table' then
		Body.set_larm_command_position(qLWaypoint)
	end
	if type(qRWaypoint)=='table' then
		Body.set_rarm_command_position(qRWaypoint)
	end

	-- Check if done
	if lStatus=='dead' and rStatus=='dead' then
		-- Goto the nextitem in the sequnce
		s = s + 1
		local stage = sequence[s]
		if not stage then return'done' end
		lco, rco = movearm.goto(stage.left, stage.right)
	end

end

function state.exit()
	print(state._NAME..' Exit')

end

return state
