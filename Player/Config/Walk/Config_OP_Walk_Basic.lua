module(..., package.seeall); require('vector')
require 'unix'
-- Walk Parameters

walk = {};

----------------------------------------------
-- Stance and velocity limit values
----------------------------------------------
walk.stanceLimitX={-0.10,0.10};
walk.stanceLimitY={0.07,0.20};
walk.stanceLimitA={0*math.pi/180,30*math.pi/180};
walk.velLimitX={-.04,.06};
walk.velLimitY={-.04,.04};
walk.velLimitA={-.4,.4};
walk.velDelta={0.02,0.02,0.15} 

----------------------------------------------
-- Stance parameters
---------------------------------------------
walk.bodyHeight = 0.295; 
walk.bodyTilt=20*math.pi/180; 
walk.footX= -0.020; 
walk.footY = 0.035;
walk.supportX = -0.005;
walk.supportY = 0.020;
walk.qLArm=math.pi/180*vector.new({90,8,-40});
walk.qRArm=math.pi/180*vector.new({90,-8,-40});
walk.qLArmKick=math.pi/180*vector.new({90,15,-40});
walk.qRArmKick=math.pi/180*vector.new({90,-15,-40});

walk.hardnessSupport = 1;
walk.hardnessSwing = 1;
walk.hardnessArm=.3;
---------------------------------------------
-- Gait parameters
---------------------------------------------
walk.tStep = 0.35;
walk.tZmp = 0.165;
walk.stepHeight = 0.035;
walk.phSingle={0.15,0.85};

--------------------------------------------
-- Compensation parameters
--------------------------------------------
walk.hipRollCompensation = 4*math.pi/180;
walk.ankleMod = vector.new({-1,0})/0.12 * 10*math.pi/180;

--------------------------------------------------------------
--Imu feedback parameters, alpha / gain / deadband / max
--------------------------------------------------------------
gyroFactor = 0.273*math.pi/180 * 300 / 1024; --dps to rad/s conversion

walk.ankleImuParamX={0.9,0.3*gyroFactor, 0, 25*math.pi/180};
walk.kneeImuParamX={0.9,1.2*gyroFactor, 0, 25*math.pi/180};
walk.ankleImuParamY={0.9,0.7*gyroFactor, 0, 25*math.pi/180};
walk.hipImuParamY={0.9,0.3*gyroFactor, 0, 25*math.pi/180};
walk.armImuParamX={0.3,10*gyroFactor, 20*math.pi/180, 45*math.pi/180};
walk.armImuParamY={0.3,10*gyroFactor, 20*math.pi/180, 45*math.pi/180};

--------------------------------------------
-- Support point modulation values
--------------------------------------------
walk.supportFront = 0.01; --Lean front when walking fast forward
walk.supportBack = -0.01; --Lean back when walking backward
walk.supportSide = 0.01; --Lean sideways when sidestepping

--------------------------------------------
-- WalkKick parameters
--------------------------------------------
walk.walkKickVel = {0.06, 0.12} --step / kick / follow 
walk.walkKickSupportMod = {{0,0},{0,0}}
walk.walkKickHeightFactor = 2.0;
walk.tStepWalkKick = 0.30;

walk.sideKickVel1 = {0.04,0.04};
walk.sideKickVel2 = {0.09,0.05};
walk.sideKickVel3 = {0.09,-0.02};
walk.sideKickSupportMod = {{0,0},{0,0}};
walk.tStepSideKick = 0.30;

--Fall detection angle... OP requires large angle
walk.fallAngle = 50*math.pi/180;

--------------------------------------------
-- Robot - specific calibration parameters
--------------------------------------------

walk.kickXComp = 0;
walk.supportCompL = {0,0,0};
walk.supportCompR = {0,0,0};
walk.servoBias = {0,0,0,0,0,0,0,0,0,0,0,0};
walk.footXComp = 0;
walk.footYComp = 0;
walk.headPitch = 40* math.pi / 180; --Pitch angle offset of OP 
walk.headPitchComp = 0;

--Apply robot specific compensation to default values
walk.footX = walk.footX + walk.footXComp;
walk.footY = walk.footY + walk.footYComp;
walk.headPitch = walk.headPitch + walk.headPitchComp;


