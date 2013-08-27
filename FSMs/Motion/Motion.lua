module(..., package.seeall);
require'common_motion'

local UltraSound = require('UltraSound')
local fsm = require('fsm')

local relax = require('relax')
local stance = require('stance')
local nullstate = require('nullstate')
local sit = require('sit')
-- This makes torso straight (for webots robostadium)
local standstill = require('standstill') 

local falling = require('falling')
local standup = require('standup')
local kick = require(Config.dev.kick)
-- slow, non-dynamic stepping for fine alignment before kick
local align = require('align') 

--For diving
local divewait = require('divewait')
local dive = require('dive')

-- Aux
local grip = require 'grip'

if Config.platform.name~="WebotsOP" then
	--Quadruped locomotion controller
  crawl = require(Config.dev.crawl)
	--Special walk controller with footstep planning
  largestep = require(Config.dev.largestep)
	-- Changes between standing, sitting, crawling state
  stancetocrawl = require'stancetocrawl' end

local sit_disable = Config.sit_disable or 0;

if sit_disable==0 then --For smaller robots
  fallAngle = Config.fallAngle or 30*math.pi/180;

  sm = fsm.new(relax);
  sm:add_state(stance);
  sm:add_state(nullstate);
  sm:add_state(walk);
  sm:add_state(sit);
  sm:add_state(standup);
  sm:add_state(falling);
  sm:add_state(kick);
  sm:add_state(standstill);
  sm:add_state(grip);
  sm:add_state(divewait);
  sm:add_state(dive);
  sm:add_state(align);

  sm:set_transition(sit, 'done', relax);
  sm:set_transition(sit, 'standup', stance);
  sm:set_transition(relax, 'standup', stance);
  sm:set_transition(relax, 'diveready', divewait);

  sm:set_transition(stance, 'done', walk);
  sm:set_transition(stance, 'sit', sit);
  sm:set_transition(stance, 'diveready', divewait);

  sm:set_transition(walk, 'sit', sit);
  sm:set_transition(walk, 'stance', stance);
  sm:set_transition(walk, 'standstill', standstill);
  sm:set_transition(walk, 'pickup', grip);
  sm:set_transition(walk, 'throw', grip);
  sm:set_transition(walk, 'align', align);

  --align transitions
  sm:set_transition(align, 'done', walk);

  --dive transitions
  sm:set_transition(walk, 'diveready', divewait);
  sm:set_transition(walk, 'dive', dive);

  sm:set_transition(divewait, 'dive', dive);
  sm:set_transition(divewait, 'walk', stance);
  sm:set_transition(divewait, 'standup', stance);
  sm:set_transition(divewait, 'sit', sit);

  sm:set_transition(dive, 'done', stance);
  sm:set_transition(dive, 'divedone', falling);

  --standstill makes the robot stand still with 0 bodytilt (for webots)
  sm:set_transition(standstill, 'stance', stance);
  sm:set_transition(standstill, 'walk', stance);
  sm:set_transition(standstill, 'sit', sit);
  sm:set_transition(standstill, 'diveready', divewait);


  -- Grip
  sm:set_transition(grip, 'timeout', grip);
  sm:set_transition(grip, 'done', stance);

  -- falling behaviours

  sm:set_transition(walk, 'fall', falling);
  sm:set_transition(align, 'fall', falling);
  sm:set_transition(divewait, 'fall', falling);
  sm:set_transition(falling, 'done', standup);
  sm:set_transition(standup, 'done', stance);
  sm:set_transition(standup, 'fail', standup);

  -- kick behaviours
  sm:set_transition(walk, 'kick', kick);
  sm:set_transition(kick, 'done', walk);
