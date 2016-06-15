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
  hcm.set_teleop_estop(1) --for not using estop

end

function state.update()
  --print(state._NAME..' Update' )
  -- Get the time of update
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t

  mcm.set_walk_kicktype(0) --Walkkick 




--[[
  local gamestate = gcm.get_game_state()
  if gamestate~=5 then return 'init' end --5 is idle state 
--]]  
end

function state.exit()
  --for manual transition to init (no estop case)
  --clear estop flag so that we can keep running
  hcm.set_teleop_estop(0)
  print(state._NAME..' Exit' )
end

return state
