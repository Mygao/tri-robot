/* 
(c) 2013 Seung Joon Yi
7 DOF
*/

#include <lua.hpp>

// For pushing/pulling torch objects
#ifdef TORCH
#include <torch/luaT.h>
#ifdef __cplusplus
extern "C"
{
#endif
#include <torch/TH/TH.h>
#ifdef __cplusplus
}
#endif
#endif

#include "THOROPKinematics.h"

/* Copied from lua_unix */
struct def_info {
  const char *name;
  double value;
};

void lua_install_constants(lua_State *L, const struct def_info constants[]) {
  int i;
  for (i = 0; constants[i].name; i++) {
    lua_pushstring(L, constants[i].name);
    lua_pushnumber(L, constants[i].value);
    lua_rawset(L, -3);
  }
}

static void lua_pushvector(lua_State *L, std::vector<double> v) {
	int n = v.size();
	lua_createtable(L, n, 0);
	for (int i = 0; i < n; i++) {
		lua_pushnumber(L, v[i]);
		lua_rawseti(L, -2, i+1);
	}
}

static std::vector<double> lua_checkvector(lua_State *L, int narg) {
	/*
	if (!lua_istable(L, narg))
	luaL_typerror(L, narg, "vector");
	*/
	if ( !lua_istable(L, narg) )
		luaL_argerror(L, narg, "vector");

#if LUA_VERSION_NUM == 502
	int n = lua_rawlen(L, narg);
#else	
	int n = lua_objlen(L, narg);
#endif
	std::vector<double> v(n);
	for (int i = 0; i < n; i++) {
		lua_rawgeti(L, narg, i+1);
		v[i] = lua_tonumber(L, -1);
		lua_pop(L, 1);
	}
	return v;
}

static void lua_pushtransform(lua_State *L, Transform t) {
	lua_createtable(L, 4, 0);
	for (int i = 0; i < 4; i++) {
		lua_createtable(L, 4, 0);
		for (int j = 0; j < 4; j++) {
			lua_pushnumber(L, t(i,j));
			lua_rawseti(L, -2, j+1);
		}
		lua_rawseti(L, -2, i+1);
	}
}

static int forward_joints(lua_State *L)
{
	/* forward kinematics to convert servo positions to joint angles */
	std::vector<double> r = lua_checkvector(L, 1);
	std::vector<double> q = THOROP_kinematics_forward_joints(&r[0]);
	lua_pushvector(L, q);
	return 1;
}

static int forward_head(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	Transform t = THOROP_kinematics_forward_head(&q[0]);
	lua_pushtransform(L, t);
	return 1;
}

/*
static int forward_l_arm(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	Transform t = THOROP_kinematics_forward_l_arm(&q[0]);
	lua_pushtransform(L, t);
	return 1;
}

static int forward_r_arm(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	Transform t = THOROP_kinematics_forward_r_arm(&q[0]);
	lua_pushtransform(L, t);
	return 1;
}
*/

static int forward_l_leg(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	Transform t = THOROP_kinematics_forward_l_leg(&q[0]);
	lua_pushvector(L, position6D(t));
	return 1;
}

static int forward_r_leg(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	Transform t = THOROP_kinematics_forward_r_leg(&q[0]);
	lua_pushvector(L, position6D(t));
	return 1;
}

/* ADDED by HEEJIN Nov.21.2014 ------------------------------------------------------*/
static int forward_l_knee(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	Transform t = THOROP_kinematics_forward_l_knee(&q[0]);
	lua_pushvector(L, position6D(t));
	return 1;
}

/* ADDED by HEEJIN Nov.21.2014 ------------------------------------------------------*/
static int forward_r_knee(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	Transform t = THOROP_kinematics_forward_r_knee(&q[0]);
	lua_pushvector(L, position6D(t));
	return 1;
}

static int l_arm_torso_7(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	double bodyPitch = luaL_optnumber(L, 2,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 3);

	//Now we can use custom hand x/y offset (for claws)
	double handOffsetXNew = luaL_optnumber(L, 4,handOffsetX);
	double handOffsetYNew = luaL_optnumber(L, 5,handOffsetY);
	double handOffsetZNew = luaL_optnumber(L, 6,handOffsetZ);
	

	Transform t = THOROP_kinematics_forward_l_arm_7(&q[0],bodyPitch,&qWaist[0],
		handOffsetXNew, handOffsetYNew, handOffsetZNew);
	lua_pushvector(L, position6D(t));
	return 1;
}

