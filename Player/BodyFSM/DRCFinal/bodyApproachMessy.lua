--Messier but hopefully better approach code using foot step planning



local state = {}
state._NAME = ...
local Body   = require'Body'
local util   = require'util'
local vector = require'vector'
local libStep = require'libStep'
-- FSM coordination
local simple_ipc = require'simple_ipc'
local motion_ch = simple_ipc.new_publisher('MotionFSM!')


-- Get the human guided approach
require'hcm'
-- Get the robot guided approach
require'wcm'

require'mcm'

local stanceLimitX = Config.walk.stanceLimitX or {-0.10 , 0.10}
local stanceLimitY = Config.walk.stanceLimitY or {0.09 , 0.20}
local stanceLimitA = Config.walk.stanceLimitA or {-0*math.pi/180, 40*math.pi/180}
local velDelta = Config.walk.velDelta or {.03,.015,.15}




local step_planner
local t_entry, t_update, t_exit
local nwaypoints, wp_id
local waypoints = {}

local target_pose
local uLeft_now, uRight_now, uTorso_now, uLeft_next, uRight_next, uTorso_next
local supportLeg
local ball_side = 1

local last_ph = 0

local uTorso0 = nil
local pose0 = nil

local last_step = 0
local first_step=0

local uLeftGlobalTarget, uRightGlobalTarget

local last_velocity=vector.zeros(3)



local function longdistance_approach()
  local target_pose = wcm.get_step_pose()
  local current_pose = wcm.get_robot_pose()
  local target_relative = util.pose_relative(target_pose, current_pose)
  local target_distance = math.sqrt(target_relative[1]^2+target_relative[2]^2)

  local target_angle = math.atan2(target_relative[2],target_relative[1])

  local vx,vy,va
  local maxStep = 0.06
  vx = util.procFunc(target_relative[1]*0.5, 0, maxStep)
  vy = util.procFunc(target_relative[2]*0.5, 0, maxStep)

  if math.abs(target_angle)>math.pi/2 then 
    --do not rotate backwards, just walk back
    target_angle = target_angle+math.pi

  end


  local aStep = math.min(1,  math.max(0,   (target_distance-0.5)/(1.0-0.5)  ))
  va = aStep* ( target_angle*0.5) + (1-aStep)* target_relative[3]*0.5

  local vStep={vx,vy,va}
    --don't turn and sidestep at once
  if math.abs(vStep[3])>0.05 then
    vStep[2] = 0
    vStep[1] = util.procFunc(vStep[1],0,0.04)
  end
  if math.abs(vStep[1])>0.025 then
    vStep[2] = 0
  end



  print(string.format("LD approach vel: %.3f %.3f %.1f",vStep[1],vStep[2],vStep[3]*180/math.pi))

  return vStep, false  
end


local function step_approach(uLeftGlobalTarget, uRightGlobalTarget)
  local uLeft = mcm.get_status_uLeft()
  local uRight = mcm.get_status_uRight()
  local uTorso = mcm.get_status_uTorso()
  local supportLeg = mcm.get_status_supportLeg()
  local uTorsoNext

  local uLSupport = util.pose_global({Config.walk.supportX, Config.walk.supportY,0},uLeft)
  local uRSupport = util.pose_global({Config.walk.supportX, -Config.walk.supportY,0},uRight)
  local uTorsoCurrent = util.se2_interpolate(0.5, uLSupport, uRSupport)

  local pose = wcm.get_robot_pose()

  local uLeftGlobal = util.pose_global(util.pose_relative(uLeft,uTorsoCurrent),pose)
  local uRightGlobal = util.pose_global(util.pose_relative(uRight,uTorsoCurrent),pose)

--[[
  print("-----------")
  print("uTorso:",unpack(uTorso))
  print("pose:",unpack(pose))
  print("uTorsoCurrent:",unpack(uTorsoCurrent))
  print("uLeftG:",unpack(uLeftGlobal))
  print("uRightG:",unpack(uRightGlobal))
  print("uLeftGT:",unpack(uLeftGlobalTarget))
  print("uRightGT:",unpack(uRightGlobalTarget))
--]]

  --uLeft and uRight from uTorso0
  local uLeftFromTorso = util.pose_relative(uLeft,uTorsoCurrent)
  local uRightFromTorso = util.pose_relative(uRight,uTorsoCurrent)
  local uLeftTargetFromTorso = util.pose_relative(uLeftGlobalTarget,pose)
  local uRightTargetFromTorso = util.pose_relative(uRightGlobalTarget,pose)
  local uTargetCenter = util.se2_interpolate(0.5,uLeftTargetFromTorso,uRightTargetFromTorso)

  dist=math.sqrt(uTargetCenter[1]*uTargetCenter[1]+uTargetCenter[2]*uTargetCenter[2])

  local angleMove=0


  local vStepTarget

