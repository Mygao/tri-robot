#ifndef THOROP7_KINEMATICS_H_
#define THOROP7_KINEMATICS_H_

#include "Transform.h"
#include <stdio.h>
#include <math.h>
#include <vector>

enum {LEG_LEFT = 0, LEG_RIGHT = 1};
enum {ARM_LEFT = 0, ARM_RIGHT = 1};

const double PI = 2*asin(1);
const double SQRT2 = sqrt(2);

//THOR-OP values, based on robotis document, and double-checked with actual robot

const double neckOffsetZ = .117;
const double neckOffsetX = 0;


//ORIGIN is at the mk1 waist position
//which is 111mm higher than mk2 waist position
//then the shoulder offset Z is the same (165mm)

const double originOffsetZ = 0.111;
const double shoulderOffsetX = 0;    
const double shoulderOffsetY = 0.234; //the same
const double shoulderOffsetZ = 0.165; //mk1 value, used for calculation
const double shoulderOffsetZ2 = 0.276; //mk2 value, for reference
const double elbowOffsetX =   .030; 

/*
const double upperArmLength = .246; //mk1 value
const double lowerArmLength = .250; //mk1 longarm

const double upperArmLength = .281; //Elongated mk1 value
const double lowerArmLength = .298; //Elongated mk1 value

*/

//const double upperArmLength = .261; //mk2 stock value
//const double lowerArmLength = .252;

const double upperArmLength = .281; //Elongated mk1 value
const double lowerArmLength = .298; //Elongated mk1 value




const double handOffsetX = 0.310; //mk2 value
const double handOffsetY = 0;
const double handOffsetZ = 0; 

//Total reach: mk1: 246+250+230 = 72.6cm
//						 mk2: 261+252+310 = 82.3cm
//	 elongated mk1: 281+298+150 = 72.9cm

//const double hipOffsetY = 0.072;	//mk1 value
//const double hipOffsetZ = 0.282; 	//mk1 value


const double hipOffsetX = 0;
const double hipOffsetY = 0.105;
const double hipOffsetZ = 0.291;  //virtual hipoffset (pelvis to origin)
const double hipOffsetZ2 = 0.180;  //mk2 real hipoffset(pelvis joint to waist joint)


//Total torso height (waist to shoulder)
//mk1: 165+282 = 447
//mk2: 276+180 = 456

const double thighLength = 0.30;
const double tibiaLength = 0.30;
//const double kneeOffsetX = 0.03; //only mk1 has kneeoffset
//const double footHeight = 0.118; //mk1 feet height
const double kneeOffsetX = 0.0;    //mk2 lacks kneeoffset
const double footHeight = 0.10;    //mk2 feet height

//SJ: Measured from NEW (smaller) feet
const double footToeX = 0.130; //from ankle to toe
const double footHeelX = 0.110; //from ankle to heel


//=================================================================

const double dThigh = sqrt(thighLength*thighLength+kneeOffsetX*kneeOffsetX);
const double aThigh = atan(kneeOffsetX/thighLength);
const double dTibia = sqrt(tibiaLength*tibiaLength+kneeOffsetX*kneeOffsetX);
const double aTibia = atan(kneeOffsetX/tibiaLength);

const double dUpperArm = sqrt(upperArmLength*upperArmLength+elbowOffsetX*elbowOffsetX);
const double dLowerArm = sqrt(lowerArmLength*lowerArmLength+elbowOffsetX*elbowOffsetX);
const double aUpperArm = atan(elbowOffsetX/upperArmLength);
const double aLowerArm = atan(elbowOffsetX/lowerArmLength);


//=================================================================
//Those values are used to calculate the multi-body COM of the robot

const double mUpperArm = 2.89;
const double mElbow = 0.13;
const double mLowerArm = 0.81;
const double mWrist = 0.97;
const double mPelvis = 8.0;
const double mTorso = 9.21;

const double mUpperLeg = 4.28;
const double mLowerLeg = 2.24;
const double mFoot = 1.74;

const double comUpperArmX = 0.1027;
const double comUpperArmZ = -0.008;

const double comElbowX = 0.0159;
const double comElbowZ = 0.0030;

