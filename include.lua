USE_LOCALHOST = true

-- Locate the Modules
local handle = io.popen('pwd')
CWD = handle:read("*a"):gsub("%s+$", "")
handle:close()
IS_WEBOTS = false
HOME = CWD:gsub('Player.*$','')
HOME = HOME:gsub('Robots.*$','')
HOME = HOME:gsub('Operate.*$','')
HOME = HOME:gsub('Modules.*$','')
HOME = HOME:gsub('Tools.*$','')
HOME = HOME:gsub('Frameworks.*$','')
HOME = HOME:gsub('Util.*$','')
if HOME:find'Webots' ~= nil then
  HOME = HOME:gsub('Webots.*$','')
  IS_WEBOTS = true
end

-- Useful constants
DEG_TO_RAD = math.pi/180
RAD_TO_DEG = 180/math.pi

-- SJ: This removes the output buffer
io.stdout:setvbuf("no")

OPERATING_SYSTEM = io.popen('uname'):read('*a'):lower():gsub("%s+$", "")

-- include C modules to cpath
-- getch.so is in Modules/getch/ (Modules/unix/unix.so -> Modules/?/?.so)
package.cpath = HOME..'/Modules/?/?.so;'..package.cpath

-- include Lua utilities to path
package.path = HOME..'/Util/?.lua;'..package.path

-- include Shared Memory files to path
package.path = HOME..'/Memory/?.lua;'..package.path

-- include Robot Agnostic wrappers
package.path = HOME..'/Player/Dev/?.lua;'..package.path

-- include World files to the path
package.path = HOME..'/Player/World/?.lua;'..package.path

-- include Config files to path
package.path = HOME..'/Config/?.lua;'..package.path

-- Save the hostname
local unix = require'unix'
HOSTNAME = unix.gethostname()

-- Config is global now!
Config = require'Config'

-- include platform specific modules
package.path  = HOME..'/Robots/'..Config.PLATFORM_NAME..'/?.lua;'..package.path
package.cpath = HOME..'/Robots/'..Config.PLATFORM_NAME..'/?.so;'..package.cpath

KEYFRAME_DIR = HOME.."/Player/Keyframes"
LOG_DIR = HOME.."/Logs/"

-- Print out the globally available variables, when using include.lua
function print_env()
	print( 'Working Dir:', CWD )
	print( 'Home Dir:', HOME )
	print( 'Operating Sys:', OPERATING_SYSTEM )
	print( 'Webots:', IS_WEBOTS )
	print( 'Platform:', Config.PLATFORM_NAME )
	print( 'Keyframes directory:', KEYFRAME_DIR )
end
