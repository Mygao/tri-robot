module(..., package.seeall);

local shm = require('shm');
local util = require('util');
local vector = require('vector');

-- shared properties
shared = {};
shsize = {};

nReturns = 1081;
shared.lidar = {};

shared.lidar.counter = vector.zeros(1);
shared.lidar.id = vector.zeros(1);

-- 4 bytes per return (float is 4 bytes in 64bit)
-- We will use doubles, though (double is 8 bytes in 64bit)
shared.lidar.ranges = nReturns*4;
shared.lidar.timestamp = vector.zeros(1);

--shared.lidar.intensities ;
shared.lidar.startAngle = vector.zeros(1); -- radians
shared.lidar.stopAngle = vector.zeros(1);  -- radians
shared.lidar.angleStep = vector.zeros(1);  -- radians
shared.lidar.startTime = vector.zeros(1);  -- seconds
shared.lidar.stopTime = vector.zeros(1);   -- seconds

-- Robot state
shared.imu = {};
shared.imu.timestamp = vector.zeros(3);
shared.imu.acc = vector.zeros(3);
shared.imu.gyro = vector.zeros(3); -- Just to give the rate
shared.imu.rpy = vector.zeros(3); -- Independent RPY from UKF

-- Odometry
shared.odom = {};
shared.odom.traveled = vector.zeros(3);

-- Generated Map
--mapSize = 400;
--shared.map = {};
--shared.map.omap = mapSize*mapSize;

shsize.lidar = shared.lidar.ranges + 2^16

print('Init shm for ',_NAME)
util.init_shm_segment(getfenv(), 'rcm', shared, shsize);
