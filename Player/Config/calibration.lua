module(..., package.seeall);

---------------------------------------------
-- Automatically generated calibration data
---------------------------------------------
cal={}

--Initial values for each robots

cal["betty"]={
  servoBias={0,0,0,0,0,0, 0,0,0,0,0,0},
  footXComp = 0,
  footYComp = 0,
  kickXComp = 0,
  headPitchComp = 0,
  armBias={0,0,0,0,0,0},
  pid = 0,
};

cal["linus"]={
  servoBias={0,0,0,0,0,0, 0,0,0,0,0,0},
  footXComp = 0,
  footYComp = 0,
  kickXComp = 0,
  headPitchComp = 0,
  armBias={0,0,0,0,0,0},
  pid = 1, --NEW FIRMWARE
};

cal["lucy"]={
  servoBias={0,0,0,0,0,0, 0,0,0,0,0,0},
  footXComp = 0,
  footYComp = 0,
  kickXComp = 0,
  headPitchComp = 0,
  armBias={0,0,0,0,0,0},
  pid = 1, --NEW FIRMWARE
};

cal["scarface"]={
  servoBias={0,0,0,0,0,0, 0,0,0,0,0,0},
  footXComp = 0,
  footYComp = 0,
  kickXComp = 0,
  headPitchComp = 0,
  armBias={0,0,0,0,0,0},
  pid = 0,
};

cal["felix"]={
  servoBias={0,0,0,0,0,0, 0,0,0,0,0,0},
  footXComp = 0,
  footYComp = 0,
  kickXComp = 0,
  headPitchComp = 4*math.pi/180;
  armBias={0,0,0,0,0,0},
  pid = 1, --NEW FIRMWARE
};

cal["hokie"]={
  servoBias={0,0,0,0,0,0, 0,0,0,0,0,0},
  footXComp = 0,
  footYComp = 0,
  kickXComp = 0,
  headPitchComp = 0;
  armBias={0,12*math.pi/180,0,0,-6*math.pi/180,0},
  pid = 1, --NEW FIRMWARE
};
------------------------------------------------------------
--Auto-appended calibration settings
------------------------------------------------------------

-- Updated date: Mon Apr  9 07:28:15 2012
cal["betty"].servoBias={0,0,2,-6,-1,0,0,0,-3,-1,-3,0,};

-- Updated date: Sun Apr 15 20:46:52 2012
cal["linus"].servoBias={3,1,2,1,1,-3,-8,3,-13,-4,1,-5,};
cal["linus"].footXComp=-0.003;
cal["linus"].kickXComp=0.000;

-- Updated date: Tue Apr 17 01:23:40 2012
cal["lucy"].servoBias={1,10,-18,20,24,7,-43,-4,10,0,6,0,};
cal["lucy"].footXComp=-0.003;
cal["lucy"].kickXComp=0.005;

-- Updated date: Mon Apr 16 18:28:20 2012
cal["betty"].servoBias={0,0,2,-6,-1,0,0,3,-3,-1,-3,-2,};
cal["betty"].footXComp=0.006;
cal["betty"].kickXComp=0.005;

-- Updated date: Mon Apr 16 23:36:32 2012
cal["scarface"].servoBias={0,0,7,0,0,0,0,0,-7,-9,-4,0,};
cal["scarface"].footXComp=0.002;
cal["scarface"].kickXComp=0.000;

-- Updated date: Wed Apr 18 12:26:58 2012
cal["scarface"].servoBias={0,0,7,0,0,0,0,0,-7,-9,-4,0,};
cal["scarface"].footXComp=0.002;
cal["scarface"].kickXComp=0.005;

-- Updated date: Wed Apr 18 23:55:59 2012
cal["lucy"].servoBias={19,3,4,20,19,10,-15,11,-20,0,6,6,};
cal["lucy"].footXComp=0.006;
cal["lucy"].kickXComp=0.005;

-- Updated date: Thu Apr 19 21:39:44 2012
cal["lucy"].servoBias={19,3,4,20,19,10,-15,11,-20,0,6,6,};
cal["lucy"].footXComp=0.006;
cal["lucy"].kickXComp=0.005;

-- Updated date: Fri Apr 20 00:00:29 2012
cal["linus"].servoBias={3,1,2,1,1,-3,-8,3,-13,-4,1,-5,};
cal["linus"].footXComp=-0.003;
cal["linus"].kickXComp=0.000;

