#!/usr/bin/env luajit

local name0 = arg[1]

local names = {}
for i=1,7 do
  local name = string.format('car%d', i)
  if (not name0) or name0==name then
    table.insert(names, name)
  end
end
if (not name0) or name0=='tri1' then
  table.insert(names, 'tri1')
end
for i, name in ipairs(names) do
  local is_inner = i%2==0
  local is_obs = name=='tri1'
  local log_flag = is_obs and "" or "--log 0"
  local cmds = {
               "cd dev/tri-robot/Modules",
               "git pull",
               "source env.bash",
               "tmux kill-session -t icra",
               "tmux new -d -s icra -n vicon",
               "tmux new-window -t icra -n vesc",
               "tmux new-window -t icra -n control",
               -- Commands
               -- Enter -> C-m
               "tmux send-keys -t icra:vicon 'cd luajit-racecar' Enter",
               "tmux send-keys -t icra:vicon 'luajit log_vicon.lua "..log_flag.."' Enter",
               --
               "tmux send-keys -t icra:vesc 'cd luajit-racecar' Enter",
               "tmux send-keys -t icra:vesc 'luajit run_vesc.lua "..log_flag.."' Enter",
               --
               }
  if is_obs then
    table.insert(cmds, "tmux send-keys -t icra:control 'cd lua-control' Enter")
    table.insert(cmds, "tmux send-keys -t icra:control 'luajit run_control.lua "..log_flag.." --desired turn_left' ")
    table.insert(cmds, "tmux new-window -t icra -n risk")
    table.insert(cmds, "tmux new-window -t icra -n joystick")
    table.insert(cmds, "tmux send-keys -t icra:joystick 'cd luajit-racecar' Enter")
    table.insert(cmds, "tmux send-keys -t icra:joystick 'luajit run_joystick.lua "..log_flag.."' Enter")
  else
    local path = is_inner and "lane_inner" or "lane_outer"
    table.insert(cmds, "tmux send-keys -t icra:control 'cd lua-control' Enter")
    table.insert(cmds, "tmux send-keys -t icra:control 'luajit run_control.lua "..log_flag.." --desired "..path.. "' Enter")
  end
  local cmds_str = table.concat(cmds, "; ")
  local ssh_cmd = string.format('ssh -C -t nvidia@%s.local "%s"', name, cmds_str)
  print(ssh_cmd)
  os.execute(ssh_cmd)

  -- Shutting down
  local cmds = {"tmux kill-session -t icra", "sudo shutdown -h now"}
  local cmds_str = table.concat(cmds, "; ")
  local ssh_cmd = string.format('ssh -C -t nvidia@%s.local "%s"', name, cmds_str)
  print(ssh_cmd)
  -- os.execute(ssh_cmd)
end

