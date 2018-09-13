// C parts
#include <math.h>

// C++ parts
#include <set>

#include <stddef.h>

// For non-holonomic porion
#define TURN_COST 1.2
#define STOP_FACTOR 1.1

typedef std::pair<double, int> CostNodePair; // (cost, node)

typedef struct {
  int ioffset;
  int joffset;
  double distance;
} NeighborStruct;

static const NeighborStruct neighbors[] = {
    // 4-connected
    {-1, 0, 1.0},
    {1, 0, 1.0},
    {0, -1, 1.0},
    {0, 1, 1.0},
    // 8-connected
    {-1, -1, sqrt(2)},
    {1, -1, sqrt(2)},
    {-1, 1, sqrt(2)},
    {1, 1, sqrt(2)},
    // 16-connected
    {2, 1, sqrt(5)},
    {1, 2, sqrt(5)},
    {-1, 2, sqrt(5)},
    {-2, 1, sqrt(5)},
    {-2, -1, sqrt(5)},
    {-1, -2, sqrt(5)},
    {1, -2, sqrt(5)},
    {2, -1, sqrt(5)},
};

// Run Dijkstra on an input matrix
// Returns an error code
#ifdef __cplusplus
extern "C"
#endif
    int
    dijkstra_matrix(double *cost_to_go, // output
                    double *costmap,    // input
                    unsigned int m, unsigned int n, int iGoal, int jGoal,
                    int nNeighbors) {

  // Check the boundaries
  if (iGoal < 0) {
    iGoal = 0;
  } else if (iGoal >= m) {
    iGoal = m - 1;
  }
  if (jGoal < 0) {
    jGoal = 0;
  } else if (jGoal >= n) {
    jGoal = n - 1;
  }

  // Characterize the matrix with graph information
  size_t nMatrixNodes = m * n;
  // size_t nMatrixEdges = (nNeighbors / 2) * nMatrixNodes + m + n;

  // Form the cost-to-go map
  int i;
  for (i = 0; i < nMatrixNodes; i++) {
    cost_to_go[i] = INFINITY;
  }

  // Add the goal state
  int indGoal = n * iGoal + jGoal;
  cost_to_go[indGoal] = 0;
  std::set<CostNodePair> Q; // Sorted set of (cost to go, node)
  Q.insert(CostNodePair(0, indGoal));

  // Iterate through the states
  while (!Q.empty()) {
    // Fetch closest node in queue
    CostNodePair top = *Q.begin();
    Q.erase(Q.begin());
    double c0 = top.first;
    int ind0 = top.second;

    // fprintf(stderr, "\n==\nNode %d \n", ind0);

    double cost0 = costmap[ind0];

    // Array subscripts of item
    int i0 = ind0 / n;
    int j0 = ind0 % n;

    // printf("Coord (%d, %d)\n", i0, j0);

    // Iterate over neighbor items
    int k;
    for (k = 0; k < nNeighbors; k++) {
      int i1 = i0 + neighbors[k].ioffset;
      if ((i1 < 0) || (i1 >= m)) {
        continue;
      }
      int j1 = j0 + neighbors[k].joffset;
      if ((j1 < 0) || (j1 >= n)) {
        continue;
      }
      size_t ind1 = i1 * n + j1;
      // fprintf(stderr ,"New item: %d\n", ind1);
      // Generate the new cost
      double avg = 0.5 * (cost0 + costmap[ind1]);
      // printf("Avg cost %f\n", avg);
      double c1 = c0 + avg * neighbors[k].distance;
      // fprintf(stderr, "\nNew cost %f\n", c1);
      double c2g = cost_to_go[ind1];
      // fprintf(stderr, "Cost2go %f\n", c2g);

      // fprintf(stderr, "!! Inspecting item %d\n", ind1);
      if (c1 < c2g) {
        // Check if the first time we are inspecting the item
        if (!isinf(c2g)) {
          Q.erase(Q.find(CostNodePair(c2g, ind1)));
        }
        cost_to_go[ind1] = c1;
        Q.insert(CostNodePair(c1, ind1));
      } // Updating c2g
    }
    // fprintf(stderr, "Done iteration.\n");
  }
  // fprintf(stderr, "Done iterating!\n");

  // Yield the cost-to-go map
  return 0;
}