static int r_arm_torso_7(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	double bodyPitch = luaL_optnumber(L, 2,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 3);

	//Now we can use custom hand x/y offset (for claws)
	double handOffsetXNew = luaL_optnumber(L, 4,handOffsetX);
	double handOffsetYNew = luaL_optnumber(L, 5,handOffsetY);
	double handOffsetZNew = luaL_optnumber(L, 6,handOffsetZ);
	

	Transform t = THOROP_kinematics_forward_r_arm_7(&q[0],bodyPitch,&qWaist[0], 
		handOffsetXNew, handOffsetYNew, handOffsetZNew);
	lua_pushvector(L, position6D(t));
	return 1;
}

/* ADDED by HEEJIN Nov.21.2014 ------------------------------------------------------*/

static int l_arm_origins(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	double bodyPitch = luaL_optnumber(L, 2,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 3);

	double handOffsetXNew = luaL_optnumber(L, 4,handOffsetX);
	double handOffsetYNew = luaL_optnumber(L, 5,handOffsetY);
	double handOffsetZNew = luaL_optnumber(L, 6,handOffsetZ);
	int idxNew = luaL_optnumber(L, 7, 0);

	

	Transform t = THOROP_kinematics_forward_l_arm_o(&q[0],bodyPitch,&qWaist[0],
		handOffsetXNew, handOffsetYNew, handOffsetZNew, idxNew);
	lua_pushvector(L, position6D(t));
	return 1;
}

static int r_arm_origins(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	double bodyPitch = luaL_optnumber(L, 2,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 3);

	double handOffsetXNew = luaL_optnumber(L, 4,handOffsetX);
	double handOffsetYNew = luaL_optnumber(L, 5,handOffsetY);
	double handOffsetZNew = luaL_optnumber(L, 6,handOffsetZ);
	int idxNew = luaL_optnumber(L, 7,0);

	Transform t = THOROP_kinematics_forward_r_arm_o(&q[0],bodyPitch,&qWaist[0], 
		handOffsetXNew, handOffsetYNew, handOffsetZNew, idxNew);
	lua_pushvector(L, position6D(t));
	return 1;
}


static int l_leg_origins(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	int idxNew = luaL_optnumber(L,2,0);

	Transform t = THOROP_kinematics_forward_l_leg_o(&q[0], idxNew);
	lua_pushvector(L, position6D(t));
	return 1;
}


static int r_leg_origins(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	int idxNew = luaL_optnumber(L,2,0);

	Transform t = THOROP_kinematics_forward_r_leg_o(&q[0], idxNew);
	lua_pushvector(L, position6D(t));
	return 1;
}

/* --------------------------------------------------------------------------------- */

static int l_wrist_torso(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	double bodyPitch = luaL_optnumber(L, 2,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 3);	

	Transform t = THOROP_kinematics_forward_l_wrist(&q[0],bodyPitch,&qWaist[0]);
	lua_pushvector(L, position6D(t));	
	return 1;
}

static int r_wrist_torso(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	double bodyPitch = luaL_optnumber(L, 2,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 3);
	

	Transform t = THOROP_kinematics_forward_r_wrist(&q[0],bodyPitch,&qWaist[0]);
	lua_pushvector(L, position6D(t));	
	return 1;
}


static int inverse_l_arm_7(lua_State *L) {
	std::vector<double> qArm;
	std::vector<double> pArm = lua_checkvector(L, 1);
	std::vector<double> qArmOrg = lua_checkvector(L, 2);
	double shoulderYaw = luaL_optnumber(L, 3,0.0);
	double bodyPitch = luaL_optnumber(L, 4,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 5);

	//Now we can use custom hand x/y offset (for claws)
	double handOffsetXNew = luaL_optnumber(L, 6,handOffsetX);
	double handOffsetYNew = luaL_optnumber(L, 7,handOffsetY);
	double handOffsetZNew = luaL_optnumber(L, 8,handOffsetZ);
	
	int flip_shoulderroll = luaL_optnumber(L, 9,0);

	Transform trArm = transform6D(&pArm[0]);		
	qArm = THOROP_kinematics_inverse_l_arm_7(trArm,&qArmOrg[0],shoulderYaw,bodyPitch,&qWaist[0],
		handOffsetXNew, handOffsetYNew, handOffsetZNew, flip_shoulderroll);
	lua_pushvector(L, qArm);
	return 1;
}

