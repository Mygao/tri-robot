-- libPlan
-- (c) 2014 Stephen McGill
-- Plan a path with the arm
local libPlan = {}
local torch  = require'torch'
torch.Tensor = torch.DoubleTensor
local vector = require'vector'
local q = require'quaternion'
local carray = require 'carray'
local util = require 'util'
local T = require'libTransform'

-- TODO List for the planner
-- TODO: Check some metric of feasibility
-- TODO: Check the FK of the goal so that we are not in the ground, etc.
-- TODO: Check if we must pass through the x,y=0,0
-- to change the orientation through the singularity
-- TODO: Handle goal of transform or just position
-- Just position disables orientation checking

-- Plan a direct path using
-- a straight line
-- res_pos: resolution in meters
-- res_ang: resolution in radians
-- use_safe_inverse: Adjust for pseudo roll?
local line_path_stack = function(self, qArm, trGoal, res_pos, res_ang, use_safe_inverse)
	res_pos = res_pos or 0.005
	res_ang = res_ang or 1*DEG_TO_RAD
	local K = self.K
	-- If goal is position vector, then skip check
	local skip_angles = type(trGoal[1])=='number'
	-- Save the goal
	local qGoal, posGoal, quatGoal, is_reach_back
	if skip_angles==true then
		posGoal = trGoal
		qGoal, is_reach_back = K.inverse_arm_position(posGoal,qArm)
	else
		-- Must also fix the rotation matrix, else the yaw will not be correct!
		qGoal, is_reach_back = K.inverse_arm(trGoal,qArm,use_safe_inverse)
	end
	--
	qGoal = util.clamp_vector(qGoal,self.min_q,self.max_q)
	--
	local fkGoal = K.forward_arm(qGoal)
	local fkArm  = K.forward_arm(qArm)
	if skip_angles==true then
		posArm = vector.new{fkArm[1][4],fkArm[2][4],fkArm[3][4]}
	else
		quatGoal, posGoal = T.to_quaternion(fkGoal)
		quatArm, posArm   = T.to_quaternion(fkArm)
	end
	--
	local nSteps
	local dPos = posGoal - posArm
	local distance = vector.norm(dPos)
	local nSteps_pos = math.ceil(distance / res_pos)
	if skip_angles==true then
		nSteps = nSteps_pos
	else
		local quatDist = quatArm - quatGoal
		local nSteps_ang = math.ceil(math.abs(quatDist) / res_ang)
		nSteps = math.max(nSteps_pos,nSteps_ang)
	end
	--
	local inv_nSteps = 1 / nSteps
	--local dTransBack = T.trans(unpack(dPos/-nSteps))
	local ddp = dPos/-nSteps
	-- Form the precomputed stack
	local qStack = {}
	local cur_qArm, cur_posArm = vector.copy(qGoal), vector.copy(posGoal)
	--local cur_trArm = trGoal
	--local cur_quatArm = quatArm
	for i=nSteps,1,-1 do
		cur_posArm = cur_posArm + ddp
		if skip_angles==true then
			cur_qArm = K.inverse_arm_position(cur_posArm,cur_qArm)
		else
			local qSlerp = q.slerp( quatArm, quatGoal, i*inv_nSteps )
			local trStep = T.from_quaternion( qSlerp, cur_posArm )
			cur_qArm = K.inverse_arm( trStep, cur_qArm )
		end
		--[[
		local trWaypoint = dTransBack * cur_trArm
		local qSlerp = q.slerp(quatArm,quatGoal,i*inv_nSteps)
		local trStep = T.from_quaternion(
			qSlerp,
			{trWaypoint[1][4],trWaypoint[2][4],trWaypoint[3][4]}
		)
		cur_qArm = K.inverse_arm(trStep,cur_qArm)
		cur_trArm = trStep
		--]]
		table.insert(qStack,cur_qArm)
	end
	-- We return the stack and the final joint configuarion
	return qStack, qGoal
end

