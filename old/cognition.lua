cwd = os.getenv('PWD')
local init = require('init')

local unix = require('unix')
require('vcm')
require('gcm')
require('wcm')
require('mcm')
local Body = require('Body')
local Vision = require('Vision')
local World = require('World')
local Detection = require('Detection') 
--local OccupancyMap = require('OccupancyMap') 

comm_inited = false;
vcm.set_camera_teambroadcast(0);
vcm.set_camera_broadcast(0);
--Now vcm.get_camera_teambroadcast() determines 
--Whether we use wired monitoring comm or wireless team comm

count = 0;
nProcessedImages = 0;
tUpdate = unix.time();

local enable_online_colortable_learning = Config.vision.enable_online_colortable_learning or 0;
local enable_freespace_detection = Config.vision.enable_freespace_detection or 0;

if (string.find(Config.platform.name,'Webots')) then
  webots = true;
end

function broadcast()
  local broadcast_enable = vcm.get_camera_broadcast();
  if broadcast_enable>0 then
    if broadcast_enable==1 then 
      --Mode 1, send 1/4 resolution, labeB, all info
      imgRate = 1; --30fps
    elseif broadcast_enable==2 then 
      --Mode 2, send 1/2 resolution, labeA, labelB, all info
      imgRate = 2; --15fps
    else
      --Mode 3, send 1/2 resolution, info for logging
      imgRate = 1; --30fps
    end
    -- Always send non-image data
    Broadcast.update(broadcast_enable);
    -- Send image data every so often
    if nProcessedImages % imgRate ==0 then
      Broadcast.update_img(broadcast_enable);    
    end
    --Reset this flag at every broadcast
    --To prevent monitor running during actual game
    vcm.set_camera_broadcast(0);
  end
end

function entry()
  World.entry();
  Vision.entry();
  if enable_freespace_detection == 1 then
    --OccupancyMap.entry();
  end
end

--Update function for wired kinnect input
function update_box()
  count = count + 1;
  tstart = unix.time();

  -- update vision 
  imageProcessed = Vision.update();
  World.update_odometry();

  -- update localization
  if imageProcessed then
    nProcessedImages = nProcessedImages + 1;
    World.update_vision();
  end
 
  if not comm_inited and 
    (vcm.get_camera_broadcast()>0 or vcm.get_camera_teambroadcast()>0) then
      Config.dev.team = 'TeamBox'; --Force using Team box here 
      local Team = require('Team');
      local GameControl = require('GameControl');
      Team.entry();
      GameControl.entry();
      print("Starting to send wireless team message..");
      comm_inited = true;
  end
  if comm_inited then
  -- SJ: TeamBox receives KINNECT data, so should run every frame
    Team.update();
  end

  if comm_inited and imageProcessed then
    GameControl.update();
  end
end












function update()
  count = count + 1;
  tstart = unix.time();

  -- update vision 
  imageProcessed = Vision.update();

  World.update_odometry();

  -- update localization
  if imageProcessed then
    nProcessedImages = nProcessedImages + 1;
    World.update_vision();

    if (nProcessedImages % 200 == 0) then
      if not webots then
        print('fps: '..(200 / (unix.time() - tUpdate)));
        Detection.print_time(); 
        tUpdate = unix.time();
      end
    end
    if enable_freespace_detection == 1 then
      --OccupancyMap.update();
    end
  end
 
  if not comm_inited and 
    (vcm.get_camera_broadcast()>0 or vcm.get_camera_teambroadcast()>0) then
      if enable_online_colortable_learning == 1 then
        local Receive = require('Receive')
      end
      if vcm.get_camera_teambroadcast()>0 then 
        local Team = require('Team');
        local GameControl = require('GameControl');
        Team.entry();
        GameControl.entry();
        print("Starting to send wireless team message..");
      else
        local Broadcast = require('Broadcast');
        print("Starting to send wired monitor message..");
        print("Starting to wired message..");
      end
      comm_inited = true;
  end

  if comm_inited and imageProcessed then
    if enable_online_colortable_learning == 1 then
      Receive.update();
    end
    if vcm.get_camera_teambroadcast()>0 then 
      GameControl.update();
      if nProcessedImages % 3 ==0 then
        Team.update();
      end
    else
      broadcast();
    end
  end

end

-- exit 
function exit()
  if vcm.get_camera_teambroadcast()>0 then 
    Team.exit();
    GameControl.exit();
  end
  Vision.exit();
  World.exit();
end
