module(..., package.seeall);

require('Body')
require('walk')
require('vector')
require('Config')
require('wcm')

t0 = 0;
timeout = Config.fsm.bodyOrbit.timeout;
maxStep = Config.fsm.bodyOrbit.maxStep;
rOrbit = Config.fsm.bodyOrbit.rOrbit;
rFar = Config.fsm.bodyOrbit.rFar;
thAlign = Config.fsm.bodyOrbit.thAlign;
tLost = Config.fsm.bodyOrbit.tLost;
direction = 1;
dribbleThres = 0.75;

function entry()
  print(_NAME.." entry");

  t0 = Body.get_time();
  attackBearing = wcm.get_attack_bearing();
  if (attackBearing > 0) then
    direction = 1;
  else
    direction = -1;
  end
end

function update()
  local t = Body.get_time();

  attackBearing, daPost = wcm.get_attack_bearing();
  --print('attackBearing: '..attackBearing);
  --print('daPost: '..daPost);
  --print('attackBearing', attackBearing)
  ball = wcm.get_ball();

  ballR = math.sqrt(ball.x^2 + ball.y^2);
  ballA = math.atan2(ball.y, ball.x+0.10);
  dr = ballR - rOrbit;
  aStep = ballA - direction*(90*math.pi/180 - dr/0.40);
  vx = maxStep*math.cos(aStep);
  
  --Does setting vx to 0 improve performance of orbit?--
  vx = 0;
  
  vy = maxStep*math.sin(aStep);
  va = 0.75*ballA;

  walk.set_velocity(vx, vy, va);

  if (t - ball.t > tLost) then
    return 'ballLost';
  end
  if (t - t0 > timeout) then
    return 'timeout';
  end
  if (ballR > rFar) then
    return 'ballFar';
  end

--  print(attackBearing*180/math.pi)

  if (math.abs(attackBearing) < thAlign) then
    return 'done';
  end

  --Overshoot escape
  if (attackBearing > 0) and direction==-1 then
    return 'done'
  elseif (attackBearing < 0) and direction==1 then
    return 'done'
  end
  
  -- check overshoot
  --[[
  if (attackBearing < direction * (2*thAlign)) then
    print('Orbit: overshoot thres meet. attackBearing: '..attackBearing..' direction: '..direction);
    return 'done'
  end
  --]]

end

function exit()
end

