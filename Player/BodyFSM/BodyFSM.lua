--------------------------------
-- Humanoid arm state machine
-- (c) 2013 Stephen McGill, Seung-Joon Yi
--------------------------------
-- Use the fsm module
local fsm = require'fsm'
-- Require the needed states
local bodyIdle = require'bodyIdle'
--[[
local bodyInit = require'bodyInit'
local bodyStepOver = require'bodyStepOver'
local bodyStepPlan = require'bodyStepPlan'
local bodyStepPlan2 = require'bodyStepPlan2' --90 deg turn
local bodyStepPlan3 = require'bodyStepPlan3' --sidestep
local bodyStepPlan4 = require'bodyStepPlan4' --minus 90 deg turn
local bodyStepTest = require'bodyStepTest' --minus 90 deg turn

local bodyStepWiden = require'bodyStepWiden' --For drilling

local bodyStepWaypoint = require'bodyStepWaypoint'

local bodyDrive = require'bodyDrive'
--]]
-- YouBot map following
local bodyPath = require'bodyPath'

-- Instantiate a new state machine with an initial state
-- This will be returned to the user
local sm = fsm.new(bodyIdle)
--[[
sm:add_state(bodyInit)
sm:add_state(bodyStepOver)
sm:add_state(bodyStepPlan)
sm:add_state(bodyStepPlan2)
sm:add_state(bodyStepPlan3)
sm:add_state(bodyStepPlan4)
sm:add_state(bodyStepTest)
sm:add_state(bodyStepWiden)
sm:add_state(bodyStepWaypoint)
sm:add_state(bodyDrive)
--]]
sm:add_state(bodyPath)

-- Setup the transitions for this FSM
--[[
sm:set_transition( bodyIdle, 'init', bodyInit )
sm:set_transition( bodyIdle, 'drive', bodyDrive)

sm:set_transition( bodyInit, 'done', bodyIdle )

sm:set_transition( bodyIdle,   'follow', bodyStepWaypoint )
sm:set_transition( bodyStepWaypoint,   'done', bodyIdle )

sm:set_transition( bodyIdle,   'stepover', bodyStepOver )
sm:set_transition( bodyStepOver,   'done', bodyIdle )

--For testing
--sm:set_transition( bodyIdle,   'stepplan', bodyStepPlan )
sm:set_transition( bodyIdle,   'stepplan2', bodyStepPlan2 )
--sm:set_transition( bodyIdle,   'stepplan3', bodyStepPlan3 )
--sm:set_transition( bodyIdle,   'stepplan4', bodyStepPlan4 )
--sm:set_transition( bodyIdle,   'steptest', bodyStepTest )
--sm:set_transition( bodyIdle,   'stepwiden', bodyStepWiden )

sm:set_transition( bodyStepPlan,   'done', bodyIdle )
sm:set_transition( bodyStepPlan2,   'done', bodyIdle )
sm:set_transition( bodyStepPlan3,   'done', bodyIdle )
sm:set_transition( bodyStepPlan4,   'done', bodyIdle )
sm:set_transition( bodyStepTest,   'done', bodyIdle )

sm:set_transition( bodyStepWiden,   'done', bodyIdle )
--]]

-- Plan and follow a path to the world goal position
sm:set_transition( bodyIdle, 'path', bodyPath )
-- Replan on timeout
sm:set_transition( bodyPath, 'timeout', bodyPath )
-- Replan upon request
sm:set_transition( bodyPath, 'path', bodyPath )
-- Finished the path
sm:set_transition( bodyPath, 'done', bodyIdle )

--------------------------
-- Setup the FSM object --
--------------------------
local obj = {}
obj._NAME = ...
local util = require'util'
-- Simple IPC for remote state triggers
local simple_ipc = require'simple_ipc'
local evts = simple_ipc.new_subscriber(...,true)
local debug_str = util.color(obj._NAME..' Event:','green')
local special_evts = special_evts or {}
obj.entry = function()
  sm:entry()
end
obj.update = function()
  -- Check for out of process events in non-blocking fashion
  local event, has_more = evts:receive(true)
  if event then
    local debug_tbl = {debug_str,event}
    if has_more then
      extra = evts:receive(true)
      table.insert(debug_tbl,'Extra')
    end
    local special = special_evts[event]
    if special then
      special(extra)
      table.insert(debug_tbl,'Special!')
    end
    print(table.concat(debug_tbl,' '))
    sm:add_event(event)
  end
  sm:update()
end
obj.exit = function()
  sm:exit()
end

obj.sm = sm

return obj
