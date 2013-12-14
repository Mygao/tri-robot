local state = {}
state._NAME = ...
require'hcm'
local vector = require'vector'
local util   = require'util'
local movearm = require'movearm'
local libArmPlan = require 'libArmPlan'
local arm_planner = libArmPlan.new_planner()


local qLArm0,qRArm0, trLArm0, trRArm0

--Initial hand angle
local lhand_rpy0 = {0,0*Body.DEG_TO_RAD, -45*Body.DEG_TO_RAD}
local rhand_rpy0 = {0,0*Body.DEG_TO_RAD, 45*Body.DEG_TO_RAD}
local lhand_rpy0 = {0,0*Body.DEG_TO_RAD, 0*Body.DEG_TO_RAD}


local function get_cutpos_tr(tooloffset)
  tooloffset = tooloffset or {0,0,0}
  local handrpy = rhand_rpy0
  local cutpos = hcm.get_tool_cutpos()
  local drill_offset = Config.armfsm.toolchop.drill_offset
  local cutpos_tr = {
    cutpos[1] + tooloffset[1],
    cutpos[2] + tooloffset[2],
    cutpos[3] + tooloffset[3] - drill_offset[3],
    handrpy[1],handrpy[2],handrpy[3] + cutpos[4]}
  return cutpos_tr
end

local function get_hand_tr(pos)
  return {pos[1],pos[2],pos[3], unpack(rhand_rpy0)}
end

local function update_model()
  local trRArmTarget = hcm.get_hands_right_tr_target()
  local trRArm = hcm.get_hands_right_tr()
  local tool_cutpos = hcm.get_tool_cutpos()

  tool_cutpos[1],tool_cutpos[2],tool_cutpos[3],tool_cutpos[4]=

    tool_cutpos[1] + trRArmTarget[1] - trRArm[1],
    tool_cutpos[2] + trRArmTarget[2] - trRArm[2],
    tool_cutpos[3] + trRArmTarget[3] - trRArm[3],
    tool_cutpos[4] + util.mod_angle(trRArmTarget[6] - trRArm[6])

  hcm.set_tool_cutpos(tool_cutpos)  
  hcm.set_state_proceed(0)
end



local function update_override()
  local overrideTarget = hcm.get_state_override_target()
  local override = hcm.get_state_override()
  local tool_model = hcm.get_tool_cutpos()

  tool_model[1],tool_model[2],tool_model[3], tool_model[4] = 
  tool_model[1] + (overrideTarget[1]-override[1]),
  tool_model[2] + (overrideTarget[2]-override[2]),
  tool_model[3] + (overrideTarget[3]-override[3]),
  tool_model[4] + (util.mod_angle(overrideTarget[4]-override[4]))
  
  hcm.set_tool_cutpos(tool_model)  
  print( util.color('Tool model:','yellow'), 
      string.format("%.2f %.2f %.2f / %.1f",
        tool_model[1],tool_model[2],tool_model[3],
        tool_model[4]*180/math.pi ))
  hcm.set_state_proceed(0)
end

local function revert_override()
  local overrideTarget = hcm.get_state_override_target()
  local override = hcm.get_state_override()
  local tool_model = hcm.get_tool_cutpos()

  tool_model[1],tool_model[2],tool_model[3], tool_model[4] = 
  tool_model[1] - (overrideTarget[1]-override[1]),
  tool_model[2] - (overrideTarget[2]-override[2]),
  tool_model[3] - (overrideTarget[3]-override[3]),
  tool_model[4] - (util.mod_angle(overrideTarget[4]-override[4]))

  hcm.set_tool_cutpos(tool_model)  
  print( util.color('Tool model:','yellow'), 
      string.format("%.2f %.2f %.2f / %.1f",
        tool_model[1],tool_model[2],tool_model[3],
        tool_model[4]*180/math.pi ))
  hcm.set_state_proceed(0)
end

local function confirm_override()
  local override = hcm.get_state_override()
  hcm.set_state_override_target(override)
end





local stage
local cut_no

function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry
  t_entry = Body.get_time()
  t_update = t_entry

  local qLArm = Body.get_larm_command_position()
  local qRArm = Body.get_rarm_command_position()
  qLArm0 = qLArm
  qRArm0 = qRArm
  
  --arm_planner:set_shoulder_yaw_target(nil,qRArm[3]) --Lock right shoulder yaw
  arm_planner:set_shoulder_yaw_target(qLArm[3],nil) --Lock right shoulder yaw
  local init_cond = arm_planner:load_boundary_condition()
  arm_planner:set_hand_mass(0,2)
  trLArm0 = Body.get_forward_larm(init_cond[1])
  trRArm0 = Body.get_forward_rarm(init_cond[2]) 
  
  stage = "drillout"
  hcm.set_tool_cutpos(Config.armfsm.toolchop.model)