static int inverse_r_arm_7(lua_State *L) {
	std::vector<double> qArm;
	std::vector<double> pArm = lua_checkvector(L, 1);	
	std::vector<double> qArmOrg = lua_checkvector(L, 2);
	double shoulderYaw = luaL_optnumber(L, 3,0.0);
	double bodyPitch = luaL_optnumber(L, 4,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 5);

//Now we can use custom hand x/y/z offset (for claws)
	double handOffsetXNew = luaL_optnumber(L, 6,handOffsetX);
	double handOffsetYNew = luaL_optnumber(L, 7,handOffsetY);
	double handOffsetZNew = luaL_optnumber(L, 8,handOffsetZ);
	
	int flip_shoulderroll = luaL_optnumber(L, 9,0);

	Transform trArm = transform6D(&pArm[0]);
	qArm = THOROP_kinematics_inverse_r_arm_7(trArm,&qArmOrg[0],shoulderYaw,bodyPitch,&qWaist[0],
		handOffsetXNew, handOffsetYNew, handOffsetZNew, flip_shoulderroll);
	lua_pushvector(L, qArm);
	return 1;
}

/*
static int inverse_l_wrist(lua_State *L) {
	std::vector<double> qArm;
	std::vector<double> pArm = lua_checkvector(L, 1);
	std::vector<double> qArmOrg = lua_checkvector(L, 2);
	double shoulderYaw = luaL_optnumber(L, 3,0.0);
	double bodyPitch = luaL_optnumber(L, 4,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 5);
	

	Transform trArm = transform6D(&pArm[0]);
	qArm = THOROP_kinematics_inverse_l_wrist(trArm,&qArmOrg[0],shoulderYaw,bodyPitch,&qWaist[0]);
	lua_pushvector(L, qArm);
	return 1;
}

static int inverse_r_wrist(lua_State *L) {
	std::vector<double> qArm;
	std::vector<double> pArm = lua_checkvector(L, 1);
	std::vector<double> qArmOrg = lua_checkvector(L, 2);	
	double shoulderYaw = luaL_optnumber(L, 3,0.0);
	double bodyPitch = luaL_optnumber(L, 4,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 5);
	

	Transform trArm = transform6D(&pArm[0]);
	qArm = THOROP_kinematics_inverse_r_wrist(trArm,&qArmOrg[0],shoulderYaw,bodyPitch,&qWaist[0]);
	lua_pushvector(L, qArm);
	return 1;
}
*/
static int inverse_l_wrist(lua_State *L) {
	std::vector<double> qArm;
	std::vector<double> pArm = lua_checkvector(L, 1);
	std::vector<double> qArmOrg = lua_checkvector(L, 2);
	double shoulderYaw = luaL_optnumber(L, 3,0.0);
	double bodyPitch = luaL_optnumber(L, 4,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 5);
	

	Transform trArm = transform6D(&pArm[0]);
	qArm = THOROP_kinematics_inverse_l_wrist(trArm,&qArmOrg[0],shoulderYaw,bodyPitch,&qWaist[0]);
	lua_pushvector(L, qArm);
	return 1;
}

