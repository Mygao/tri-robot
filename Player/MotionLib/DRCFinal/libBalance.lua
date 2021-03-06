local Body   = require'Body'
local K      = Body.Kinematics
local T      = require'Transform'
local util   = require'util'
local vector = require'vector'

require'mcm'

-- SJ: Shared library for 2D leg trajectory generation
-- So that we can reuse them for different controllers

local footY    = Config.walk.footY
local supportX = Config.walk.supportX
local supportY = Config.walk.supportY
local torsoX    = Config.walk.torsoX

local DEG_TO_RAD = math.pi/180
local sformat = string.format

-- Gyro stabilization parameters
local ankleImuParamX = Config.walk.ankleImuParamX
local ankleImuParamY = Config.walk.ankleImuParamY
local kneeImuParamX  = Config.walk.kneeImuParamX
local hipImuParamY   = Config.walk.hipImuParamY

-- Hip sag compensation parameters
local hipRollCompensation = Config.walk.hipRollCompensation or {0,0}
local ankleRollCompensation = Config.walk.ankleRollCompensation or 0
local anklePitchCompensation = Config.walk.anklePitchCompensation or 0
local kneePitchCompensation = Config.walk.kneePitchCompensation or 0
local hipPitchCompensation = Config.walk.hipPitchCompensation or 0



local function get_ft()
  local y_angle_zero = 3*math.pi/180
  local l_ft, r_ft = Body.get_lfoot(), Body.get_rfoot()  
  local ft= {
    lf_x=l_ft[1],rf_x=r_ft[1],
    lf_y=l_ft[2],rf_y=r_ft[2],
    lf_z=l_ft[3],rf_z=r_ft[3],
    lt_x=-l_ft[4],rt_x=-r_ft[4],
    lt_y=l_ft[5],rt_y=r_ft[5],
    lt_z=0, rt_z=0 --do we ever need yaw torque?
  }
  if IS_WEBOTS then
    ft.lt_y, ft.rt_y = -l_ft[4],-r_ft[5]      
    ft.lt_x,ft.rt_x = -l_ft[5],-r_ft[4] 
  end
  local rpy = Body.get_rpy()
  local gyro, gyro_t = Body.get_gyro()
  local imu={
    roll_err = rpy[1], pitch_err = rpy[2]-y_angle_zero,  
    v_roll = gyro[1], v_pitch = gyro[2]
  }

  mcm.set_status_LFT({ft.lf_x,ft.lf_y,ft.lf_z,  ft.lt_x, ft.lt_y, ft.lt_z})
  mcm.set_status_RFT({ft.rf_x,ft.rf_y,ft.rf_z,  ft.rt_x, ft.rt_y, ft.rt_z})
  mcm.set_status_IMU({imu.roll_err, imu.pitch_err, v_roll,v_pitch})
  return ft,imu
end




local function get_compensation()


--New compensation code to cancelout backlash on ALL leg joints
  dt= dt or 0.010

  --Now we limit the angular velocity of compensation angles 

  local dShift = {30*DEG_TO_RAD,30*DEG_TO_RAD,30*DEG_TO_RAD,30*DEG_TO_RAD}

  local gyro_pitch = gyro_rpy[2]
  local gyro_roll = gyro_rpy[1]

  -- Ankle feedback
  local ankleShiftXTarget = util.procFunc(gyro_pitch*ankleImuParamX[2],ankleImuParamX[3],ankleImuParamX[4])
  local ankleShiftYTarget = util.procFunc(gyro_roll*ankleImuParamY[2],ankleImuParamY[3],ankleImuParamY[4])
  local kneeShiftXTarget = util.procFunc(gyro_pitch*kneeImuParamX[2],kneeImuParamX[3],kneeImuParamX[4])
  local hipShiftYTarget=util.procFunc(gyro_roll*hipImuParamY[2],hipImuParamY[3],hipImuParamY[4])