end

function state.update()
  --  print(state._NAME..' Update' )
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t

  local cur_cond = arm_planner:load_boundary_condition()
  local trLArm = Body.get_forward_larm(cur_cond[1])
  local trRArm = Body.get_forward_rarm(cur_cond[2])  
  
  if stage=="drillout" then
    if hcm.get_state_proceed()==1 then 
      local trRArmTarget1 = get_hand_tr(Config.armfsm.toolchop.arminit[2])
      local trRArmTarget2 = get_hand_tr(Config.armfsm.toolchop.arminit[3])
      local arm_seq = {{'move',nil,trRArmTarget1},{'move',nil,trRArmTarget2}}
      if arm_planner:plan_arm_sequence2(arm_seq) then stage="drilloutmove" end
    elseif hcm.get_state_proceed()==-1 then 
      --[[
      local trRArmTarget1 = get_hand_tr(Config.armfsm.toolgrip.armhold)
      local arm_seq = {{'move',nil,trRArmTarget1}}
      if arm_planner:plan_arm_sequence2(arm_seq) then stage="backtohold" end
      --]]
      hcm.get_state_proceed(0)
    end
  elseif stage=="drilloutmove" then
    if arm_planner:play_arm_sequence(t) then 
      if hcm.get_state_proceed()==1 then             
        print("trRArm:",arm_planner.print_transform(trRArm))
        local trRArmTarget1 = get_cutpos_tr(Config.armfsm.toolchop.drill_clearance)      

        print("trRArmTarget:",arm_planner.print_transform(trRArmTarget1))
        local arm_seq = {{'move',nil, trRArmTarget1}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "drillpositionwait" end      
        hcm.set_state_proceed(0)
      elseif hcm.get_state_proceed()==-1 then       
        local trRArmTarget1 = get_hand_tr(Config.armfsm.toolchop.arminit[2])
        local trRArmTarget2 = get_hand_tr(Config.armfsm.toolchop.arminit[1])
        local arm_seq = {{'move',nil, trRArmTarget1},{'move',nil, trRArmTarget2}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "drillout" end
      end
    end
  elseif stage=="drillpositionwait" then
    if arm_planner:play_arm_sequence(t) then 
      if hcm.get_state_proceed()==1 then 
         print("trRArm:",arm_planner.print_transform(trRArm))
        local trRArmTarget1 = get_cutpos_tr()
        local arm_seq = {{'move',nil,trRArmTarget1}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "drillcut" end
      elseif hcm.get_state_proceed()==-1 then 
--[[        
        local trRArmTarget1 = get_hand_tr(Config.armfsm.toolchop.arminit[3])
        local arm_seq = {{'move',nil,trRArmTarget1}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "drilloutmove" end
        hcm.set_state_proceed(0)
--]]        
--[[      elseif hcm.get_state_proceed() == 2 then --Model modification
        update_model()        
        local trRArmTarget1 = get_cutpos_tr(Config.armfsm.toolchop.drill_clearance)      
        local arm_seq = {{'move',nil, trRArmTarget1}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "drillpositionwait" end      
--]]        
      elseif hcm.get_state_proceed() == 3 then --Model modification
        update_override()        
        local trRArmTarget1 = get_cutpos_tr(Config.armfsm.toolchop.drill_clearance)      
        local arm_seq = {{'move',nil, trRArmTarget1}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "drillpositionwait" 
          confirm_override()
        else revert_override() end      
      end
    end
  elseif stage=="drillcut" then
    if arm_planner:play_arm_sequence(t) then 
      if hcm.get_state_proceed()==1 then 

      elseif hcm.get_state_proceed()==-1 then 
        local trRArmTarget1 = get_cutpos_tr(Config.armfsm.toolchop.drill_clearance)      
        local arm_seq = {{'move',nil, trRArmTarget1}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "drillpositionwait" end      
        hcm.set_state_proceed(0)
--[[        
      elseif hcm.get_state_proceed() == 2 then --Model modification
        update_model()        
        local trRArmTarget1 = get_cutpos_tr()
        local arm_seq = {{'move',nil, trRArmTarget1}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "drillcut" end      
--]]        
      elseif hcm.get_state_proceed() == 3 then --Model modification        
        update_override()        
        local trRArmTarget1 = get_cutpos_tr()
        local arm_seq = {{'move',nil, trRArmTarget1}}
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "drillcut" 
          confirm_override()
        else revert_override() end      
      end
    end
  elseif stage=="backtohold" then    
    if arm_planner:play_arm_sequence(t) then 
      
    end
  end
  
  
end

function state.exit()  
  print(state._NAME..' Exit' )
end

return state