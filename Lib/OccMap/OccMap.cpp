// Class for Robot Local Occupancy Map

#include "OccMap.h"
#include <cassert>
#include <time.h>
#include <stdio.h>
#include <iostream>
#include <iomanip>
#include <cmath>
#include <algorithm>


OccMap::OccMap()
:map_size(50), map_size_metric(1.0) ,resolution(map_size_metric / map_size)
,grid_num(map_size * map_size)
,rx(25), ry(40)
,max_dis(sqrt(rx * rx + ry * ry))
// initiate accumulated robot odom change
,odom_x(0.0), odom_y(0.0), odom_a(0.0)
,odom_change_num(0)
// vars for vision update
,default_p(0.25)
,default_log_p(log(default_p / (1 - default_p)))
{
}

const double EXT_LOG = 15;

inline void OccMap::range_check(double &num) {
  if (num > EXT_LOG) num =  EXT_LOG; // log likelihood 0.9999
  if (num < -EXT_LOG) num = -EXT_LOG; // log likelihood 0.0001
}

int OccMap::reset_size(int size, int robot_x, int robot_y, double time) {
  map_size = size;
  resolution = map_size_metric / map_size;
  grid_num = map_size * map_size;
  rx = robot_x;
  ry = robot_y;
  max_dis = sqrt(rx * rx + ry * ry);
  if (grid.size() < grid_num) {
    grid_out.resize(grid_num);
    grid.resize(grid_num);
  }
  randomize_map();

  // reset map init time
  if (grid_updated_time.size() < grid_num)
    grid_updated_time.resize(grid_num);
  for (int i = 0; i < grid_num; i++)
    grid_updated_time[i] = time;

  // reset Odometry
  odometry_reset();
  return 1;
}

int OccMap::randomize_map(void) {
  cout << grid.size() << ' ' << grid_num << endl;
  assert(grid.size() == grid_num);
  int grid_size = grid_num;
  srand(time(NULL));
  for (int i = 0; i < grid_num; i++) {
    grid[i] = log(rand() * default_p / RAND_MAX);
  }
  return 1;
}

vector<uint32_t>& OccMap::get_map(void) {
  for (int i = 0; i < grid.size(); i++)
    grid_out[i] = (1 - 1/(1+exp(grid[i]))) * 10000;
  return grid_out;
}

vector<double>& OccMap::get_map_updated_time(void) {
  return grid_updated_time;
}

int& OccMap::get_robot_pos_x(void) {
  return rx;
}

int& OccMap::get_robot_pos_y(void) {
  return ry;
}

int OccMap::time_decay(double time) {
  double decay_coef = 0.001;
  double P = 0, P1 = 0;
  int i = 0;
  for (i = 0; i < grid_num; i++) {
    P = 1 - 1 / (1 + exp(grid[i]));
    P1 = P * exp(-decay_coef * (time - grid_updated_time[i]));
    grid[i] = log(P1 / (1 - P1));
    range_check(grid[i]);
  }
  return 1;
}


bool grid_compare(struct grid_point P1, struct grid_point P2) {
  return P1.key < P2.key;
}

