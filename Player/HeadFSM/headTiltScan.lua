local Body = require'Body'
-- TODO: Get the shm desired endpoints
-- TODO: Should these endpoints be in vcm?  Probably...
require'vcm'

local state = {}
state._NAME = 'headTiltScan'

local min_tilt, max_tilt, mid_tilt, mag_tilt
local t_entry, t_update, ph_speed, ph, forward

-- Update the parameters
local function update_tilt_params()
  -- Set up the tilt boundaries
  local e = vcm.get_head_lidar_endpoints()
  min_tilt = e[1]
  max_tilt = e[2]
  mid_tilt = (max_tilt + min_tilt) / 2
  mag_tilt = max_tilt - min_tilt
  -- Grab the desired resolution (number of columns)
  local res = vcm.get_head_lidar_mesh_resolution()[1]
  -- Complete the scan at this rate
  ph_speed = 40 / res -- 40 Hz update of the LIDAR
end

-- Take a given radian and back convert to find the durrent phase
-- Direction is the side of the mid point, as a boolean (forward is true)
-- Dir: forward is true, backward is false
-- TODO: Check for mag_tilt==0
local function radians_to_ph( rad )
  rad = math.max( math.min(rad, max_tilt), min_tilt )
  return ( rad - min_tilt ) / mag_tilt, rad>mid_tilt
end

function state.entry()
  print(state._NAME..' Entry' ) 
  -- When entry was previously called
  local t_entry_prev = t_entry
  -- Update the time of entry
  t_entry = Body.get_time()
  t_update = t_entry
  
  -- Grab the updated tilt paramters
  update_tilt_params()
  
  -- Ascertain the phase, from the current position of the lidar
  local cur_angle = Body.get_head_position()[2]
  ph, forward = radians_to_ph( cur_angle )
end

function state.update()
  --print(state._NAME..' Update' )

  -- Get the time of update
  local t = Body.get_time()
  local t_diff = t - t_update
  -- Save this at the last update time
  t_update = t
  
  -- Grab the updated tilt paramters
  update_tilt_params()
  
  -- Update the direction
  forward = (forward and ph<1) or ph<=0
  -- Update the phase of the tilt
  if forward then
    ph = ph + t_diff * ph_speed
  else
    ph = ph - t_diff * ph_speed
  end
  -- Clamp the phase to avoid crazy behavior
  ph = math.max( math.min(ph, 1), 0 )

  -- Set the desired angle of the lidar tilt
  local rad = min_tilt + ph*mag_tilt
  Body.set_head_command_position( {0, rad} )
end

function state.exit()
  print(state._NAME..' Exit' )
end

return state