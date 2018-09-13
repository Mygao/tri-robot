#pragma once

typedef struct {
  int ioffset;
  int joffset;
  double distance;
} NeighborStruct;

#ifdef __cplusplus
extern "C"
#endif
int dijkstra_matrix(double* cost_to_go, // output
                    double* costmap, //input
                    unsigned int m, unsigned int n,
                    int iGoal, int jGoal,
                    int nNeighbors);

int dijkstra_nonholonomic(double* cost_to_go, // output
                        double* costmap, //input
                        unsigned int m, unsigned int n, unsigned int p,
                        double* p_goal, double* p_start,
                        int nNeighbors);