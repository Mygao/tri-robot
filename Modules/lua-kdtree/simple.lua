#!/usr/bin/env lua5.1
kdtree = require'kdtree'
kd = kdtree.create(2)
kd:insert{0,0}
kd:insert{0.981577,1.000000}
kd:insert{0.065534, -0.56208162734382}
kd:insert{1,1}
kd:insert{1,1}
kd:insert{0,0}

print(unpack(kd:nearest({1,1})[1]))
print(unpack(kd:nearest({0,0})[1]))