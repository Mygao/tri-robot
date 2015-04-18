local state = {}
state._NAME = ...
local Body = require'Body'
require'vcm'
local t_entry, t_update, t_exit
local min_pan, max_pan, mid_pan, mag_sweep
local t_sweep, ph, forward
local min, max = math.min, math.max

-- Sync mesh parameters
local function update_pan_params()
	-- Necessary variables
	mag_sweep, t_sweep = unpack(vcm.get_mesh0_sweep())
	-- Some simple safety checks
	mag_sweep = min(max(mag_sweep, 10 * DEG_TO_RAD), math.pi)
	t_sweep = min(max(t_sweep, 1), 20)
	-- Convenience variables
	min_pan = -mag_sweep/2
  max_pan = mag_sweep/2
  mid_pan = 0
end

function state.entry()
--  print(state._NAME..' Entry' ) 

  -- Update the time of entry
  local t_entry_prev = t_entry -- When entry was previously called
  t_entry = Body.get_time()
  t_update = t_entry
  
  -- Grab the updated pan paramters
  update_pan_params()
  
  -- Ascertain the phase, from the current position of the lidar
	if type(forward)~='boolean' or type(ph)~='number' then
  	local rad = Body.get_lidar_position()
		-- Take a given radian and back convert to find the current phase
		-- Direction is the side of the mid point, as a boolean (forward is true)
		-- Dir: forward is true, backward is false
		rad = math.max(math.min(rad, max_pan), min_pan)
  	ph, forward = (rad - min_pan) / mag_sweep, rad>mid_pan
		-- Check if we are *way* out of phase
		if ph>1.1 or ph<.1 then print('LIDAR WAY OUT OF PHASE') end
	end

	-- Torque enable
	Body.set_lidar_torque_enable(1)

end

function state.update()
  --print(state._NAME..' Update' )
  -- Get the time of update
  local t = Body.get_time()
	local dt = t - t_update
	t_update = t
	
  -- Update the phase of the pan
	local is_forward = (forward and ph<1) or ph<=0
	ph = ph + (is_forward and 1 or -1) * (dt/t_sweep * mag_sweep)
	ph = math.max(math.min(ph, 1), 0)

  -- Set the desired angle of the lidar tilt
  if Config.use_single_scan then
	  Body.set_lidar_command_position(0)
  else
	  Body.set_lidar_command_position(min_pan + ph * mag_sweep)
	end
	
	-- We are switching directions, so emit an event
	if forward ~= is_forward then
		forward = is_forward
		ph = ph > 0.5 and 1 or 0
		return'switch'
	end
	
end

function state.exit()
--  print(state._NAME..' Exit' )
end

return state
