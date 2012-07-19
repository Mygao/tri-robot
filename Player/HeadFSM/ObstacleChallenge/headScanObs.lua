------------------------------
--NSL Linear two-line head scan
------------------------------

module(..., package.seeall);

require('Body')
require('wcm')
require('mcm')

pitch0 = 33*math.pi/180;
pitchMag = 20.5*math.pi/180;
yawMag = 10*math.pi/180;
yaw0 = 0*math.pi/180;

tScan = 2.0;
timeout = tScan * 2;

t0 = 0;
direction = 1;


function entry()
  print("Head SM:".._NAME.." entry");

  -- start scan in ball's last known direction
  t0 = Body.get_time();
  ball = wcm.get_ball();
  timeout = tScan * 2;

  yaw_0, pitch_0 = HeadTransform.ikineCam(ball.x, ball.y,0);
  local currentYaw = Body.get_head_position()[1];

  if currentYaw>0 then
    direction = 1;
    yawDir = 1
  else
    direction = -1;
    yawDir = -1
  end
--[[
  if pitch_0>pitch0 then
    pitchDir=1;
  else
    pitchDir=-1;
  end
  --]]
end

function update()
  pitchBias =  mcm.get_headPitchBias();--Robot specific head angle bias

  local t = Body.get_time();
  -- update head position

  local ph = (t-t0)/tScan;
  ph = ph - math.floor(ph);

  if ph<0.25 then --phase 0 to 0.25
--    yaw=yawMag*(ph*4)* direction;
      pitch=pitchMag*(ph*4)*direction;
--    pitch=pitch0+pitchMag*pitchDir;
      yaw= yaw0 + yawMag*yawDir;
  elseif ph<0.75 then --phase 0.25 to 0.75
--    yaw=yawMag*(1-(ph-0.25)*4)* direction;
    pitch=pitchMag*(1-(ph-0.25)*4)* direction;
--  pitch=pitch0-pitchMag*pitchDir;
    yaw = yaw0 - yawMag * yawDir;
  else --phase 0.75 to 1
    pitch=pitchMag*(-1+(ph-0.75)*4)* direction;
--    yaw=yawMag*(-1+(ph-0.75)*4)* direction;
--    pitch=pitch0+pitchMag*pitchDir;
    yaw = yaw0 + yawMag * yawDir;
  end

  Body.set_head_command({yaw, pitch-pitchBias+pitch0});

--  if vcm.get_freespace_allBlocked() == 1 then
--    print('blocked view')
--    return 'blocked'
--  end

  if (t - t0 > timeout) then
    return 'timeout';
  end
end

function exit()
end
