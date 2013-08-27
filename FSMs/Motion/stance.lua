--[[
local Config = require('Config')
local Body = require(Config.dev.body)
local Kinematics = require(Config.dev.kinematics)
local walk = require(Config.dev.walk)
local vector = require('vector')
local Transform = require('Transform')
require('mcm')
--]]

require'common_motion'

local stance = {}
stance._NAME = ...

local active = true;
local t0 = 0;

local bodyHeight = Config.walk.bodyHeight;
local bodyTilt=Config.walk.bodyTilt;
local qLArm = Config.walk.qLArm;
local qRArm = Config.walk.qRArm;

-- Max change in position6D to reach stance:
local dpLimit = Config.stance.dpLimitStance or vector.new({.04, .03, .07, .4, .4, .4});
 
local tFinish=0;
local tStartWait=0.2;
 
local tEndWait=Config.stance.delay or 0;
local tEndWait=tEndWait/100;
local tStart=0;
 
local hardnessLeg = Config.stance.hardnessLeg or 1;

function stance.entry()
  print("Motion SM:"..stance._NAME.." entry");

  -- Final stance foot position6D
  pTorsoTarget = vector.new({-mcm.get_footX(), 0, bodyHeight, 0,bodyTilt,0})
  pLLeg = vector.new({-Config.walk.supportX, Config.walk.footY, 0, 0,0,0})
  pRLeg = vector.new({-Config.walk.supportX, -Config.walk.footY, 0, 0,0,0})

  Body.set_syncread_enable(1); 
  started=false; 
  tFinish=0;

  Body.set_head_command({0,0});
  Body.set_head_hardness(.5);

  Body.set_waist_hardness(1);
  Body.set_waist_command(0);

  t0 = Body.get_time();
  mcm.set_walk_bipedal(1); --now on feet

  walk.active=false;
end

function stance.update()
  local t = Body.get_time();

  --For OP, wait a bit to read joint readings
  if not started then 
    if t-t0>tStartWait then
      started=true;

      local qLLeg = Body.get_lleg_position();
      local qRLeg = Body.get_rleg_position();
      local dpLLeg = Kinematics.torso_lleg(qLLeg);
      local dpRLeg = Kinematics.torso_rleg(qRLeg);

      pTorsoL=pLLeg+dpLLeg;
      pTorsoR=pRLeg+dpRLeg;
      pTorso=(pTorsoL+pTorsoR)*0.5;

--[[
      --For OP, lift hip a bit before starting to standup
      if(Config.platform.name == 'OP') then
        print("Initial bodyHeight:",pTorso[3]);
        if pTorso[3]<0.21 then
          Body.set_lleg_hardness(0.5);
          Body.set_rleg_hardness(0.5);
          Body.set_actuator_command(Config.stance.initangle)
          unix.usleep(1E6*0.4);
	  started=false;
	  return;
        end
      end
--]]

      Body.set_lleg_command(qLLeg);
      Body.set_rleg_command(qRLeg);
      Body.set_lleg_hardness(hardnessLeg);
      Body.set_rleg_hardness(hardnessLeg);
      t0 = Body.get_time();
      count=1;

      Body.set_syncread_enable(0); 
    else 
      Body.set_syncread_enable(1); 
      return; 
    end
  end

  local dt = t - t0;
  t0 = t;
  local tol = true;
  local tolLimit = 1e-6;
  dpDeltaMax = dt*dpLimit;

  dpTorso = pTorsoTarget - pTorso;
  for i = 1,6 do
    if (math.abs(dpTorso[i]) > tolLimit) then
      tol = false;
      if (dpTorso[i] > dpDeltaMax[i]) then
        dpTorso[i] = dpDeltaMax[i];
      elseif (dpTorso[i] < -dpDeltaMax[i]) then
        dpTorso[i] = -dpDeltaMax[i];
      end
    end
  end

  pTorso=pTorso+dpTorso;

  --vcm.set_camera_bodyHeight(pTorso[3]);
  --vcm.set_camera_bodyTilt(pTorso[5]);

	-- Change to use mcm for the body height and body tilt
  mcm.set_camera_bodyHeight(pTorso[3]);
  mcm.set_camera_bodyTilt(pTorso[5]);
	

--print("BodyHeight/Tilt:",pTorso[3],pTorso[5]*180/math.pi)

  q = Kinematics.inverse_legs(pLLeg, pRLeg, pTorso, 0);
  Body.set_lleg_command(q);

  if (tol) then
    if tFinish==0 then
      tFinish=t;
--[[
      Body.set_larm_command(qLArm);
      Body.set_rarm_command(qRArm);
      Body.set_larm_hardness(.1);
      Body.set_rarm_hardness(.1);
--]]
    else
      if t-tFinish>tEndWait then
	print("Stand done, time elapsed",t-tStart)
	--vcm.set_camera_bodyHeight(Config.walk.bodyHeight);
	--vcm.set_camera_bodyTilt(Config.walk.bodyTilt);
	-- Change to use mcm
	mcm.set_camera_bodyHeight(Config.walk.bodyHeight);
	mcm.set_camera_bodyTilt(Config.walk.bodyTilt);

	walk.stance_reset();
--	walk.start();
        return "done"
      end
    end
  end

end

function stance.exit()
end

return stance