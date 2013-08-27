module(..., package.seeall);
--SJ: IK based lookGoal to take account of bodytilt


local Body = require('Body')
local Config = require('Config')
local vcm = require('vcm')
local ocm = require('ocm')

t0 = 0;
yawSweep = Config.fsm.headLookGoal.yawSweep;
yawMax = Config.head.yawMax;
dist = Config.fsm.headReady.dist;
tScan = Config.fsm.headLookGoal.tScan;
minDist = Config.fsm.headLookGoal.minDist;

function entry()
  print(_NAME.." entry");
  ocm.set_vision_update(0);

  t0 = Body.get_time();
  attackAngle = wcm.get_attack_angle();
  defendAngle = wcm.get_defend_angle();
  attackClosest = math.abs(attackAngle) < math.abs(defendAngle);
  if attackClosest then
    yaw0 = wcm.get_attack_angle();
  else
    yaw0 = wcm.get_defend_angle();
  end
end

function update()
  local t = Body.get_time();
  local tpassed=t-t0;
  local ph= tpassed/tScan;
  local yawbias = (ph-0.5)* yawSweep;

  height=vcm.get_camera_height();

  yaw1 = math.min(math.max(yaw0+yawbias, -yawMax), yawMax);
  local yaw, pitch =HeadTransform.ikineCam(
	dist*math.cos(yaw1),dist*math.sin(yaw1), height);
  Body.set_head_command({yaw, pitch});

  ball = wcm.get_ball();
  ballR = math.sqrt (ball.x^2 + ball.y^2);

  if vcm.get_freespace_allBlocked() == 1 then
--    print('blocked view')
--    return 'blocked'
  end

  if (t - t0 > tScan) then
--    tGoal = wcm.get_goal_t();
--    if (tGoal - t0 > 0) or ballR<minDist then
      return 'timeout';
--    else
--      return 'lost';
--    end
  end
end

function exit()
end
