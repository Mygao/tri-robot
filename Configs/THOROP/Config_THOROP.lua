-- Global Config
Config = {}


IS_STEVE = true
--IS_STEVE = false


-- General parameters
Config.PLATFORM_NAME = 'THOROP'
Config.nJoint = 37
Config.IS_COMPETING = false
Config.demo = true

-- Printing of debug messages
Config.debug = {
	webots_wizard = false,
  obstacle = false,
  follow = false,
  approach = false,
  planning = false,
  goalpost = false,
  world = false,
  feedback = false,
}

-- Tune for Webots
if IS_WEBOTS then
  Config.use_localhost = true
  -- Default Webots sensors
  Config.sensors = {
		ft = true,
		feedback = 'feedback_wizard',
    head_camera = 'camera_wizard',
    --chest_lidar = 'mesh_wizard',
    --head_lidar = 'slam_wizard',
    --kinect = 'kinect2_wizard',
	 	world = 'world_wizard',
  }
  -- Adjust the timesteps if desired
  -- Config.camera_timestep = 33
  -- Config.lidar_timestep = 200 --slower
  -- Config.kinect_timestep = 30
end

Config.enable_touchdown = false
Config.raise_body = true

----------------------------------
-- Application specific Configs --
----------------------------------
local exo
if IS_STEVE then
	Config.testfile = 'test_teleop'
	exo = {
		'Robot', 'Walk', 'Net',
		'FSM_Steve', 'Arm_Steve', 'Vision_Steve', 'World_Steve'
	}
	if IS_WEBOTS then
		--Config.sensors.chest_lidar = 'mesh_wizard'
		----[[
		Config.sensors.kinect = 'kinect2_wizard'
		Config.kinect_timestep = 50
		--]]
	end
else
	--Config.testfile = 'test_balance'
  Config.testfile = 'test_testbed'
	exo = {
		'Robot','Walk','Net','Manipulation',
		'FSM_DRCFinal','World_DRCFinal','Vision_DRCFinal'
	}
	if IS_WEBOTS then
--		Config.kinect_timestep = 50
	end
end

Config.use_jacobian_arm_planning = true
--Config.use_jacobian_arm_planning = false


-----------------------------------
-- Load Paths and Configurations --
-----------------------------------
-- Custom Config files
if Config.demo then table.insert(exo, 'Demo') end
for _,v in ipairs(exo) do
	local fname = {'Config_', Config.PLATFORM_NAME, '_', v}
	local filename = table.concat(fname)
  assert(pcall(require, filename))
end

-- Custom motion libraries
for i,sm in pairs(Config.fsm.libraries) do
	local pname = {HOME, '/Player/', i,'/' ,sm, '/?.lua;', package.path}
	package.path = table.concat(pname)
end

-- Finite state machine paths
for sm, en in pairs(Config.fsm.enabled) do
	if en then
		local selected = Config.fsm.select[sm]
		if selected then
			local pname = {HOME, '/Player/', sm, 'FSM/', selected, '/?.lua;', package.path}
			package.path = table.concat(pname)
		else --default fsm
			local pname = {HOME, '/Player/', sm, 'FSM/', '?.lua;', package.path}
			package.path = table.concat(pname)
		end
	end
end

return Config
