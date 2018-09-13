#!/usr/bin/env luajit

local names = {'tri1'}
for i=1,7 do
  local name = string.format('car%d', i)
  table.insert(names, name)
end
for _, name in ipairs(names) do
  local cmd = {
  'ssh -C -t nvidia@'..name..'.local ',
  '"cd dev/tri-robot/Modules; git pull; source env.bash; tmux new -d -s icra -n vicon; tmux new-window -t icra -n vesc; tmux new-window -t icra -n control"',}
  cmd = table.concat(cmd)
  print(cmd)
  os.execute(cmd)
end
