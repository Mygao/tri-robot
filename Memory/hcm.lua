--------------------------------
-- Human Communication Module --
-- (c) 2013 Stephen McGill    --
--------------------------------
local vector = require'vector'
local memory = require'memory'
local DEG_TO_RAD = math.pi/180


local shared_data = {}
local shared_data_sz = {}

local zeros = require'vector'.zeros
local ones = require'vector'.ones

local shared_data = {}
local shared_data_sz = {}

shared_data.network = {
	open = zeros(1),
	topen = zeros(1)
}

shared_data.teleop = {
	-- Head angles
  head = zeros(2),
	-- Delta Transforms (xyz,rpy)
	dlarm = zeros(6),
	drarm = zeros(6),
  -- Assume 7DOF arm
  larm = zeros(7),
  rarm = zeros(7),
	-- Null space options (Shoulder angle, flip_roll)
  loptions = zeros(2),
  roptions = zeros(2),
	-- Use compensation when moving the arm?
	compensation = ones(1),
	-- Gripper has some modes it can use: 0 is torque, 1 is position
	lgrip_mode = zeros(1),
	rgrip_mode = zeros(1),
	-- We have three fingers
	lgrip_torque = zeros(3),
	rgrip_torque = zeros(3),
	lgrip_position = zeros(3),
	rgrip_position = zeros(3),
	-- Waypoint
	waypoint = zeros(3)
}

shared_data.demo = {
	waypoints = 'deans_reception',
}

shared_data.assist = {
  -- Cylinder: [x center, y center, z center, radius, height]
  cylinder = zeros(5),
}

shared_data.guidance={}
shared_data.guidance.color = 'CYAN'
shared_data.guidance.t = zeros(1)


shared_data.audio = {}
shared_data.audio.request = vector.zeros(1)

shared_data.drive={}
shared_data.drive.gas_pedal = vector.zeros(2)
shared_data.drive.gas_pedal_time = vector.zeros(1)
shared_data.drive.wheel_angle = vector.zeros(1)
shared_data.drive.pedal_ankle_pitch = vector.zeros(1)
shared_data.drive.pedal_knee_pitch = vector.zeros(1)


-- For robocup ball approach demo
local ball = {}
ball.approach = vector.zeros(0)
shared_data.ball = ball



shared_data.state={}
shared_data.state.proceed = vector.zeros(1)

--Now we use TWO sets of params (both are INCREMENTS)

--override variables are (x,y,z, r,p,y, TASK)
--unit of x,y,z is in meters
--unit of r,p,y is radians
--unit of TASK is 1
shared_data.state.override=vector.zeros(7)

shared_data.state.override_support=vector.zeros(7)




--Not used any more
shared_data.state.override_target=vector.zeros(7)

--This variable is used for target transform based tele-op and fine tuning
shared_data.hands={}

--This variable should contain CURRENT hand transforms
shared_data.hands.left_tr = vector.zeros(6)
shared_data.hands.right_tr = vector.zeros(6)

--This variable should contain TARGET hand transforms
shared_data.hands.left_tr_target = vector.zeros(6)
shared_data.hands.right_tr_target = vector.zeros(6)

--They store previous hand target transforms (in case movement is not possible)
shared_data.hands.left_tr_target_old = vector.zeros(6)
shared_data.hands.right_tr_target_old = vector.zeros(6)

-- for the left and right hands
shared_data.hands.read = vector.zeros(2)


-- Desired joint properties
shared_data.joints = {}
-- x,y,z,roll,pitch,yaw
shared_data.joints.plarm  = vector.zeros( 6 )
shared_data.joints.prarm  = vector.zeros( 6 )
-- TODO: 6->7 arm joint angles
shared_data.joints.qlarm  = vector.zeros( 7 )
shared_data.joints.qrarm  = vector.zeros( 7 )
-- 3 finger joint angles
shared_data.joints.qlgrip = vector.zeros( 3 )
shared_data.joints.qrgrip = vector.zeros( 3 )

shared_data.joints.qlshoulderyaw = vector.zeros( 1 )
shared_data.joints.qrshoulderyaw = vector.zeros( 1 )
-- Teleop mode
-- 1: joint, 2: IK
shared_data.joints.teleop = vector.ones( 1 )





-- Motion directives
shared_data.motion = {}
shared_data.motion.velocity = vector.zeros(3)
-- Emergency stop of motion
shared_data.motion.estop = vector.zeros(1)

--Head look angle
shared_data.motion.headangle = vector.zeros(2)

--Body height Target
shared_data.motion.bodyHeightTarget = vector.zeros(1)


-- Waypoints
-- {[x y a][x y a][x y a][x y a]...}
shared_data.motion.waypoints  = vector.zeros(3)
-- How many of the waypoints are actually used
shared_data.motion.nwaypoints = vector.ones(1)
-- Local or global waypoint frame of reference
-- 0: local
-- 1: global
shared_data.motion.waypoint_frame = vector.zeros(1)


-------------------------------
-- Task specific information --
-------------------------------



-------------------------------------------------------------------
-- OLD VALVE MODEL (which can have nonzero yaw and pitch)
shared_data.wheel = {}
-- This has all values: the right way, since one rpc call
-- {handlepos(3) handleyaw handlepitch handleradius}
shared_data.wheel.model = vector.new({0.36,0.00,0.02, 0, 0*DEG_TO_RAD,0.20})
-- Target angle of wheel
shared_data.wheel.turnangle = vector.zeros(1)
-------------------------------------------------------------------