else --For large robots that cannot sit down or getup

  --THOROP specific (walk-crawl)

  fallAngle = 1E6; --NEVER check falldown

  sm = fsm.new(standstill);
  sm:add_state(stance);
  sm:add_state(walk);

  sm:add_state(crawl);
  sm:add_state(largestep);

  sm:add_state(stancetocrawl);



  sm:set_transition(stance, 'done', walk);
  sm:set_transition(stance, 'sit', stancetocrawl);

  sm:set_transition(walk, 'stance', stance);
  sm:set_transition(walk, 'standstill', standstill);
  sm:set_transition(walk, 'sit', stancetocrawl);


  sm:set_transition(walk, 'step', largestep);
  sm:set_transition(largestep, 'done', stance);

  sm:set_transition(stancetocrawl,'crawldone',crawl);
  sm:set_transition(stancetocrawl,'stancedone',stance);

  sm:set_transition(crawl, 'sit', stancetocrawl);

  --standstill makes the robot stand still with 0 bodytilt (for webots)
  sm:set_transition(standstill, 'stance', stance);
  sm:set_transition(standstill, 'walk', stance);
  sm:set_transition(standstill, 'done', stance); 

  sm:set_transition(standstill, 'sit', stancetocrawl);



end

-- TODO: This should be in mcm
-- set state debug handle to shared memory settor
--sm:set_state_debug_handle(gcm.set_fsm_motion_state);

-- TODO: fix kick->fall transition
--sm:set_transition(kick, 'fall', falling);

bodyTilt = Config.walk.bodyTilt or 0;

-- For still time measurement (dodgeball)
stillTime = 0;
stillTime0 = 0;
wasStill = false;

-- Ultra Sound Processor
if UltraSound then UltraSound.entry() end

function entry()
  sm:entry()
  mcm.set_walk_isFallDown(0);
  mcm.set_motion_fall_check(1); --check fall by default
end

function update()
  -- update us
	if UltraSound then UltraSound.update() end

  local imuAngle = Body.get_sensor_imuAngle();
  local maxImuAngle = 
	math.max(math.abs(imuAngle[1]), math.abs(imuAngle[2]-bodyTilt));
	
	--Should we check for fall? 1 = yes
  local fall = mcm.get_motion_fall_check() 
  if maxImuAngle > fallAngle and fall==1 then
    sm:add_event("fall");
    mcm.set_walk_isFallDown(1); --Notify world to reset heading 
  else
    mcm.set_walk_isFallDown(0); 
  end

  -- Keep track of how long we've been still for
  -- Update our last still measurement
  if( walk.still and not wasStill ) then
    stillTime0 = Body.get_time();
    stillTime = 0;
  elseif( walk.still and wasStill) then
    stillTime = Body.get_time() - stillTime0;
  else
    stillTime = 0;
  end
  wasStill = walk.still;


  if walk.active or align.active then
    mcm.set_walk_isMoving(1);
  else
    mcm.set_walk_isMoving(0);
  end

  sm:update();

  -- update shm
  update_shm();
end

function walk_start()
  is_bipedal = mcm.get_walk_bipedal();
  if is_bipedal>0 then     walk.start();
  else   crawl.start();
  end
end

function walk_stop()
  is_bipedal = mcm.get_walk_bipedal();
  if is_bipedal>0 then     walk.stop();
  else   crawl.stop();
  end
end

function set_walk_velocity(vx,vy,va)
  is_bipedal = mcm.get_walk_bipedal();
  if is_bipedal>0 then     walk.set_velocity(vx,vy,va);
  else   crawl.set_velocity(vx,vy,va);
  end
end

function exit()
  sm:exit();
end

function event(e)
  sm:add_event(e);
end

function update_shm()
  -- Update the shared memory
  mcm.set_walk_bodyOffset(walk.get_body_offset());
  mcm.set_walk_uLeft(walk.uLeft);
  mcm.set_walk_uRight(walk.uRight);
	if UltraSound then
		mcm.set_us_left(UltraSound.left);
		mcm.set_us_right(UltraSound.right);
	end
  mcm.set_walk_stillTime( stillTime );
end
