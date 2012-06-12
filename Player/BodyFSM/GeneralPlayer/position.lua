module(..., package.seeall);

require('Body')
require('walk')
require('vector')
require('Config')
require('wcm')

rTurn= Config.fsm.bodyPosition.rTurn;
rTurn2= Config.fsm.bodyPosition.rTurn2;
rDist1= Config.fsm.bodyPosition.rDist1;
rDist2= Config.fsm.bodyPosition.rDist2;
rOrbit= Config.fsm.bodyPosition.rOrbit;




maxStep1 = Config.fsm.bodyPosition.maxStep1;

maxStep2 = Config.fsm.bodyPosition.maxStep2;
rVel2 = Config.fsm.bodyPosition.rVel2 or 0.5;
aVel2 = Config.fsm.bodyPosition.aVel2 or 45*math.pi/180;
maxA2 = Config.fsm.bodyPosition.maxA2 or 0.2;
maxY2 = Config.fsm.bodyPosition.maxY2 or 0.02;

maxStep3 = Config.fsm.bodyPosition.maxStep3;
rVel3 = Config.fsm.bodyPosition.rVel3 or 0.8;
aVel3 = Config.fsm.bodyPosition.aVel3 or 30*math.pi/180;
maxA3 = Config.fsm.bodyPosition.maxA3 or 0.1;
maxY3 = Config.fsm.bodyPosition.maxY3 or 0;













function posCalc()
  ball=wcm.get_ball();
  pose=wcm.get_pose();
  ballR = math.sqrt(ball.x^2 + ball.y^2);
  ballxy=vector.new( {ball.x,ball.y,0} );
  tBall = Body.get_time() - ball.t;
  posexya=vector.new( {pose.x, pose.y, pose.a} );
  ballGlobal=util.pose_global(ballxy,posexya);
  goalGlobal=wcm.get_goal_attack();
  aBallLocal=math.atan2(ball.y,ball.x); 
  aBall=math.atan2(ballGlobal[2]-pose.y, ballGlobal[1]-pose.x);
  aGoal=math.atan2(goalGlobal[2]-ballGlobal[2],goalGlobal[1]-ballGlobal[1]);

  --Apply angle
  kickAngle=  wcm.get_kick_angle();
  aGoal = util.mod_angle(aGoal - kickAngle);

  --In what angle should we approach the ball?
  angle1=util.mod_angle(aGoal-aBall);
end




function getAttackerHomePose()
  posCalc();
  --Direct approach 
  if Config.fsm.playMode~=3 then
    local homepose={ballGlobal[1],ballGlobal[2], aBall};
    return homepose;
  end

  --Curved approach
  if math.abs(angle1)<math.pi/2 then
--    rDist=math.min(rDist1,math.max(rDist2,ballR-rTurn2));

    --New approach
    rDist = math.min(
        rDist2 + (rDist1-rDist2) * math.abs(angle1) / (math.pi/2),
        ballR
        );    

    local homepose={
        ballGlobal[1]-math.cos(aGoal)*rDist,
        ballGlobal[2]-math.sin(aGoal)*rDist,
        aGoal};
    return homepose;
  elseif angle1>0 then
    local homepose={
        ballGlobal[1]+math.cos(-aBall+math.pi/2)*rOrbit,
        ballGlobal[2]-math.sin(-aBall+math.pi/2)*rOrbit,
        aBall};
    return homepose;

  else
    local homepose={
        ballGlobal[1]+math.cos(-aBall-math.pi/2)*rOrbit,
        ballGlobal[2]-math.sin(-aBall-math.pi/2)*rOrbit,
        aBall};
    return homepose;
  end
end



------------------------------------------------------------------
-- Defender
------------------------------------------------------------------



--Simple defender
function getDefenderHomePose0()
  posCalc();

  homePosition = .6 * ballGlobal;
  homePosition[1] = homePosition[1] - 0.50*util.sign(homePosition[1]);
  homePosition[2] = homePosition[2] - 0.80*util.sign(homePosition[2]);
  relBallX = ballGlobal[1]-homePosition[1];
  relBallY = ballGlobal[2]-homePosition[2];

  -- face ball 
  homePosition[3] = util.mod_angle(math.atan2(relBallY, relBallX));
  return homePosition;
end