--[[
  local angleShift = mcm.get_walk_angleShift()

  angleShift[1] = util.p_feedback(angleShift[1], ankleShiftXTarget, ankleImuParamX[1],dShift[1], dt)
  angleShift[2] = util.p_feedback(angleShift[2], ankleShiftYTarget, ankleImuParamY[1], dShift[2], dt)
  angleShift[3] = util.p_feedback(angleShift[3], kneeShiftXTarget, kneeImuParamX[1], dShift[3], dt)
  angleShift[4] = util.p_feedback(angleShift[4], hipShiftYTarget, hipImuParamY[1], dShift[4], dt)
--]]




  local dShiftTarget = {}
  dShiftTarget[1]=ankleImuParamX[1]*(ankleShiftXTarget-angleShift[1])
  dShiftTarget[2]=ankleImuParamY[1]*(ankleShiftYTarget-angleShift[2])
  dShiftTarget[3]=kneeImuParamX[1]*(kneeShiftXTarget-angleShift[3])
  dShiftTarget[4]=hipImuParamY[1]*(hipShiftYTarget-angleShift[4])
  

  angleShift[1] = angleShift[1] + math.max(-dShift[1]*dt,math.min(dShift[1]*dt,dShiftTarget[1]))
  angleShift[2] = angleShift[2] + math.max(-dShift[2]*dt,math.min(dShift[2]*dt,dShiftTarget[2])) 
  angleShift[3] = angleShift[3] + math.max(-dShift[3]*dt,math.min(dShift[3]*dt,dShiftTarget[3])) 
  angleShift[4] = angleShift[4] + math.max(-dShift[4]*dt,math.min(dShift[4]*dt,dShiftTarget[4])) 


  mcm.set_walk_angleShift(angleShift)

  local delta_legs = vector.zeros(12)

  local uTorso = mcm.get_status_uTorso()
  local uLeft = mcm.get_status_uLeft()
  local uRight = mcm.get_status_uRight()
  local uZMP = mcm.get_status_uZMP()

  local uLeftSupport = util.pose_global({supportX, supportY, 0}, uLeft)
  local uRightSupport = util.pose_global({supportX, -supportY, 0}, uRight)

  local dTL = math.sqrt( (uTorso[1]-uLeftSupport[1])^2+ (uTorso[2]-uLeftSupport[2])^2)
  local dTR = math.sqrt((uTorso[1]-uRightSupport[1])^2+(uTorso[2]-uRightSupport[2])^2)
  local supportRatio = math.max(dTL,dTR)/(dTL+dTR)

  --SJ: now we apply the compensation during DS too
  local phComp1 = Config.walk.phComp[1]
  local phComp2 = Config.walk.phComp[2]
  local phCompSlope = Config.walk.phCompSlope

  local phSingleComp = math.min( math.max(ph-phComp1, 0)/(phComp2-phComp1), 1)
  local phComp = math.min( phSingleComp/phCompSlope, 1,
                          (1-phSingleComp)/phCompSlope)
  supportRatioLeft, supportRatioRight = 0,0


  local phComp2 = math.max(0, math.min(1, (supportRatio-0.58)/ (0.66-0.58)) )
  local phCompLift = math.max(0, math.min(1, (supportRatio-0.6)/ (0.94-0.58)) )


  local phCompLift = phComp2 --knee compensation for standard walking too



--  if mcm.get_stance_singlesupport()==1 then phComp = phComp*2 end

  phComp = 0 
  local swing_leg_sag_compensation_left = Config.walk.footSagCompensation[1]
  local swing_leg_sag_compensation_right = Config.walk.footSagCompensation[2]

  local kneeComp={0,0}  
  local knee_compensation = Config.walk.kneePitchCompensation

  local zLegComp = mcm.get_status_zLegComp()

  if dTL>dTR then --Right support
    supportRatioRight = math.max(phComp,phComp2);
    kneeComp[2] = phCompLift*knee_compensation
    mcm.set_walk_zSag({phCompLift*swing_leg_sag_compensation_left,0})

    zLegComp[1] = math.max(-supportRatioRight,zLegComp[1])
  else
    supportRatioLeft = math.max(phComp,phComp2);
    kneeComp[1] = phCompLift*knee_compensation

    mcm.set_walk_zSag({0,phCompLift*swing_leg_sag_compensation_right})
    zLegComp[2] = math.max(-supportRatioLeft,zLegComp[2])
  end

  



  delta_legs[2] = angleShift[4] + hipRollCompensation[1]*supportRatioLeft
  delta_legs[3] = - hipPitchCompensation*supportRatioLeft
  delta_legs[4] = angleShift[3] - kneePitchCompensation*supportRatioLeft-kneeComp[1]
  delta_legs[5] = angleShift[1] - anklePitchCompensation*supportRatioLeft
  delta_legs[6] = angleShift[2] + ankleRollCompensation*supportRatioLeft

  delta_legs[8]  = angleShift[4] - hipRollCompensation[2]*supportRatioRight
  delta_legs[9] = -hipPitchCompensation*supportRatioRight
  delta_legs[10] = angleShift[3] - kneePitchCompensation*supportRatioRight-kneeComp[2]
  delta_legs[11] = angleShift[1] - anklePitchCompensation*supportRatioRight
  delta_legs[12] = angleShift[2] - ankleRollCompensation

  mcm.set_walk_delta_legs(delta_legs)  

  return delta_legs, angleShift