-- Updated date: Fri Apr 20 21:12:24 2012
cal["lucy"].servoBias={19,3,10,20,19,22,-15,11,-20,0,6,6,};
cal["lucy"].footXComp=0.006;
cal["lucy"].kickXComp=0.005;

-- Updated date: Fri Apr 20 21:14:31 2012
cal["lucy"].servoBias={19,-22,10,20,19,-1,-15,11,-20,0,6,6,};
cal["lucy"].footXComp=0.006;
cal["lucy"].kickXComp=0.005;

-- Updated date: Fri Apr 20 21:16:10 2012
cal["lucy"].servoBias={19,-22,10,20,19,-1,-15,11,-20,0,6,6,};
cal["lucy"].footXComp=0.006;
cal["lucy"].kickXComp=0.005;

--AFTER LEG SWAP WITH LUCY
-- Updated date: Mon Apr 23 22:03:46 2012
cal["linus"].servoBias={3,1,43,1,-12,-17,-8,-5,-13,-4,1,-5,};
cal["linus"].footXComp=0.012;
cal["linus"].kickXComp=0.005;

-- Updated date: Sat May  5 09:56:25 2012
cal["linus"].servoBias={3,1,43,1,-14,-31,-8,-5,-13,-4,1,0,};
cal["linus"].footXComp=0.006;
cal["linus"].kickXComp=0.005;

-- Updated date: Sat May  5 21:53:24 2012
cal["scarface"].servoBias={0,0,7,0,0,0,0,0,-7,-9,-4,0,};
cal["scarface"].footXComp=-0.003;
cal["scarface"].kickXComp=0.010;

-- Updated date: Sat May  5 22:07:10 2012
cal["scarface"].servoBias={0,0,7,0,0,0,0,0,-7,-9,-4,2,};
cal["scarface"].footXComp=-0.003;
cal["scarface"].kickXComp=0.010;

-- Updated date: Sat May  5 22:28:03 2012
cal["felix"].servoBias={11,-11,0,0,0,0,-9,4,0,0,-6,12,};
cal["felix"].footXComp=-0.002;
cal["felix"].kickXComp=0.000;

-- Updated date: Sat May  5 22:35:53 2012
cal["felix"].servoBias={11,-11,0,0,0,0,-9,4,0,0,-6,12,};
cal["felix"].footXComp=0.001;
cal["felix"].kickXComp=0.005;

-- Updated date: Sat May  5 22:50:50 2012
cal["felix"].servoBias={11,1,0,0,0,0,-9,10,0,0,-6,15,};
cal["felix"].footXComp=0.001;
cal["felix"].kickXComp=0.005;


-- Updated date: Sun May  6 12:03:01 2012
cal["hokie"].servoBias={0,0,0,0,0,0,0,0,0,0,0,0,};
cal["hokie"].footXComp=0.000;
cal["hokie"].kickXComp=0.000;

-- Updated date: Sun May  6 14:20:12 2012
cal["hokie"].servoBias={0,0,0,25,0,-26,0,0,0,0,0,2,};
cal["hokie"].footXComp=0.000;
cal["hokie"].kickXComp=0.000;

-- Updated date: Sun May  6 14:23:18 2012
cal["hokie"].servoBias={0,-14,0,25,0,-26,0,8,0,0,0,2,};
cal["hokie"].footXComp=0.010;
cal["hokie"].kickXComp=0.000;

-- Updated date: Sun May  6 14:26:23 2012
cal["hokie"].servoBias={0,-14,0,25,0,-26,0,10,0,0,0,2,};
cal["hokie"].footXComp=0.010;
cal["hokie"].kickXComp=0.000;

-- Updated date: Sun May  6 14:53:11 2012
cal["hokie"].servoBias={0,-13,-64,25,0,-26,0,-11,78,0,0,2,};
cal["hokie"].footXComp=0.006;
cal["hokie"].kickXComp=0.000;

-- Updated date: Sun May  6 16:55:53 2012
cal["hokie"].servoBias={0,-13,-48,26,0,-26,0,-3,66,-33,0,2,};
cal["hokie"].footXComp=0.006;
cal["hokie"].kickXComp=0.000;
