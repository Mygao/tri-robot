module(..., package.seeall);
require('vector')
--require('vcm')

-- Camera Parameters

camera = {};
camera.ncamera = 1;
camera.switchFreq = 0; --unused for OP
camera.width = 640;
camera.height = 480;
camera.x_center = 328;
camera.y_center = 248;

camera.focal_length = 533; -- in pixels
camera.focal_base = 640; -- image width used in focal length calculation

camera.auto_param = {};
camera.auto_param[1] = {key='white balance temperature, auto', val={0}};
camera.auto_param[2] = {key='power line frequency',   val={0}};
camera.auto_param[3] = {key='backlight compensation', val={0}};
camera.auto_param[4] = {key='exposure, auto',val={1}}; --1 for manual
camera.auto_param[5] = {key="exposure, auto priority",val={0}};


camera.param = {};
camera.param[1] = {key='brightness',    val={0}};
camera.param[2] = {key='contrast',      val={10}};
camera.param[3] = {key='saturation',    val={15}};
camera.param[4] = {key='gain',          val={255}};
camera.param[5] = {key='white balance temperature', val={1550}};
camera.param[6] = {key='sharpness',     val={0}};
camera.param[7] = {key='exposure (absolute)',      val={2000}};

camera.lut_file = 'field_A_morning.raw';