--Small valve (which requires one handed operation)
shared_data.smallvalve = {}
-- This has all values: the right way, since one rpc call
-- {pos(3) roll_start roll_end}
shared_data.smallvalve.model = vector.new({0.50,0.25,0.02,
			 -20*DEG_TO_RAD, 90*DEG_TO_RAD})

--Large valve (which requires one handed operation)
shared_data.largevalve={}
--We assume the valve has zero pitch and yaw
-- {pos(3) radius roll_start roll_end}
shared_data.largevalve.model = vector.new({0.55,0.15,0.02,
	0.13, -60*DEG_TO_RAD, 60*DEG_TO_RAD})


shared_data.barvalve={}
--pos(3) radius turnangle wristangle
shared_data.barvalve.model = vector.new({0.55,0.20,0.02,
   0.05, 0, 70*DEG_TO_RAD })


--Debris model
shared_data.debris = {}
-- {pos(3) yaw}
shared_data.debris.model = vector.new({0.50,0.25,0.02, 0})



--Hose model
shared_data.hose = {}
shared_data.hose.model = vector.new({0.35,-0.25,0.0, 0})


shared_data.hoseattach = {}
shared_data.hoseattach.model = vector.new({0.35,0.30,-0.10, 0})






-- Door Opening
shared_data.door = {}
--door_hand, hinge_xyz(3), door_r, grip_offset_x
shared_data.door.model = vector.new({	
	0.45,0.85,-0.15, --Hinge XYZ pos from robot frame
	-0.60, --Door radius, negative - left hinge, positive - right hinge
	-0.05, --The X offset of the door handle (from door surface)
	0.05, --The Y offset of the knob axis (from gripping pos)
	0, --Knob roll target
	0, --Door yaw target
	})
shared_data.door.yaw = vector.zeros(1) --The current angle of the door
shared_data.door.yaw_target = vector.new({-20*math.pi/180}) --The target angle of the door 



-- Drill gripping
shared_data.tool={}

--The model of drill for pickup,  posxyz(3), yawangle
shared_data.tool.model = vector.new({0.45,0.15,-0.05,  0*DEG_TO_RAD})

-- The positions to start and end cutting
shared_data.tool.cutpos = vector.new({0.40,0.20,0, 0})
shared_data.tool.yaw = vector.zeros(1)



-- Fire suppression
shared_data.fire={}
shared_data.fire.model = vector.new({0.45,0,-0.05, 0,0})

-- Range of panning
shared_data.fire.panangle = vector.new({30*DEG_TO_RAD})
shared_data.fire.yaw = vector.zeros(1)



-- Dipoles for arbitrary grabbing
-- TODO: Use this in place of the wheel/door?
shared_data.left = {}
shared_data.left.cathode = vector.zeros(3)
shared_data.left.anode = vector.zeros(3)
-- strata (girth) / angle of attack / climb (a->c percentage)
shared_data.left.grip = vector.zeros(3)
----
shared_data.right = {}
shared_data.right.cathode = vector.zeros(3)
shared_data.right.anode = vector.zeros(3)
-- strata (girth) / angle of attack / climb (a->c percentage)
shared_data.right.grip = vector.zeros(3)


-- Monitor
shared_data.monitor = {}
shared_data.monitor.fps = vector.new({5}) 

-- Camera
shared_data.camera = {}
shared_data.camera.bias = vector.zeros(4)
shared_data.camera.log = vector.zeros(1)
--Neck yaw
--Camera roll, pitch, yaw

shared_data.legdebug={}
shared_data.legdebug.left=vector.zeros(4) --x,y,a,z
shared_data.legdebug.right=vector.zeros(4) --x,y,a,z
shared_data.legdebug.torso=vector.zeros(2) --x,y

shared_data.legdebug.enable_balance=vector.zeros(2) --imu based orientation stabilization
shared_data.legdebug.enable_gyro=vector.zeros(1) --imu based orientation stabilization


shared_data.legdebug.enable_imu=vector.zeros(1) --imu based orientation stabilization
shared_data.legdebug.enable_z_compliance=vector.zeros(1) 
shared_data.legdebug.enable_a_compliance=vector.zeros(1) 

shared_data.legdebug.torso_angle=vector.zeros(2) --pitch roll



shared_data.move={}
shared_data.move.target=vector.zeros(3) --relative pos, x y a



shared_data.step={}
shared_data.step.supportLeg=vector.zeros(1)
shared_data.step.relpos = vector.zeros(3)      --x y a
shared_data.step.zpr = vector.zeros(3)         --z p r
shared_data.step.nosolution = vector.zeros(1)         --z p r

shared_data.step.dir = vector.zeros(1)         --temporary
shared_data.step.auto = vector.zeros(1)         --temporary


--These variables are only used for offline testing of arm states
shared_data.state.success = vector.zeros(0)
shared_data.state.tstartrobot = vector.zeros(0)
shared_data.state.tstartactual = vector.zeros(0)


-- Call the initializer
memory.init_shm_segment(..., shared_data, shared_data_sz)
