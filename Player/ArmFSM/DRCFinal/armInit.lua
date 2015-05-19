--------------------------------
-- Humanoid arm state
-- (c) 2013 Stephen McGill, Seung-Joon Yi
--------------------------------
local state = {}
state._NAME = ...

local Body   = require'Body'
local util   = require'util'
local vector = require'vector'
local movearm = require'movearm'
local t_entry, t_update, t_finish, t_last_debug
local timeout = 15.0

-- Goal position is arm Init, with hands in front, ready to manipulate
local qLArmTarget, qRArmTarget
local last_error

--SJ: now SLOWLY move joint one by one
function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry -- When entry was previously called
  t_entry = Body.get_time()
  t_update = t_entry
  t_finish = t

-- Close rgrip
Body.set_rgrip_command_torque({-10,-10,10})
-- Open rgrip
Body.set_rgrip_command_torque({10,10,-10})
-- No torque rgrip
Body.set_rgrip_command_torque({0,0,0})

  

 if not IS_WEBOTS then
	local vel = 1000
    print('INIT setting params')
    for i=1,10 do
      Body.set_larm_command_velocity(vector.ones(7)*vel)
      unix.usleep(1e6*0.01);
      Body.set_rarm_command_velocity(vector.ones(7)*vel)
      unix.usleep(1e6*0.01);
    end
  end

  --Slowly close all fingers
	--[[
  Body.move_lgrip1(Config.arm.torque.movement)
  Body.move_lgrip2(Config.arm.torque.movement)
  Body.move_rgrip1(Config.arm.torque.movement)
  Body.move_rgrip2(Config.arm.torque.movement)
	--]]

  qLArmTarget = Body.get_inverse_larm(
    vector.zeros(7),
    Config.arm.trLArm0,
    Config.arm.ShoulderYaw0[1],
    mcm.get_stance_bodyTilt(),{0,0},true)

  qRArmTarget = Body.get_inverse_rarm(
    vector.zeros(7),
    Config.arm.trRArm0,
    Config.arm.ShoulderYaw0[2],
    mcm.get_stance_bodyTilt(),{0,0},true)

  
--  qLArmTarget = Body.get_inverse_arm_given_wrist(qLWrist, Config.arm.lrpy0)
--  qRArmTarget = Body.get_inverse_arm_given_wrist(qRWrist, Config.arm.rrpy0)

  print("QLArmTarget:", util.print_jangle(qLArmTarget))
  print("QRArmTarget:", util.print_jangle(qRArmTarget))  


--[[
  -- Default qLArmTarget: 131 3 0  -81 87 49 -90
  -- Default qRArmTarget: 131 -3 0 -81 -87 -49 90
  qLArmTarget=vector.new({90, 0, 0, -150, 90,   29, -90})*DEG_TO_RAD
  qRArmTarget=vector.new({90, 0, 0, -150, -90, -29, 90})*DEG_TO_RAD



  local trLArm = Body.get_forward_larm(qLArmTarget,0,{0,0},true)
  local trRArm = Body.get_forward_rarm(qRArmTarget,0,{0,0},true)  

  print("TRL:",util.print_transform(trLArm))
  print("TRR:",util.print_transform(trRArm))
--]]


  mcm.set_stance_enable_torso_track(0)
  mcm.set_arm_dqVelLeft(Config.arm.vel_angular_limit_init)
  mcm.set_arm_dqVelRight(Config.arm.vel_angular_limit_init)

  t_last_debug=t_entry
  last_error = 999
  stage = 1
end

function state.update()
  local t  = Body.get_time()
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t
  local qLArm = Body.get_larm_command_position()
  local qRArm = Body.get_rarm_command_position()

  local ret
  local qLArmTargetC, qRArmTargetC = util.shallow_copy(qLArm),util.shallow_copy(qRArm)

