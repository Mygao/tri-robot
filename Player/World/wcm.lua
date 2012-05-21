module(..., package.seeall);

require('shm');
require('util');
require('vector');
require('Config');

-- shared properties
shared = {};
shsize = {};

shared.robot = {};
shared.robot.pose = vector.zeros(3);
shared.robot.uTorso = vector.zeros(3);
shared.robot.battery_level = vector.zeros(1);
shared.robot.is_fall_down = vector.zeros(1);
shared.robot.time = vector.zeros(1);
shared.robot.penalty = vector.zeros(1);
shared.robot.gpspose = vector.zeros(3);
shared.robot.gps_attackbearing = vector.zeros(1);
shared.robot.gps_ball = vector.zeros(3);


shared.ball = {};
shared.ball.x = vector.zeros(1);
shared.ball.y = vector.zeros(1);
shared.ball.t = vector.zeros(1);
shared.ball.velx = vector.zeros(1);
shared.ball.vely = vector.zeros(1);
shared.ball.dodge = vector.zeros(1);

shared.goal = {};
shared.goal.t = vector.zeros(1);
shared.goal.attack = vector.zeros(3);
shared.goal.defend = vector.zeros(3);
shared.goal.attack_bearing = vector.zeros(1);
shared.goal.attack_angle = vector.zeros(1);
shared.goal.defend_angle = vector.zeros(1);
shared.goal.attack_post1 = vector.zeros(2);
shared.goal.attack_post2 = vector.zeros(2);

--Added for side approach/sidekick/kickoff handling
shared.kick = {};
shared.kick.dir=vector.zeros(1);
shared.kick.angle=vector.zeros(1);
shared.kick.type=vector.zeros(1);
shared.kick.kickOff = vector.zeros(1);
shared.kick.tKickOff = vector.zeros(1);

--Added for obstacle avoidance
shared.obstacle = {};
shared.obstacle.dist = vector.zeros(1);
shared.obstacle.pose = vector.zeros(3);

--Localization monitoring
shared.particle = {};
shared.particle.x=vector.zeros(Config.world.n);
shared.particle.y=vector.zeros(Config.world.n);
shared.particle.a=vector.zeros(Config.world.n);
shared.particle.w=vector.zeros(Config.world.n);


-----------------------------------------------
-- This shm is used for wireless team monitoring only
-- Indexed by player ID + teamOffset 
-----------------------------------------------
listen_monitor = Config.listen_monitor or 0;

if listen_monitor>0 then
  shared.teamdata={};
  shared.teamdata.teamColor=vector.zeros(10);
  shared.teamdata.robotId=vector.zeros(10);
  shared.teamdata.role=vector.zeros(10);
  shared.teamdata.time=vector.zeros(10);
  shared.teamdata.posex=vector.zeros(10);
  shared.teamdata.posey=vector.zeros(10);
  shared.teamdata.posea=vector.zeros(10);
  shared.teamdata.ballx=vector.zeros(10);
  shared.teamdata.bally=vector.zeros(10);
  shared.teamdata.ballt=vector.zeros(10);
  shared.teamdata.attackBearing=vector.zeros(10);
  shared.teamdata.fall=vector.zeros(10);
  shared.teamdata.penalty=vector.zeros(10);
  shared.teamdata.battery_level=vector.zeros(10);

  shared.teamdata.goal=vector.zeros(10);
  shared.teamdata.goalv11=vector.zeros(10);
  shared.teamdata.goalv12=vector.zeros(10);
  shared.teamdata.goalv21=vector.zeros(10);
  shared.teamdata.goalv22=vector.zeros(10);

  shared.teamdata.goalB11=vector.zeros(10);
  shared.teamdata.goalB12=vector.zeros(10);
  shared.teamdata.goalB13=vector.zeros(10);
  shared.teamdata.goalB14=vector.zeros(10);
  shared.teamdata.goalB15=vector.zeros(10);

  shared.teamdata.goalB21=vector.zeros(10);
  shared.teamdata.goalB22=vector.zeros(10);
  shared.teamdata.goalB23=vector.zeros(10);
  shared.teamdata.goalB24=vector.zeros(10);
  shared.teamdata.goalB25=vector.zeros(10);

  shared.teamdata.landmark=vector.zeros(10);
  shared.teamdata.landmarkv1=vector.zeros(10);
  shared.teamdata.landmarkv2=vector.zeros(10);

--Team LabelB monitoring

  processed_img_width = Config.camera.width;
  processed_img_height = Config.camera.height;
  processed_img_width = processed_img_width / 2;
  processed_img_height = processed_img_height / 2;
 
  labelB_size =  ((processed_img_width/Config.vision.scaleB)*
     (processed_img_height/Config.vision.scaleB));

  shared.labelB = {};
  shared.labelB.p1 = labelB_size;
  shared.labelB.p2 = labelB_size;
  shared.labelB.p3 = labelB_size;
  shared.labelB.p4 = labelB_size;
  shared.labelB.p5 = labelB_size;
  shared.labelB.p6 = labelB_size;
  shared.labelB.p7 = labelB_size;
  shared.labelB.p8 = labelB_size;
  shared.labelB.p9 = labelB_size;
  shared.labelB.p10 = labelB_size;
  shsize.labelB = 10*labelB_size + 2^16;

  shared.robotNames = {};

end

util.init_shm_segment(getfenv(), _NAME, shared, shsize);


-- helper functions for access the data in the same manner as World

function get_ball()
  return {x=get_ball_x(), y=get_ball_y(), vx=get_ball_velx(), vy=get_ball_vely(), t=get_ball_t()};
end

function get_pose()
  pose = get_robot_pose();
  return {x=pose[1], y=pose[2], a=pose[3]};
end

function get_tGoal()
  return get_goal_t();
end

function get_attack_bearing()
  return get_goal_attack_bearing();
end

function get_attack_angle()
  return get_goal_attack_angle();
end

function get_defend_angle()
  return get_goal_defend_angle();
end