static int inverse_r_wrist(lua_State *L) {
	std::vector<double> qArm;
	std::vector<double> pArm = lua_checkvector(L, 1);
	std::vector<double> qArmOrg = lua_checkvector(L, 2);	
	double shoulderYaw = luaL_optnumber(L, 3,0.0);
	double bodyPitch = luaL_optnumber(L, 4,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 5);
	

	Transform trArm = transform6D(&pArm[0]);
	qArm = THOROP_kinematics_inverse_r_wrist(trArm,&qArmOrg[0],shoulderYaw,bodyPitch,&qWaist[0]);
	lua_pushvector(L, qArm);
	return 1;
}
static int inverse_arm_given_wrist(lua_State *L) {
	std::vector<double> qArm;
	std::vector<double> pArm = lua_checkvector(L, 1);
	std::vector<double> qArmOrg = lua_checkvector(L, 2);
	double bodyPitch = luaL_optnumber(L, 3,0.0);
	std::vector<double> qWaist = lua_checkvector(L, 4);


	Transform trArm = transform6D(&pArm[0]);	
	qArm = THOROP_kinematics_inverse_arm_given_wrist(trArm,&qArmOrg[0],bodyPitch,&qWaist[0]);
	lua_pushvector(L, qArm);
	return 1;
}

static int l_leg_torso(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	Transform t = THOROP_kinematics_forward_l_leg(&q[0]);
	lua_pushvector(L, position6D(t));
	return 1;
}

static int torso_l_leg(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	Transform t = inv(THOROP_kinematics_forward_l_leg(&q[0]));
	lua_pushvector(L, position6D(t));
	return 1;
}

static int r_leg_torso(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	Transform t = THOROP_kinematics_forward_r_leg(&q[0]);
	lua_pushvector(L, position6D(t));
	return 1;
}

static int torso_r_leg(lua_State *L) {
	std::vector<double> q = lua_checkvector(L, 1);
	Transform t = inv(THOROP_kinematics_forward_r_leg(&q[0]));
	lua_pushvector(L, position6D(t));
	return 1;
}

static int inverse_joints(lua_State *L)
{
	/* inverse kinematics to convert joint angles to servo positions */
	std::vector<double> q = lua_checkvector(L, 1);
	std::vector<double> r = THOROP_kinematics_inverse_joints(&q[0]);
	lua_pushvector(L, r);
	return 1;
}



static int com_upperbody(lua_State *L) {
	std::vector<double> qWaist = lua_checkvector(L, 1);
	std::vector<double> qLArm = lua_checkvector(L, 2);
	std::vector<double> qRArm = lua_checkvector(L, 3);
	double bodyPitch = luaL_optnumber(L, 4,0.0);
	double mLHand = luaL_optnumber(L, 5,0.0);
	double mRHand = luaL_optnumber(L, 6,0.0);


	std::vector<double> r = THOROP_kinematics_com_upperbody(
		&qWaist[0],&qLArm[0],&qRArm[0],bodyPitch, mLHand, mRHand);
	lua_pushvector(L, r);
	return 1;
}


static int calculate_knee_height(lua_State *L) {
	std::vector<double> qLeg = lua_checkvector(L, 1);
	double trKnee = THOROP_kinematics_calculate_knee_height(&qLeg[0]);
	lua_pushnumber(L, trKnee);
	return 1;
}




static int calculate_com_pos(lua_State *L) {
	std::vector<double> qWaist = lua_checkvector(L, 1);
	std::vector<double> qLArm = lua_checkvector(L, 2);
	std::vector<double> qRArm = lua_checkvector(L, 3);
	std::vector<double> qLLeg = lua_checkvector(L, 4);
	std::vector<double> qRLeg = lua_checkvector(L, 5);
	double bodyPitch = luaL_optnumber(L, 6,0.0);

	std::vector<double> r = THOROP_kinematics_calculate_com_positions(
		&qWaist[0],&qLArm[0],&qRArm[0],&qLLeg[0],&qRLeg[0],bodyPitch);
	lua_pushvector(L, r);
	return 1;
}

static int calculate_com_pos_global(lua_State *L) {
	std::vector<double> qWaist = lua_checkvector(L, 1);
	std::vector<double> qLArm = lua_checkvector(L, 2);
	std::vector<double> qRArm = lua_checkvector(L, 3);
	std::vector<double> qLLeg = lua_checkvector(L, 4);
	std::vector<double> qRLeg = lua_checkvector(L, 5);

	std::vector<double> uSupport = lua_checkvector(L, 6);
	int supportLeg = luaL_optnumber(L, 7,0);

	std::vector<double> r = THOROP_kinematics_calculate_com_positions_global(
		&qWaist[0],&qLArm[0],&qRArm[0],&qLLeg[0],&qRLeg[0],&uSupport[0],supportLeg);
	lua_pushvector(L, r);
	return 1;
}