end







function moveleg.get_leg_compensation_new(supportLeg, ph, gyro_rpy,angleShift,supportRatio,dt)


end












function moveleg.ft_compensate(t_diff)

  local enable_balance = hcm.get_legdebug_enable_balance()
  local ft,imu = moveleg.get_ft()
  moveleg.process_ft_height(ft,imu,t_diff) -- height adaptation
--  moveleg.process_ft_roll(ft,t_diff) -- roll adaptation
  moveleg.process_ft_pitch(ft,t_diff) -- pitch adaptation
end






function moveleg.process_ft_height(ft,imu,t_diff)
  --------------------------------------------------------------------------------------------------------
  -- Foot height differential adaptation

  local zf_touchdown = 50
  local zf_touchdown_confirm = 50
  local zf_support = 150

  local z_shift_max = 0.05 --max 5cm difference
  local z_vel_max_diff = 0.4 --max 40cm per sec
  local z_vel_max_balance = 0.05 --max 5cm per sec
  local k_const_z_diff = 0.5 / 100  -- 50cm/s for 100 N difference
  local z_shift_diff_db = 50 --50N deadband
  local k_balancing = 0.4 


  local enable_balance = hcm.get_legdebug_enable_balance()


  local uLeft = mcm.get_status_uLeft()
  local uRight = mcm.get_status_uRight()
  local uTorso = mcm.get_status_uTorso()  

  local uLeftTorso = util.pose_relative(uLeft,uTorso)
  local uRightTorso = util.pose_relative(uRight,uTorso)

  local zvShift={0,0}
  local balancing_type=0


  local enable_adapt = true

  local LR_pitch_err = -(uLeftTorso[1]-uRightTorso[1])*math.tan( imu.pitch_err)
  local LR_roll_err =  (uLeftTorso[2]-uRightTorso[2])*math.tan(imu.roll_err)
  local zvShiftTarget = util.procFunc( (LR_pitch_err + LR_roll_err) * k_balancing, 0, z_vel_max_balance )

  local zmp_err_left = {0,0,0}
  local zmp_err_right = {0,0,0}


  local uZMP = mcm.get_status_uZMP()  
  local uZMPLeft=mcm.get_status_uLeft()
  local uZMPRight=mcm.get_status_uRight()
  local forceLeft, forceRight = 0,0

  if ft.lf_z>zf_touchdown then
    zmp_err_left = {-ft.lt_y/ft.lf_z, ft.lt_x/ft.lf_z, 0}
    uZMPLeft = util.pose_global(zmp_err_left, uLeft)
    forceLeft = ft.lf_z
  end
  if ft.rf_z>zf_touchdown then
    zmp_err_right = {-ft.rt_y/ft.rf_z, ft.rt_x/ft.rf_z, 0}
    uZMPRight = util.pose_global(zmp_err_right, uRight)
    forceRight = ft.rf_z
  end

  local uZMPMeasured= (forceLeft*uZMPLeft + forceRight*uZMPRight) / (forceLeft+forceRight)

  local force_total = {0,0}

  force_total[1] = math.sqrt(ft.lf_z^2+ft.lf_x^2+ft.lf_y^2)
  force_total[2] = math.sqrt(ft.rf_z^2+ft.rf_x^2+ft.rf_y^2)


  mcm.set_status_LZMP({zmp_err_left[1],zmp_err_left[2],0})
  mcm.set_status_RZMP({zmp_err_right[1],zmp_err_right[2],0})  
  mcm.set_status_uZMPMeasured(uZMPMeasured) 
  

  local uTorsoZMPComp = mcm.get_status_uTorsoZMPComp()

--  local zmp_err_db = 0.01 
  local zmp_err_db = 0.0025  
  local k_zmp_err = -0.25 --0.5cm per sec for 1cm error
  local max_torso_vel = 0.01 --1cm per sec
  local max_zmp_comp = 0.04

  local foot_z_vel = -0.02

