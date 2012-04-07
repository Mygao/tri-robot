module(..., package.seeall);
require('vector')

--Sit/stand stance parameters
stance={};
stance.bodyHeightSit = 0.175;
stance.footXSit = -0.03;
stance.dpLimitSit=vector.new({.03,.01,.06,.1,.3,.1});
stance.bodyHeightDive= 0.25;
stance.bodyTiltStance=20*math.pi/180; --bodyInitial bodyTilt, 0 for webots
stance.dpLimitStance=vector.new({.04, .03, .07, .4, .4, .4});
stance.initangle = {
  0,0,
  105*math.pi/180, 30*math.pi/180, -45*math.pi/180,
  0,  0.055, -0.77, 2.08, -1.31, -0.055, 
  0, -0.055, -0.77, 2.08, -1.31, 0.055,
  105*math.pi/180, -30*math.pi/180, -45*math.pi/180,
}

-- Head Parameters
head = {};
head.camOffsetZ = 0.37;
head.pitchMin = -55*math.pi/180;
head.pitchMax = 68*math.pi/180;
head.yawMin = -90*math.pi/180;
head.yawMax = 90*math.pi/180;
head.cameraPos = {{0.034, 0.0, 0.0332}} --OP, spec value, may need to be recalibrated
head.cameraAngle = {{0.0,0}}; -- We set it zero here
head.neckZ=0.0765; --From CoM to neck joint 
head.neckX=0.013; --From CoM to neck joint

--IMU bias/sensitivity parameters
gyro={};
gyro.rpy={3,2,1}	--axis remap, rotation in x,y,z
acc={};
acc.xyz={2,1,3};	--axis remap

angle={};
angle.gMax = 1.2;  
angle.gMin= 0.8;
angle.accFactor=0.2;

-- Spec, 0.0008 V/dps  / (1.5/512) V/step 
-- Output unit:degree per sec
gyro.sensitivity=vector.new({1,-1,-1})/0.273 
gyro.zero=vector.new({512,512,512});

--Those biases can be measured using test_imu.lua
acc.sensitivity=vector.new({1,-1,-1})/128; --Spec
acc.zero=vector.new({512,512,512}); --Spec

--Servo parameters
servo={}
servo.idMap={
  19,20,		--Head
  2,4,6,		--LArm
  8,10,12,14,16,18,--LLeg
  7,9,11,13,15,17,--RLeg
  1,3,5,		--RArm
}
servo.dirReverse={
  2,	--Head
  4,	--LArm
  6,7,8,9,--LLeg
  12,13,16,--RLeg
  18,19,20,--RArm
}

-- PID Parameters
servo.p_param={
  32,32,                --Head
  16,16,16,             --LArm
  16,16,16,16,16,16,    --LLeg
  16,16,16,16,16,16,    --RLeg
  --  32,32,32,32,32,32,  --RLeg
  16,16,16,             --RArm
  --  21,                 --Aux servo
}
servo.i_param={
  0,0,          --Head
  0,0,0,        --LArm
  0,0,0,0,0,0,  --LLeg
  0,0,0,0,0,0,  --RLeg
  0,0,0,        --RArm
  --  21,         --Aux servo
}
servo.d_param={
  8,8,              --Head
  16,16,16,         --LArm
  16,16,16,16,16,16,--LLeg
  16,16,16,16,16,16,--RLeg
  16,16,16,         --RArm
  --  21,             --Aux servo
}


----------------------------------------------
--Robot-specific firmware version handling
----------------------------------------------

servo.pid = 0; --old firmware default
servo.armBias = {0,0,0,0,0,0}; --in degree

local robotName = unix.gethostname();
if( robotName=='felix' ) then
elseif( robotName=='betty' ) then
elseif( robotName=='linus' ) then
elseif( robotName=='lucy' ) then
  servo.pid = 1;
  servo.idMap = {
    19,20,		--Head
    2,4,6,		--LArm
    8,10,12,14,16,18,--LLeg
    7,9,11,13,15,17,--RLeg
    1,3,5,		--RArm
    --    21, 		--Aux servo
  }
elseif( robotName=='scarface' ) then
end


nJoint = #servo.idMap;
if servo.pid ==0 then -- For old firmware with 12-bit precision
  print(robotName.." has 12-bit firmware")
  servo.steps=vector.ones(nJoint)*1024;
  servo.moveRange=vector.ones(nJoint)*300*math.pi/180;
  servo.posZero={
    512,512,
    205,665,819,
    512,512,512,512,512,512,
    512,512,512,512,512,512,
    819,358,205,
    --		512,		--For aux
  }
else -- For new, PID firmware with 14-bit precision
  print(robotName.." has 14-bit firmware")
  servo.steps=vector.ones(nJoint)*4096;
  servo.posZero={
    2048,2048, --Head
    1024,2560,3072, --LArm
    2048,2048,2048,2048,2048,2048, --LLeg
    2048,2048,2048,2048,2048,2048, --RLeg
    3072,1536,1024, --RArm
    --          512, -- For aux
  };
  servo.moveRange=vector.ones(nJoint)*360*math.pi/180;
  servo.armBias = vector.new({0,15,0,0,-45,0}) * math.pi/180 * servo.steps[1]/servo.moveRange[1];
  --[[ For aux
  servo.moveRange[21] = 300;
  servo.steps[21] = 1024;
  --]]
end

