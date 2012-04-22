--Steve
--Ashleigh
--This code is used to broadcast each robot's information over network
--Sent string is in lua format (for monitoring)

module(..., package.seeall);


require('Comm')
-- Only send items from shared memory
require('vcm')
require('gcm')
require('wcm')
require('serialization');
require('ImageProc')
require('Config');

--sendShm = {'wcm','vcm','gcm'}
sendShm = { wcmshm=wcm, gcmshm=gcm, vcmshm=vcm }
itemReject = 'yuyv,labelA,labelB,yuyv2,yuyv3'

-- Initiate Sending Address
Comm.init(Config.dev.ip_wired,111111);
print('Sending to',Config.dev.ip_wired);

-- Add a little delay between packet sending
-- pktDelay = 500; -- time in us
-- Empirical value for keeping all packets intact
pktDelay = 1E6 * 0.001; --For image and colortable
pktDelay2 = 1E6 * 0.001; --For info
imageCount=0;

debug = 0;

subsampling=Config.vision.subsampling or 0;
subsampling2=Config.vision.subsampling2 or 0;

function sendB()
  -- labelB --
  labelB = vcm.get_image_labelB();
  width = vcm.get_image_width()/8; 
  height = vcm.get_image_height()/8;
  count = vcm.get_image_count();
  
  array = serialization.serialize_array(labelB, width, height, 'uint8', 'labelB', count);
  sendlabelB = {};
  sendlabelB.team = {};
  sendlabelB.team.number = gcm.get_team_number();
  sendlabelB.team.player_id = gcm.get_team_player_id();

  stime1,stime2,infosize=0,0,0;
  for i=1,#array do
    sendlabelB.arr = array[i];
    t0 = unix.time();
    local senddata=serialization.serialize(sendlabelB);
    infosize=infosize+#senddata;
    t1=unix.time();
    stime1=stime1+t1-t0;
    Comm.send(senddata);
    t2=unix.time();
    stime2=stime2+t2-t1;
  end 
  if debug>0 then
    print("LabelB info size:",#array,"Total",infosize);
    print("Total serialization time:",stime1);
    print("Total comm time:",stime2);
  end
end

function sendA()
  -- labelA --
  labelA = vcm.get_image_labelA();
  width = vcm.get_image_width()/2; 
  height = vcm.get_image_height()/2;
  count = vcm.get_image_count();
  
  array = serialization.serialize_array(labelA, width, height, 'uint8', 'labelA', count);
  sendlabelA = {};
  sendlabelA.team = {};
  sendlabelA.team.number = gcm.get_team_number();
  sendlabelA.team.player_id = gcm.get_team_player_id();
  stime1,stime2,infosize=0,0,0;  
  for i=1,#array do
    sendlabelA.arr = array[i];
    t0 = unix.time();
    local senddata=serialization.serialize(sendlabelA);
    infosize=infosize+#senddata;
    t1=unix.time();
    stime1=stime1+t1-t0;
    Comm.send(senddata);
    t2=unix.time();
    stime2=stime2+t2-t1;
    -- Need to sleep in order to stop drinking out of firehose
    unix.usleep(pktDelay);
  end
  if debug>0 then
    print("LabelA info size:",#array,"Total",infosize);
    print("Total serialization time:",stime1);
    print("Total comm time:",stime2);
  end
end

function sendImg()
  -- yuyv --
  yuyv = vcm.get_image_yuyv();
  width = vcm.get_image_width()/2; -- number of yuyv packages
  height = vcm.get_image_height();
  count = vcm.get_image_count();
  
  array = serialization.serialize_array2(yuyv, width, height, 
	'int32', 'yuyv', count);
--  array = serialization.serialize_array(yuyv, width, height, 
--	'int32', 'yuyv', count);

  sendyuyv = {};
  sendyuyv.team = {};
  sendyuyv.team.number = gcm.get_team_number();
  sendyuyv.team.player_id = gcm.get_team_player_id();

  local tSerialize=0;
  local tSend=0;  
  local totalSize=0;
  for i=1,#array do
    sendyuyv.arr = array[i];
    t0 = unix.time();
    senddata=serialization.serialize(sendyuyv);     
    t1 = unix.time();
    tSerialize= tSerialize + t1-t0;
    Comm.send(senddata);
    t2 = unix.time();
    tSend=tSend+t2-t1;
    totalSize=totalSize+#senddata;

    -- Need to sleep in order to stop drinking out of firehose
    unix.usleep(pktDelay);
  end
  if debug>0 then
    print("Image info array num:",#array,"Total size",totalSize);
    print("Total Serialize time:",#array,"Total",tSerialize);
    print("Total Send time:",tSend);
  end
end

function sendImgSub2()
  -- yuyv2 --
  yuyv2 = vcm.get_image_yuyv2();
  width = vcm.get_image_width()/4; -- number of yuyv packages
  height = vcm.get_image_height()/2;
  count = vcm.get_image_count();
  
--  array = serialization.serialize_array(yuyv2, width, height, 
--		'int32', 'ysub2', count);
  array = serialization.serialize_array2(yuyv2, width, height, 
		'int32', 'ysub2', count);
  sendyuyv2 = {};
  sendyuyv2.team = {};
  sendyuyv2.team.number = gcm.get_team_number();
  sendyuyv2.team.player_id = gcm.get_team_player_id();

  local tSerialize=0;
  local tSend=0;  
  local totalSize=0;
  for i=1,#array do
    sendyuyv2.arr = array[i];
    t0 = unix.time();
    senddata=serialization.serialize(sendyuyv2);
    t1 = unix.time();
    tSerialize= tSerialize + t1-t0;
    Comm.send(senddata);
    t2 = unix.time();
    tSend=tSend+t2-t1;
    totalSize=totalSize+#senddata;

    -- Need to sleep in order to stop drinking out of firehose
    unix.usleep(pktDelay);
  end

  if debug>0 then
    print("Image2 info array num:",#array,"Total size",totalSize);
    print("Total Serialize time:",#array,"Total",tSerialize);
    print("Total Send time:",tSend);
  end
end

function sendImgSub4()
  -- yuyv3 --
  yuyv3 = vcm.get_image_yuyv3();
  width = vcm.get_image_width()/8; -- number of yuyv packages
  height = vcm.get_image_height()/4;
  count = vcm.get_image_count();

  array = serialization.serialize_array2(yuyv3, width, height, 
		'int32', 'ysub4', count);
  sendyuyv3 = {};
  sendyuyv3.team = {};
  sendyuyv3.team.number = gcm.get_team_number();
  sendyuyv3.team.player_id = gcm.get_team_player_id();

  local tSerialize=0;
  local tSend=0;  
  for i=1,#array do
    sendyuyv3.arr = array[i];
    t0 = unix.time();
    senddata=serialization.serialize(sendyuyv3);
    t1 = unix.time();
    tSerialize= tSerialize + t1-t0;
    Comm.send(senddata);
    t2 = unix.time();
    tSend=tSend+t2-t1;

    -- Need to sleep in order to stop drinking out of firehose
    unix.usleep(pktDelay);
  end
  if debug>0 then
    print("Image3 info array num:",#array,"Total size",#senddata*#array);
    print("Total Serialize time:",#array,"Total",tSerialize);
    print("Total Send time:",tSend);
  end
end

function update(enable)
  if enable == 0 then return; end
  --At level 3, we only send yuyv for logging and nothing else
  if enable == 3 then return; end
	
  send = {};	
  for shmHandlerkey,shmHandler in pairs(sendShm) do
    send[shmHandlerkey] = {};
    for sharedkey,sharedvalue in pairs(shmHandler.shared) do
      send[shmHandlerkey][sharedkey] = {};
      for itemkey,itemvalue in pairs(shmHandler.shared[sharedkey]) do
	--String can partially match
	m_1,m_2=string.find(itemReject, itemkey);
	sendokay=false;
        if m_1==nil or not (m_1==1 and m_2==itemReject:len()) then

--print(string.format("shmHandlerKey %s sharedkey %s itemkey %s\n",
--	shmHandlerkey,sharedkey,itemkey));

  	  send[shmHandlerkey][sharedkey][itemkey] = 
                 shmHandler['get_'..sharedkey..'_'..itemkey]();
 	end
      end
    end
  end
  t0 = unix.time();
  senddata=serialization.serialize(send);
  t1 = unix.time();
  Comm.send(senddata);
  t2 = unix.time();
  unix.usleep(pktDelay2);

  if debug>0 then
    print("SHM Info byte:",#senddata)
    print("Serialize time:",t1-t0);
    print("Comm time:",t2-t1);
  end
end

function update_img( enable, imagecount )
  if(enable==1) then
    --1: Fast debug mode
    --send 1/4 image and labelB
    if subsampling2>0 then
      sendImgSub4();
      sendB();
    end
  elseif(enable==2) then
    --2: Vision debug mode
    --Send everything 
    if subsampling>0 then
      sendImgSub2();
      sendA();
      sendB();
    else
      sendImg();
      sendA();
      sendB();
    end
  elseif enable==3 then
    --3: Logging mode
    --Only send 160*120 yuyv for logging
    if subsampling>0 then
      sendImgSub2();
    else
      sendImg();
    end
  end
end