--  local foot_z_vel = -0.03


	local foot_z_flex_lift = 0.01
	local foot_z_flex_lift = 0.00

	if (ft.lf_z>zf_support*2 and ft.rf_z<zf_touchdown) or enable_balance[2]>0 then

      local torso_x_comp = util.procFunc(zmp_err_left[1]*k_zmp_err,zmp_err_db,max_torso_vel)
      local torso_y_comp = util.procFunc(zmp_err_left[2]*k_zmp_err,zmp_err_db,max_torso_vel)
  --    uTorsoZMPComp[1] = util.procFunc(uTorsoZMPComp[1]+ torso_x_comp*t_diff,0,max_zmp_comp)
      uTorsoZMPComp[2] = util.procFunc(uTorsoZMPComp[2]+ torso_y_comp*t_diff,0,max_zmp_comp)

      mcm.set_status_uTorsoZMPComp(uTorsoZMPComp)


  elseif  (ft.rf_z>zf_support*2 and ft.lf_z<zf_touchdown) or enable_balance[1]>0 then

      local torso_x_comp = util.procFunc(zmp_err_right[1]*k_zmp_err,zmp_err_db,max_torso_vel)
      local torso_y_comp = util.procFunc(zmp_err_right[2]*k_zmp_err,zmp_err_db,max_torso_vel)
  --    uTorsoZMPComp[1] = uTorsoZMPComp[1] + torso_x_comp*t_diff
      uTorsoZMPComp[2] = uTorsoZMPComp[2] + torso_y_comp*t_diff

      mcm.set_status_uTorsoZMPComp(uTorsoZMPComp)


  end

  if ft.lf_z>zf_support and ft.rf_z>zf_support then --double support
  elseif ft.lf_z>zf_support then --left support

    if enable_balance[2]>0 then --left support  
      if ft.rf_z<zf_touchdown and uTorsoZMPComp[2]>-0.02 then
          zvShift[2] = foot_z_vel --Lower left feet 
  --      elseif zmp_err_left[2]>0.01 then 
          --zvShift[2] = 0.01 --Raise the foot
      end
      if ft.rf_z>zf_touchdown_confirm and uTorsoZMPComp[2]<-0.02 then
        print("Touchdown detected")
        enable_balance[2]=0
        hcm.set_legdebug_enable_balance(enable_balance)
        hcm.set_state_proceed(1) --auto advance!

--[[
			  local zShift = mcm.get_status_zLeg()
				mcm.set_status_zLeg({zShift[1],zShift[2]+foot_z_flex_lift})
				mcm.set_status_zLegComp({0,-foot_z_flex_lift})
--]]
      end
    end

  elseif ft.rf_z>zf_support then  --right support

    if enable_balance[1]>0 then --right support



      if ft.lf_z<zf_touchdown and uTorsoZMPComp[2]<0.02 then
        zvShift[1] = foot_z_vel --Lower left feet 
      end

      if ft.lf_z>zf_touchdown_confirm and uTorsoZMPComp[2]>0.02 then
        print("Touchdown detected")
        enable_balance[1]=0
        hcm.set_legdebug_enable_balance(enable_balance)
        hcm.set_state_proceed(1) --auto advance!
--[[
			  local zShift = mcm.get_status_zLeg()
				mcm.set_status_zLeg({zShift[1]+foot_z_flex_lift,zShift[2]})
				mcm.set_status_zLegComp({-foot_z_flex_lift,0})
--]]
      end
    end
  end



  local zShift = mcm.get_status_zLeg()
  local z_min = -0.05

  zShift[1] = math.max(z_min, zShift[1]+zvShift[1]*t_diff)
  zShift[2] = math.max(z_min, zShift[2]+zvShift[2]*t_diff)

  mcm.set_walk_zvShift(zvShift)
  mcm.set_walk_zShift(zShift)
  mcm.set_status_zLeg(zShift)
  
  --------------------------------------------------------------------------------------------------------
end

function moveleg.process_ft_roll(ft,t_diff)

--[[
  local k_const_tx =   20 * math.pi/180 /5  --Y angular spring constant: 20 deg/s  / 5 Nm
  local r_const_tx =   0 --zero damping for now  
  local ax_shift_db =  0.3 -- 0.3Nm deadband
  local ax_vel_max = 30*math.pi/180 
  local ax_shift_max = 30*math.pi/180
--]]

