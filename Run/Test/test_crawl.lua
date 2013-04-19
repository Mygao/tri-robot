-- CHARLI laser testing
print('Testing ARMS')

cwd = cwd or os.getenv('PWD')
package.path = cwd.."/?.lua;"..package.path;
local init = require('init')

local carray = require 'carray'

local Config = require('Config')
local Body = require('Body')
local Speak = require('Speak')
local Motion = require('Motion')
local vector = require('vector')

-- Laser getting
--local WebotsLaser = require 'WebotsLaser'
--print( "LIDAR Dim:", WebotsLaser.get_width(), WebotsLaser.get_height())
--nlidar_readings = WebotsLaser.get_width() * WebotsLaser.get_height();


local rcm = require 'rcm'
--
local mcm = require 'mcm'

-- Arms
local pickercm = require 'pickercm'
local Kinematics = require ('Kinematics')
local Transform = require 'Transform'


local Team = require 'Team' --To receive the GPS coordinates from objects
local wcm = require 'wcm'

local walk = require 'walk'

--Arm target transforms

--[[
trLArmOld = vector.new({0.16, 0.24, -0.09, 0,0,0});
trRArmOld = vector.new({0.16, -0.24, -0.09, 0,0,0});

trLArmOld = vector.new({0.16, 0.24, -0.07, 0, 0, -math.pi/4});
trRArmOld = vector.new({0.16, -0.24, -0.07, 0, 0, math.pi/4});
--]]

--New position considering the hand offset
trLArmOld = vector.new({0.28, 0.22, 0.05, 0, 0, -math.pi/2});
trRArmOld = vector.new({0.28, -0.22,0.05, 0, 0, math.pi/2});


trLArm=vector.new({0,0,0,0,0,0});
trRArm=vector.new({0,0,0,0,0,0});
trLArm0=vector.new({0,0,0,0,0,0});
trRArm0=vector.new({0,0,0,0,0,0});

trLArm[1],trLArm[2],trLArm[3],trLArm[4],trLArm[5],trLArm[6]=
trLArmOld[1],trLArmOld[2],trLArmOld[3],trLArmOld[4],trLArmOld[5],trLArmOld[6];

trLArm0[1],trLArm0[2],trLArm0[3],trLArm0[4],trLArm0[5],trLArm0[6]=
trLArmOld[1],trLArmOld[2],trLArmOld[3],trLArmOld[4],trLArmOld[5],trLArmOld[6];

trRArm[1],trRArm[2],trRArm[3],trRArm[4],trRArm[5],trRArm[6]=
trRArmOld[1],trRArmOld[2],trRArmOld[3],trRArmOld[4],trRArmOld[5],trRArmOld[6];

trRArm0[1],trRArm0[2],trRArm0[3],trRArm0[4],trRArm0[5],trRArm0[6]=
trRArmOld[1],trRArmOld[2],trRArmOld[3],trRArmOld[4],trRArmOld[5],trRArmOld[6];

Body.set_l_gripper_command({0,0});
Body.set_r_gripper_command({0,0});
Body.set_l_gripper_hardness({1,1});
Body.set_r_gripper_hardness({1,1});

-- Initialize Variables
webots = false;
teamID   = Config.game.teamNumber;
playerID = Config.game.playerID;
print '=====================';
print('Team '..teamID,'Player '..playerID)
print '=====================';
targetvel=vector.zeros(3);
if (string.find(Config.platform.name,'Webots')) then
  print('On webots!')
  webots = true;
end
Team.entry();


-- Key Input
if( webots ) then
  controller.wb_robot_keyboard_enable( 100 );
else
  local getch = require 'getch'
  getch.enableblock(1);
end



arm_initing = 1;
arm_init_stage = 0;
arm_init_t0 = 0;
arm_stage_duration={2.0,1.0,1.0,1.0};
is_moving = 0;

