#ifndef _GZ_COMMS_MANAGER_H_
#define _GZ_COMMS_MANAGER_H_

#include <gazebo/math/Vector3.hh>
#include <gazebo/physics/physics.hh>
#include <gazebo/physics/PhysicsTypes.hh>
#include <gazebo/transport/TransportTypes.hh>
#include <gazebo/common/Time.hh>
#include <gazebo/common/Plugin.hh>
#include <gazebo/common/Events.hh>
#include <gazebo/sensors/SensorManager.hh>
#include <gazebo/sensors/SensorTypes.hh>
#include <gazebo/sensors/ContactSensor.hh>
#include <gazebo/sensors/ImuSensor.hh>
#include <gazebo/sensors/Sensor.hh>

#include <string>
#include <vector>
#include "Comms/config.h"
#include "Comms/dcm.h"

extern "C" {
#include "Comms/pid.h"
#include "Comms/filter.h"
}

// gz_comms_manager.so : gazebo plugin for joint control and proprioception
////////////////////////////////////////////////////////////////////////////////

namespace gazebo
{
class gz_comms_manager : public ModelPlugin
{
public:
  gz_comms_manager();
public:
  virtual ~gz_comms_manager();
public:
  void Load(physics::ModelPtr _parent, sdf::ElementPtr _sdf);
private:
  void initialize_controllers();
private:
  void on_l_foot_contact();
private:
  void on_r_foot_contact();
private:
  void reset();
private:
  void update();

private:
  physics::ModelPtr model;
private:
  physics::WorldPtr world;
private:
  event::ConnectionPtr update_connection;
private:
  event::ConnectionPtr reset_connection;
private:
  event::ConnectionPtr l_foot_contact_connection;
private:
  event::ConnectionPtr r_foot_contact_connection;
private:
  common::Time last_update_time;
private:
  double physics_time_step;

  // Device Comms Manager
private:
  Dcm dcm;

  // Joints
private:
  physics::Joint_V joints;
private:
  std::vector<int> joint_index;
private:
  std::vector<struct pid> joint_position_pids;
private:
  std::vector<struct filter> joint_velocity_filters;

  // Gripper joints
private:
  int l_gripper_index;
private:
  int r_gripper_index;

  // Force torque joints
private:
  int l_ankle_index;
private:
  int r_ankle_index;
private:
  int l_wrist_index;
private:
  int r_wrist_index;

  // Contact sensors
private:
  sensors::ContactSensorPtr l_foot_contact_sensor;
private:
  sensors::ContactSensorPtr r_foot_contact_sensor;
private:
  std::string l_foot_link_name;
private:
  std::string l_foot_contact_sensor_name;
private:
  std::string r_foot_link_name;
private:
  std::string r_foot_contact_sensor_name;


  // Imu
private:
  boost::shared_ptr<sensors::ImuSensor> imu_sensor;
private:
  std::string imu_link_name;
private:
  std::string imu_sensor_name;

  // Controller settings
private:
  int joint_max;
private:
  std::vector<double> joint_damping;
private:
  std::vector<double> p_gain_constant;
private:
  std::vector<double> i_gain_constant;
private:
  std::vector<double> d_gain_constant;
private:
  std::vector<double> d_break_freq;
private:
  std::vector<double> p_gain_default;
private:
  std::vector<double> i_gain_default;
private:
  std::vector<double> d_gain_default;
};
}

#endif
