assert(Config, 'Need a pre-existing Config table!')

local fsm = {}

Config.torque_legs = true

-- Update rate in Hz
fsm.update_rate = 100

-- Which FSMs should be enabled?
fsm.enabled = {
	Arm = true,
	Body = true,
	Head = true,
	Motion = true,
	Gripper = true,
	Lidar = true,
}

--SJ: now we can have multiple FSM options
fsm.select = {
	Arm = 'Steve',
	Body = 'Steve',
	Gripper = 'Steve',
	Head = 'Steve',
	Motion = 'Steve'
}

-- Custom libraries
fsm.libraries = {
	MotionLib = 'DRCFinal',
	--MotionLib = 'Steve',
	ArmLib = 'Steve',
	World = 'Steve'
}

fsm.Body = {
	{'bodyIdle', 'init', 'bodyInit'},
	--
	{'bodyInit', 'done', 'bodyStop'},
	--
	{'bodyStop', 'init', 'bodyInit'},
	{'bodyStop', 'approach', 'bodyApproach'},
	{'bodyStop', 'stepover1', 'bodyStep'},
	--
	{'bodyApproach', 'done', 'bodyStop'},
	{'bodyApproach', 'stop', 'bodyStop'},
	{'bodyApproach', 'init', 'bodyStop'},
	--
	{'bodyStep', 'nextstep', 'bodyStep'},
  {'bodyStep', 'done', 'bodyStop'},
}

fsm.Head = {
	{'headIdle', 'init', 'headCenter'},
	--
	{'headCenter', 'teleop', 'headTeleop'},
	{'headCenter', 'trackhand', 'headTrackHand'},
	{'headCenter', 'mesh', 'headMesh'},
	--
	{'headTeleop', 'init', 'headCenter'},
	{'headTeleop', 'trackhand', 'headTrackHand'},
	--
	{'headTrackHand', 'init', 'headCenter'},
	{'headTrackHand', 'teleop', 'headTeleop'},
	--
	{'headMesh', 'init', 'headCenter'},
	{'headMesh', 'done', 'headCenter'},
}

fsm.Gripper = {
	{'gripperIdle', 'init', 'gripperCenter'},
	{'gripperIdle', 'teleop', 'gripperTeleop'},
	{'gripperIdle', 'dean', 'gripperDeanOpen'},
	--
	{'gripperCenter', 'idle', 'gripperIdle'},
	{'gripperCenter', 'teleop', 'gripperTeleop'},
	{'gripperCenter', 'dean', 'gripperDeanOpen'},
	--
	{'gripperTeleop', 'idle', 'gripperIdle'},
	{'gripperTeleop', 'init', 'gripperCenter'},
	--
	{'gripperDeanOpen', 'init', 'gripperCenter'},
	{'gripperDeanOpen', 'idle', 'gripperIdle'},
	{'gripperDeanOpen', 'teleop', 'gripperTeleop'},
	{'gripperDeanOpen', 'close', 'gripperDeanClose'},
	--
	{'gripperDeanClose', 'init', 'gripperCenter'},
	{'gripperDeanClose', 'idle', 'gripperIdle'},
	{'gripperDeanClose', 'teleop', 'gripperTeleop'},
	{'gripperDeanClose', 'open', 'gripperDeanOpen'},
}

fsm.Lidar = {
	{'lidarIdle', 'pan', 'lidarPan'},
	--
	{'lidarPan', 'switch', 'lidarPan'},
	{'lidarPan', 'stop', 'lidarIdle'},
}

fsm.Arm = {
	-- Idle
	{'armIdle', 'timeout', 'armIdle'},
	{'armIdle', 'init', 'armInit'},
	-- Init
	{'armInit', 'timeout', 'armInit'},
	--{'armInit', 'done', 'armInit'},
	{'armInit', 'ready', 'armReady'},
	{'armInit', 'teleopraw', 'armTeleopRaw'},
	-- Ready pose (for manipulating)
	{'armReady', 'timeout', 'armReady'},
	{'armReady', 'teleop', 'armTeleop'},
	{'armReady', 'teleopraw', 'armTeleopRaw'},
	{'armReady', 'init', 'armInit'},
	{'armReady', 'door', 'armDoor'},
	{'armReady', 'jacobian', 'armJacobian'},
	--
	{'armJacobian', 'teleopraw', 'armTeleopRaw'},
	{'armJacobian', 'done', 'armJacobian'},
	-- Teleop
	{'armTeleop', 'init', 'armInit'},
	--{'armTeleop', 'done', 'armTeleop'},
	{'armTeleop', 'teleop', 'armTeleop'},
	{'armTeleop', 'ready', 'armReady'},
	{'armTeleop', 'teleopraw', 'armTeleopRaw'},
	{'armTeleop', 'door', 'armDoor'}, -- eh...
	-- Teleop Raw
	{'armTeleopRaw', 'init', 'armInit'},
	{'armTeleopRaw', 'teleopraw', 'armTeleopRaw'},
	{'armTeleopRaw', 'ready', 'armReady'},
	{'armTeleopRaw', 'teleop', 'armTeleop'},
	--
	{'armDoor', 'done', 'armTeleop'}, -- eh...
}

