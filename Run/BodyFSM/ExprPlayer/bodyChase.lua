module(..., package.seeall);

local Body = require('Body')
local wcm = require('wcm')
local walk = require('walk')
local vector = require('vector')
local behavior = require('behavior')

t0 = 0;
timeout = Config.fsm.bodyChase.timeout;
maxStep = Config.fsm.bodyChase.maxStep;
rClose = Config.fsm.bodyChase.rClose;
tLost = Config.fsm.bodyChase.tLost;

rFar = Config.fsm.bodyChase.rFar;

function entry()
  print("Body FSM:".._NAME.." entry");

  t0 = Body.get_time();
end

function update()
  local t = Body.get_time();

  -- get ball position
  ball = wcm.get_ball();
  ballR = math.sqrt(ball.x^2 + ball.y^2);

  -- calculate walk velocity based on ball position
  vStep = vector.new({0,0,0});
  vStep[1] = .6*ball.x;
  vStep[2] = .75*ball.y;
  scale = math.min(maxStep/math.sqrt(vStep[1]^2+vStep[2]^2), 1);
  vStep = scale*vStep;

  ballA = math.atan2(ball.y, ball.x+0.10);
  vStep[3] = 0.75*ballA;
  walk.set_velocity(vStep[1],vStep[2],vStep[3]);
  
  if ballR>rFar and gcm.get_team_role()==0 then
    --ballFar check - Only for goalie
    return "ballFar";
  end

  if (t - ball.t > tLost) then
    return "ballLost";
  end
  if (t - t0 > timeout) then
    return "timeout";
  end
  if (ballR < rClose) then
    behavior.update();
    return "ballClose";
  end
  if (t - t0 > 1.0 and Body.get_sensor_button()[1] > 0) then
    return "button";
  end
end

function exit()
end