int OccMap::vision_update(vector<double>& free_bound, vector<int>& free_bound_type,
    int width, double time) {
  vector<grid_point> pt_update; // vector to save the point need to be update
  vector<grid_point>::iterator low; // pointer to the found in binary search
  // Go through all observation
  double ob_x = 0, ob_y = 0;
  int ni = 0, nj = 0, index = 0; 
  for (int cnt = 0; cnt < free_bound_type.size(); cnt++) {
    if (free_bound_type[cnt] != 2){
      // find pts need to be update
      ob_x = odom_x + cos(odom_a) * free_bound[cnt] - sin(odom_a) * free_bound[cnt + width];
      ob_y = odom_y + sin(odom_a) * free_bound[cnt] + cos(odom_a) * free_bound[cnt + width];
      for (int inc = -gau_ker_size; inc <= gau_ker_size; inc++) {
        for (int jnc = -gau_ker_size; jnc <= gau_ker_size; jnc++) {
          ni = (rx * resolution - ob_y + inc * resolution) / resolution;
          nj = (ry * resolution - ob_x + jnc * resolution) / resolution;
          // check range
          if ((ni < 0) || (ni >= map_size) || (nj < 0) || (nj >= map_size)) continue;
          // calculate index based on row and col
          index = nj * map_size + ni;
          struct grid_point new_pt = {index, gau[inc + gau_ker_size][jnc + gau_ker_size]};
          // search and insert
          low = lower_bound(pt_update.begin(), pt_update.end(), new_pt, grid_compare);
          if (low == pt_update.end() || low->key != new_pt.key) {
            pt_update.push_back(new_pt);
            sort(pt_update.begin(), pt_update.end(), grid_compare);
          } else {
            low->value = max(low->value, new_pt.value);
          } // if (low == ...
        } // for jnc
      } // for inc
    } // if free_bound_type
  } // for cnt
 
  // Update Map
  vector<grid_point>::iterator it;
  for (it = pt_update.begin(); it != pt_update.end(); ++it) {
    grid[it->key] += log(it->value / (1 - it->value));
    grid[it->key] -= default_log_p;
    range_check(grid[it->key]);
    grid_updated_time[it->key] = time;
  }
  return 1;
}

int OccMap::get_odometry(double& pose_x, double& pose_y, double& pose_a) {
  pose_x = odom_x;
  pose_y = odom_y;
  pose_a = odom_a;
  return 1;
}

int OccMap::odometry_reset(void) {
  odom_x = 0.0;
  odom_y = 0.0;
  odom_a = 0.0;
  return 1;
}

int OccMap::map_shift(int shift_x, int shift_y) {
  vector<grid_point> odom_change;
  int i = 0, j = 0;
  for (int cnt = 0; cnt < grid_num; cnt ++) 
    if (grid[cnt] > default_log_p) { // only shift grids that likelihood
                                    // Larger then default value
      i = cnt % map_size;
      j = (cnt - i) / map_size;
      i += shift_y;
      j += shift_x;
      if ((i >= 0) && (i < map_size) && (j >= 0) && (j < map_size)) {
        grid_point new_pt = {j * map_size +i, grid[cnt]};
        odom_change.push_back(new_pt);
      }
      grid[cnt] = default_log_p;
    }
  for (int k = 0; k < odom_change.size(); k++)
    grid[odom_change[k].key] = odom_change[k].value;
  return 1;
}

int OccMap::odometry_update(const double odomX, const double odomY,
    const double odomA) {
  odom_x = odom_x + odomX * cos(odom_a) - odomY * sin(odom_a);
  odom_y = odom_y + odomX * sin(odom_a) + odomY * cos(odom_a);
  odom_a += odomA;
//  cout << odom_x << ' ' << odom_y << ' ' << odom_a << endl;
//  Map shift
  int shift_scale = 5;
  double odom_i = odom_x / (shift_scale * resolution);
  double odom_j = odom_y / (shift_scale * resolution);
  if (odom_i >= 1) {
    cout << "down shift" << endl;
    map_shift(shift_scale, 0);
    odom_x -= shift_scale * resolution;
    odom_i--;
  } else if (odom_i <= -1) {
    cout << "up shift" << endl;
    map_shift(-shift_scale, 0);
    odom_x += shift_scale * resolution;
    odom_i++;
  }
  if (odom_j >= 1) {
    cout << "left shift" << endl;
    map_shift(0, shift_scale);
    odom_y -= shift_scale * resolution;
    odom_j--;
  } else if (odom_j <= -1) {
    cout << "right shift" << endl;
    map_shift(0, -shift_scale);
    odom_y += shift_scale * resolution;
    odom_j++;
  }
  return 1;
}

inline float sqrtA(float x) {
  unsigned int i = *(unsigned int*) &x;
  i += 127 << 23;
  i >>= 1;
  return *(float*) &i;
}

