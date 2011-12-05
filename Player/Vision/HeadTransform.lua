-- SJ was here
module(..., package.seeall);

require('Config');
require('Transform');
require('vector');

tHead = Transform.eye();
tNeck = Transform.eye();
camPosition = 0;

camOffsetZ = Config.head.camOffsetZ;
pitchMin = Config.head.pitchMin;
pitchMax = Config.head.pitchMax;
yawMin = Config.head.yawMin;
yawMax = Config.head.yawMax;

cameraPos = Config.head.cameraPos;
cameraAngle = Config.head.cameraAngle;

horizonA = 1;
horizonB = 1;

-- COPIED FROM Vision
-- Initialize the Labeling
-- Don't want to require Vision if not needed
labelA = {};
-- labeled image is 1/4 the size of the original
labelA.m = Config.camera.width/2;
labelA.n = Config.camera.height/2;
nxA = labelA.m;
x0A = 0.5 * (nxA-1);
nyA = labelA.n;
y0A = 0.5 * (nyA-1);
focalA = Config.camera.focal_length/(Config.camera.focal_base/nxA);

scaleB = 4;
labelB = {};
labelB.m = labelA.m/scaleB;
labelB.n = labelA.n/scaleB;
nxB = nxA/scaleB;
x0B = 0.5 * (nxB-1);
nyB = nyA/scaleB;
y0B = 0.5 * (nyB-1);
focalB = focalA/scaleB;

print('HeadTransform LabelB size: ('..labelB.m..', '..labelB.n..')');
print('HeadTransform LabelA size: ('..labelA.m..', '..labelA.n..')');

-- OP specific
neckX    = Config.head.neckX; 
neckZ    = Config.head.neckZ; 
footX    = Config.walk.footX + Config.walk.footXComp;
supportX = Config.walk.supportX;
--TODO: use actual bodyHeight and bodyTilt using shm
bodyTilt=Config.walk.bodyTilt; --Original
bodyHeight=Config.walk.bodyHeight;

function entry()
end


<<<<<<< HEAD
function update(sel, headAngles)
  if (string.find(Config.platform.name,'OP')) then
    update_op(sel, headAngles);
	--print("Update OP HeadTransform");
  else
    update_nao(sel, headAngles);
	--print("Update Nao HeadTransform");
  end 
  update_horizon(sel,headAngles);
end


function update_nao(sel, headAngles)
=======
function update(sel,headAngles)
>>>>>>> 7fe4fd81ecc514e73ce534f98fc58e9e766f96c8
  -- cameras are 0 indexed so add one for use here
  sel = sel + 1;

  tNeck = Transform.trans(-footX,0,bodyHeight); 
  tNeck = tNeck*Transform.rotY(bodyTilt);
  tNeck = tNeck*Transform.trans(neckX,0,neckZ);
  tNeck = tNeck*Transform.rotZ(headAngles[1])*Transform.rotY(headAngles[2]);

  tHead = tNeck*Transform.trans(cameraPos[sel][1], cameraPos[sel][2], cameraPos[sel][3]);
  --Robot specific head angle bias
  tHead = tHead*Transform.rotY( pitch0 );
  tHead = tHead*Transform.rotY( cameraAngle[sel][2]);

<<<<<<< HEAD
end

-- From OP
function update_op(sel,headAngles)
  -- cameras are 0 indexed so add one for use here
  sel = sel + 1;
  tNeck = Transform.trans(-footX,0,bodyHeight); 
  tNeck = tNeck*Transform.rotY(bodyTilt);
  tNeck = tNeck*Transform.trans(neckX,0,neckZ);
  tNeck = tNeck*Transform.rotZ(headAngles[1])*Transform.rotY(headAngles[2]);
  tHead = tNeck*Transform.trans(cameraPos[sel][1], cameraPos[sel][2], cameraPos[sel][3]);
  tHead = tHead*Transform.rotY(cameraPos[sel][2]);

end

function update_horizon(sel,headAngles)
  sel = sel + 1;
  -- update horizon
  pa = headAngles[2] + cameraAngle[sel][2];
  horizonA = (labelA.n/2.0) - focalA*math.tan(pa) - 2;
  horizonA = math.min(labelA.n, math.max(math.floor(horizonA), 0));
  horizonB = (labelB.n/2.0) - focalB*math.tan(pa) - 1;
  horizonB = math.min(labelB.n, math.max(math.floor(horizonB), 0));
  --print('horizon-- pitch: '..pa..'  A: '..horizonA..'  B: '..horizonB);