static int com_upperbody_2(lua_State *L) {
	std::vector<double> comXYZ = lua_checkvector(L, 1);
	double mLHand = luaL_optnumber(L, 2,0.0);
	double mRHand = luaL_optnumber(L, 3,0.0);
	std::vector<double> r = THOROP_kinematics_com_upperbody_2(
		&comXYZ[0],mLHand, mRHand);	
	lua_pushvector(L, r);
	return 1;	
}

static int calculate_zmp(lua_State *L) {
	std::vector<double> com0 = lua_checkvector(L, 1);
	std::vector<double> com1 = lua_checkvector(L, 2);
	std::vector<double> com2 = lua_checkvector(L, 3);
	double dt0 = luaL_optnumber(L, 4,0.0);
	double dt1 = luaL_optnumber(L, 5,0.0);
	std::vector<double> r = THOROP_kinematics_calculate_zmp(
		&com0[0],&com1[0],&com2[0],dt0,dt1);	
	lua_pushvector(L, r);
	return 1;	
}


static int inverse_l_leg(lua_State *L) {
	std::vector<double> qLeg;
	std::vector<double> pLeg = lua_checkvector(L, 1);
	Transform trLeg = transform6D(&pLeg[0]);
	qLeg = THOROP_kinematics_inverse_l_leg(trLeg,0.0,0.0);
	lua_pushvector(L, qLeg);
	return 1;
}

static int inverse_r_leg(lua_State *L) {
	std::vector<double> qLeg;
	std::vector<double> pLeg = lua_checkvector(L, 1);
	Transform trLeg = transform6D(&pLeg[0]);
	qLeg = THOROP_kinematics_inverse_r_leg(trLeg,0.0,0.0);
	lua_pushvector(L, qLeg);
	return 1;
}

static int inverse_legs(lua_State *L) {
	std::vector<double> qLLeg(12), qRLeg;
	std::vector<double> pLLeg = lua_checkvector(L, 1);
	std::vector<double> pRLeg = lua_checkvector(L, 2);
	std::vector<double> pTorso = lua_checkvector(L, 3);
	std::vector<double> aShiftX = lua_checkvector(L, 4);
	std::vector<double> aShiftY = lua_checkvector(L, 5);

	Transform trLLeg = transform6D(&pLLeg[0]);
	Transform trRLeg = transform6D(&pRLeg[0]);
	Transform trTorso = transform6D(&pTorso[0]);

	int birdwalk = luaL_optnumber(L, 6,0);
	std::vector<double> qL = lua_checkvector(L, 7);
	std::vector<double> qR = lua_checkvector(L, 8);

	//now we should be able to manually choose tilt type
	//and the minimum tilt angle for them
	int leftTiltType = luaL_optnumber(L, 9, 0);
	int rightTiltType = luaL_optnumber(L, 10, 0);
	double leftTiltMin = luaL_optnumber(L, 11, 0.0);
	double rightTiltMin = luaL_optnumber(L, 12, 0.0);
	Transform trTorso_LLeg = inv(trTorso)*trLLeg;
	Transform trTorso_RLeg = inv(trTorso)*trRLeg;


	if ((leftTiltType==0) && (rightTiltType==0)){ //automatic
		if(trTorso_LLeg(0,3)>trTorso_RLeg(0,3)){ //Left front
			qLLeg = THOROP_kinematics_inverse_leg_toelift(trTorso_LLeg,LEG_LEFT,aShiftX[0],aShiftY[0],birdwalk,qL[4],leftTiltMin);
			qRLeg = THOROP_kinematics_inverse_leg_heellift(trTorso_RLeg,LEG_RIGHT,aShiftX[1],aShiftY[1],birdwalk, qR[4],rightTiltMin);
		}else{
			qLLeg = THOROP_kinematics_inverse_leg_heellift(trTorso_LLeg,LEG_LEFT,aShiftX[0],aShiftY[0],birdwalk,  qL[4],leftTiltMin) ;
			qRLeg = THOROP_kinematics_inverse_leg_toelift(trTorso_RLeg,LEG_RIGHT,aShiftX[1],aShiftY[1],birdwalk, qR[4],rightTiltMin);
		}
	}else{
		if (leftTiltType==1) {
			qLLeg = THOROP_kinematics_inverse_leg_toelift(trTorso_LLeg,LEG_LEFT,aShiftX[0],aShiftY[0],birdwalk,qL[4],leftTiltMin);
		}else{
			qLLeg = THOROP_kinematics_inverse_leg_heellift(trTorso_LLeg,LEG_LEFT,aShiftX[0],aShiftY[0],birdwalk,qL[4],leftTiltMin);
		}
		if (rightTiltType==1) {
			qRLeg = THOROP_kinematics_inverse_leg_toelift(trTorso_RLeg,LEG_RIGHT,aShiftX[1],aShiftY[1],birdwalk, qR[4],rightTiltMin);
		}else{
			qRLeg = THOROP_kinematics_inverse_leg_heellift(trTorso_RLeg,LEG_RIGHT,aShiftX[1],aShiftY[1],birdwalk, qR[4],rightTiltMin);
		}
	}
	qLLeg.insert(qLLeg.end(), qRLeg.begin(), qRLeg.end());
	lua_pushvector(L, qLLeg);
	return 1;
}


