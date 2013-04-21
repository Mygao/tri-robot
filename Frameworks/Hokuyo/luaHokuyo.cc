#include "luaHokuyo.h"
#include "HokuyoCircularHardware.hh"
#include "Timer.hh"
#include <string>
#include <vector>
#include "ErrorMessage.hh"
#include <stdlib.h>


#include <iostream>

using namespace std;
using namespace Upenn;


#define HOKUYO_DEF_DEVICE "/dev/ttyACM0"

//SCAN_NAME is used to determine the scanType and scanSkip values
//See below for details

#define SCAN_NAME "range"
//#define SCAN_NAME "top_urg_range+intensity"
//#define SCAN_NAME "range+intensity1+AGC1"


enum { HOKUYO_TYPE_UTM,
       HOKUYO_TYPE_UBG
     };

HokuyoCircularHardware * dev = NULL;
LidarScan lidarScan;

static int lua_hokuyo_shutdown(lua_State *L) {
  PRINT_INFO("exiting..\n");
  if (dev)
  { 
    PRINT_INFO("Stopping thread\n");
    if (dev->StopThread())
    {
      luaL_error(L, "could not stop thread\n");
    }

    PRINT_INFO("Stopping device\n");
    if (dev->StopDevice())
    {
      luaL_error(L, "could not stop device\n");
    }

    dev->Disconnect();
    delete dev;
  }
  exit(0);
  return 1;
}

static int lua_hokuyo_open(lua_State* L) {
  string address(luaL_checkstring(L, 1));
  if (address.length() < 1) 
    address = string(HOKUYO_DEF_DEVICE);

  string lidarSerial(luaL_checkstring(L, 2));
  if (lidarSerial.length() < 1)
    luaL_error(L, "LIDAR serial not defined");

  string id = string();

  char * lidar0Type = getenv("LIDAR0_TYPE");
//  char * lidar1Type = getenv("LIDAR1_TYPE");


  //default to HOKUYO_UTM
  if (!lidar0Type)
    lidar0Type = (char*)"HOKUYO_UTM";

//  if (!lidar1Type)
//    lidar1Type = (char*)"HOKUYO_UTM";


  int nPoints = 0;
//  if (argc >=4)
//    nPoints = strtol(argv[3],NULL,10);
  
  const int numBuffers=50;      //number of buffers to be used in the circular buffer
  const int bufferSize = HOKUYO_MAX_DATA_LENGTH;
  int baudRate=115200;            //communication baud rate (does not matter for USB connection)
  dev = new HokuyoCircularHardware(bufferSize,numBuffers); //create an instance of HokuyoCircular

  PRINT_INFO("Connecting to device "<< address <<"\n");
  if (dev->Connect(address,baudRate))   //args: device name, baud rate
  {
    luaL_error(L, "could not connect\n");
    return -1;
  }

  string lidarTypeStr;
  int lidarType;
  string serial = dev->GetSerial();
  PRINT_INFO("Sensor's serial number is "<<serial<<"\n");

  if (id.empty() || id.compare("-1") == 0)
  {
//    char * lidar0serial = getenv("LIDAR0_SERIAL");
//    char * lidar1serial = getenv("LIDAR1_SERIAL");

//    if ( !lidar0serial || !lidar1serial)
//    {
//      luaL_error(L, "LIDAR0_SERIAL and/or LIDAR1_SERIAL are not defined\n");
//      return -1;
//    }

    if (serial.compare(lidarSerial) == 0)
    {
      id = string("0");
      lidarTypeStr = string(lidar0Type);
    }
//    else if (serial.compare(lidar1serial) == 0)
//    {
//      id = string("1");
//      lidarTypeStr = string(lidar1Type);
//    }
    else
    {
      luaL_error(L, "lidar id is not defined and current serial (\" %s\") does not match neither LIDAR0_SERIAL nor LIDAR1_SERIAL\n", serial.c_str());
      return -1;
    }
    PRINT_INFO("Sensor identified as LIDAR"<<id<<"\n");
  }

  if (lidarTypeStr.compare("HOKUYO_UTM") == 0)
    lidarType = HOKUYO_TYPE_UTM;
  else if (lidarTypeStr.compare("HOKUYO_UBG") == 0)
    lidarType = HOKUYO_TYPE_UBG;
  else
  {
    lidarType = HOKUYO_TYPE_UTM;
  }

  int maxPoints;
  switch (lidarType)
  {
    case HOKUYO_TYPE_UTM:
      maxPoints = 1081;
      break; 
    case HOKUYO_TYPE_UBG:
      maxPoints = 769;
      break;
    default:
      luaL_error(L, "unknown sensor type: \" %d\"\n", lidarType);
      return -1;
  }

  if (nPoints ==0)
    nPoints = maxPoints;
  else if (nPoints > maxPoints)
  {
    luaL_error(L, "nPoints is larger than maxPoints : \" %d \" > \" %d \"\n", nPoints, maxPoints);
    return -1;
  }

  PRINT_INFO("Number of points in scan = " << nPoints << "\n");

  int scanStart=0;      //start of the scan
  int scanEnd=nPoints -1;//1080;      //end of the scan
  int scanSkip=1;       
  int encoding=HOKUYO_3DIGITS; 
  int scanType;                
  char scanName[128];        //name of the scan - see Hokuyo.hh for allowed types
  strcpy(scanName,SCAN_NAME); 

  int sensorType= dev->GetSensorType();
  string firmware = dev->GetFirmware();
  PRINT_INFO("firmware: "<<firmware<<"\n");
  int newSkip;

  //get the special skip value (if needed) and scan type, depending on the scanName and sensor type
  if (dev->GetScanTypeAndSkipFromName(sensorType, scanName, &newSkip, &scanType)){
    luaL_error(L, "Error getting the scan parameters\n");
    exit(1);
  }

  if (newSkip!=1){            //this means that a special value for skip must be used in order to request
    scanSkip=newSkip;         //a special scan from 04LX. Otherwise, just keep the above specified value of 
  }                           //skip


  //start the thread, so that the UpdateFunction will be called continously
  PRINT_INFO("Starting thread\n");
  if (dev->StartThread())
  {
    luaL_error(L, "could not start thread\n");
    return -1;
  }


  //set the scan parameters
  if (dev->SetScanParams(scanName,scanStart, scanEnd, scanSkip, encoding, scanType)){
    PRINT_INFO("Error setting the scan parameters\n");
    exit(1);
  }

  //fill the lidarScan static values
  lidarScan.ranges.size = nPoints;
  lidarScan.ranges.data = new float[lidarScan.ranges.size];
  lidarScan.startAngle  = -135.0/180.0*M_PI;;
  lidarScan.stopAngle   = 135.0/180.0*M_PI;;
  lidarScan.angleStep   = 0.25/180.0*M_PI;
  lidarScan.counter     = 0;
  lidarScan.id          = 0;

  Timer scanTimer;
  scanTimer.Tic();
  int cntr =0;

  return 1;
}