--  if dist > 0.30 then --robot away from traget, aim for the center position
  if false then
    local angleTurn
    angleTurn = math.atan2(uTargetCenter[2],uTargetCenter[1])
    if dist>0.50 then
      vStepTarget={uTargetCenter[1],uTargetCenter[2],angleTurn}
    else
      vStepTarget={uTargetCenter[1],uTargetCenter[2],uTargetCenter[3]}
    end


  else
    local supportStr
    if last_step==1 then
      if supportLeg==0 then
        uRightTargetFromTorso = util.pose_global({0, -2*Config.walk.footY,0},uLeftFromTorso)
        uLSupportNext = util.pose_global({Config.walk.supportX, Config.walk.supportY,0},uLeftFromTorso)
        uRSupportNext = util.pose_global({Config.walk.supportX, -Config.walk.supportY,0},uRightTargetFromTorso)
        uTorsoNext = util.se2_interpolate(0.5, uLSupportNext, uRSupportNext)
      else
        uLeftTargetFromTorso = util.pose_global({0, 2*Config.walk.footY,0},uRightFromTorso)
        uLSupportNext = util.pose_global({Config.walk.supportX, Config.walk.supportY,0},uLeftFromTorso)
        uRSupportNext = util.pose_global({Config.walk.supportX, -Config.walk.supportY,0},uRightTargetFromTorso)
        uTorsoNext = util.se2_interpolate(0.5, uLSupportNext, uRSupportNext)
      end
      local vStep = {uTorsoNext[1],uTorsoNext[2],uTorsoNext[3]}
      last_step=2
      print(string.format("approach vel: %.3f %.3f %.1f",vStep[1],vStep[2],vStep[3]*180/math.pi))
      return vStep,true
    elseif last_step==2 then
      return {0,0,0},true
    end

    if supportLeg==0 then
      --Last step was left support step (right foot movement)
      --Next step should be left foot movement
      supportStr='Left foot move next'
--print("Left foot move next")
      uLSupportNext = util.pose_global({Config.walk.supportX, Config.walk.supportY,0},uLeftFromTorso)
      uRSupportNext = util.pose_global({Config.walk.supportX, -Config.walk.supportY,0},uRightTargetFromTorso)
      uTorsoNext = util.se2_interpolate(0.5, uLSupportNext, uRSupportNext)
      vStepTarget = {uTorsoNext[1],uTorsoNext[2],uTorsoNext[3]}
    else
      supportStr='Right foot move next'
--print("R foot move next")
      uLSupportNext = util.pose_global({Config.walk.supportX, Config.walk.supportY,0},uLeftFromTorso)
      uRSupportNext = util.pose_global({Config.walk.supportX, -Config.walk.supportY,0},uRightTargetFromTorso)
      uTorsoNext = util.se2_interpolate(0.5, uLSupportNext, uRSupportNext)
      vStepTarget = {uTorsoNext[1],uTorsoNext[2],uTorsoNext[3]}
    end

--      print("uLeftSN:",unpack(uLSupportNext))
--      print("uRightSN:",unpack(uRSupportNext))


  end

  --local vStepTarget = {uTorsoNext[1],uTorsoNext[2],0}


  local maxStep = 0.06
  if Config.maxStepApproach1 then
    if vStepTarget[1]>(Config.maxStepApproachTh or 0.20) then
      maxStep = Config.maxStepApproach1 or 0.10
    else
      maxStep = Config.maxStepApproach2 or 0.06
    end
  end


  vStep={0,0,0}
  vStep[1] = math.min(Config.walk.velLimitX[2],math.max(Config.walk.velLimitX[1],vStepTarget[1]))
  vStep[2] = math.min(Config.walk.velLimitY[2],math.max(Config.walk.velLimitY[1],vStepTarget[2]))
  vStep[3] = math.min(Config.walk.velLimitA[2],math.max(Config.walk.velLimitA[1],vStepTarget[3]))

  velMag = math.sqrt(vStep[1]^2+vStep[2]^2)
  vStep[1]=vStep[1]/velMag * math.min(maxStep,velMag)
  vStep[2]=vStep[2]/velMag * math.min(maxStep,velMag)





  --don't turn and sidestep at once
  if math.abs(vStep[3])>0.05 then
    vStep[2] = 0
    vStep[1] = util.procFunc(vStep[1],0,0.04)
  end
  if math.abs(vStep[2])>0.02 then
    vStep[1] = util.procFunc(vStep[1],0,0.03)
  end
  if math.abs(vStep[1])>0.025 then
    vStep[2] = 0
  end





  local velDiff = vector.new(vStep) - last_velocity
  velDiff[1] = util.procFunc(velDiff[1],0,velDelta[1])
  velDiff[2] = util.procFunc(velDiff[2],0,velDelta[2])
  velDiff[3] = util.procFunc(velDiff[3],0,velDelta[3])
  vStep = last_velocity+velDiff
  last_velocity=vStep

