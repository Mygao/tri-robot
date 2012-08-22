module(..., package.seeall)

walkSine = {}
walkSine.parameters = { 
  x_offset = 0.025, -- meters
  y_offset = 0.1,
  z_offset = -0.783,
  step_amplitude = 0.0035, --0.01, -- 0.022,
  x_swing_ratio = 0,
  y_swing_amplitude = 0.0024, --0.02, -- 0.04,
  z_swing_amplitude = 0.001, -- 0.015,
  hip_pitch_offset = 0.01, -- radians
  period_time = 0.85, --0.8, -- seconds
}

walkZMP = {}
walkZMP.parameters = {

}