--print('qL init',unpack(qLArm))
--print('qR init',unpack(qRArm))




  if stage==1 then
    --straighten shoulder yaw
    qLArmTargetC[3],qRArmTargetC[3] = qLArmTarget[3],qRArmTarget[3]
  elseif stage==2 then
    if math.abs(qLArmTargetC[3]-qLArmTarget[3])<math.pi/2 and
      math.abs(qLArmTargetC[3]-qLArmTarget[3])<math.pi/2 then     
      stage=7  --no need to unscrew wrist yaw
      return
    else 
      stage=3 
      return
    end --unscrew wrist yaw
  elseif stage==3 then
    --unscrew wrist yaw. First straighten wrist roll
    qLArmTargetC[3],qRArmTargetC[3] = qLArmTarget[3],qRArmTarget[3]
    qLArmTargetC[6],qRArmTargetC[6] = 0,0
  elseif stage==4 then
    --unscrew wrist yaw. after straighten wrist roll
    qLArmTargetC[3],qRArmTargetC[3] = qLArmTarget[3],qRArmTarget[3]
    qLArmTargetC[6],qRArmTargetC[6] = 0,0
    qLArmTargetC[5],qRArmTargetC[5] = qLArmTarget[5],qRArmTarget[5]
    qLArmTargetC[7],qRArmTargetC[7] = qLArmTarget[7],qRArmTarget[7]
  elseif stage==5 then
    qLArmTargetC,qRArmTargetC = qLArmTarget,qRArmTarget
  elseif stage==6 then
    return "done"
  elseif stage==7 then
    --Straighten wrist yaws first (without touching roll)
    qLArmTargetC[3],qRArmTargetC[3] = qLArmTarget[3],qRArmTarget[3]    
    qLArmTargetC[5],qRArmTargetC[5] = qLArmTarget[5],qRArmTarget[5]
    qLArmTargetC[7],qRArmTargetC[7] = qLArmTarget[7],qRArmTarget[7]
  elseif stage==8 then
    qLArmTargetC,qRArmTargetC = qLArmTarget,qRArmTarget
  elseif stage==9 then
    return "done"    
  end

  local dqArmLim = vector.new({10,10,10,10,45,30,45}) *DEG_TO_RAD
  if IS_WEBOTS then dqArmLim = dqArmLim*10 end



  local ret = movearm.setArmJoints(qLArmTargetC,qRArmTargetC,dt,dqArmLim,true)
--  if ret==1 then return "done" end

  local qLArmActual = Body.get_larm_position()
  local qRArmActual = Body.get_rarm_position()
  local qLArmCommand = Body.get_larm_command_position()
  local qRArmCommand = Body.get_rarm_command_position()

  local err=0
  for i=1,7 do
    err=err+math.abs(qLArmActual[i]-qLArmCommand[i])
    err=err+math.abs(qRArmActual[i]-qRArmCommand[i])
  end

  if t>t_last_debug+0.2 then
    t_last_debug=t
    if ret==1 and math.abs(last_error-err)<0.2*math.pi/180 then 
      stage = stage+1
      print("Total joint reading err:",err*180/math.pi)
    else
     --print('armInit',ret,stage,err)
    end
    last_error = err
  end    


end

function state.exit()
  local libArmPlan = require 'libArmPlan'
  local arm_planner = libArmPlan.new_planner()
  arm_planner:reset_torso_comp(qLArmTarget,qRArmTarget)
--[[
  Body.move_lgrip1(0)
  Body.move_lgrip2(0)
  Body.move_rgrip1(0)
  Body.move_rgrip2(0)
--]]


  if not IS_WEBOTS then
    for i=1,10 do
      Body.set_larm_command_velocity({0,0,0,0,0,0,0})
      unix.usleep(1e6*0.01);
      Body.set_rarm_command_velocity({0,0,0,0,0,0,0})
      unix.usleep(1e6*0.01);
    end
  end
  
  print(state._NAME..' Exit' )

--SJ: now we store the COM offset for default arm posture
--needed for arm returning
  local COMoffset = mcm.get_stance_COMoffset()
  mcm.set_stance_COMoffsetPose1(COMoffset)
end

return state

