#!/usr/bin/env luajit

local names = {'tri1'}
for i=1,7 do
  local name = string.format('car%d', i)
  table.insert(names, name)
end
for _, name in ipairs(names) do
  local cmds = {
               "cd dev/tri-robot/Modules",
               "git pull",
               "source env.bash",
               "tmux new -d -s icra -n vicon",
               "tmux new-window -t icra -n vesc",
               "tmux new-window -t icra -n control",
               "tmux new-window -t icra -n houston",
               "tmux new-window -t icra -n risk",
               -- Commands
               "tmux send-keys -t icra:vesc 'cd luajit-racecar' Enter" -- Enter -> C-m
               }
  local cmds_str = table.concat(cmds, "; ")
  local ssh_cmd = string.format('ssh -C -t nvidia@%s.local "%s"', name, cmds_str)
  print(ssh_cmd)
  -- os.execute(ssh_cmd)
end