print(string.format("approach vel: %.3f %.3f %.1f",vStep[1],vStep[2],vStep[3]*180/math.pi))

  local uTorsoTargetActual = util.pose_global(vStep,uTorsoCurrent)


--[[
  print()
  print("uTorsoTargetCurrent:",unpack(uTorsoCurrent))
  print("uLeftGlobal:",unpack(uLeftGlobal))
  print("uRightGlobal:",unpack(uRightGlobal))
  print("uLeftGlobalT:",unpack(uLeftGlobalTarget))
  print("uRightGlobalT:",unpack(uRightGlobalTarget))

  print("uSLeftGlobal:",unpack(uLSupportNextGlobal))
  print("uSRightGlobal:",unpack(uRSupportNextGlobal))
  print("uTNGlobal:",unpack(uTorsoNextGlobal))

  print("vStep:",unpack(vStep))
  print("uTorsoTargetActual:",unpack(uTorsoTargetActual))
  --]]


  if supportLeg==1 then --current right support, right foot movement
    local uRSupportNext = {2*uTorsoTargetActual[1]-uLSupport[1],2*uTorsoTargetActual[2]-uLSupport[2],2*uTorsoTargetActual[3]-uLSupport[3]}
    local uRNext = util.pose_global({-Config.walk.supportX, Config.walk.supportY,0}, uRSupportNext  )
    local uRightLeft = util.pose_relative(uRNext, uLeft)
    uRightLeft[1] = math.min(math.max(uRightLeft[1], stanceLimitX[1]), stanceLimitX[2])
    uRightLeft[2] = math.min(math.max(uRightLeft[2], -stanceLimitY[2]), -stanceLimitY[1])
    uRightLeft[3] = math.min(math.max(uRightLeft[3], -stanceLimitA[2]), -stanceLimitA[1])
    local uRight2 = util.pose_global(uRightLeft,uLeft)
    local uRNextGlobal = util.pose_global( util.pose_relative(uRight2,uTorso) ,pose)

--[[
    print("pose:",unpack(pose))
    print("uRNext:",unpack(uRNext))
    print("uRNextGlobal:",unpack(uRNextGlobal))
    print("uRNextGlobaT:",unpack(uRightGlobalTarget))
--]]
    if math.abs(uRNextGlobal[1]-uRightGlobalTarget[1])<0.01 and
      math.abs(uRNextGlobal[2]-uRightGlobalTarget[2])<0.01 and
      math.abs(util.mod_angle(uRNextGlobal[3]-uRightGlobalTarget[3]))<3*math.pi/180 then
--print("APPROACHED")
--      print("uRTarget:",unpack(uRightGlobalTarget))
      last_step = 1
    end



  else --current left support, left foot movement next
    local uLSupportNext = {2*uTorsoTargetActual[1]-uRSupport[1],2*uTorsoTargetActual[2]-uRSupport[2],2*uTorsoTargetActual[3]-uRSupport[3]}
    local uLNext = util.pose_global({-Config.walk.supportX, -Config.walk.supportY,0}, uLSupportNext  )
    local uLeftRight = util.pose_relative(uLNext, uRight)
    uLeftRight[1] = math.min(math.max(uLeftRight[1], stanceLimitX[1]), stanceLimitX[2])
    uLeftRight[2] = math.min(math.max(uLeftRight[2], stanceLimitY[1]),stanceLimitY[2])
    uLeftRight[3] = math.min(math.max(uLeftRight[3], stanceLimitA[1]), stanceLimitA[2])
    local uLeft2 = util.pose_global(uLeftRight,uRight)
    local uLNextGlobal = util.pose_global( util.pose_relative(uLeft2,uTorso) ,pose)