static int calculate_foot_tilt(lua_State *L) {
	std::vector<double> qLFootLift(4), qRFootLift;
	std::vector<double> pLLeg = lua_checkvector(L, 1);
	std::vector<double> pRLeg = lua_checkvector(L, 2);
	std::vector<double> pTorso = lua_checkvector(L, 3);

	Transform trLLeg = transform6D(&pLLeg[0]);
	Transform trRLeg = transform6D(&pRLeg[0]);
	Transform trTorso = transform6D(&pTorso[0]);
	Transform trTorso_LLeg = inv(trTorso)*trLLeg;
	Transform trTorso_RLeg = inv(trTorso)*trRLeg;

	qLFootLift = THOROP_kinematics_calculate_foot_lift(trTorso_LLeg,0);
	qRFootLift = THOROP_kinematics_calculate_foot_lift(trTorso_RLeg,1);

	qLFootLift.insert(qLFootLift.end(), 
		qRFootLift.begin(), qRFootLift.end());
	//LHeel LToe RHeel RToe
	lua_pushvector(L, qLFootLift);
	return 1;
}

static int inverse_legs_foot_tilt(lua_State *L) {
	std::vector<double> qLLeg(12), qRLeg;
	std::vector<double> pLLeg = lua_checkvector(L, 1);
	std::vector<double> pRLeg = lua_checkvector(L, 2);
	std::vector<double> pTorso = lua_checkvector(L, 3);
	std::vector<double> qFootLift = lua_checkvector(L, 4);

	Transform trLLeg = transform6D(&pLLeg[0]);
	Transform trRLeg = transform6D(&pRLeg[0]);
	Transform trTorso = transform6D(&pTorso[0]);
	Transform trTorso_LLeg = inv(trTorso)*trLLeg;
	Transform trTorso_RLeg = inv(trTorso)*trRLeg;

	qLLeg = THOROP_kinematics_inverse_leg_tilt(trTorso_LLeg,qFootLift[0],0);
	qRLeg = THOROP_kinematics_inverse_leg_tilt(trTorso_RLeg,qFootLift[1],1);
	qLLeg.insert(qLLeg.end(), qRLeg.begin(), qRLeg.end());

	lua_pushvector(L, qLLeg);
	return 1;
}

/* Extra definitions */

