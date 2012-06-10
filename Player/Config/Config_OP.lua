module(..., package.seeall);

require('vector')

platform = {}; 
platform.name = 'OP'

function loadconfig(configName)
  local localConfig=require(configName);
  for k,v in pairs(localConfig) do
    Config[k]=localConfig[k];
  end
end

--Robot CFG should be loaded first to set PID values
loadconfig('Robot/Config_OP_Robot') 
loadconfig('Walk/Config_OP_Walk')
loadconfig('World/Config_OP_World')
loadconfig('Kick/Config_OP_Kick')
--loadconfig('Kick/Config_OP_Kick2')
loadconfig('Vision/Config_OP_Vision')
--Location Specific Camera Parameters--

loadconfig('Vision/Config_OP_Camera_VT')
--loadconfig('Vision/Config_OP_Camera_L512')
--loadconfig('Vision/Config_OP_Camera_L512_Day')
--loadconfig('Vision/Config_OP_Camera_Grasp')

-- Device Interface Libraries
dev = {};
dev.body = 'OPBody'; 
dev.camera = 'OPCam';
dev.kinematics = 'OPKinematics';
dev.ip_wired = '192.168.123.255';
dev.ip_wireless = '192.168.1.255';
dev.game_control='OPGameControl';
dev.team='TeamNSL';
dev.walk='NewNewNewWalk';
dev.kick = 'NewNewKick'
dev.gender = 1; -- 1 for body and 0 for girl 

speak = {}
speak.enable = false; 

-- Game Parameters
game = {};
game.teamNumber = 18;
--Not a very clean implementation but we're using this way for now
local robotName=unix.gethostname();
--Default role: 0 for goalie, 1 for attacker, 2 for defender
--Default team: 0 for blue, 1 for red
if (robotName=='scarface') then
  dev.gender = 1;
  game.playerID = 1; --for scarface
  game.role = 1; --Default attacker
elseif (robotName=='linus') then
  dev.gender = 1;
  game.playerID = 2; 
  game.role = 1; --Default attacker
elseif (robotName=='betty') then
  dev.gender = 0;
  game.playerID = 3; 
  game.role = 1; --Default attacker
elseif (robotName=='lucy') then
  dev.gender = 0;
  game.playerID = 4; 
  game.role = 1; --Default attacker
elseif (robotName=='felix') then
  dev.gender = 1;
  game.playerID = 5; 
  game.role = 1; --Default attacker
elseif (robotName=='sally') then
  dev.gender = 0;
  game.playerID = 5; 
  game.role = 1; --Default attacker
else
  dev.gender = 1;
  game.playerID = 5; 
  game.role = 1; --Default attacker
end

game.teamColor = 0; --Blue team
--game.teamColor = 1; --Red team
game.robotName = robotName;
game.robotID = game.playerID;
game.nPlayers = 5;
--------------------

--FSM and behavior settings
fsm = {};
--SJ: loading FSM config  kills the variable fsm, so should be called first
loadconfig('FSM/Config_OP_FSM')
fsm.game = 'RoboCup';
fsm.head = {'GeneralPlayer'};
fsm.body = {'GeneralPlayer'};

--Behavior flags, should be defined in FSM Configs but can be overrided here
fsm.enable_obstacle_detection = 1;
fsm.kickoff_wait_enable = 0;
fsm.playMode = 3; --1 for demo, 2 for orbit, 3 for direct approach
fsm.forcePlayer = 0; --1 for attacker, 2 for defender, 3 for goalie 
fsm.enable_walkkick = 1;
fsm.enable_sidekick = 0;

--FAST APPROACH TEST
fsm.fast_approach = 0;
--fsm.bodyApproach.maxStep = 0.06;

-- Team Parameters
team = {};
team.msgTimeout = 5.0;
team.nonAttackerPenalty = 6.0; -- eta sec
team.nonDefenderPenalty = 0.5; -- dist from goal
team.tKickOffWear =7.0;

-- keyframe files
km = {};
km.standup_front = 'km_NSLOP_StandupFromFront.lua';
km.standup_back = 'km_NSLOP_StandupFromBack.lua';

-- Low battery level
-- Need to implement this api better...
bat_med = 120; -- Slow down if voltage drops below 12.2V 
bat_low = 118; -- 11.8V warning




--[[
-- Stretcher
loadconfig( 'Config_Stretcher' );
game.playerID = 1;
fsm.game = 'Stretcher';
fsm.head = {'Stretcher'};
fsm.body = {'Stretcher'};
dev.team = "TeamPrimeQ"
dev.walk = "StretcherWalk"
--]]

gps_only = 0;

goalie_dive = 1; --1 for arm only, 2 for actual diving
--goalie_dive = 2; --1 for arm only, 2 for actual diving

--Speak enable
speakenable = false;