--Blocking defender 
function getDefenderHomePose()
  posCalc();

  goal_defend=wcm.get_goal_defend();
  relBallX = ballGlobal[1]-goal_defend[1];
  relBallY = ballGlobal[2]-goal_defend[2];
  RrelBall = math.sqrt(relBallX^2+relBallY^2)+0.001;
  distGoal = 1.8;
  homePosition = {};
  homePosition[1]= goal_defend[1]+distGoal * relBallX / RrelBall;
  homePosition[2]= goal_defend[2]+distGoal * relBallY / RrelBall;
  homePosition[3] = math.atan2(relBallY, relBallX);
  return homePosition;
end

--Front supporter

function getSupporterHomePose()
  posCalc();
  goal_defend=wcm.get_goal_defend();
  attackGoalPosition = vector.new(wcm.get_goal_attack());

  relBallX = ballGlobal[1]-goal_defend[1];
  relBallY = ballGlobal[2]-goal_defend[2];
  RrelBall = math.sqrt(relBallX^2+relBallY^2)+0.001;

-- move near attacking goal
--TODO: prevent oscillation

  homePosition = attackGoalPosition;
  homePosition[1] = homePosition[1] - util.sign(homePosition[1]) * 1.5;
  homePosition[2] = -1*util.sign(ballGlobal[2]) * 1.25;

  relBallX = ballGlobal[1]-homePosition[1];
  relBallY = ballGlobal[2]-homePosition[2];

  -- face ball 
  homePosition[3] = math.atan2(relBallY, relBallX);
  return homePosition;
end

function getGoalieHomePose()
  --Changing goalie position for moving goalie
  posCalc();

  homePosition = 0.98*vector.new(wcm.get_goal_defend());

--[[
  vBallHome = math.exp(-math.max(tBall-3.0, 0)/4.0)*
        (ballGlobal - homePosition);
  rBallHome = math.sqrt(vBallHome[1]^2 + vBallHome[2]^2);

  maxPosition = 0.55;

  if (rBallHome > maxPosition) then
    scale = maxPosition/rBallHome;
    vBallHome = scale*vBallHome;
  end
  homePosition = homePosition + vBallHome;
--]]

  goal_defend=wcm.get_goal_defend();
  relBallX = ballGlobal[1]-goal_defend[1];
  relBallY = ballGlobal[2]-goal_defend[2];
  RrelBall = math.sqrt(relBallX^2 + relBallY^2);

  if tBall>8 or RrelBall > 4.0 then  
    --Go back and face center
    dist = 0.40;
    relBallX = -goal_defend[1];
    relBallY = -goal_defend[2];
    homePosition[3] = util.mod_angle(math.atan2(relBallY, relBallX));
  else --Move out 
    dist = 0.60; 
    homePosition[3] = util.mod_angle(math.atan2(relBallY, relBallX));
  end

  homePosition[1] = homePosition[1] + dist*relBallX /RrelBall;
  homePosition[2] = homePosition[2] + dist*relBallY /RrelBall;

  return homePosition;
end

function getGoalieHomePose2()
  posCalc();

  --Fixed goalie position for diving goalie
  homePosition = 0.94*vector.new(wcm.get_goal_defend());

  --face center of the field
  goal_defend=wcm.get_goal_defend();
  relBallX = -goal_defend[1];
  relBallY = -goal_defend[2];
  homePosition[3] = util.mod_angle(math.atan2(relBallY, relBallX));

  return homePosition;
end

---------------------------------------------------------
-- Velocity Generation
--------------------------------------------------------








function setAttackerVelocity(homePose)
  uPose=vector.new({pose.x,pose.y,pose.a})
  homeRelative = util.pose_relative(homePose, uPose);  
  rHomeRelative = math.sqrt(homeRelative[1]^2 + homeRelative[2]^2);
  aHomeRelative = math.atan2(homeRelative[2],homeRelative[1]);
  homeRot=math.abs(aHomeRelative);

  --Distance-specific velocity generation
  veltype=0;

  if rHomeRelative>rVel3 and homeRot<aVel3 then
    --Fast front dash
    maxStep = maxStep3;
    maxA = maxA3;
    maxY = maxY3;
    if max_speed==0 then
      max_speed=1;
      print("MAXIMUM SPEED")