fsm.Motion = {
	-- Idle
	{'motionIdle', 'timeout', 'motionIdle'},
	{'motionIdle', 'stand', 'motionInit'},
	-- Init
	{'motionInit', 'done', 'motionStance'},
	{'motionInit', 'timeout', 'motionInit'},
	--
	{'motionStance', 'sway', 'motionSway'},
	{'motionStance', 'lean', 'motionLean'},
	--
	{'motionSway', 'lean', 'motionLean'},
	{'motionSway', 'switch', 'motionSway'},
	{'motionSway', 'timeout', 'motionSway'},
	{'motionSway', 'stand', 'motionStance'},
	--
	{'motionLean', 'stepup', 'motionLift'},
	{'motionLean', 'stepdown', 'motionStepDown'},
	{'motionLean', 'stand', 'motionInit'},
	--
	{'motionLift', 'lean', 'motionLean'},
	{'motionLift', 'timeout', 'motionLower'},
	{'motionLift', 'quit', 'motionLower'},
	--{'motionLift', 'done', 'motionLower'},
	{'motionLift', 'done', 'motionHold'},
	--
	{'motionHold', 'done', 'motionLower'},
	--
	{'motionLower', 'flat', 'motionStance'},
	{'motionLower', 'uneven', 'motionCaptainMorgan'},
	--
	{'motionCaptainMorgan', 'stepup', 'motionStepUp'},
	{'motionCaptainMorgan', 'stepdown', 'motionJoin'},
	--
	{'motionStepUp', 'done', 'motionHold'},
	--
	{'motionStepDown', 'done', 'motionLower'},
	--
	{'motionJoin', 'done', 'motionLower'},
}

if fsm.libraries.MotionLib == 'RoboCup' then
	fsm.select.Motion = 'RoboCup'
	fsm.Motion = {
		{'motionIdle', 'timeout', 'motionIdle'},
		{'motionIdle', 'stand', 'motionInit'},
		{'motionIdle', 'bias', 'motionBiasInit'},

		{'motionBiasInit', 'done', 'motionBiasIdle'},
		{'motionBiasIdle', 'stand', 'motionInit'},

		{'motionInit', 'done', 'motionStance'},

		{'motionStance', 'bias', 'motionBiasInit'},
		{'motionStance', 'preview', 'motionStepPreview'},
		{'motionStance', 'kick', 'motionKick'},
		{'motionStance', 'done_step', 'motionHybridWalkKick'},

		{'motionStance', 'sit', 'motionSit'},
		{'motionSit', 'stand', 'motionStandup'},
		{'motionStandup', 'done', 'motionStance'},

		{'motionStepPreview', 'done', 'motionStance'},
		{'motionKick', 'done', 'motionStance'},

		--For new hybrid walk
		{'motionStance', 'hybridwalk', 'motionHybridWalkInit'},
		{'motionHybridWalkInit', 'done', 'motionHybridWalk'},

		{'motionHybridWalk', 'done', 'motionStance'},
		{'motionHybridWalk', 'done', 'motionHybridWalkEnd'},

		{'motionHybridWalk', 'done_step', 'motionHybridWalkKick'},
		{'motionHybridWalkKick', 'done', 'motionStance'},
		{'motionHybridWalkKick', 'walkalong', 'motionHybridWalk'},

		--  {'motionHybridWalk', 'done_step', 'motionStepNonstop'},
		--  {'motionStepNonstop', 'done', 'motionStance'},

		{'motionHybridWalkEnd', 'done', 'motionStance'},
	}
elseif fsm.libraries.MotionLib == 'DRCFinal' then
	fsm.select.Motion = 'DRCFinal'
	fsm.Motion = {
  {'motionIdle', 'timeout', 'motionIdle'},
  {'motionIdle', 'stand', 'motionInit'},
  {'motionInit', 'done', 'motionStance'},

  {'motionIdle', 'bias', 'motionBiasInit'},
  {'motionStance', 'bias', 'motionBiasInit'},
  {'motionBiasInit', 'done', 'motionBiasIdle'},
  {'motionBiasIdle', 'stand', 'motionInit'},


  {'motionStance', 'preview', 'motionStepPreview'},
  {'motionStepPreview', 'done', 'motionStance'},

  {'motionStance', 'stair', 'motionStepPreviewStair'},
  {'motionStepPreviewStair', 'done', 'motionStance'},

  {'motionStance', 'hybridwalk', 'motionHybridWalkInit'},
  {'motionHybridWalkInit', 'done', 'motionHybridWalk'},
  {'motionHybridWalk', 'done', 'motionHybridWalkEnd'},
  {'motionHybridWalkEnd', 'done', 'motionStance'},

  {'motionStance', 'uninit', 'motionUnInit'},
  {'motionUnInit', 'done', 'motionIdle'},
	}
end

Config.fsm = fsm

return Config
