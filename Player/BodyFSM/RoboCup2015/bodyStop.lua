local state = {}
state._NAME = ...
local util   = require'util'


local Body = require'Body'
local timeout = 10.0
local t_entry, t_update, t_exit, t_plan
require'gcm'

--Tele-op state for testing various stuff
--Don't do anything until commanded
local old_state

function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry -- When entry was previously called
  t_entry = Body.get_time()
  t_update = t_entry

  if mcm.get_walk_ismoving()>0 then
    print("requesting stop")
    mcm.set_walk_stoprequest(1)
  end
end

function state.update()
  --  print(state._NAME..' Update' )
  -- Get the time of update
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  if gcm.get_game_state()==3 and 
    (gcm.get_game_role()~=2) then

     if wcm.get_robot_timestarted()==0 then 
      wcm.set_robot_timestarted(t) end

    if gcm.get_game_role()==0 then --goalie
      print(util.color("Goalie start!",'blue'))
      return'goalie'
    elseif gcm.get_game_role()==1 then
      print(util.color("Attacker start!",'red'))
      return'play'
    elseif gcm.get_game_role()==3 then
      print(util.color("Demo start!",'green'))
      return'play'
    end
  end
end

function state.exit()
  print(state._NAME..' Exit' )
  t_exit = Body.get_time()  
end

return state