const double comLowerArmX = 0.0464;

const double comWristX = 0.146;
const double comWristZ = -0.0039;

const double comTorsoX = -0.0208;
const double comTorsoZ = 0.1557;

const double comPelvisX = -0.0264;
const double comPelvisZ = -0.1208;


const double comUpperLegX = -0.0082;
const double comUpperLegY = 0.0211;
const double comUpperLegZ = -0.124;

const double comLowerLegX = 0.0074;
const double comLowerLegY = -0.0313;
const double comLowerLegZ = -0.1796;

const double comFootX = -0.0048;
const double comFootZ = -0.0429;



//////////////////////////////////////////////////////////////////////////
// New values for calculate the multi-body COM and ZMP of the robot
// Based on latest robotis information for THOR-OP


//Coordinate:   Y Z

/*
//robotis new masses
const double Mass[22] = {
	0.165, 1.122, 3.432, 2.464, 0.946, 1.133, // Mass of Each Right Leg Part
	0.165, 1.122, 3.432, 2.464, 0.946, 1.133, // Mass of Each Left Leg Part
	3.179, 0.13*1.1, 0.81*1.1, 1.067, // Mass of Each Right Arm Part
	3.179, 0.13*1.1, 0.81*1.1, 1.067, // Mass of Each Left Arm Part
	8.8, 10.131}; // Mass of Each Body Part
*/


const double Mass[22]={
	mUpperLeg,mLowerLeg,mFoot,0,0,0,
	mUpperLeg,mLowerLeg,mFoot,0,0,0,
	mUpperArm,mElbow,mLowerArm,mWrist,
	mUpperArm,mElbow,mLowerArm,mWrist,
	mTorso,
	mPelvis
};


const double g = 9.81;

const double MassBody[2]={
	9.21, //torso
	8.0,  //pelvis	


//Mk2 values
//	9.782 //torso
//  0.657 //Waist middle section
//  4.465 //Pelvis	
};
const double bodyCom[2][3]={
	{-0.0208,0,0.1557},	//after shoulder pitch
	{-0.0264,0,-0.1208},//after shoulder roll	
};

//Based on webots mass 
const double MassArm[7]={
	0.1,
	2.89,
	0.13, 
	0.81, 
	0.97, 
	0.1,	 
	0.1,	//gripper mass... TBD
//0,0,0,

//MK2 values
//	1.04, 0.752, 2.021, 1.161, 0.37, 0.102, 1.44	
};

const double InertiaArm[7][6]={
	{0.0000625, 0.0000625, 0.0000625, 0,0,0},
	{0.00180625, 0.00180625, 0.00180625, 0,0,0},
	{0.00008125, 0.00008125, 0.00008125, 0,0,0},
	{0.00050625,0.00050625, 0.00050625, 0,0,0},
	{0.00060625,0.00060625, 0.00060625, 0,0,0},
	{0.0000625,0.0000625,0.0000625, 0,0,0},
	{0.0000625,0.0000625,0.0000625, 0,0,0}
};



const double armLink[7][3]={
	{0,0.234,0.165}, //waist-shoulder roll 
	{0,0,0}, //shoulder pitch-shoulder roll
	{0,0,0}, //shouder roll-shoulder yaw
	{0.246,0,0.030},//shoulder yaw-elbow 
	{0.250,0,-0.030},//elbow to wrist yaw 1
	{0,0,0},//wrist yaw1 to wrist roll
	{0,0,0}//wrist roll to wrist yaw2
};
const double rarmLink0[3] = {0,-0.234,0.165};

//Com position from joint center
const double armCom[7][3]={
	{0,0,0},	//after shoulder pitch
	{0.1027,0,-0.008},//after shoulder roll
	{0.246,0,0.030}, //after shoulder yaw	
	{0.0464,0,0},//after elbow
//	{-0.2036,0,0},//after elbow	
	{-0.040,0,0}, //after wrist yaw 1
	{0,0,0}, //after wrist roll
	{0.095,0,0} //after wrist yaw 2
};