=======
  -- update horizon
  pa = headAngles[2] + cameraAngle[sel][2];
  horizonA = (labelA.n/2.0) - focalA*math.tan(pa) - 2;
  horizonA = math.min(labelA.n, math.max(math.floor(horizonA), 0));
  horizonB = (labelB.n/2.0) - focalB*math.tan(pa) - 1;
  horizonB = math.min(labelB.n, math.max(math.floor(horizonB), 0));
  --print('horizon-- pitch: '..pa..'  A: '..horizonA..'  B: '..horizonB);

>>>>>>> 7fe4fd81ecc514e73ce534f98fc58e9e766f96c8
end

function exit()
end

function get_horizonA()
  return horizonA;
end

function get_horizonB()
  return horizonB;
end

function coordinatesA(c, scale)
  scale = scale or 1;
  local v = vector.new({focalA,
                       -(c[1] - x0A),
                       -(c[2] - y0A),
                       scale});
  v = tHead*v;
  v = v/v[4];
  return v;
end

function coordinatesB(c, scale)
  scale = scale or 1;
  local v = vector.new({focalB,
                        -(c[1] - x0B),
                        -(c[2] - y0B),
                        scale});
  v = tHead*v;
  v = v/v[4];
  return v;
end


function ikineCam(x, y, z, select)
  if (string.find(Config.platform.name,'OP')) then
    return ikineCam_op(x, y, z, select);
	--print("OP inverse Kinematics");
  else
    return ikineCam_nao(x, y, z, select);
	--print("Nao inverse Kinematics");
  end
end


function ikineCam_nao(x, y, z, select)
  --Bottom camera by default (cameras are 0 indexed so add 1)
  select = (select or 0) + 1;

  --Look at ground by default
  z = z or 0;

<<<<<<< HEAD
  z = z-camOffsetZ;
  local norm = math.sqrt(x^2 + y^2 + z^2);
  local yaw = math.atan2(y, x);
  local pitch = math.asin(-z/(norm + 1E-10));

  pitch = pitch - cameraAngle[select][2];
  yaw = math.min(math.max(yaw, yawMin), yawMax);
  pitch = math.min(math.max(pitch, pitchMin), pitchMax);
  return yaw, pitch;
end

-- For OP
function ikineCam_op(x, y, z, select)
  --Bottom camera by default (cameras are 0 indexed so add 1)
  select = (select or 0) + 1;
=======
  --Cancel out the neck X and Z offset 
>>>>>>> 7fe4fd81ecc514e73ce534f98fc58e9e766f96c8
  v = getNeckOffset();
  x = x-v[1]; 
  z = z-v[3]; 

<<<<<<< HEAD
  --Look at ground by default
  z = z or 0;

  z=z-v[3]; -- Les the offset

  -- IDK what this does...
  x = x-v[1];
  
=======
>>>>>>> 7fe4fd81ecc514e73ce534f98fc58e9e766f96c8
  --Cancel out body tilt angle
  v = Transform.rotY(-bodyTilt)*vector.new({x,y,z,1});
  v=v/v[4];

  x,y,z=v[1],v[2],v[3];
  local norm = math.sqrt(x^2 + y^2 + z^2);
  local yaw = math.atan2(y, x);
  local pitch = math.asin(-z/(norm + 1E-10));

  pitch = pitch - cameraAngle[select][2];
  yaw = math.min(math.max(yaw, yawMin), yawMax);
  pitch = math.min(math.max(pitch, pitchMin), pitchMax);
  return yaw, pitch;
end

function getCameraOffset() 
    local v=vector.new({0,0,0,1});
    v=tHead*v;
    v=v/v[4];
    return v;
end

function getNeckOffset()
    local v=vector.new({0,0,0,1});
    v=tNeck*v;
    v=v/v[4];
    return v;
end

--Project 3d point to level plane with some height
function projectGround(v,targetheight)

  targetheight=targetheight or 0;
  local cameraOffset=getCameraOffset();
  local vout=vector.new(v);

  --Project to plane
  if v[3]<targetheight then
        vout= cameraOffset+
           (v-cameraOffset)*(
           (cameraOffset[3]-targetheight) / (cameraOffset[3] - v[3] )
           );
  end

  --Discount body offset
  uBodyOffset = mcm.get_walk_bodyOffset();
  vout[1] = vout[1] + uBodyOffset[1];
  vout[2] = vout[2] + uBodyOffset[2];
  return vout;
end

