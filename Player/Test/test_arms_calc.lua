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


--Arm target transforms

--[[
trLArmOld = vector.new({0.16, 0.24, -0.09, 0,0,0});
trRArmOld = vector.new({0.16, -0.24, -0.09, 0,0,0});

trLArmOld = vector.new({0.16, 0.24, -0.07, 0, 0, -math.pi/4});
trRArmOld = vector.new({0.16, -0.24, -0.07, 0, 0, math.pi/4});
--]]

--New position considering the hand offset
trLArmOld = vector.new({0.28, 0.22, 0.05, 0, 0, -math.pi/4});
trRArmOld = vector.new({0.28, -0.22,0.05, 0, 0, math.pi/4});


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

arm_count=1;

function arm_demo()

  arm_count=(arm_count+1)%400;

  if arm_count<100 then
    trLArm[1]=trLArm[1]+0.001;
    trRArm[3]=trRArm[3]+0.001;
  elseif arm_count<200 then
    trLArm[2]=trLArm[2]+0.001;
    trRArm[1]=trRArm[1]+0.001;
  elseif arm_count<300 then
    trLArm[1]=trLArm[1]-0.001;
    trRArm[3]=trRArm[3]-0.001;
  else 
    trLArm[2]=trLArm[2]-0.001;
    trRArm[1]=trRArm[1]-0.001;
  end

--[[
  ph = arm_count/400;
  trL=Transform.eye()
--   * Transform.trans(0.16,0,-0.09)
   * Transform.trans(0.18,0,-0.09)
   * Transform.rotX((ph-0.5) * math.pi/2)
   * Transform.trans(0,0.24,0);
  trLArm[1]=trL[1][4];
  trLArm[2]=trL[2][4];
  trLArm[3]=trL[3][4];
  trLArm[4]=(ph-0.5) * math.pi/2;
  print(unpack(trLArm));
--]]

  motion_arms_ik();
end


function calculate_arm_space()
    local tr_arm={0,0,0,0,0,0};

    local y_offset = 0.219;
    local z_offset = 0.144;


    outfile = assert(io.open("armspace.txt","wb"))

    for l= -9,9 do -- -90 degree to 90 degree
      for i=1,50 do
        for j=-49,50 do
          for k=1,50 do

            tr_arm[1]=i/100;    
            tr_arm[2]=y_offset + j/100;    
            tr_arm[3]=z_offset - k/100;    
	    tr_arm[6]= l * math.pi/18; 
            local qLArmInv = Kinematics.inverse_l_arm(tr_arm);
            local torso_larm_ik = Kinematics.l_arm_torso(qLArmInv);
            --Check if the positional error is small enough
            local dist1 = 
              (torso_larm_ik[1]-tr_arm[1])^2+
     	      (torso_larm_ik[2]-tr_arm[2])^2+
	      (torso_larm_ik[3]-tr_arm[3])^2;
            if dist1<0.0001 then
	      outfile:write(string.format("%d %d %d %d\n",l,i,j,k))
            end
          end
        end
      end
    end
    outfile:flush();
end




function motion_arms_ik()
    local qLArmInv = Kinematics.inverse_l_arm(trLArm);
    local qRArmInv = Kinematics.inverse_r_arm(trRArm);
    local torso_larm_ik = Kinematics.l_arm_torso(qLArmInv);
    local torso_rarm_ik = Kinematics.r_arm_torso(qRArmInv);

    --Check if the error is small enough
    local dist1 = 
	(torso_larm_ik[1]-trLArm[1])^2+
	(torso_larm_ik[2]-trLArm[2])^2+
	(torso_larm_ik[3]-trLArm[3])^2;

    local dist2 = 
	(torso_rarm_ik[1]-trRArm[1])^2+
	(torso_rarm_ik[2]-trRArm[2])^2+
	(torso_rarm_ik[3]-trRArm[3])^2;

    if dist1<0.001 and dist2<0.001 then
      walk.upper_body_override_on();
      walk.upper_body_override(qLArmInv, qRArmInv, walk.bodyRot0);

      trLArmOld[1],trLArmOld[2],trLArmOld[3],trLArmOld[4],trLArmOld[5],trLArmOld[6]=
      trLArm[1],trLArm[2],trLArm[3],trLArm[4],trLArm[5],trLArm[6];

      trRArmOld[1],trRArmOld[2],trRArmOld[3],trRArmOld[4],trRArmOld[5],trRArmOld[6]=
      trRArm[1],trRArm[2],trRArm[3],trRArm[4],trRArm[5],trRArm[6];
    else
      trLArm[1],trLArm[2],trLArm[3],trLArm[4],trLArm[5],trLArm[6]=
      trLArmOld[1],trLArmOld[2],trLArmOld[3],trLArmOld[4],trLArmOld[5],trLArmOld[6];

      trRArm[1],trRArm[2],trRArm[3],trRArm[4],trRArm[5],trRArm[6]=
      trRArmOld[1],trRArmOld[2],trRArmOld[3],trRArmOld[4],trRArmOld[5],trRArmOld[6];
    end