const double MassLeg[6]={
	0.165, 1.122, 3.432, 2.464, 0.946, 1.133

//MK2 values
//	1.455, 1.022, 3.394, 4.745, 1.022, 1.32
};




const double legLink[7][3]={
	{0,0.072,-0.282}, //waist-hipyaw
	{0,0,0}, //hip yaw-roll
	{0,0,0}, //hip roll-pitch
	{-0.030,0,-0.300}, //hip pitch-knee
	{0.030,0,-0.300}, //knee-ankle pitch
	{0,0,0}, //ankle pitch-ankle roll
	{0,0,-0.118}, //ankle roll - foot bottom
};


const double llegLink0[3] = {0,0.072,-0.282};
const double rlegLink0[3] = {0,-0.072,-0.282};

const double legCom[12][3]={
	//left
	{0,0,0},	//after hip yaw
	{0,0,0},	//after hip roll
	{-0.029, 0.014,-0.130},	//after hip pitch (upper leg)
	{0.031,  0.019,-0.119},	//after knee (lower leg)
	{0,0,0}, //after ankle pitch
	{0,0,-0.031}, //after ankle pitch	

	//right
	{0,0,0},	//after hip yaw
	{0,0,0},	//after hip roll
	{-0.029, -0.014,-0.130},	//after hip pitch (upper leg)
	{0.031,  -0.019,-0.119},	//after knee (lower leg)
	{0,0,0}, //after ankle pitch
	{0,0,-0.031}, //after ankle pitch	
};


const double InertiaLeg[12][6]={
	//left
	{0.000103125,0.000103125,0.000103125,0,0,0},
	{0.00070125,0.00070125,0.00070125,0,0,0},
	{0.002145,0.002145,0.002145,0,0,0},
	{0.00154,0.00154,0.00154,0,0,0},
	{0.00059125,0.00059125,0.00059125,0,0,0},
	{0.000708125,0.000708125,0.000708125,0,0,0},

	//right
	{0.000103125,0.000103125,0.000103125,0,0,0},
	{0.00070125,0.00070125,0.00070125,0,0,0},
	{0.002145,0.002145,0.002145,0,0,0},
	{0.00154,0.00154,0.00154,0,0,0},
	{0.00059125,0.00059125,0.00059125,0,0,0},
	{0.000708125,0.000708125,0.000708125,0,0,0}
};

const double comOffsetMm[22][3]={//in mm
	//RLEG
	{0,-18.8,47.8}, 
	{0,21.6,0},
	{-129.22547,-13.9106,-29.4},
	{-119.0632,-19.3734,31.3},
	{0,0,-11.2},
	{-31.49254,0.-5.3},
	//LLEG
	{0,-18.8,47.8}, //in mm?
	{0,-21.6,0},
	{-129.22547,13.9106,-29.4},
	{-119.0632,19.3734,31.3},
	{0,0,-11.2},
	{-31.49254,0.-5.3},
	//RARM
	{-22,143.3,0.0}, 
	{0,0,35.1},
	{0,46.4,0},
	{3.9,146,0},
	//LARM
	{-22,-143.3,0.0}, 
	{0,0,35.1},
	{0,-46.4,0},
	{3.9,146,0},
	//Body upper
	{-26.4,0,161.2},
	//Body lower
	{-20.8,0,155.7}
};

const double servoOffset[] = {
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0
};





///////////////////////////////////////////////////////////////////////////////////////
// COM and ZMP generation functions
///////////////////////////////////////////////////////////////////////////////////////

Transform THOROP_kinematics_forward_head(const double *q);
Transform THOROP_kinematics_forward_l_leg(const double *q);
Transform THOROP_kinematics_forward_r_leg(const double *q);
std::vector<double> THOROP_kinematics_inverse_r_leg(const Transform trLeg, double aShiftX, double aShiftY);
std::vector<double> THOROP_kinematics_inverse_l_leg(const Transform trLeg, double aShiftX, double aShiftY);

///////////////////////////////////////////////////////////////////////////////////////
// Arm FK / IK
///////////////////////////////////////////////////////////////////////////////////////



Transform THOROP_kinematics_forward_l_arm_7(const double *q, double bodyPitch, const double *qWaist,
	double handOffsetXNew, double handOffsetYNew, double handOffsetZNew);