--      Speak.play('./mp3/max_speed.mp3',50)
    end
    veltype=1;
  elseif rHomeRelative>rVel2 and homeRot<aVel2 then
    --Medium speed 
    maxStep = maxStep2;
    maxA = maxA2;
    maxY = maxY2;
    veltype=2;
 
  else --Normal speed
    maxStep = maxStep1;
    maxA = 999;
    maxY = 999;
    veltype=3;
  end

  --Slow down if battery is low
  batt_level=Body.get_battery_level();
  if batt_level*10<Config.bat_med then
    maxStep = maxStep1;
  end

  vx,vy,va=0,0,0;
  aTurn=math.exp(-0.5*(rHomeRelative/rTurn)^2);
  --Don't turn to ball if close
  if rHomeRelative < 0.3 then 
    aTurn = math.max(0.5,aTurn);
  end

  vx = maxStep*homeRelative[1]/rHomeRelative;

  --Sidestep more if ball is close and sideby
  if rHomeRelative<rVel2 and  
           math.abs(aHomeRelative)>45*180/math.pi then
     vy = maxStep*homeRelative[2]/rHomeRelative;
     aTurn = 1; --Turn toward the goal
  else
     vy = 0.3*maxStep*homeRelative[2]/rHomeRelative;
  end
  vy = math.max(-maxY,math.min(maxY,vy));
  scale = math.min(maxStep/math.sqrt(vx^2+vy^2), 1);
  vx,vy = scale*vx,scale*vy;

  if math.abs(aHomeRelative)<70*180/math.pi then
    --Don't allow the robot to backstep if ball is in front
--    vx=math.max(0,vx) 
  end

  va = 0.5*(aTurn*homeRelative[3] --Turn toward the goal
     + (1-aTurn)*aHomeRelative); --Turn toward the target
  va = math.max(-maxA,math.min(maxA,va)); --Limit rotation
  return vx,vy,va;
end



function setGoalieVelocity0()
  maxStep = 0.06;
  homeRelative = util.pose_relative(homePosition, {pose.x, pose.y, pose.a});
  rHomeRelative = math.sqrt(homeRelative[1]^2 + homeRelative[2]^2);
  aHomeRelative = math.atan2(homeRelative[2], homeRelative[1]);

--Basic velocity generation
  vx = maxStep*homeRelative[1]/rHomeRelative;
  vy = maxStep*homeRelative[2]/rHomeRelative;
  rTurn = 0.3;
  aTurn=math.exp(-0.5*(rHomeRelative/rTurn)^2);
  vaTurn = .2 * aHomeRelative;
  vaGoal = .35*homeRelative[3];
  va = aTurn * vaGoal + (1-aTurn)*vaTurn;
  return vx,vy,va;
end



function setDefenderVelocity(homePose)
  homeRelative = util.pose_relative(homePose, {pose.x, pose.y, pose.a});
  rHomeRelative = math.sqrt(homeRelative[1]^2 + homeRelative[2]^2);
  aHomeRelative = math.atan2(homeRelative[2],homeRelative[1]);
  homeRot=math.abs(aHomeRelative);

  if rHomeRelative>rVel3 and homeRot<aVel3 then
    --Fast front dash
    maxStep = maxStep3;
    maxA = maxA3;
    maxY = maxY3;
    if max_speed==0 then
      max_speed=1;
      print("MAXIMUM SPEED")
--      Speak.play('./mp3/max_speed.mp3',50)
    end
    veltype=1;
  elseif rHomeRelative>rVel2 and homeRot<aVel2 then
    --Medium speed 
    maxStep = maxStep2;
    maxA = maxA2;
    maxY = maxY2;
    veltype=2;
  elseif rHomeRelative>0.40 then --Normal speed
    maxStep = maxStep1;
    maxA = 999;
    maxY = 999;
    veltype=3;
  else --Reached target area, don't move too much
    maxStep = 0.02;
    maxA = 999;
    maxY = 999;
  end

  --Slow down if battery is low
  batt_level=Body.get_battery_level();
  if batt_level*10<Config.bat_med then
    maxStep = maxStep1;
  end

  vx,vy,va=0,0,0;
  aTurn=math.exp(-0.5*(rHomeRelative/rTurn)^2);
  if rHomeRelative<0.40 then 
    aTurn = 1; 
  end
 vx = maxStep*homeRelative[1]/rHomeRelative;
  vy = math.max(-maxY,math.min(maxY,vy));
  scale = math.min(maxStep/math.sqrt(vx^2+vy^2), 1);
  vx,vy = scale*vx,scale*vy;

  va = 0.5*(aTurn*homeRelative[3] --Turn toward the target direction
     + (1-aTurn)*aHomeRelative); --Turn toward the target
  va = math.max(-maxA,math.min(maxA,va)); --Limit rotation
  return vx,vy,va;
end

