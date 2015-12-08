dofile'../../include.lua'
-- Libraries
local unix = require 'unix'
local lD = require'libDynamixel'
local util = require'util'


if not one_chain then
  if OPERATING_SYSTEM=='darwin' then
    --[[
    right_arm = lD.new_bus('/dev/cu.usbserial-FTVTLUY0A')
    left_arm  = lD.new_bus'/dev/cu.usbserial-FTVTLUY0B'
    right_leg = lD.new_bus'/dev/cu.usbserial-FTVTLUY0C'
    left_leg  = lD.new_bus'/dev/cu.usbserial-FTVTLUY0D'
    --]]
    --chain = lD.new_bus(nil, 57600)
    chain = lD.new_bus()
  else
    right_arm = lD.new_bus('/dev/ttyUSB0')
    left_arm  = lD.new_bus'/dev/ttyUSB1'
if Config.birdwalk then
    right_leg = lD.new_bus'/dev/ttyUSB3'
    left_leg  = lD.new_bus'/dev/ttyUSB2'
else
    right_leg = lD.new_bus'/dev/ttyUSB2'
    left_leg  = lD.new_bus'/dev/ttyUSB3'
end
    chain = right_leg
  end
end

local byte_to_number = lD.byte_to_number
local nx_registers = lD.nx_registers
local mx_registers = lD.mx_registers

--local leg_regs = {'position','temperature', 'data', 'command_position', 'position_p'}
local leg_regs = {'position','current', 'data', 'command_position', 'position_p'}
--local leg_regs = {'position','current', 'data'}
--local leg_regs = {'position','temperature'}
local lleg = Config.chain.lleg
local lleg_ok = lD.check_indirect_address(lleg.m_ids, leg_regs, left_leg)
local rleg = Config.chain.rleg
local rleg_ok = lD.check_indirect_address(rleg.m_ids, leg_regs, right_leg)
print('LLeg Check', lleg_ok, unpack(lleg.m_ids))
print('RLeg Check', rleg_ok, unpack(rleg.m_ids))
----[[
if not lleg_ok then
  lD.set_indirect_address(lleg.m_ids, leg_regs, left_leg)
end
if not rleg_ok then
  lD.set_indirect_address(rleg.m_ids, leg_regs, right_leg)
end
--]]
os.exit()

local arm_regs = {'position','temperature'}
--local arm_regs = {'position','temperature', 'data', 'command_position', 'position_p'}
--[[
local larm = Config.chain.larm
local larm_ok = lD.check_indirect_address(larm.m_ids, arm_regs, left_arm)
print('LArm Check', larm_ok)
if not larm_ok then
  lD.set_indirect_address(larm.m_ids, arm_regs, left_arm)
end
--]]
----[[
local rarm = Config.chain.rarm
local rarm_ok = lD.check_indirect_address(rarm.m_ids, arm_regs, right_arm)
print('ids', unpack(rarm.m_ids))
print('RArm Check', rarm_ok)
if not rarm_ok then
  lD.set_indirect_address(rarm.m_ids, arm_regs, right_arm)
end
--]]
os.exit()

for i,m in ipairs(Config.chain.lleg) do
	local status = libDynamixel.check_indirect_address(m, left_leg)
	if status then
		local value = libDynamixel.byte_to_number[#status.parameter](unpack(status.parameter))
		print(string.format('Mode: %d',value))
		if not (value==4) then
			print('setting',m)
			libDynamixel.set_nx_mode(m,4,left_arm)
		else
			print(m,'already set!')
		end
	else
		print('MOTOR',m,'not responding')
	end
end

for i,m in ipairs({9,13}) do
	local status = libDynamixel.get_nx_mode(m,right_arm)
	if status then
		local value = libDynamixel.byte_to_number[#status.parameter](unpack(status.parameter))
		print(string.format('Mode: %d',value))
		if not (value==4) then
			print('setting',m)
			libDynamixel.set_nx_mode(m,4,right_arm)
		else
			print(m,'already set!')
		end
	else
		print('MOTOR',m,'not responding')
	end
end

