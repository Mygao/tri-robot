if Config.fsm.avoidance_mode == 0 then 
  print("=====Walk Through Head FSM Loaded====")
  HeadFSM = require('HeadFSMGoal');
elseif Config.fsm.avoidance_mode == 1 then
  print("======Dribble Head FSM Loaded========")
  HeadFSM = require('HeadFSMDribble');
elseif Config.fsm.avoidance_mode == 2 then
  print("===Potential Field Navigation========")
  HeadFSM = require('HeadFSMGoal');
elseif Config.fsm.avoidance_mode == 3 then
  print("====Potential Field Dribble==========")
  HeadFSM = require('HeadFSMDribble');
end