local detectObstacle = {}

local ImageProc = require'ImageProc'
require'vcm'

-- Define Color
colorOrange = Config.color.orange
colorYellow = Config.color.yellow
colorCyan = Config.color.cyan
colorField = Config.color.field
colorWhite = Config.color.white

enable_obstacle_detection = Config.vision.enable_obstacle_detection or 0
use_tilted_bbox = Config.vision.use_tilted_bbox or 0

-[[
if enable_obstacle_detection>0 then
  map_div = Config.vision.obstacle.map_div
  gamma = Config.vision.obstacle.gamma
  gamma_field = Config.vision.obstacle.gamma_field
  r_sigma = Config.vision.obstacle.r_sigma
  min_r = Config.vision.obstacle.min_r
  max_r = Config.vision.obstacle.max_r
  min_j = Config.vision.obstacle.min_j
else
  map_div = 10
  gamma = 0.99
  gamma_field = 0.95
  r_sigma = 8
  min_r = 1.0
  max_r = 4.0
  min_j = 5
end
--]]

local max_gap = 1

weight=vector.zeros(6*4*map_div*map_div)
updated=vector.zeros(6*4*map_div*map_div)

function update_obstacle(v)
  pose=wcm.get_obstacle_pose()
  vGlobal = util.pose_global(v,pose)
  xindex=math.floor((vGlobal[1]+3)*map_div+0.5)
  yindex=math.floor((vGlobal[2]+2)*map_div+0.5)

  --add gaussian update
  --TODO: use correct log-odds
  sigma =  (v[1]^2+v[2]^2)/r_sigma

  for i=-3,3 do
    for j=-3,3 do
      ix=math.max(1,math.min(6*map_div,i+xindex))
      iy=math.max(1,math.min(4*map_div,j+yindex))
      w=math.exp(-(i*i+j*j)/sigma)
      index=(ix-1)*(4*map_div) + iy
      weight[index]=math.min(1,weight[index]+w)
    end
  end

end     

function update_weights()

  --Get approximate boundary of current FOV
  v1=HeadTransform.coordinatesB({1,1,0,0})
  v1=HeadTransform.projectGround(v1,0)
  r1=v1[1]^2+v1[2]^2
  angle1=math.atan2(v1[2],v1[1])
  
  v2=HeadTransform.coordinatesB({Vision.labelB.m,1,0,0})
  v2=HeadTransform.projectGround(v2,0)
  r2=v2[1]^2+v2[2]^2
  angle2=math.atan2(v2[2],v2[1])

  --midpoint in the bottom
  v3=HeadTransform.coordinatesB({Vision.labelB.m/2,Vision.labelB.n,0,0})
  v3=HeadTransform.projectGround(v3,0)
  r3=v3[1]^2+v3[2]^2

  pose=wcm.get_obstacle_pose()

  for j=1,4*map_div do     
    for i=1,6*map_div do     
      posx = i/map_div - 3
      posy = j/map_div - 2

      angle=math.atan2(posy-pose[2],posx-pose[1])-pose[3]
      r2_pos = (posy-pose[2])^2 + (posx-pose[1])^2

      within_fov = false
      if util.mod_angle(angle1-angle)>0 and 
	util.mod_angle(angle2-angle)<0 then
	--get Approx. r and angle
	r_min = r3
	r_max = (r1+r2)/2
	if r2_pos<r_max and r2_pos>r_min then
	  within_fov=true
	end
      end
      index=(i-1)*(4*map_div) + j
--TODO: use log-odds 
      if updated[index] ==0 then
        if within_fov then
          gamma_field = 0.8
          weight[index]=weight[index]*gamma_field
        else
          weight[index]=weight[index]*gamma
        end
      else
        updated[index]=0
      end
    end
  end


end

covered={}
blocked={}

local debug_msg
local function add_debug_msg(str)
  debug_msg = debug_msg..str
end

function detectObstacle.detect(labelB, HeadTransform, t)
  debug_msg = ''

  local obstacle = {}
  obstacle.detect = 0
  count=0

  if use_tilted_bbox>0 then
    tiltAngle = HeadTransform.getCameraRoll()
  else
    tiltAngle = 0
  end

  obstacleB = ImageProc.obstacles(
	Vision.labelB.data,Vision.labelB.m,Vision.labelB.n,
	colorField+colorWhite+colorOrange,tiltAngle,max_gap)

  if #obstacleB<1 then
  	add_debug_msg('No obstacles detected\n')
  	return obstacle
  end

  add_debug_msg(string.format('%d potential obstacles\n', #obstacleB))

  -- TODO: check if nObs > possible value
  obstacle.v = {}
  obstacle.width = {}
  for i=1,#obstacleB do
  	local width = obstacleB[i].width
  	local position = obstacleB[i].position
  	local bboxB = {position[1]-width/2, position[1]+width/2, 
  	  position[2]-20, position[2]}
  	local bboxA = libVision.bboxB2A(bboxB)

  	local scale = width / obstacleWidth
    v = HeadTransform.coordinatesB({position[1], position[2],0,0}, scale)
    v = HeadTransform.projectGround(v,0)  --TODO
    r = math.sqrt(v[1]^2+v[2]^2)

    obstacle.v[i] = v
    obstacle.width[i] = width
    --[[
    if r>min_r and r<max_r then 
      update_obstacle(v)
    end
    --]]
  end

  --vcm.set_obstacle_lowpoint(obstacleB)
 -- update_weights()
 -- update_shm()
end

function update_shm()
  vcm.set_obstacle_map(weight)
end