--[[
    print("pose:",unpack(pose))
    print("uLNext:",unpack(uLNext))
    print("uLNextGlobal:",unpack(uLNextGlobal))
    print("uLNextGlobaT:",unpack(uLeftGlobalTarget))
--]]

    if math.abs(uLNextGlobal[1]-uLeftGlobalTarget[1])<0.01 and
      math.abs(uLNextGlobal[2]-uLeftGlobalTarget[2])<0.01 and
      math.abs(util.mod_angle(uLNextGlobal[3]-uLeftGlobalTarget[3]))<3*math.pi/180 then
--      print("uLTarget:",unpack(uLeftGlobalTarget))
      last_step = 1
    end
  end




  return vStep,false
end



local function update_target()
--Stationary target case
  uLeftGlobalTarget = util.pose_global({-Config.walk.supportX,Config.walk.footY,0},wcm.get_step_pose() )
  uRightGlobalTarget = util.pose_global({-Config.walk.supportX,-Config.walk.footY,0},wcm.get_step_pose() )
end


local finished=false

local function update_velocity()
  update_target()

  local target_pose = wcm.get_step_pose()
  local current_pose = wcm.get_robot_pose()
  local target_relative = util.pose_relative(target_pose, current_pose)
  local target_distance = math.sqrt(target_relative[1]^2+target_relative[2]^2)


--  local vStep,arrived = step_approach(uLeftGlobalTarget, uRightGlobalTarget)
  local vStep, arrived

  if Config.hybrid_approach then

    if target_distance<0.5 then
      vStep,arrived = step_approach(uLeftGlobalTarget, uRightGlobalTarget)
    else
      vStep = longdistance_approach()
    end  
  else
    vStep,arrived = step_approach(uLeftGlobalTarget, uRightGlobalTarget)
  end
  mcm.set_walk_vel(vStep)
  if arrived then
    mcm.set_walk_stoprequest(1)
    finished=true
    return 'done'
  end
end




function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry -- When entry was previously called
  local ret = nil

  t_entry = Body.get_time()
  t_update = t_entry

  last_ph = 0
  last_step = 0
  wcm.set_robot_etastep(-1) --we're in approach
  finished=false
  last_velocity=vector.zeros(3)
  local move_target = vector.pose(hcm.get_teleop_waypoint())
  if move_target[1]==0 and move_target[2]==0 and move_target[3]==0 then
    finished = true --don't need to walk, just exit
    pose0 = wcm.get_robot_pose()
  else
    print('bodyApproach2 | Waypoint', move_target)
    local pose = wcm.get_robot_pose()
    local global_target_pose = util.pose_global(move_target,pose)

    --print("Original pose:",unpack(pose))
    pose0 = wcm.get_robot_pose()
    --print("Target pose:",unpack(global_target_pose))
    local movement = util.pose_relative(global_target_pose,pose)
    print(string.format("Target movement: %.3f %.3f %.1f",movement[1],movement[2],movement[3]*180/math.pi))

    wcm.set_step_pose(global_target_pose)
    motion_ch:send'hybridwalk'
  end
  first_step=0
end

function state.update()
  local t  = Body.get_time() 
  if mcm.get_walk_ismoving()==0 then 
    if finished or t-t_entry>3 then
    return "done" end
  end
  --print(state._NAME..' Update' )
  -- Get the time of update
  local ret = nil
  
  local dt = t - t_update
  -- Save this at the last update time
  t_update = t

  --2 3 4 5 for stance init walk end
  if mcm.get_motion_state()==4 then
    local check_ph = 0.95
    local ph = mcm.get_status_ph()
    if last_ph<check_ph and ph>=check_ph then update_velocity() end
    last_ph = ph
  end
end

function state.exit()
--  print("Original pose:",unpack(pose0))
--  print("Reached pose:",unpack(wcm.get_robot_pose())  )

  local movement = util.pose_relative(wcm.get_robot_pose(),pose0)

  print("Time spent:",Body.get_time()-t_entry)
  print(string.format("Final movement: %.3f %.3f %.1f",movement[1],movement[2],movement[3]*180/math.pi))
  print(state._NAME..' Exit' )
  wcm.set_robot_etastep(0) --out of approach
end

return state
