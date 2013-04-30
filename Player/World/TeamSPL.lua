module(..., package.seeall);

require('Config');
require('Body');
require('Comm');
require('Speak');
require('vector');
require('serialization');

require('wcm');
require('gcm');

--Makes error with webots
Comm.init(Config.dev.ip_wireless,Config.dev.ip_wireless_port);
print('Receiving Team Message From',Config.dev.ip_wireless);

playerID = gcm.get_team_player_id(); strategy = 0

msgTimeout = Config.team.msgTimeout;
nonAttackerPenalty = Config.team.nonAttackerPenalty;
nonDefenderPenalty = Config.team.nonDefenderPenalty;
time_to_stand = Config.km.time_to_stand;
twoDefenders = Config.team.twoDefenders;

role = -1;

count = 0;

state = {};
state.robotName = Config.game.robotName;
state.teamNumber = gcm.get_team_number();
state.id = playerID;
state.teamColor = gcm.get_team_color();
state.time = Body.get_time();
state.role = -1;
state.pose = {x=0, y=0, a=0};
state.ball = {t=0, x=1, y=0};
state.attackBearing = 0.0;--Why do we need this?
state.penalty = 0;
state.tReceive = Body.get_time();
state.battery_level = wcm.get_robot_battery_level();
state.fall=0;

state.soundFilter = wcm.get_sound_detFilter();
state.soundDetection = wcm.get_sound_detection();
soundOdomPose = wcm.get_sound_odomPose();
state.soundOdomPose = {x=soundOdomPose[1], y=soundOdomPose[2], a=soundOdomPose[3]};
--state.xp = wcm.get_particle_x();
--state.yp = wcm.get_particle_y();
--state.ap = wcm.get_particle_a();

--Added key vision infos
state.goal=0;  --0 for non-detect, 1 for unknown, 2/3 for L/R, 4 for both
state.goalv1={0,0};
state.goalv2={0,0};
state.landmark=0; --0 for non-detect, 1 for yellow, 2 for cyan
state.landmarkv={0,0};
states = {};
states[playerID] = state;

strat = {}

---Receives messages from teammates
tLastReceived = 0


function recv_msgs()
  while (Comm.size() > 0) do 
    t = serialization.deserialize(Comm.receive());
    if (t and (t.teamNumber) and (t.teamNumber == state.teamNumber) and (t.id) and (t.id ~= playerID)) then
      t.tReceive = Body.get_time();
      tLastReceived = Body.get_time();
      states[t.id] = t;
    elseif (t and (t.strat)) then
      t.tReceive = Body.get_time();
      strat = t
    end
  end
end

function entry()
end

function pack_labelB()
  labelB = vcm.get_image_labelB();
  width = vcm.get_image_width()/8;
  height = vcm.get_image_height()/8;
  count = vcm.get_image_count();
  array = serialization.serialize_label_rle(
  labelB, width, height, 'uint8', 'labelB',count);
  state.labelB = array;
end