#ifdef TORCH
static Transform luaT_checktransform(lua_State *L, int narg) {
  const THDoubleTensor * _t =
		(THDoubleTensor *) luaT_checkudata(L, narg, "torch.DoubleTensor");
  // Check the dimensions
  if(_t->size[0]!=4||_t->size[1]!=4)
    luaL_error(L, "Bad dimensions: %ld x %ld",_t->size[0],_t->size[1]);

  // Form into our Transform type
  Transform tr;
  for (int i = 0; i < 4; i++)
    for (int j = 0; j < 4; j++)
      tr(i,j) = THTensor_fastGet2d( _t, i, j );

  return tr;
}
static void luaT_pushtransform(lua_State *L, Transform t) {
  // Make the Tensor
  THLongStorage *sz = THLongStorage_newWithSize(2);
  sz->data[0] = 4;
  sz->data[1] = 4;
  THDoubleTensor *_t = THDoubleTensor_newWithSize(sz,NULL);

  // Copy the data
  //double* dest = _t->storage->data;
  for (int i = 0; i < 4; i++)
    for (int j = 0; j < 4; j++)
      THTensor_fastSet2d( _t, i, j, t(i,j) );

  // Push the Tensor
	luaT_pushudata(L, _t, "torch.DoubleTensor");
}
#endif
static Transform lua_checktransform(lua_State *L, int narg) {
  // Table of tables
  luaL_checktype(L, narg, LUA_TTABLE);
#if LUA_VERSION_NUM == 502
	int n_el = lua_rawlen(L, 1);
#else
  int n_el = lua_objlen(L, 1);
#endif
  if(n_el!=4)
    luaL_error(L, "Bad dimension! %d x ?",n_el);

  // Make the Transform
  Transform tr;
  int i, j;

  // Loop through the transform
  for (i = 1; i <= 4; i++) {
    // Grab the table entry
    lua_rawgeti(L, narg, i);
    // Get the top of the stack
    int top_tbl = lua_gettop(L);
    //printf("Top of stack: %d\n",top_arg);

    luaL_checktype(L, top_tbl, LUA_TTABLE);
    #if LUA_VERSION_NUM == 502
      int n_el2 = lua_rawlen(L, 1);
    #else
      int n_el2 = lua_objlen(L, 1);
    #endif
    if(n_el!=4)
      luaL_error(L, "Bad dimension! %d x %d",i,n_el2);

    // Work with the table, which is pushed
    for (j = 1; j <= 4; j++) {
      // Grab the table entry on top of the stack (of 2 things?)
      lua_rawgeti(L, top_tbl, j);
      int top_num = lua_gettop(L);
      // The number is now on the top of the stack
      double el = luaL_checknumber(L, top_num);
      // Work with the table, which is pushed
      //printf("El @ (%d,%d)=%lf\n",i,j,el);
      tr(i-1,j-1) = el;
      // Remove the number from the stack
      lua_pop(L, 1);
    }
    // Remove from the stack
    lua_pop(L, 1);
  }

  // Return the Transform
  return tr;
}

