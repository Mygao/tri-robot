local state = {}
state._NAME = ...
local Body  = require'Body'
local t_entry, t_update, t_exit
local timeout = 10.0
require'gcm'
require'wcm'

function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry
  t_entry = Body.get_time()
  t_update = t_entry
	arm_ch:send'teleopraw'
	Body.set_larm_torque_enable(0)
	Body.set_rarm_torque_enable(0)
end

function state.update()
  --print(state._NAME..' Update' )
  -- Get the time of update
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t

	-- Constanly stay in raw
	arm_ch:send'teleopraw'
	-- TODO: Make one large torque off
	Body.set_larm_torque_enable(0)
	Body.set_rarm_torque_enable(0)

end

function state.exit()
  print(state._NAME..' Exit' )
end

return state