-- This should have exponential approach properties...
local line_path_iter = function(self, qArm, trGoal, res_pos, res_ang, use_safe_inverse)
	res_pos = res_pos or 0.005
	res_ang = res_ang or 1*DEG_TO_RAD
	local K = self.K
	-- If goal is position vector, then skip check
	local skip_angles = type(trGoal[1])=='number'
	-- Save the goal
	local qGoal, posGoal, quatGoal, is_reach_back
	if skip_angles==true then
		posGoal = trGoal
		qGoal, is_reach_back = K.inverse_arm_position(posGoal,qArm)
	else
		-- Must also fix the rotation matrix, else the yaw will not be correct!
		qGoal, is_reach_back = K.inverse_arm(trGoal,qArm,use_safe_inverse)
	end
	--
	qGoal = util.clamp_vector(qGoal,self.min_q,self.max_q)
	--
	local fkGoal = K.forward_arm(qGoal)
	if skip_angles==false then
		quatGoal, posGoal = T.to_quaternion(fkGoal)
		vector.new(posGoal)
	end
	-- TODO: Add failure detection; if no dist/ang changes in a while
	-- We return the iterator and the final joint configuarion
	return function(cur_qArm)
		local cur_trArm = K.forward_arm(cur_qArm)
		local trStep, dAng, dAxis, quatArm, posArm
		if skip_angles==true then
			posArm = {cur_trArm[1][4],cur_trArm[2][4],cur_trArm[3][4]}
		else
			quatArm, posArm = T.to_quaternion(cur_trArm)
			dAng, dAxis = q.diff(quatArm,quatGoal)
		end
		--
		local dPos = posGoal - posArm
		local distance = vector.norm(dPos)
		if distance<res_pos then
			-- If both within tolerance, then we are done
			if skip_angles==true or math.abs(dAng)<res_ang then return end
			-- Else, just rotate in place
			local qSlerp = q.slerp(quatArm,quatGoal,res_ang/dAng)
			trStep = T.from_quaternion(qSlerp,posGoal)
		elseif skip_angles==true or math.abs(dAng)<res_ang then
			-- Just translation
			local ddpos = (res_pos / distance) * dPos
			if skip_angles==true then
				return K.inverse_arm_position(ddpos+posArm, cur_qArm)
			end
			trStep = T.trans(unpack(ddpos)) * cur_trArm
		else
			-- Both translation and rotation
			trStep = T.from_quaternion(
				q.slerp(quatArm,quatGoal,res_ang/dAng),
				dPos*res_pos/distance + posArm
			)
		end
		return K.inverse_arm(trStep, cur_qArm)
	end, qGoal
end

local joint_path_stack = function(self, qArm, qGoal, res_q)
	res_q = res_q or 2*DEG_TO_RAD
	qGoal = util.clamp_vector(qGoal,self.min_q,self.max_q)
	--
	local dq = qGoal - qArm
	local distance = vector.norm(dq)
	local nSteps = math.ceil(distance / res_q)
	local ddq = dq / nSteps
	-- Form the precomputed stack
	local qStack = {}
	for i=nSteps,1,-1 do table.insert(qStack,qArm + i*ddq) end
	-- We return the stack and the final joint configuarion
	return qStack
end

local joint_path_iter = function(self, qGoal, res_q)
	res_q = res_q or 2*DEG_TO_RAD
	qGoal = util.clamp_vector(qGoal,self.min_q,self.max_q)
	return function(cur_qArm)
		local dq = qGoal - cur_qArm
		local distance = vector.norm(dq)
		local ddq = res_q / distance * dq
		if distance<res_q then return end
		return cur_qArm + ddq
	end

end

libPlan.new_planner = function(kinematics, min_q, max_q)
	local planner = {}
	planner.K = kinematics
	planner.min_q = min_q
	planner.max_q = max_q
	--
	planner.line_stack = line_path_stack
	planner.line_iter = line_path_iter
	--
	planner.joint_stack = joint_path_stack
	planner.joint_iter = joint_path_iter
	return planner
end

return libPlan