function init_arms()
  t = Body.get_time();
  if arm_initing>0 then     
    walk.upper_body_override_on();
    current_duration = arm_stage_duration[arm_init_stage+1];
    if arm_init_t0+current_duration< t then
      arm_init_stage = arm_init_stage+1;
      arm_init_t0 = t;
    end
    ph = (t-arm_init_t0) /current_duration;
    if arm_init_stage==0 then
      qLArm =  {math.pi/2, math.pi/2 * ph, 0, 0,0,0};
      qRArm =  {math.pi/2, -math.pi/2 * ph, 0, 0,0,0};      
    elseif arm_init_stage==1 then

      qLArm =  {(1-ph)*math.pi/2, math.pi/2 , ph*math.pi/2,  
			0,-math.pi/2*ph,0};
      qRArm =  {(1-ph)*math.pi/2, -math.pi/2,  -ph*math.pi/2, 
			0,math.pi/2*ph,0};      

    elseif arm_init_stage==2 then
      qLArm =  {0, math.pi/2-math.pi/9*ph , math.pi/2,
		 (math.pi/9-math.pi/2)*ph, -math.pi/2,-math.pi/2*ph};
      qRArm =  {0, -math.pi/2+ math.pi/9*ph , -math.pi/2,
		  (math.pi/9-math.pi/2)*ph, math.pi/2,math.pi/2*ph};      
    else
      qLArm =  {0, math.pi/2 -math.pi/9 ,math.pi/2,
		 (math.pi/9-math.pi/2), -math.pi/2,-math.pi/2};
      qRArm =  {0, -math.pi/2+ math.pi/9 ,-math.pi/2,
		  (math.pi/9-math.pi/2), math.pi/2, math.pi/2};      

      arm_initing = 0;
      trLArmOld = Kinematics.l_arm_torso(qLArm);
      trRArmOld = Kinematics.r_arm_torso(qRArm);

      --Lower the hand a bit to avoid singularity
      trLArmOld[3]=trLArmOld[3] - 0.02; 
      trRArmOld[3]=trRArmOld[3] - 0.02;

      trLArmOld[6]= - math.pi/2; 
      trRArmOld[6]= math.pi/2;

      trLArm[1],trLArm[2],trLArm[3],trLArm[4],trLArm[5],trLArm[6]=
	trLArmOld[1],trLArmOld[2],trLArmOld[3],trLArmOld[4],trLArmOld[5],trLArmOld[6];

      trLArm0[1],trLArm0[2],trLArm0[3],trLArm0[4],trLArm0[5],trLArm0[6]=
	trLArmOld[1],trLArmOld[2],trLArmOld[3],trLArmOld[4],trLArmOld[5],trLArmOld[6];

      trRArm[1],trRArm[2],trRArm[3],trRArm[4],trRArm[5],trRArm[6]=
	trRArmOld[1],trRArmOld[2],trRArmOld[3],trRArmOld[4],trRArmOld[5],trRArmOld[6];

      trRArm0[1],trRArm0[2],trRArm0[3],trRArm0[4],trRArm0[5],trRArm0[6]=
	trRArmOld[1],trRArmOld[2],trRArmOld[3],trRArmOld[4],trRArmOld[5],trRArmOld[6];

    end   
    walk.upper_body_override(qLArm, qRArm, walk.bodyRot0);

  end
end



function update_cognition()

  body_pos = Body.get_sensor_gps();
  body_rpy = Body.get_sensor_imuAngle();
  object_pos = wcm.get_robot_gps_ball();

  trBody=Transform.eye()
   * Transform.trans(body_pos[1],body_pos[2],body_pos[3])
   * Transform.rotZ(body_rpy[3])
   * Transform.rotY(body_rpy[2]);

  trEffector = Transform.eye()
   * Transform.trans(object_pos[1],object_pos[2],object_pos[3])
   * Transform.rotZ(trLArm[6]); --End effector transform (currently yaw only)

  trRelative = Transform.inv(trBody)*trEffector;
  pRelative = {trRelative[1][4],trRelative[2][4],trRelative[3][4]};


