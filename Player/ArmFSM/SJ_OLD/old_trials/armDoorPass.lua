local state = {}
state._NAME = ...
require'hcm'
local vector = require'vector'
local util   = require'util'
local movearm = require'movearm'
local libArmPlan = require 'libArmPlan'
local arm_planner = libArmPlan.new_planner()

local lhand_rpy = Config.armfsm.doorpass.lhand_rpy
local rhand_rpy = Config.armfsm.doorpass.rhand_rpy





local trLArm0, trRArm0, trLArm1, trRArm1, qLArm0, qRarm0
local stage

local qLArmInit0,qRArmInit0


local qLArmFold, qRArmFold



function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry
  t_entry = Body.get_time()
  t_update = t_entry

  local qLArm = Body.get_larm_command_position()
  local qRArm = Body.get_rarm_command_position()

  mcm.set_arm_lhandoffset(Config.arm.handoffset.gripper)
  mcm.set_arm_rhandoffset(Config.arm.handoffset.gripper)

  qLArm0 = qLArm
  qRArm0 = qRArm
  
  trLArm0 = Body.get_forward_larm(qLArm0)
  trRArm0 = Body.get_forward_rarm(qRArm0)  

  arm_planner:reset_torso_comp(qLArm, qRArm)
  arm_planner:save_boundary_condition({qLArm, qRArm, qLArm, qRArm, {0,0}})
--  arm_planner:set_shoulder_yaw_target(nil,nil)
  arm_planner:set_shoulder_yaw_target(qLArm0[3],qRArm0[3])
  
  qLArm1 = Body.get_inverse_arm_given_wrist( qLArm, {0,0,0, unpack(lhand_rpy)})  
  qRArm1 = Body.get_inverse_arm_given_wrist( qRArm, {0,0,0, unpack(rhand_rpy)})
  
  trLArm1 = Body.get_forward_larm(qLArm1)
  trRArm1 = Body.get_forward_rarm(qRArm1)  
    
--  arm_planner:set_shoulder_yaw_target(1*DEG_TO_RAD, -1*DEG_TO_RAD)

  arm_planner:set_shoulder_yaw_target(-2*DEG_TO_RAD, 2*DEG_TO_RAD)
  arm_planner:set_shoulder_yaw_target(nil,nil)

  local wrist_seq = {{'wrist',trLArm1, trRArm1}}
  if arm_planner:plan_arm_sequence2(wrist_seq) then stage = "wristturn" end
  hcm.set_state_proceed(1)
end


function state.update()
--  print(state._NAME..' Update' )
  -- Get the time of update
  if plan_failed then return "planfail" end
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t
  --if t-t_entry > timeout then return'timeout' end

  local cur_cond = arm_planner:load_boundary_condition()
  local trLArm = Body.get_forward_larm(cur_cond[1])
  local trRArm = Body.get_forward_rarm(cur_cond[2])  
  
   if stage=="wristturn" then 
    if arm_planner:play_arm_sequence(t) then       
      if hcm.get_state_proceed()==1 then 
        print("trLArm:",util.print_transform(trLArm))
        print("trRArm:",util.print_transform(trRArm))
        local arm_seq = {
          {'move',Config.armfsm.doorpass.larminit[1],Config.armfsm.doorpass.rarminit[1]},
          {'wrist',Config.armfsm.doorpass.larminit[2],Config.armfsm.doorpass.rarminit[2]},
        }                          
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "armfold" end
      elseif hcm.get_state_proceed()==-1 then 
        arm_planner:set_shoulder_yaw_target(qLArm0[3],qRArm0[3]) 
        local wrist_seq = {{"wrist",trLArm0,nil}}
        if arm_planner:plan_arm_sequence2(wrist_seq) then stage = "armbacktoinitpos" end  
      end
    end
  elseif stage=="armfold" then
    if arm_planner:play_arm_sequence(t) then       
      if hcm.get_state_proceed()==1 then 
      elseif hcm.get_state_proceed()==-1 then         
        local arm_seq = {
          {'wrist',Config.armfsm.doorpass.larminit[1],Config.armfsm.doorpass.rarminit[1]},
          {'move',Config.armfsm.doorpass.larminit[1],Config.armfsm.doorpass.rarminit[1]},
        }                          
        if arm_planner:plan_arm_sequence2(arm_seq) then stage = "armunfold" end
      end  
    end
  elseif stage=="armunfold" then
    if arm_planner:play_arm_sequence(t) then           
      arm_planner:set_shoulder_yaw_target(qLArm0[3],qRArm0[3])            
      local arm_seq = {{'wrist',trLArm0,trRArm0}}
      if arm_planner:plan_arm_sequence2(arm_seq) then stage = "backtoinitpos" end
    end   
    
  elseif stage=="backtoinitpos" then
    if arm_planner:play_arm_sequence(t) then return"done" end
  end
end



function state.exit()  
  print(state._NAME..' Exit' )
end

return state

