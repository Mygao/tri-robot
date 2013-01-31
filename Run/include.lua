-- sets include paths for lua module access
-- usage: dofile('include.lua')

local function shell(command)
  local pipe = io.popen(command, 'r')
  local result = pipe:read('*a')
  pipe:close()
  return result
end

-- get dynamic lib suffix
local uname = shell('uname') 
if string.match(uname, 'Darwin') then
  csuffix = 'dylib'
else
  csuffix = 'so'
end

-- get absolute path prefix for code directory
local pwd = shell('pwd') 
local prefix = string.gsub(pwd, '/Run.*$', '')

-- set path for lua modules 
package.path = prefix.."/Config/?.lua;"..package.path
package.path = prefix.."/Config/Platform/?.lua;"..package.path
package.path = prefix.."/Config/Motion/?.lua;"..package.path
package.path = prefix.."/Data/?.lua;"..package.path
package.path = prefix.."/Framework/Util/?.lua;"..package.path
package.path = prefix.."/Framework/Comms/?.lua;"..package.path
package.path = prefix.."/Framework/Motion/?.lua;"..package.path
package.path = prefix.."/Framework/Motion/FSMs/?.lua;"..package.path
package.path = prefix.."/Framework/Motion/States/?.lua;"..package.path
package.path = prefix.."/Framework/Proprioception/?.lua;"..package.path
package.path = prefix.."/Framework/Platform/?.lua;"..package.path
package.path = prefix.."/Framework/Cognition/Slam/?.lua;"..package.path

-- set path for c modules 
package.cpath = prefix.."/Framework/Lib/?/?."..csuffix..";"..package.cpath
package.cpath = prefix.."/Framework/Lib/lcm/?."..csuffix..";"..package.cpath
package.cpath = prefix.."/Framework/Lib/unix/?."..csuffix..";"..package.cpath
package.cpath = prefix.."/Framework/Platform/?."..csuffix..";"..package.cpath
package.cpath = prefix.."/Framework/Cognition/Slam/?."..csuffix..";"..package.cpath
