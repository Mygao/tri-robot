module(..., package.seeall);

require('Body')
require('wcm')
require('walk')
require('vector')

t0 = 0;
timeout = 15.0;

tDelay = 3.0;


-- turn velocity
vSpin = 0.3;
direction = 1;

function entry()
  print("Body FSM:".._NAME.." entry");
  t0 = Body.get_time();
end

function update()
  local t = Body.get_time();
  --Turn to face opponents' goal

--  attackBearing = wcm.get_attack_bearing();

  pose = wcm.get_pose();

  if (pose.y>0) then
    pose_target = -math.pi/2;
  else
    pose_target = math.pi/2;
  end

--  attackBearing = wcm.get_attack_bearing();
  attackBearing = util.mod_angle(pose_target - pose.a);

  vx,vy=0,0;
  va = .2*attackBearing;
  va=math.max(math.min(vSpin,va),-va);

  print("attackBearing:",attackBearing*180/math.pi)
  walk.set_velocity(vx,vy,va);

  if (t - t0 > timeout) then
    return "timeout";
  end
  if (math.abs(attackBearing)<5*math.pi/180) and
	t-t0> tDelay then
    return "done";
  end

end

function exit()
end