--[[
  print("body abs pos:",unpack( body_pos )); --Check Body GPS 
  --print("body pitch and yaw:",body_rpy[2]*180/math.pi, body_rpy[3]*180/math.pi);
  print("object abs pos:",unpack( object_pos )); 

  print("object rel pos:",unpack(pRelative))

  print("current LArm rel pos:",
	trLArm[1],trLArm[2],trLArm[3]);
--]]

end



function auto_move_arms()
  if is_moving==0 then return;
  end

  qInv, dist = check_ik(pRelative,1);

--[[
  if dist>0.001 then 
    print("Target unreachabe")
    is_moving=0; 
    return; 
  end
--]]

  --Check if the object is reachable
  armDir = vector.new({
	pRelative[1]-trLArm[1],
	pRelative[2]-trLArm[2],
	pRelative[3]-trLArm[3]});

  if is_moving==1 then
    armDir[3] = armDir[3]+ 0.11; --Approach : aim higher
  elseif is_moving==2 then
    armDir[3] = armDir[3]+ 0.02; --pickup bit higherr
  elseif is_moving==3 then --pick up
    armDir[1],armDir[2]=0,0;
    armDir[3] = 0.05-trLArm[3];
  elseif is_moving==4 then --put down
    armDir[1],armDir[2]=0,0;
    armDir[3] = -0.04-trLArm[3];
  elseif is_moving==5 then --put down
    armDir[1],armDir[2]=0,0;
    armDir[3] = 0.05-trLArm[3];
  end


--print("Target dir:",unpack(armDir))

  dRelative = math.sqrt(armDir[1]^2 + armDir[2]^2+armDir[3]^2);

  vel=0.001;
  if dRelative<0.02 then 
   vel=0.00025;
  end

  if dRelative<0.0025 then --Approached the target
    print("TARGET REACHED")
    if is_moving==1 then 
      --Open gripper
      Body.set_l_gripper_command({math.pi/6,-math.pi/6});
      is_moving = 2;
    elseif is_moving==2 then
      --Now grasp
      print("Arm height:",trLArm[3])
      Body.set_l_gripper_command({0,0});
      is_moving = 3;
    elseif is_moving==3 then
      is_moving = 4; 
    elseif is_moving==4 then
      Body.set_l_gripper_command({math.pi/6,-math.pi/6});
      is_moving = 5; 
    elseif is_moving==5 then
      is_moving = 0;
      return;
    end
  end

  trLArm[1] = trLArm[1] + vel*armDir[1]/dRelative;
  trLArm[2] = trLArm[2] + vel*armDir[2]/dRelative;
  trLArm[3] = trLArm[3] + vel*armDir[3]/dRelative;

  motion_arms_ik();  
end



function check_ik(tr, is_left)
  local qInv, dist, torso_arm_ik;
  if is_left>0 then
    qInv = Kinematics.inverse_l_arm(tr);
    torso_arm_ik = Kinematics.l_arm_torso(qInv);
  else
    qInv = Kinematics.inverse_r_arm(tr);
    torso_arm_ik = Kinematics.r_arm_torso(qInv);
  end

  dist = math.sqrt(
	(torso_arm_ik[1]-tr[1])^2+
	(torso_arm_ik[2]-tr[2])^2+
	(torso_arm_ik[3]-tr[3])^2);
  return qInv, dist;
end




function motion_arms_ik()
  if arm_initing>0 then return; end
  qLArmInv, dist1 = check_ik(trLArm, 1);
  qRArmInv, dist2 = check_ik(trRArm, 0);

--  print("Error:",dist1)


  if dist1<0.01 and dist2<0.01 then