/*
  [cost_to_go] = dijkstra_nonholonomic(A, xya_goal, xya_start, [nNeighbors]);
  where positive costs are given in matrix A
  with nNeighbors different orientations.
*/
// Costmap is 2D, but the output is 3D, with turning?
#ifdef __cplusplus
extern "C"
#endif
    int
    dijkstra_nonholonomic(double *cost_to_go,
                          double *costmap, // input
                          unsigned int m, unsigned int n, double *p_goal,
                          double *p_start, int nNeighbors) {

  /*
  Due to hopping in 16 neighbor pattern, need to seed
     a cluster of goal states--using 4 corners with (iGoal, jGoal)
     being one corner
     */

  // Goal
  int iGoal = floor(p_goal[0] - 1); // 0-indexing
  if (iGoal < 0) {
    iGoal = 0;
  } else if (iGoal > m - 2) {
    iGoal = m - 2;
  }
  int jGoal = floor(p_goal[1] - 1);
  if (jGoal < 0) {
    jGoal = 0;
  } else if (jGoal > n - 2) {
    jGoal = n - 2;
  }
  int aGoal = round(nNeighbors / (2 * M_PI) * p_goal[2]);
  aGoal = aGoal % nNeighbors;
  if (aGoal < 0) {
    aGoal += nNeighbors;
  }
  int indGoal = iGoal + m * jGoal + m * n * aGoal; // linear index

  // Start
  int iStart = round(p_start[0] - 1);
  if (iStart < 0) {
    iStart = 0;
  } else if (iStart > m - 1) {
    iStart = m - 1;
  }
  int jStart = round(p_start[1] - 1);
  if (jStart < 0) {
    jStart = 0;
  } else if (jStart > n - 1) {
    jStart = n - 1;
  }
  int aStart = round(nNeighbors / (2 * M_PI) * p_start[2]);
  aStart = aStart % nNeighbors;
  if (aStart < 0) {
    aStart += nNeighbors;
  }

  // Map size
  size_t nMatrixNodes = m * n;

  // 3D with angle, so indexing is painful
  // linear index
  int indStart = iStart + m * jStart + m * n * aStart;

  // Initiate cost to go values
  for (int i = 0; i < nNeighbors * m * n; i++) {
    cost_to_go[i] = INFINITY;
  }

  // Priority queue implementation as STL set
  std::set<CostNodePair> Q; // Sorted set of (cost to go, node)
  // Seeding goal states
  // TODO: Ensure indices are all valid
  cost_to_go[indGoal] = 0;
  Q.insert(CostNodePair(0, indGoal));
  cost_to_go[indGoal + 1] = 0;
  Q.insert(CostNodePair(0, indGoal + 1));
  cost_to_go[indGoal + m] = 0;
  Q.insert(CostNodePair(0, indGoal + m));
  cost_to_go[indGoal + m + 1] = 0;
  Q.insert(CostNodePair(0, indGoal + m + 1));

  int nNode = 0;
  while (!Q.empty()) {
    nNode++;
    // Fetch closest node in queue
    CostNodePair top = *Q.begin();
    Q.erase(Q.begin());
    double c0 = top.first;
    int ind0 = top.second;

    // Short circuit computation if path to start has been found:
    if (c0 > STOP_FACTOR * cost_to_go[indStart]) {
      break;
    }

    // Array subscripts of node:
    int a0 = ind0 / nMatrixNodes;
    int ij0 = ind0 - a0 * nMatrixNodes;
    int j0 = ij0 / m;
    int i0 = ij0 % m;
    // Iterate over neighbor nodes:
    for (int ashift = -1; ashift <= +1; ashift++) {
      // Non-negative heading index
      int a1 = (a0 + nNeighbors + ashift) % nNeighbors;

      int ioffset = neighbors[a1].ioffset;
      int joffset = neighbors[a1].joffset;

      int i1 = i0 - ioffset;
      if ((i1 < 0) || (i1 >= m))
        continue;
      int j1 = j0 - joffset;
      if ((j1 < 0) || (j1 >= n))
        continue;

      double cost = costmap[ij0];
      int koffset = floor(neighbors[a1].distance);
      for (int k = 1; k <= koffset; k++) {
        int ij = ij0 - k * (m * joffset + ioffset) / koffset;
        if (costmap[ij] > cost) {
          cost = costmap[ij];
        }
      }

      if (ashift != 0) {
        cost *= TURN_COST;
      }

      int ind1 = i1 + m * j1 + nMatrixNodes * a1;
      double c1 = c0 + cost * neighbors[a1].distance;

      // Heuristic cost:
      // double h1 = sqrt((iStart-i1)*(iStart-i1)+(jStart-j1)*(jStart-j1));

      double c2g = cost_to_go[ind1];

      if (c1 < c2g) {
        if (!isinf(c2g)) {
          Q.erase(Q.find(CostNodePair(c2g, ind1)));
        }
        // { Q.erase(CostNodePair(c2g, ind1)); }
        cost_to_go[ind1] = c1;
        Q.insert(CostNodePair(c1, ind1));
      }
    }
  }

  return 0;
}
