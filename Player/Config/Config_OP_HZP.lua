-- Bezier coefficients when Left leg is stance
alpha_R = {
  { 0.0227, 0.0339, 0.1459, 0.1236, 0.0437, 0.0262},
  { 0.0619, 0.0980, 0.3872, 0.3285, 0.1238, 0.0714},
  { -0.8481, -0.2658, -1.5419, -2.2761, -0.1923, -0.9502},
  { 0.8394, -0.1535, 2.6844, 2.1607, -0.7553, 0.5657},
  { -0.3415, 0.0742, -1.5156, -0.2534, 0.6004, 0.0341},
  { -0.0659, -0.1040, -0.4129, -0.3503, -0.1315, -0.0760},
  { -0.0115, 0.0309, 0.0562, 0.0547, 0.0347, -0.0077},
  { -0.0296, 0.0973, 0.0522, 0.0502, 0.0962, -0.0183},
  { -0.9154, -0.9324, -0.8535, -0.8606, -0.8731, -0.8250},
  { 0.5531, 0.6824, 0.6144, 0.6509, 0.7732, 0.7812},
  { 0.0129, -0.0978, -0.1147, -0.1442, -0.2484, -0.3054},
  { 0.0336, -0.0906, -0.1633, -0.1587, -0.1018, 0.0227},
};

--[[
% Rows of the above matrices indicate the following variables
ind_LHipYawPitch=1;
ind_LHipRoll=2;
ind_LHipPitch=3;
ind_LKneePitch=4;
ind_LAnklePitch=5;
ind_LAnkleRoll=6;
ind_RHipYawPitch=7;
ind_RHipRoll=8;
ind_RHipPitch=9;
ind_RKneePitch=10;
ind_RAnklePitch=11;
ind_RAnkleRoll=12;
-]]

-- Bezier coefficients when Right leg is stance
alpha_L = {
  { 0.0112, -0.0312, -0.0561, -0.0548, -0.0344, 0.0080},
  { 0.0288, -0.0972, -0.0520, -0.0504, -0.0963, 0.0191},
  { -0.9156, -0.9325, -0.8540, -0.8614, -0.8750, -0.8281},
  { 0.5520, 0.6811, 0.6128, 0.6498, 0.7713, 0.7782},
  { 0.0142, -0.0965, -0.1126, -0.1422, -0.2446, -0.2993},
  { -0.0327, 0.0915, 0.1629, 0.1591, 0.1009, -0.0235},
  { -0.0230, -0.0338, -0.1475, -0.1218, -0.0440, -0.0259},
  { -0.0627, -0.0977, -0.3914, -0.3240, -0.1245, -0.0705},
  { -0.8467, -0.2573, -1.5763, -2.2268, -0.2105, -0.9490},
  { 0.8395, -0.1659, 2.7423, 2.0947, -0.7102, 0.5737},
  { -0.3431, 0.0780, -1.5394, -0.2362, 0.5734, 0.0249},
  { 0.0668, 0.1037, 0.4174, 0.3455, 0.1323, 0.0751}, 
};

