cwd = os.getenv('PWD')
local init = require('init')
local Config = require 'Config'

--SJ: Config values are directly overriden here 
--So that we don't need to modify config variables every time
Config.dev.team = 'TeamBox'
Config.game.gcTimeout = 2;
Config.team.msgTimeout = 1.0;
Config.game.playerID = 1

local skeleton = require 'skeleton'
local Boxer = require 'Boxer'
local getch = require('getch')
getch.enableblock(1);

teamID   = Config.game.teamNumber;
playerID = Config.game.playerID;
nPlayers = Config.game.nPlayers;
nPlayers = 2

net = true
function entry()
	-- Check inputs
	print("Num args: ",#arg)
	inp_logs = {};
	if( arg[1] ) then
		nPlayers = #arg
		for i=1,nPlayers do
			dofile( arg[i] )
			inp_logs[i] = log;
		end
	end

	print '=====================';
	print('Team '..teamID,'Player '..playerID)
	print '=====================';

	-- Initialize FSMs
	skeleton.entry(inp_logs)
	for pl=1,nPlayers do
		Boxer.entry(pl);
	end
	if( net ) then
		local Team = require 'Team'
		Team.entry(true) -- true means we have the primesense
	end

	t0 = unix.time();
	t_last_debug = t0;
	count = 0;

end

function update()
	local t_start = unix.time();
  
	-- Updates
	if not skeleton.update() then
		return false
	end
	for pl=1,nPlayers do
		Boxer.update(pl);
	end
	if( net ) then
		Team.update()
	end

	-- User Key input
	local keycode = process_keyinput();
	if keycode==string.byte("q") then
		return false
	end
	
	-- Toggle Logging
	if keycode==string.byte("l") then
		skeleton.toggle_logging()
	end

	-- Debugging
	if( t_start-t_last_debug>1 ) then
		local fps = count / (t_start-t_last_debug)
		t_last_debug = t_start
		count = 0;
		print('Debugging...')
		print( string.format('%.1f FPS\n',fps) )
	end
	count = count+1;
	return true
end

function exit()
	skeleton.exit()
	for pl=1,nPlayers do
		Boxer.exit(pl)
	end
end

function process_keyinput()
	local str=getch.get();
	if #str>0 then
		local byte=string.byte(str,1);
		return byte
	end
end

entry()
while true do
	if not update() then
		exit()
		break;
	end
end