--  if true then
      walk.upper_body_override_on();
      walk.upper_body_override(qLArmInv, qRArmInv, walk.bodyRot0);

      trLArmOld[1],trLArmOld[2],trLArmOld[3],trLArmOld[4],trLArmOld[5],trLArmOld[6]=
      trLArm[1],trLArm[2],trLArm[3],trLArm[4],trLArm[5],trLArm[6];

      trRArmOld[1],trRArmOld[2],trRArmOld[3],trRArmOld[4],trRArmOld[5],trRArmOld[6]=
      trRArm[1],trRArm[2],trRArm[3],trRArm[4],trRArm[5],trRArm[6];

      pTorso = 
        Transform.transform6D(
	  vector.new({walk.supportX,0,walk.bodyHeight,0,walk.bodyTilt,0})
	);
      
      LH_global = pTorso * Transform.transform6D(trLArm);
      RH_global = pTorso * Transform.transform6D(trRArm);
 
  else

    is_moving=0;
    print("STUCK!")


      trLArm[1],trLArm[2],trLArm[3],trLArm[4],trLArm[5],trLArm[6]=
      trLArmOld[1],trLArmOld[2],trLArmOld[3],trLArmOld[4],trLArmOld[5],trLArmOld[6];

      trRArm[1],trRArm[2],trRArm[3],trRArm[4],trRArm[5],trRArm[6]=
      trRArmOld[1],trRArmOld[2],trRArmOld[3],trRArmOld[4],trRArmOld[5],trRArmOld[6];
  end

end





-- Process Key Inputs
function process_keyinput()
  if( webots ) then
    str = controller.wb_robot_keyboard_get_key()
    byte = str;
    -- Webots only return captal letter number
    if byte>=65 and byte<=90 then
      byte = byte + 32;
    end
  else
    str  = getch.get();
    byte = string.byte(str,1);
  end
  --print('byte: ', byte)
  --print('string: ',string.char(byte))

  if byte==0 then return false; end
	
  local update_walk_vel = false;
  local update_arm = false;

  --Arm target position control
  if byte==string.byte("s") then  
    trLArm[1],trLArm[2],trLArm[3],trLArm[4],trLArm[5],trLArm[6]=
    trLArm0[1],trLArm0[2],trLArm0[3],trLArm0[4],trLArm0[5],trLArm0[6];

    trLArmOld[1],trLArmOld[2],trLArmOld[3],trLArmOld[4],trLArmOld[5],trLArmOld[6]=
    trLArm[1],trLArm[2],trLArm[3],trLArm[4],trLArm[5],trLArm[6];

    update_arm = true;

  elseif byte==string.byte("k") then  
    trRArm[1],trRArm[2],trRArm[3],trRArm[4],trRArm[5],trRArm[6]=
    trRArm0[1],trRArm0[2],trRArm0[3],trRArm0[4],trRArm0[5],trRArm0[6];

    trRArmOld[1],trRArmOld[2],trRArmOld[3],trRArmOld[4],trRArmOld[5],trRArmOld[6]=
    trRArm[1],trRArm[2],trRArm[3],trRArm[4],trRArm[5],trRArm[6];

    update_arm = true;

  elseif byte==string.byte("w") then  
    trLArm[1]=trLArm[1]+0.01;
    update_arm = true;
  elseif byte==string.byte("x") then  
    trLArm[1]=trLArm[1]-0.01;
    update_arm = true;
  elseif byte==string.byte("a") then  
    trLArm[2]=trLArm[2]+0.01;
    update_arm = true;
  elseif byte==string.byte("d") then  
    trLArm[2]=trLArm[2]-0.01;
    update_arm = true;
  elseif byte==string.byte("q") then  
    trLArm[3]=trLArm[3]+0.01;
    update_arm = true;
  elseif byte==string.byte("z") then  
    trLArm[3]=trLArm[3]-0.01;
    update_arm = true;



  elseif byte==string.byte("1") then  
    trLArm[6]=trLArm[6]+math.pi/18;
    update_arm = true;
  elseif byte==string.byte("2") then  
    trLArm[6]=trLArm[6]-math.pi/18;
    update_arm = true;
  elseif byte==string.byte("3") then  
    trLArm[4]=trLArm[4]+math.pi/18;
    update_arm = true;
  elseif byte==string.byte("4") then  
    trLArm[4]=trLArm[4]-math.pi/18;
    update_arm = true;
  elseif byte==string.byte("5") then  
    trLArm[5]=trLArm[5]+math.pi/18;
    update_arm = true;
  elseif byte==string.byte("6") then  
    trLArm[5]=trLArm[5]-math.pi/18;
    update_arm = true;

  elseif byte==string.byte("j") then  
    walk.bodyTilt = walk.bodyTilt + 1*math.pi/180;
    update_arm = true;
  elseif byte==string.byte("l") then  
    walk.bodyTilt = walk.bodyTilt - 1*math.pi/180;
    update_arm = true;

  elseif byte==string.byte("i") then  
    walk.bodyHeight = walk.bodyHeight + 0.01;
    update_arm = true;
  elseif byte==string.byte(",") then  
    walk.bodyHeight = walk.bodyHeight - 0.01;
    update_arm = true;

  elseif byte==string.byte("h") then  
    mcm.footX = mcm.footX -0.01;
    update_arm = true;
  elseif byte==string.byte(";") then  
    mcm.footX = mcm.footX +0.01;
    update_arm = true;

  elseif byte==string.byte("u") then  
    walk.footY = walk.footY + 0.01;
    update_arm = true;
  elseif byte==string.byte("m") then  
    walk.footY = walk.footY - 0.01;
    update_arm = true;


  elseif byte==string.byte("g") then  

    print("armX:",LH_global[1][4]);
    print("armY:",LH_global[2][4]);
    print("armZ:",LH_global[3][4]);


    print("Wrist RPY:",trLArm[4],trLArm[5],trLArm[6]);
    print("bodyTilt:",walk.bodyTilt*180/math.pi)
    print("bodyHeight:",walk.bodyHeight)
    print("footX:",mcm.footX)
    print("footY:",walk.footY)


  end

  trRArm[1],trRArm[2],trRArm[3],trRArm[4],trRArm[5],trRArm[6]=
  trLArm[1],-trLArm[2],trLArm[3],-trLArm[4],trLArm[5],-trLArm[6];


  if ( update_arm ) then  
   is_moving=0;
   motion_arms_ik();  
  end
  return true
 