inline double norm(int x1, int y1, int x2, int y2) {
  double squaredist = (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
  return (double)sqrt(squaredist);
}

inline grid_ij get_mean(vector<grid_ij>& cluster) {
  double sum_i = 0, sum_j = 0;
  int size = cluster.size();
  for (int cnt = 0; cnt < cluster.size(); cnt++) {
    sum_i += cluster[cnt].i / size;
    sum_j += cluster[cnt].j / size;
  }
  grid_ij new_mean = {sum_i, sum_j, 0.0};
  return new_mean;
}


int OccMap::kmean_clustering(void) {
  vector<grid_ij> good_pt;
  int i = 0, j = 0;
  for (int cnt = 0; cnt < grid_num; cnt++) {
    if (grid[cnt] > default_log_p) {
      i = cnt % map_size;
      j = (cnt - i) / map_size;
      grid_ij new_pt = {i, j, grid[cnt]};
      good_pt.push_back(new_pt);
    }
  }
  int K = 2;
  vector<grid_ij> means, means_new;
  vector<grid_ij> cluster[K];
  int r = 0;
  // Random init mean from points
  srand(time(0));
  for (int cnt = 0; cnt < K; cnt++) {
    r = (rand() % good_pt.size()) + 1;
    means.push_back(good_pt[r]);
    means_new.push_back(good_pt[r]);
  }

    // iteration to cluser points
  vector<grid_ij>::iterator it; 
  bool changed = false;
  do {
    changed = false;
    for (it = good_pt.begin(); it != good_pt.end(); ++it) {
      double mindist = 100000000;
      int minindex = -1;
      for (int mit = 0; mit <= means.size(); mit++) {
        double dist = norm(it->i, it->j, means[mit].i, means[mit].j);
        if (dist < mindist) {
          mindist = dist;
          minindex = mit;
        }
      }
      cluster[minindex].push_back(*it);
    }
    // get new mean
    for (int cnt = 0; cnt < K; cnt ++) {
  //    cout << cluster[cnt].size() << endl;
      if (cluster[cnt].size() != 0) {
//        cout << "old " << means[cnt].i << ' ' << means[cnt].j << endl;
        double sum_i = 0, sum_j = 0;
        for (int iter = 0; iter < cluster[cnt].size(); iter++) {
          sum_i += cluster[cnt][iter].i;
          sum_j += cluster[cnt][iter].j;
        }
        means_new[cnt].i = round(sum_i / cluster[cnt].size());
        means_new[cnt].j = round(sum_j / cluster[cnt].size());
//        cout << "new " << means_new[cnt].i << ' ' << means_new[cnt].j << endl;
      } else {
        r = (rand() % good_pt.size()) + 1;
        means_new[cnt] = good_pt[r];
//        cout << "new " << means_new[cnt].i << ' ' << means_new[cnt].j << endl;    
      }
      if ((means[cnt].i != means_new[cnt].i) || (means[cnt].j != means_new[cnt].j)) 
        changed = true; 
//      cout << changed << endl;
      means = means_new;
    }
  }
  while (changed);

//  cout << changed <<endl;
//  for (int cnt = 0; cnt < K; cnt++) {
//    cout << means[cnt].i << ' ' << means[cnt].j << endl;
//  }
//  cout << endl;
  nOb = K;
  for (int cnt = 0; cnt < nOb; cnt++) {
    obstacle new_ob;
    //TODO
    new_ob.centroid_x = means[cnt].i;
    new_ob.centroid_y = means[cnt].j;
    new_ob.left_angle_range = ;
    new_ob.right_angle_range = ;
    new_ob.nearest_x = ;
    new_ob.nearest_y = ;
    obs.push_back(new_ob);
  }
  return 1;
}

int OccMap::init_obstacle(void) {
  const int maxObstacleClusters = 5;
  nOb = 0;
  obs.clear();
  return 1;
}
