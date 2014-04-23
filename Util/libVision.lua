-- libDetect
-- (c) 2014 Stephen McGill
-- General Detection methods
local libVision = {}
local torch  = require'torch'

function libDetect.yuyv2labelA(yuyv_t, labelA, w, h)
  -- Resize the labelA image if needed
  labelA:resizeAs(torch.ByteTensor(w/2,h/2))
  -- Access the data with the FFI
  local y, lA, yuyv = 
    yuyv_t:reshape(h/2,w,4):sub(1,-1,1,w/2):select(3,1):cdata(),
    labelA:data(),
    yuyv_t:data()
  -- Counters and Bounds
  local na, nb, s, idx, i = 
    tonumber(y.size[0])-1,
    tonumber(y.size[1])-1,
    tonumber(y.stride[0]),
    tonumber(y.storageOffset),
    0
  -- Temporary variables for the loop
  local y6,u6,v6,index,cdt
  for a=0,na do
    for b=0,nb do
      y6, u6, v6 =
        rshift(yuyv[idx], 2),
        band(yuyv[idx+1],0xFC),
        band(yuyv[idx+2],0xFC)
      index = bor( y6, lshift(u6,4), lshift(v6,10) )
      cdt = lut[index]
      lA[i] = cdt
      -- Stride to next, assume 4
      idx = idx + 4
      i = i + 1
    end
    -- stride to next
    idx = idx + s
  end
  -- Need not return anything, since we are given the labelA holder
end

return libDetect