Transform THOROP_kinematics_forward_r_arm_7(const double *q, double bodyPitch, const double *qWaist,
	double handOffsetXNew, double handOffsetYNew, double handOffsetZNew);

std::vector<double> THOROP_kinematics_inverse_r_arm_7(
	const Transform trArm, const double *qOrg, double shoulderYaw, double bodyPitch, const double *qWaist,
	double handOffsetXNew, double handOffsetYNew, double handOffsetZNew, int flip_shoulderroll);
std::vector<double> THOROP_kinematics_inverse_l_arm_7(
	const Transform trArm, const double *qOrg, double shoulderYaw, double bodyPitch, const double *qWaist,
	double handOffsetXNew, double handOffsetYNew, double handOffsetZNew, int flip_shoulderroll);

std::vector<double> THOROP_kinematics_inverse_arm(Transform trArm, std::vector<double>& qOrg, double shoulderYaw, bool flip_shoulderroll);


///////////////////////////////////////////////////////////////////////////////////////
// Wrist FK / IK
///////////////////////////////////////////////////////////////////////////////////////

//std::vector<double> THOROP_kinematics_inverse_wrist(Transform trWrist, std::vector<double>& qOrg, double shoulderYaw);

std::vector<double> THOROP_kinematics_inverse_wrist(Transform trWrist, int arm, const double *qOrg, double shoulderYaw, double bodyPitch, const double *qWaist); 

Transform THOROP_kinematics_forward_l_wrist(const double *q, double bodyPitch, const double *qWaist);
Transform THOROP_kinematics_forward_r_wrist(const double *q, double bodyPitch, const double *qWaist);

std::vector<double> THOROP_kinematics_inverse_r_wrist(const Transform trWrist, const double *qOrg, double shoulderYaw, double bodyPitch, const double *qWaist);
std::vector<double> THOROP_kinematics_inverse_l_wrist(const Transform trWrist, const double *qOrg, double shoulderYaw, double bodyPitch, const double *qWaist); 
std::vector<double> THOROP_kinematics_inverse_arm_given_wrist(Transform trArm, const double *qOrg, double bodyPitch, const double *qWaist); 



///////////////////////////////////////////////////////////////////////////////////////
// COM and ZMP generation
///////////////////////////////////////////////////////////////////////////////////////

std::vector<double> THOROP_kinematics_calculate_com_positions(
    const double *qWaist,  const double *qLArm,   const double *qRArm,
    const double *qLLeg,   const double *qRLeg,   
    double mLHand, double mRHand, double bodyPitch,
    int use_lleg, int use_rleg
    );

void THOROP_kinematics_calculate_arm_com(const double* rpyangle,  
   const double *qArm, int index,double *comxyz, double*comrpy);  

std::vector<double> THOROP_kinematics_calculate_zmp(const double *com0, const double *com1, 
		const double *com2,double dt0, double dt1);

int THOROP_kinematics_check_collision(const double *qLArm,const double *qRArm);
int THOROP_kinematics_check_collision_single(const double *qArm,int is_left);


void THOROP_kinematics_calculate_arm_torque(
	double* stall_torque,double* b_matrx,
	const double *rpyangle,	const double *qArm);

void THOROP_kinematics_calculate_arm_torque_adv(
  double* stall_torque,double* acc_torque,double* acc_torque2,const double *rpyangle,
  const double *qArm,const double *qArmVel,const double *qArmAcc,double dq);

void THOROP_kinematics_calculate_arm_jacobian(  
  double* ret, const double *qArm, const double *qWaist,const double *rpyangle, 
  double handx, double handy, double handz, int is_left);


void THOROP_kinematics_calculate_leg_torque(
	double* stall_torque,double* b_matrx,
	const double *rpyangle,	const double *qLeg,
	int isLeft, double grf, const double *support);

void THOROP_kinematics_calculate_support_leg_torque(
  double* stall_torque, double* b_matrx,
  const double *rpyangle,const double *qLeg,
  int isLeft, double grf, const double *comUpperBody);


#endif