--    if true then

--[[

    if dist1<0.001 and dist2<0.001 then
      walk.upper_body_override_on();
      walk.upper_body_override(qLArmInv, qRArmInv, walk.bodyRot0);
    end

    trLArmOld[1],trLArmOld[2],trLArmOld[3],trLArmOld[4],trLArmOld[5],trLArmOld[6]=
    trLArm[1],trLArm[2],trLArm[3],trLArm[4],trLArm[5],trLArm[6];

    trRArmOld[1],trRArmOld[2],trRArmOld[3],trRArmOld[4],trRArmOld[5],trRArmOld[6]=
    trRArm[1],trRArm[2],trRArm[3],trRArm[4],trRArm[5],trRArm[6];

--]]


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

  if byte==0 then
		return false
	end
	
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
  elseif byte==string.byte("c") then  
    trLArm[6]=trLArm[6]+0.1;
    update_arm = true;
  elseif byte==string.byte("v") then  
    trLArm[6]=trLArm[6]-0.1;
    update_arm = true;

  elseif byte==string.byte("e") then  --Open gripper
    Body.set_l_gripper_command({math.pi/6,-math.pi/6});

  elseif byte==string.byte("r") then  --Close gripper
    Body.set_l_gripper_command({0,0});







  elseif byte==string.byte("i") then  
    trRArm[1]=trRArm[1]+0.01;
    update_arm = true;
  elseif byte==string.byte(",") then  
    trRArm[1]=trRArm[1]-0.01;
    update_arm = true;
  elseif byte==string.byte("j") then  
    trRArm[2]=trRArm[2]+0.01;
    update_arm = true;
  elseif byte==string.byte("l") then  
    trRArm[2]=trRArm[2]-0.01;
    update_arm = true;
  elseif byte==string.byte("u") then  
    trRArm[3]=trRArm[3]+0.01;
    update_arm = true;
  elseif byte==string.byte("m") then  
    trRArm[3]=trRArm[3]-0.01;
    update_arm = true;
  elseif byte==string.byte("b") then  
    trRArm[6]=trRArm[6]+0.1;
    update_arm = true;
  elseif byte==string.byte("n") then  
    trRArm[6]=trRArm[6]-0.1;
    update_arm = true;

  elseif byte==string.byte("t") then  --Open gripper
    Body.set_r_gripper_command({math.pi/6,-math.pi/6});

  elseif byte==string.byte("y") then  --Close gripper
    Body.set_r_gripper_command({0,0});


  end




  if ( update_arm ) then
    motion_arms_ik();
   
    body_pos = Body.get_sensor_gps();
    body_rpy = Body.get_sensor_imuAngle();
    object_pos = wcm.get_robot_gps_ball();
    

print("body abs pos:",unpack( body_pos )); --Check Body GPS 
--print("body pitch and yaw:",body_rpy[2]*180/math.pi, body_rpy[3]*180/math.pi);
print("object abs pos:",unpack( object_pos )); 


  trBody=Transform.eye()
   * Transform.trans(body_pos[1],body_pos[2],body_pos[3])
   * Transform.rotZ(body_rpy[3])
   * Transform.rotY(body_rpy[2]);

  trEffector = Transform.eye()
   * Transform.trans(object_pos[1],object_pos[2],object_pos[3])
   * Transform.rotZ(-math.pi/4); --For L arm (45 deg yaw)

  trRelative = Transform.inv(trBody)*trEffector;

  pRelative = {trRelative[1][4],trRelative[2][4],trRelative[3][4]};

print("object rel pos:",unpack(pRelative))


print("current LArm rel pos:",
	trLArm[1],trLArm[2],trLArm[3]);



  end

  return true
  
end

function update()
  count = count + 1;

  -- Update State Machines 
  Motion.update();
  Body.update();

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

calculate_arm_space();

while (true) do
	-- Run Updates
  process_keyinput();

--  arm_demo();
  Team.update();

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
