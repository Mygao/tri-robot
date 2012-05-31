// Class Header for Robot Local Occupancy Map
#ifndef __OCCMAP_H__
#define __OCCMAP_H__

#include <vector>
#include <stdint.h>

using namespace std;

// Gird Map Coordinate
// 0 -------------> X
// |
// |
// y

const int gau_ker_size = 7;
const double gau[gau_ker_size][gau_ker_size] =
{{   0.0529305,   0.0833038,   0.0457804,  0.00878514, 0.000588672, 1.37738e-05, 1.12535e-07,},
  {   0.0833038,    0.270868,    0.307544,     0.12193,   0.0168799, 0.000815988, 1.37738e-05,},
  {   0.0457804,    0.307544,    0.721422,    0.590919,    0.169013,   0.0168799, 0.000588672,},
  {  0.00878514,     0.12193,    0.590919,           1,    0.590919,     0.12193,  0.00878514,},
  { 0.000588672,   0.0168799,    0.169013,    0.590919,    0.721422,    0.307544,   0.0457804,},
  { 1.37738e-05, 0.000815988,   0.0168799,     0.12193,    0.307544,    0.270868,   0.0833038,},
  { 1.12535e-07, 1.37738e-05, 0.000588672,  0.00878514,   0.0457804,   0.0833038,   0.0529305,}};

class OccMap {
public:
  OccMap();
  ~OccMap() {}
  int randomize_map(void);
  int reset_size(int map_size, int robot_x, int robot_y, double time);
  vector<uint32_t>& get_map(void);
  vector<double>& get_map_updated_time(void);
  int& get_robot_pos_x(void);
  int& get_robot_pos_y(void);
  
  int odometry_init(void);
  int odometry_update(const double odomX, const double odomY, const double odomA);
  int vision_proc_init(int obs_width);
  int vision_update(vector<double>& free_bound, vector<int>& free_bound_type, int width, double time);
  int time_decay(double time);
  inline void range_check(double &num);

private:
  // Map size in grids
  int map_size;
  // Map actual size
  double map_size_metric;
  // Grid num
  int grid_num;
  // Map Max resolution
  double resolution;
  // Map Structure
  vector<double> grid;
  // Map for output
  vector<uint32_t> grid_out;
  // Map update time
  vector<double> grid_updated_time;

  // Robot Position in Grid
  int rx;
  int ry;
  // distance from Robot position to origin
  double max_dis;
  // Accumulated Robot Odometry Change
  double odom_x;
  double odom_y;
  double odom_a;
  struct odom_pt {
    int x;
    int y;
    double value;
  };
  vector<odom_pt> odom_change;
  int odom_change_num;

  // Gaussian rotation angle
  vector<double> gau_theta;
  vector<double> gau_a;
  vector<double> gau_b;
  vector<double> gau_c;
  double var_x;
  double var_y;
  double gau_max_range;
  double gau_min_p;
  double default_p;
  double default_log_p;

};

#endif
