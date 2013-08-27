module(..., package.seeall);

local Body = require('Body')
local boxercm = require('boxercm')
local walk = require('walk')
local vector = require('vector')

t0 = 0;
timeout = 5;
qL = boxercm.get_body_qLArm();
qR = boxercm.get_body_qRArm();
rpy = boxercm.get_body_rpy();

function entry()
  print("Body FSM:".._NAME.." entry");
  Motion.sm:add_event('walk');
  t0 = Body.get_time();
end

function update()
  local t = Body.get_time();

  walk.start()

  -- Check if there is a punch activated
  qL = boxercm.get_body_qLArm();
  qR = boxercm.get_body_qRArm();
  rpy = boxercm.get_body_rpy();

  -- Add the override
  walk.upper_body_override(qL, qR, rpy);

  if( boxercm.get_body_enabled() == 0 ) then
    print('Boxing disabled!')
    return "disabled";
  end

end

function exit()
  walk.upper_body_override_off()
end