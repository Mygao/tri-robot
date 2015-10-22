local state = {}
state._NAME = ...
local Body   = require'Body'
local util   = require'util'
local vector = require'vector'

-- Get the human guided approach
require'hcm'
-- Get the robot guided approach
require'wcm'

require'mcm'

local footstepplanner = require'footstepplanner'


-- FSM coordination
local simple_ipc = require'simple_ipc'
local motion_ch = simple_ipc.new_publisher('MotionFSM!')

local t_entry, t_update, t_exit, t_stage
local nwaypoints, wp_id
local waypoints = {}

local pose, target_pose
local step_planner
local uLeft_now, uRight_now, uTorso_now, uLeft_next, uRight_next, uTorso_next
local supportLeg




local stage = 1
local ready_for_input = true

local is_possible = true




local function calculate_footsteps(stage)
  local step_queue = step_queues[stage]
  --Write to SHM
  local maxSteps = 40
  step_queue_vector = vector.zeros(15*maxSteps)
  for i=1,#step_queue do    
    local offset = (i-1)*15;
    step_queue_vector[offset+1] = step_queue[i][1][1]
    step_queue_vector[offset+2] = step_queue[i][1][2]
    step_queue_vector[offset+3] = step_queue[i][1][3]

    step_queue_vector[offset+4] = step_queue[i][2]

    step_queue_vector[offset+5] = step_queue[i][3]
    step_queue_vector[offset+6] = step_queue[i][4]    
    step_queue_vector[offset+7] = step_queue[i][5]    

    step_queue_vector[offset+8] = step_queue[i][6][1]
    step_queue_vector[offset+9] = step_queue[i][6][2]
    step_queue_vector[offset+10] = 0

    step_queue_vector[offset+11] = step_queue[i][7][1]
    step_queue_vector[offset+12] = step_queue[i][7][2]
    step_queue_vector[offset+13] = step_queue[i][7][3]

    if step_queue[i][8] then
      step_queue_vector[offset+14] = step_queue[i][8][1]
      step_queue_vector[offset+15] = step_queue[i][8][2]
    else
      step_queue_vector[offset+14] = 0
      step_queue_vector[offset+15] = 0
    end

  end
  mcm.set_step_footholds(step_queue_vector)
  mcm.set_step_nfootholds(#step_queue)
end

testing_humanoid_2k15 = true

function state.entry()
  print(state._NAME..' Entry' )
  -- Update the time of entry
  local t_entry_prev = t_entry -- When entry was previously called
  t_entry = Body.get_time()
  t_update = t_entry

  local uTorso = mcm.get_status_uTorso()  
  local uLeft = mcm.get_status_uLeft()
  local uRight = mcm.get_status_uRight()

  --Which foot is ahead?
  local uLeftTorso = util.pose_relative(uLeft,uTorso)
  local uRightTorso = util.pose_relative(uRight,uTorso)

  local leg_move_factor = math.abs(uLeftTorso[1]-uRightTorso[1])/0.25

  is_possible = true
  hcm.set_step_nosolution(0)
  supportLeg=hcm.get_step_supportLeg()


-- Determine next step leg, position, height, angle  
-- supportLeg = footstepplanner.getnextstep()
  







  if hcm.get_step_nosolution()>0 then
    --don't start step if there's no foot positions available!
    is_possible = false
    return
  end

  local step_min = 0.05
--  local step_min = 0.10
  
  step_relpos = hcm.get_step_relpos() 
  step_zpr = hcm.get_step_zpr()
  if step_zpr[1]>0 then sh1,sh2 = step_zpr[1]+step_min, step_zpr[1]
  else sh1,sh2 = step_min, step_zpr[1]
  end

  local st,wt = 1.0,3.0
--  if IS_WEBOTS then st,wt = 1.0,1.0 end
  if IS_WEBOTS and not Config.enable_touchdown then 
    st,wt = 0.3,1.0 
    st,wt = 0.3,1.5 
  end

  local aShiftY0=mcm.get_walk_aShiftY()

  local leg_move_dist = 
    math.abs(step_relpos[1])+math.abs(step_relpos[2])+
    math.abs(step_zpr[1])+step_min+step_min
  local wt2 = wt *  math.max(1,  leg_move_dist / 0.20) 




  --[[
  --automatic detect
  supportLeg = 0 --right support
  if step_relpos[1]>0 then --walk forward
    if uLeftTorso[1]>uRightTorso[1] then supportLeg=1 end--LF is leading foot, so left support
  else
    if uLeftTorso[1]<uRightTorso[1] then supportLeg=1 end--RF is leading foot, so left support
  end
--]]


  if supportLeg == 1 then
    --Take right step

    print("left support, supportY:",Config.walk.supportY)

    local uRightTarget = util.pose_global(step_relpos, uRight)
    local uLeftSupport = util.pose_global({Config.walk.supportX, Config.walk.supportY,0},uLeft)
    local uRightSupport = util.pose_global({Config.walk.supportX, -Config.walk.supportY,0},uRightTarget)
    local uTorsoTarget = util.se2_interpolate(0.5,uLeftSupport,uRightSupport)
    local uLeftTorsoTarget = util.pose_relative(uTorsoTarget, uLeftSupport)
    local side_adj = Config.walk.supportY - 0.00
    local com_side = Config.walk.footY+Config.walk.supportY-side_adj
 

--[[
    print("uLeft:",unpack(uLeft))
    print("uRight:",unpack(uRight))
    print("uRightTarget:",unpack(uRightTarget))
    print("uTorsoTarget:",unpack(uTorsoTarget))
    print("uLeftTorso:",unpack(uLeftTorso))
    print("uLeftTorsoTarget:",unpack(uLeftTorsoTarget))

    print("side_adj:",side_adj)
    print("com_side:",com_side)
--]]

    if Config.enable_touchdown then
      step_queues={
         {
          {{0,0,0},    2,  st, 0.1, 0.1,   {uLeftTorso[1],com_side},{0,0,0} },    --Shift and Lift
          {step_relpos,0,  0.1,wt2,0.1 ,   {0,-side_adj},     {0,sh1,sh2},  {-uLeftTorsoTarget[1],-uLeftTorsoTarget[2] - Config.walk.supportY}},   --LS     --Move and land
         },

         {
          {{0,0,0},2,        st, 0.1, 0.1,   {0,0},{0,0,0} },  --move to center
         },
      }
    else
      if Config.piecewise_step then

        step_queues={
        {
          {{0,0,0},    2,  st*3, st, 0.1,   {uLeftTorso[1],com_side},{0,0,0} },    --Shift and Lift
--        },
--        {
          {step_relpos,0,  st,wt2,st ,   {0,-side_adj},     {0,sh1,sh2},  {-uLeftTorsoTarget[1],-uLeftTorsoTarget[2] - Config.walk.supportY}},   --LS     --Move and land
        },
        {
          {{0,0,0},2,        st*3, st, st,   {0,0},{0,0,0} },  --move to center
        },
        }


      else
        step_queues={
         {
          {{0,0,0},    2,  st*3, 0.1, 0.1,   {uLeftTorso[1],com_side},{0,0,0} },    --Shift and Lift
          {step_relpos,0,  0.1,wt2,0.1 ,   {0,-side_adj},     {0,sh1,sh2},  {-uLeftTorsoTarget[1],-uLeftTorsoTarget[2] - Config.walk.supportY}},   --LS     --Move and land

        {{0,0,0},2,        st*3, st, 0.1,   {0,0},{0,0,0} },  --move to center
----------FOR HUMANOIDS TESING, move all the way to the next support
  --   {{0,0,0},2,       st*6, st*3, 0.1,   {uRightTorso[1]+step_relpos[1]/2,-com_side},{0,0,0} },  --move to center



         },
        }

      end
      
    end

  else

--print("right support, supportY:",Config.walk.supportY)

    --Take left step
    local uLeftTarget = util.pose_global(step_relpos, uLeft)
    local uLeftSupport = util.pose_global({Config.walk.supportX, Config.walk.supportY,0},uLeftTarget)
    local uRightSupport = util.pose_global({Config.walk.supportX, -Config.walk.supportY,0},uRight)
    local uTorsoTarget = util.se2_interpolate(0.5,uLeftSupport,uRightSupport)
    local uRightTorsoTarget = util.pose_relative(uTorsoTarget, uRightSupport)
    local side_adj = Config.walk.supportY - 0.00
    local com_side = Config.walk.footY+Config.walk.supportY-side_adj

--[[  
    print("uLeft:",unpack(uLeft))
    print("uRight:",unpack(uRight))
    print("uLeftTarget:",unpack(uLeftTarget))
    print("uTorsoTarget:",unpack(uTorsoTarget))
    print("uRightTorso:",unpack(uRightTorso))
    print("uRightTorsoTarget:",unpack(uRightTorsoTarget))

    print("side_adj:",side_adj)
    print("com_side:",com_side)
--]]    

    if Config.enable_touchdown then
      step_queues={
         {
          {{0,0,0},2,        st, 0.1, 0.1,   {uRightTorso[1]  , -com_side},{0,0,0} },    --Shift and Lift
          {step_relpos,1,   0.1,wt2,0.1 ,   {0,side_adj}, {0,sh1,sh2}   ,  {-uRightTorsoTarget[1]  , -uRightTorsoTarget[2] + Config.walk.supportY}},   --LS     --Move and land
         },

         {
          {{0,0,0},2,        st, 0.1, 0.1,   {0,0},{0,0,0} },  --move to center
         },
      }
    else
      if Config.piecewise_step then
        step_queues={
        {
          {{0,0,0},2,        st*3, st, 0.1,   {uRightTorso[1]  , -com_side},{0,0,0} },    --Shift and Lift
--        },
--        {
          {step_relpos,1,   st,wt2,st ,   {0,side_adj}, {0,sh1,sh2}   ,  {-uRightTorsoTarget[1]  , -uRightTorsoTarget[2] + Config.walk.supportY}},   --LS     --Move and land
        },
        {
          {{0,0,0},2,        st*3, st, st,   {0,0},{0,0,0} },  --move to center
        },
        }

      else
       step_queues={
         {
          {{0,0,0},2,        st*3, 0.1, 0.1,   {uRightTorso[1]  , -com_side},{0,0,0} },    --Shift and Lift
          {step_relpos,1,   0.1,wt2,0.1 ,   {0,side_adj}, {0,sh1,sh2}   ,  {-uRightTorsoTarget[1]  , -uRightTorsoTarget[2] + Config.walk.supportY}},   --LS     --Move and land
          {{0,0,0},2,        st*3, st, 0.1,   {0,0},{0,0,0} },  --move to center


----------FOR HUMANOIDS TESING, move all the way to the next support
--       {{0,0,0},2,       st*6, st*3, 0.1,   {uRightTorso[1]+step_relpos[1]/2,com_side},{0,0,0} },  --move to center




         },
      }
      end
    end
  end




  stage = 1
  calculate_footsteps(stage)
  motion_ch:send'stair'  
  mcm.set_stance_singlesupport(1)
  is_started = true  
  t_stage = t_entry
end


function state.update()
  local t  = Body.get_time()

  --print(state._NAME..' Update' ) 
  -- Get the time of update
  
  local dt = t - t_update

  if not is_possible then 
    print("ENDEDENDED")
    print("ENDEDENDED")
    return "done" 
  end
  -- Save this at the last update time
  t_update = t
  if mcm.get_walk_ismoving()==0 and t-t_stage>0.5 then    
    if ready_for_input then print("Ready")
      ready_for_input = false
    end    
    if stage==#step_queues then 
      print("STEPEND")      
      motion_ch:send'stop'  
      --return 'nextstep'
      hcm.set_step_dir(0)
      return 'done'


    elseif hcm.get_state_proceed()==1 then     

      print("STEPADVANCE")
      --Clear the zmp compensation value here between transition---------------------
      local uTorsoZMPComp = mcm.get_status_uTorsoZMPComp()
      local uTorso = mcm.get_status_uTorso()
      uTorso = util.pose_global({uTorsoZMPComp[1],uTorsoZMPComp[2],0},uTorso)
      mcm.set_status_uTorsoZMPComp({0,0,0})
      mcm.set_status_uTorso(uTorso)


      hcm.set_state_proceed(0) --stop at each step


      stage = stage+1
      calculate_footsteps(stage)
      motion_ch:send'stair'  
      ready_for_input = true
      t_stage = t
    end
  else 
    hcm.set_state_proceed(0) --no pogo stick
  end

end

function state.exit()
  print(state._NAME..' Exit' )
  mcm.set_stance_singlesupport(0)
  if hcm.get_step_auto()==0 then
    hcm.set_step_dir(0)
  end
end

return state
