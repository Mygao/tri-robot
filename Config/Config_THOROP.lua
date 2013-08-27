local Config = {}
Config.PLATFORM_NAME = 'THOROP'
Config.USE_LOCALHOST = true

-- Exogenuous Configs
local exo = {}
exo.Walk = 'Walk'

-- Iterate through each Config
for k,v in pairs(exo) do
  local exo_name = k..'/Config_'..Config.PLATFORM_NAME..'_'..v
  print('Loading exogenous',v)
  local exo_config = require(exo_name)
  for kk,vv in pairs(exo_config) do Config[kk] = vv end
end

-- Device Interface Libraries
Config.dev = {}
Config.dev.body         = 'THOROPBody'
Config.dev.kinematics   = 'THOROPKinematics'
Config.dev.game_control = 'OPGameControl'
Config.dev.team         = 'TeamNSL'
Config.dev.kick         = 'NewNewKick'
Config.dev.walk         = 'GrumbleWalk'
Config.dev.crawl        = 'ScrambleCrawl'
Config.dev.largestep    = 'ZMPStepStair'
Config.dev.gender       = 'boy'

-------------------
-- Network settings
-------------------
-- TODO: Verify with ifconfig
Config.net = {}
-- Robot IP addresses
Config.net.robot = {
['wired']    = '192.168.123.22',
['wireless'] = '192.168.1.22',
}
-- Remote Operator IP addresses
Config.net.operator = {
['wired']              = '192.168.123.23',
['wired_broadcast']    = '192.168.123.255',
['wireless']           = '192.168.1.23',
['wireless_broadcast'] = '192.168.1.255'
}

if Config.USE_LOCALHOST then
  -- wired
  Config.net.robot.wired = 'localhost'
  Config.net.operator.wired = 'localhost'
  Config.net.operator.wired_broadcast = 'localhost'
  -- wireless
  Config.net.robot.wireless = 'localhost'
  Config.net.operator.wireless = 'localhost'
  Config.net.operator.wireless_broadcast = 'localhost'
end

-- Ports
Config.net.reliable_rpc   = 55555
Config.net.unreliable_rpc = 55556
Config.net.team           = 44444
Config.net.state          = 44445
Config.net.head_camera    = 33333
Config.net.mesh           = 33334
Config.net.rgbd           = 33335

-- keyframe files
Config.km = {}
Config.km.standup_front = 'km_Charli_StandupFromFront.lua'
Config.km.standup_back  = 'km_Charli_StandupFromBack.lua'

return Config