// Assume just the Left arm
// TODO: Add any extra flags
static int luaTHOROP_inverse_arm(lua_State *L) {
	std::vector<double> qArm;
	double shoulderYaw;
	bool flip_shoulderroll;

	// Current joint angles must be given as arg 2
  if( !lua_istable(L,1) ){
		Transform tr = luaT_checktransform(L, 1);
		std::vector<double> qArm0 = lua_checkvector(L, 2);
		shoulderYaw = luaL_checknumber(L, 3);
		flip_shoulderroll = lua_toboolean(L, 4);
    qArm = THOROP_kinematics_inverse_arm(
			tr,
			qArm0,
			shoulderYaw,
			flip_shoulderroll
		);
	} else {
		Transform tr = lua_checktransform(L, 1);
		std::vector<double> qArm0 = lua_checkvector(L, 2);
		shoulderYaw = luaL_checknumber(L, 3);
		flip_shoulderroll = lua_toboolean(L, 4);
    qArm = THOROP_kinematics_inverse_arm(tr, qArm0, shoulderYaw, flip_shoulderroll);
	}
	lua_pushvector(L, qArm);
	// Push the shoulder yaw is the indicator of the current null space setup
	//lua_pushnumber(L, qArm[2]);
	// NOTE: Just for forward, actually :P we know from the inverse input
	// TODO: Common API to mean a float value for interpolation?
	// TODO: Is COM compensation a good null space option?
	return 1;
}
/*
// Assume just the Left arm
static int luaTHOROP_inverse_wrist(lua_State *L) {
	std::vector<double> qArm;
	double shoulderYaw;
	//char is_reach_back;

	// Current joint angles must be given as arg 2
  if( !lua_istable(L, 1) ){
		Transform tr = luaT_checktransform(L, 1);
		std::vector<double> qArm0 = lua_checkvector(L, 2);
		shoulderYaw = luaL_optnumber(L, 3, 0.0);
		// TODO: Add any extra flags
    qArm = THOROP_kinematics_inverse_wrist(tr, qArm0, shoulderYaw);
	} else {
		Transform tr = lua_checktransform(L, 1);
		std::vector<double> qArm0 = lua_checkvector(L, 2);
		shoulderYaw = luaL_optnumber(L, 3, 0.0);
    qArm = THOROP_kinematics_inverse_wrist(tr, qArm0, shoulderYaw);
	}
	lua_pushvector(L, qArm);
	// TODO:  some other indicator...
	//lua_pushnumber(L, is_reach_back);
	return 1;
}
*/
static const struct luaL_Reg kinematics_lib [] = {
	{"forward_head", forward_head},
//	{"forward_larm", forward_l_arm},
//	{"forward_rarm", forward_r_arm},
	{"forward_lleg", forward_l_leg},
	{"forward_rleg", forward_r_leg},
	{"forward_joints", forward_joints},
	{"forward_lknee", forward_l_knee},
	{"forward_rknee", forward_r_knee},
  
	{"lleg_torso", l_leg_torso},
	{"torso_lleg", torso_l_leg},
	{"rleg_torso", r_leg_torso},
	{"torso_rleg", torso_r_leg},	
	
	{"inverse_l_leg", inverse_l_leg},
	{"inverse_r_leg", inverse_r_leg},
	{"inverse_legs", inverse_legs},

	{"calculate_knee_height",calculate_knee_height},
		
	{"inverse_joints", inverse_joints},

  /* 7 DOF specific */
	{"l_arm_torso_7", l_arm_torso_7},
	{"r_arm_torso_7", r_arm_torso_7},
	{"inverse_l_arm_7", inverse_l_arm_7},
	{"inverse_r_arm_7", inverse_r_arm_7},

  /* Wrist specific */
    {"l_wrist_torso", l_wrist_torso},
	{"r_wrist_torso", r_wrist_torso},
	{"inverse_l_wrist", inverse_l_wrist},
	{"inverse_r_wrist", inverse_r_wrist},

	{"inverse_arm_given_wrist", inverse_arm_given_wrist},

 /* COM calculation */
    
	{"com_upperbody", com_upperbody},

	{"calculate_com_pos", calculate_com_pos},
	{"calculate_com_pos_global", calculate_com_pos_global},

	{"calculate_zmp", calculate_zmp},

	{"com_upperbody_2",com_upperbody_2},

	{"calculate_foot_tilt",calculate_foot_tilt},
	{"inverse_legs_foot_tilt",inverse_legs_foot_tilt},

	/* Extras */
	{"inverse_arm", luaTHOROP_inverse_arm},
	//{"inverse_wrist", luaTHOROP_inverse_wrist},

	{"l_arm_origins", l_arm_origins},
	{"r_arm_origins", r_arm_origins},

	{"l_leg_origins", l_leg_origins},
	{"r_leg_origins", r_leg_origins},

	{NULL, NULL}
};

static const def_info kinematics_constants[] = {
  {"neckOffsetX", neckOffsetX},
  {"neckOffsetZ", neckOffsetZ},
  {"shoulderOffsetX", shoulderOffsetX},
  {"shoulderOffsetY", shoulderOffsetY},
  {"shoulderOffsetZ", shoulderOffsetZ},
  {"upperArmLength", upperArmLength},
  {"lowerArmLength", lowerArmLength},
  {"elbowOffsetX", elbowOffsetX},
  {"handOffsetX", handOffsetX},
  {"handOffsetY", handOffsetY},
  {"handOffsetZ", handOffsetZ},  
  {NULL, 0}
};

extern "C"
int luaopen_THOROPKinematics (lua_State *L) {
#if LUA_VERSION_NUM == 502
	luaL_newlib(L, kinematics_lib);
#else
	luaL_register(L, "Kinematics", kinematics_lib);
#endif
	lua_install_constants(L, kinematics_constants);
	return 1;
}