function update()
  count = count + 1;

  state.time = Body.get_time();
  state.teamNumber = gcm.get_team_number();
  if (state.teamColor ~= gcm.get_team_color()) then
    print('Team color has changed - re-initing particles')
    World.init_particles();
  end
  state.teamColor = gcm.get_team_color();
  state.pose = wcm.get_pose();
  state.ball = wcm.get_ball();
  state.role = role;
  state.attackBearing = wcm.get_attack_bearing();
  state.battery_level = wcm.get_robot_battery_level();
  state.fall=wcm.get_robot_is_fall_down(); --Added

  if gcm.in_penalty() then
    state.penalty = 1;
  else
    state.penalty = 0;
  end

  state.soundFilter = wcm.get_sound_detFilter();
  state.soundDetection = wcm.get_sound_detection();
  soundOdomPose = wcm.get_sound_odomPose();
  state.soundOdomPose = {x=soundOdomPose[1], y=soundOdomPose[2], a=soundOdomPose[3]};
  --state.xp = wcm.get_particle_x();
  --state.yp = wcm.get_particle_y();
  --state.ap = wcm.get_particle_a();

  --Added Vision Info 
  state.goal=0;
  if vcm.get_goal_detect()>0 then
    state.goal = 1 + vcm.get_goal_type();
    local v1=vcm.get_goal_v1();
    local v2=vcm.get_goal_v2();
    state.goalv1[1],state.goalv1[2]=v1[1],v1[2];
    state.goalv2[1],state.goalv2[2]=0,0;
    if vcm.get_goal_type()==3 then --two goalposts 
      state.goalv2[1],state.goalv2[2]=v2[1],v2[2];
    end
  end

  state.landmark=0;
  if vcm.get_landmark_detect()>0 then
    local v = vcm.get_landmark_v();
    state.landmark = 1; 
    state.landmarkv[1],state.landmarkv[2] = v[1],v[2];
  end
  
  pack_labelB();

  if (math.mod(count, 1) == 0) then
    -- use old serialization for team monitor so the 
    --  old matlab team monitor can be used
    --local msg = serialization.serialize_orig(state) 
    -- CHANGED BASED ON NSL CODE
    msg = serialization.serialize(state) 
    Comm.send(msg, #msg);
    print(#msg)
    --Copy of message sent out to other players
    state.tReceive = Body.get_time();
    states[playerID] = state;
  end

  -- receive new messages
  recv_msgs();

  -- eta and defend distance calculation:
  eta = {};
  ddefend = {};
  t = Body.get_time();
  for id = 1,4 do

    if not states[id] or not states[id].ball.x then
      -- no message from player have been received
      eta[id] = math.huge;
      ddefend[id] = math.huge;

    else
      -- eta to ball
      rBall = math.sqrt(states[id].ball.x^2 + states[id].ball.y^2);
      tBall = states[id].time - states[id].ball.t;
      fallPen = states[id].fall * time_to_stand; -- fall penalty
      eta[id] = rBall/0.10 + 4*math.max(tBall-1.0,0) + fallPen;
      
      -- distance to goal
      dgoalPosition = vector.new(wcm.get_goal_defend());
      pose = wcm.get_pose();
    
      if twoDefenders == 1 then
        ddefend[id] = (-1) * util.sign ( dgoalPosition[1] ) * pose.y; -- use defender who is on the right
      else
        ddefend[id] = math.sqrt((pose.x - dgoalPosition[1])^2 + (pose.y - dgoalPosition[2])^2);
      end

      if (states[id].role ~= 1) then
        -- Non attacker penalty:
        eta[id] = eta[id] + nonAttackerPenalty;
      end
      if (states[id].penalty > 0) or (Body.get_time() - states[id].tReceive > msgTimeout) then
        eta[id] = math.huge;
      end

      if (states[id].role ~= 2) then
        -- Non defender penalty:
        if twoDefenders == 1 then
          ddefend[id] = ddefend[id] + 0.2;
        else
          ddefend[id] = ddefend[id] + 0.3;
        end
      end
      if (states[id].penalty > 0) or (t - states[id].tReceive > msgTimeout) then
        ddefend[id] = math.huge;
      end
    end
  end

--[[
  if count % 20 == 0 then
    print('---------------');
    print('eta:');
    util.ptable(eta)
    print('fall penalty:');
    for id = 1,4 do
      if states[id] then
        print(id..'\t'..states[id].fall);
      else
        print(id..'\tna');
      end
    end
    print('ddefend:');
    util.ptable(ddefend)
    print('---------------');
  end
--]]


  if gcm.get_game_state()<2 then 
    --Don't switch roles until the gameSet state
    --Because now bodyReady is based on roles
    return;
  end
  -- goalie never changes role
  if playerID ~= 1 then
    if strategy <= 0 then
      eta[1] = math.huge;
      ddefend[1] = math.huge;

      minETA, minEtaID = min(eta);
      if minEtaID == playerID then
        -- attack
        set_role(1);
      else
        -- furthest player back is defender
        minDDefID = 0;
        minDDef = math.huge;
        for id = 2,4 do
          if id ~= minEtaID and ddefend[id] <= minDDef then
            minDDefID = id;
            minDDef = ddefend[id];
          end
        end

    minETA, minEtaID = min(eta);
    if minEtaID == playerID then
      -- attack
      set_role(1);
    else
      -- furthest player back (or to the right, if using two defenders) is defender
      minDDefID = 0;
      minDDef = math.huge;
      for id = 2,4 do
        if id ~= minEtaID and ddefend[id] <= minDDef then
          minDDefID = id;
          minDDef = ddefend[id];
        end
      end
    end


    gcmstrat = gcm.get_team_strat();
    stratRole = nil
    if gcmstrat and (playerID == 2 or playerID == 3) then
      strategy = gcmstrat[Config.game.playerID - 1]
      print(strategy, role)

      if strategy == 2 then
        stratRole = 1
      elseif strategy == 3 then
        stratRole = 2
      elseif strategy == 4 then
        stratRole = 3
      end
      if stratRole then
        set_role(stratRole)
      end
    end
  end
  -- update shm
  update_shm() 
end

function update_shm() 
  -- update the shm values
  gcm.set_team_role(role);
  
 -- gcm.set_team_strat(strat.strat)
end

function exit()
end

---Returns current role
--@return int role, 1=attacker, 2=defender, 3=supporter, 0=goalie
function get_role()
  return role;
end

---Sets role
--@param r Role 
function set_role(r)
  if role ~= r then 
    role = r;
    wireless = (Body.get_time()-tLastReceived) < 1;
    if wireless then
      Speak.talk('Received packet')
    end
    Body.set_indicator_role(role, wireless);
    if role == 1 then
      -- attack
      Speak.talk('Attack');
    elseif role == 2 then
      -- defend
      Speak.talk('Defend');
    elseif role == 3 then
      -- support
      Speak.talk('Support');
    elseif role == 0 then
      -- goalie
      Speak.talk('Goalie');
    else
      -- no role
      Speak.talk('ERROR: Unknown Role');
    end
  end
  update_shm();
end

set_role(Config.game.role);

function get_player_id()
  return playerID; 
end

function min(t)
  local imin = 0;
  local tmin = math.huge;
  for i = 1,#t do
    if (t[i] < tmin) then
      tmin = t[i];
      imin = i;
    end
  end
  return tmin, imin;
end