--slower, more damped
  local k_const_tx =  10 *   math.pi/180 /5  --Y angular spring constant: 10 deg/s  / 5 Nm
  local r_const_tx =   -0.2 --zero damping for now
  local ax_shift_max = 30*math.pi/180
  local ax_shift_db = 1
  local ax_vel_max = 10*math.pi/180 


  if IS_WEBOT and false then
    k_const_tx = k_const_tx*3
    ax_vel_max = ax_vel_max*3
  end


  local df_max = 100 --full damping beyond this
  local df_min = 30 -- zero damping 

  ----------------------------------------------------------------------------------------
  -- Ankle roll adaptation 

  local aShiftX=mcm.get_walk_aShiftX()
  local avShiftX=mcm.get_walk_avShiftX()

  local enable_balance = hcm.get_legdebug_enable_balance()

  local left_damping_factor = math.max(0,math.min(1, (ft.lf_z-df_min)/df_max))
  local right_damping_factor = math.max(0,math.min(1, (ft.rf_z-df_min)/df_max))



  avShiftX[1] = util.procFunc( ft.lt_x*k_const_tx + 
    avShiftX[1]*r_const_tx*left_damping_factor    
      ,k_const_tx*ax_shift_db*left_damping_factor, 
      ax_vel_max)

  avShiftX[2] = util.procFunc( ft.rt_x*k_const_tx + 
    avShiftX[2]*r_const_tx*right_damping_factor 
      ,k_const_tx*ax_shift_db*right_damping_factor, 
      ax_vel_max)

  if enable_balance[1]>0 then
    aShiftX[1] = aShiftX[1]+avShiftX[1]*t_diff
    aShiftX[1] = math.min(ax_shift_max,math.max(-ax_shift_max,aShiftX[1]))
  end

  if enable_balance[2]>0 then
    aShiftX[2] = aShiftX[2]+avShiftX[2]*t_diff
    aShiftX[2] = math.min(ax_shift_max,math.max(-ax_shift_max,aShiftX[2]))
  end

  mcm.set_walk_aShiftX(aShiftX)
  mcm.set_walk_avShiftX(avShiftX)
  

  ----------------------------------------------------------------------------------------

end

function moveleg.process_ft_pitch(ft,t_diff)

  local k_const_ty =  20 *   math.pi/180 /5  --Y angular spring constant: 20 deg/s  / 5 Nm
  local r_const_ty =   -0.2 --zero damping for now
  local ay_shift_max = 30*math.pi/180
  local ay_shift_db = 1
  local ay_vel_max = 10*math.pi/180 

  local df_max = 100 --full damping beyond this
  local df_min = 30 -- zero damping 


if IS_WEBOT and false then
    k_cosnt_ty = k_cosnt_ty*3
    ay_vel_max = ay_vel_max*3
  end

  ----------------------------------------------------------------------------------------
  -- Ankle pitch adaptation 
  local aShiftY=mcm.get_walk_aShiftY()
  local avShiftY=mcm.get_walk_avShiftY()

  local enable_balance = hcm.get_legdebug_enable_balance()


  local left_damping_factor = math.max(0,math.min(1, (ft.lf_z-df_min)/df_max))
  local right_damping_factor = math.max(0,math.min(1, (ft.rf_z-df_min)/df_max))


    
  avShiftY[1] = util.procFunc(  ft.lt_y*k_const_ty + 
    avShiftY[1]*r_const_ty*left_damping_factor 
      ,k_const_ty*ay_shift_db*left_damping_factor , 
      ay_vel_max)
  avShiftY[2] = util.procFunc(  ft.rt_y*k_const_ty + 
    avShiftY[2]*r_const_ty*right_damping_factor    
      ,k_const_ty*ay_shift_db*right_damping_factor , 
      ay_vel_max)

	--if foot is firmly on the ground, lower the gain a lot (to reduce vibration)
	if ft.lf_z>100 then avShiftY[1] = avShiftY[1]*0.25  end
	if ft.rf_z>100 then avShiftY[2] = avShiftY[2]*0.25  end



--[[
  --foot idle, return to heel strike position
  if ft.lf_z<50 and math.abs(ft.lt_y)<ay_shift_db then
	  aShiftTarget = -10*math.pi/180		
		avShiftY[1] = util.procFunc( (aShiftTarget-aShiftY[1])*0.5, 0, 5*math.pi/180)
  end

  if ft.rf_z<50 and math.abs(ft.rt_y)<ay_shift_db then
	  aShiftTarget = -10*math.pi/180		
		avShiftY[2] = util.procFunc( (aShiftTarget-aShiftY[2])*0.5, 0, 5*math.pi/180)
  end
--]]

  if enable_balance[1]>0 then
    aShiftY[1] = aShiftY[1]+avShiftY[1]*t_diff
    aShiftY[1] = math.min(ay_shift_max,math.max(-ay_shift_max,aShiftY[1]))
  end

  if enable_balance[2]>0 then
    aShiftY[2] = aShiftY[2]+avShiftY[2]*t_diff
    aShiftY[2] = math.min(ay_shift_max,math.max(-ay_shift_max,aShiftY[2]))
  end

  mcm.set_walk_aShiftY(aShiftY)
  mcm.set_walk_avShiftY(avShiftY)

  ----------------------------------------------------------------------------------------

end






return moveleg
