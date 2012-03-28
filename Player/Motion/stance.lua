module(..., package.seeall);

require('Config')
require('Body')
require('Kinematics')
require('walk')
require('vector')
require('Transform')
require('vcm')

active = true;
t0 = 0;

footX = Config.walk.footX or 0;
footY = Config.walk.footY;
supportX = Config.walk.supportX;
bodyHeight = Config.walk.bodyHeight;
bodyTilt=Config.walk.bodyTilt;
qLArm = Config.walk.qLArm;
qRArm = Config.walk.qRArm;

-- Final stance foot position6D
pTorsoTarget = vector.new({0, 0, bodyHeight, 0,bodyTilt,0});
pLLeg = vector.new({-supportX + footX, footY, 0, 0,0,0});
pRLeg = vector.new({-supportX + footX, -footY, 0, 0,0,0});

-- Max change in position6D to reach stance:
dpLimit = Config.stance.dpLimitStance or vector.new({.04, .03, .07, .4, .4, .4});

tFinish=0;
tStartWait=0.2;
tEndWait=Config.stance.delay or 0;
tEndWait=tEndWait/100;
tStart=0;

function entry()
  print("Motion SM:".._NAME.." entry");
  Body.set_syncread_enable(1); 
  started=false; 
  tFinish=0;

  Body.set_head_command({0,0});
  Body.set_head_hardness(.5);

  Body.set_waist_hardness(1);
  Body.set_waist_command(0);

  t0 = Body.get_time();

  walk.active=false;
end

function update()
  local t = Body.get_time();
  local dt = t - t0;

  --For OP, wait a bit to read joint readings
  if not started then 
    if dt>tStartWait then
      started=true;

      local qLLeg = Body.get_lleg_position();
      local qRLeg = Body.get_rleg_position();
      local dpLLeg = Kinematics.torso_lleg(qLLeg);
      local dpRLeg = Kinematics.torso_rleg(qRLeg);

      pTorsoL=pLLeg+dpLLeg;
      pTorsoR=pRLeg+dpRLeg;
      pTorso=(pTorsoL+pTorsoR)*0.5;

      Body.set_lleg_command(qLLeg);
      Body.set_rleg_command(qRLeg);
      Body.set_lleg_hardness(1);
      Body.set_rleg_hardness(1);
      t0 = Body.get_time();
      count=1;
      tStart=t0;
      Body.set_syncread_enable(0); 
    else 
      Body.set_syncread_enable(1); 
      return; 
    end
  end


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

  vcm.set_camera_bodyHeight(pTorso[3]);
  vcm.set_camera_bodyTilt(pTorso[5]);
--print("BodyHeight/Tilt:",pTorso[3],pTorso[5]*180/math.pi)

  q = Kinematics.inverse_legs(pLLeg, pRLeg, pTorso, 0);
  Body.set_lleg_command(q);

  if (tol) then
    if tFinish==0 then
      tFinish=t;
      Body.set_larm_command(qLArm);
      Body.set_rarm_command(qRArm);
      Body.set_larm_hardness(.1);
      Body.set_rarm_hardness(.1);
    else
      if t-tFinish>tEndWait then
	print("Stand done, time elapsed",t-tStart)
        return "done"
      end
    end
  end

end

function exit()
  vcm.set_camera_bodyHeight(Config.walk.bodyHeight);
  vcm.set_camera_bodyTilt(Config.walk.bodyTilt);

  walk.stance_reset();
  walk.start();
end