end

function update()
  count = count + 1;

  -- Update State Machines 
  Motion.update();
  Body.update();
  update_cognition();
  auto_move_arms();
--[[	
	-- Update the laser scanner
	lidar_scan = WebotsLaser.get_scan()
	-- Set the Range Comm Manager values
	rcm.set_lidar_ranges( carray.pointer(lidar_scan) );
	rcm.set_lidar_timestamp( Body.get_time() )
	--print("Laser data:",unpack(rcm.get_lidar_ranges()))
	
	-- Show the odometry
	odom, odom0 = mcm.get_odometry();
	rcm.set_robot_odom( vector.new(odom) )
	
	-- Show IMU
  imuAngle = Body.get_sensor_imuAngle();
	rcm.set_robot_imu( vector.new(imuAngle) )
	gyr = Body.get_sensor_imuGyrRPY();
	rcm.set_robot_gyro( vector.new(gyr) );
--]]


--print("Roll", gyr[1], "Pitch",gyr[2]);

  -- Check if the last update completed without errors
  lcount = lcount + 1;
  if (count ~= lcount) then
    print('count: '..count)
    print('lcount: '..lcount)
    Speak.talk('missed cycle');
    lcount = count;
  end
  io.stdout:flush();  
end

-- Initialize
Motion.entry()
count = 0;
lcount = 0;
tUpdate = unix.time();
Motion.event("standup");

-- if using Webots simulator just run update
local tDelay = 0.005 * 1E6; -- Loop every 5ms

--calculate_arm_space();

arm_initing = 1;
arm_init_t0 = Body.get_time();


while (true) do
	-- Run Updates
  process_keyinput();

--  arm_demo();
  Team.update();
  init_arms();

  update();

  -- Debug Messages every 1 second
  t_diff = Body.get_time() - (t_last or 0);
  if(t_diff>1) then
		--print('qLArm',qLArm)
    t_last = Body.get_time();
  end

  if(darwin) then
    unix.usleep(tDelay);
  end
end