static int lua_hokuyo_update(lua_State *L) {

  double timeout_sec = 0.1;
  double time_stamp;

  vector< vector<unsigned int> > values;
  vector<double> timeStamps;

  if (dev->GetValues(values,timeStamps,timeout_sec) == 0)
  {
    int numPackets = values.size();
    //printf("num packets = %d\n",numPackets);
    for (int j=0; j<numPackets; j++)
    {
      time_stamp = timeStamps[j];
      
      //copy ranges
      vector<unsigned int> & ranges = values[j];
      
      //fill the LidarScan packet
      lidarScan.startTime = lidarScan.stopTime = time_stamp;
      lidarScan.counter++;
      
      float * rangesF = lidarScan.ranges.data;
      for (unsigned int jj=0;jj<lidarScan.ranges.size; jj++)
        *rangesF++ = (float)ranges[jj]*0.001;

    }
  }

  else
  {
    luaL_error(L, "could not get values (timeout)\n");
  }

  return 1;
}

static int lua_hokuyo_retrieve(lua_State *L) {
  lua_createtable(L, 0, 1);

  lua_pushstring(L, "counter");
  lua_pushinteger(L, lidarScan.counter);
  lua_settable(L, -3);

  lua_pushstring(L, "id");
  lua_pushinteger(L, lidarScan.id);
  lua_settable(L, -3);

  lua_pushstring(L, "ranges");
  lua_pushlightuserdata(L, (void *)lidarScan.ranges.data);
  lua_settable(L, -3);

  lua_pushstring(L, "range_size");
  lua_pushinteger(L, lidarScan.ranges.size);
  lua_settable(L, -3);
  
  lua_pushstring(L, "float_size");
  lua_pushinteger(L, sizeof(float));
  lua_settable(L, -3);
 
//  lua_createtable(L, lidarScan.ranges.size, 0);
//  for (int i = 0; i < lidarScan.ranges.size; i++) {
//    lua_pushnumber(L, lidarScan.ranges.data[i]);
//    lua_rawseti(L, -2, i+1);
//  }
//  lua_settable(L, -3);

  lua_pushstring(L, "startAngle");
  lua_pushnumber(L, lidarScan.startAngle);
  lua_settable(L, -3);

  lua_pushstring(L, "stopAngle");
  lua_pushnumber(L, lidarScan.stopAngle);
  lua_settable(L, -3);

  lua_pushstring(L, "angleStep");
  lua_pushnumber(L, lidarScan.angleStep);
  lua_settable(L, -3);

  lua_pushstring(L, "startTime");
  lua_pushnumber(L, lidarScan.startTime);
  lua_settable(L, -3);

  lua_pushstring(L, "stopTime");
  lua_pushnumber(L, lidarScan.stopTime);
  lua_settable(L, -3);

  return 1;
}

static const luaL_Reg hokuyo_lib [] = {
  {"open", lua_hokuyo_open},
  {"update", lua_hokuyo_update},
  {"retrieve", lua_hokuyo_retrieve},
  {"shutdown", lua_hokuyo_shutdown}, 
  {NULL, NULL}
};

int luaopen_Hokuyo(lua_State *L) {
#if LUA_VERSION_NUM == 502
  luaL_newlib(L, hokuyo_lib);
#else
  luaL_register(L, "Hokuyo", hokuyo_lib);
#endif

  return 1;
}

