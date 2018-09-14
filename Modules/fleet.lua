#!/usr/bin/env luajit

local names = {}
for i=1,7 do
  local name = string.format('car%d', i)
  table.insert(names, name)
end
table.insert(names, 'tri1')
for i, name in ipairs(names) do
  local is_inner = i%2==0
  local is_log = name=='tri1'
  local cmds = {
               "cd dev/tri-robot/Modules",
               "git pull",
               "source env.bash",
               "tmux kill-session -t icra",
               "tmux new -d -s icra -n vicon",
               "tmux new-window -t icra -n vesc",
               "tmux new-window -t icra -n control",
               -- "tmux new-window -t icra -n houston",
               -- "tmux new-window -t icra -n risk",
               -- Commands
               -- Enter -> C-m
               "tmux send-keys -t icra:vicon 'cd luajit-racecar' Enter",
               "tmux send-keys -t icra:vicon 'luajit log_vicon.lua "..(is_log and "" or "--log 0").."' Enter",
               --
               "tmux send-keys -t icra:vesc 'cd luajit-racecar' Enter",
               "tmux send-keys -t icra:vesc 'luajit run_vesc.lua "..(is_log and "" or "--log 0").."' Enter",
               --
               "tmux send-keys -t icra:control 'cd lua-control' Enter",
               "tmux send-keys -t icra:control 'luajit run_control.lua "..(is_log and "" or "--log 0").." --desired "..(is_inner and "lane_inner" or "lane_outer").. "' Enter",
               }
  local cmds_str = table.concat(cmds, "; ")
  local ssh_cmd = string.format('ssh -C -t nvidia@%s.local "%s"', name, cmds_str)
  print(ssh_cmd)
  -- os.execute(ssh_cmd)

  local cmds = {"tmux kill-session -t icra", "sudo shutdown -h now"}
  local cmds_str = table.concat(cmds, "; ")
  local ssh_cmd = string.format('ssh -C -t nvidia@%s.local "%s"', name, cmds_str)
  os.execute(ssh_cmd)
end

