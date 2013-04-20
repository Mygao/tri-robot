/* 
   Lua interface to Image Processing utilities

   To compile on Mac OS X:
   g++ -arch i386 -o luaImageUtil.dylib -bundle -undefined dynamic_lookup luaImageUtil.cpp -lm
 */

#ifdef __cplusplus
extern "C" {
#endif

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#ifdef __cplusplus
}
#endif

#include <stdint.h>
#include <math.h>
#include <vector>
#include <string>
#include <algorithm>

#include "block_bitor.h"
#include "ConnectRegions.h"

#include "lua_color_stats.h"
#include "lua_color_count.h"
#include "lua_colorlut_gen.h"
#include "lua_connect_regions.h"
#include "lua_goal_posts.h"
#include "lua_field_lines.h"
#include "lua_field_spots.h"
#include "lua_field_occupancy.h"
#include "lua_robots.h"

#include <iostream>

//Downsample camera YUYV image for monitor

static int lua_subsample_yuyv2yuyv(lua_State *L){
  static std::vector<uint32_t> yuyv_array;

  // 1st Input: Original YUYV-format input image
  uint32_t *yuyv = (uint32_t *) lua_touserdata(L, 1);
  if ((yuyv == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input YUYV not light user data");
  }
  // 2nd Input: Width (in YUYV macropixels) of the original YUYV image
  int m = luaL_checkint(L, 2);
  // 3rd Input: Height (in YUVY macropixels) of the original YUYV image
  int n = luaL_checkint(L, 3);
  // 4th Input: How much to subsample 
  int subsample_rate = luaL_checkint(L, 4);

  yuyv_array.resize( m*n/subsample_rate/subsample_rate );
  int yuyv_ind = 0;

  for (int j = 0; j < n; j++){
    for (int i = 0; i < m; i++) {
      if (((i%subsample_rate==0) && (j%subsample_rate==0)) || subsample_rate==1)	{
        yuyv_array[yuyv_ind++] = *yuyv;
      }
      yuyv++;
    }
  }

  // Pushing light data
  lua_pushlightuserdata(L, &yuyv_array[0]);
  return 1;
}



static int lua_subsample_yuyv2yuv(lua_State *L){
  // Structure this is an array of 8bit channels
  // Y,U,V,Y,U,V
  // Row, Row, Row...
  static std::vector<uint8_t> yuv_array;

  // 1st Input: Original YUYV-format input image
  uint32_t *yuyv = (uint32_t *) lua_touserdata(L, 1);
  if ((yuyv == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input YUYV not light user data");
  }

  // 2nd Input: Width (in YUYV macropixels) of the original YUYV image
  int m = luaL_checkint(L, 2);

  // 3rd Input: Height (in YUVY macropixels) of the original YUYV image
  int n = luaL_checkint(L, 3);

  // 4th Input: How much to subsample 
  // subsample_amount == 1: use only one of the Y channels
  // subsample_amount == 2: use only one of the Y channels, every other macropixel
  // TODO: subsample_amount == 0: use only both Y channels
  int subsample_rate = luaL_checkint(L, 4);

  // Image is 3 bytes for 3 channels, times the total num of pixels
  yuv_array.resize( 3*(m*n/2) );
  int yuv_ind = 0;
  for (int j = 0; j < n; j++) {
    for (int i = 0; i < m; i++) {
      if (((i%subsample_rate==0) && (j%subsample_rate==0)) || subsample_rate==1)	{
        //YUYV -> Y8U8V8
        uint8_t indexY= (*yuyv & 0xFF000000) >> 24;
        uint8_t indexU= (*yuyv & 0x0000FF00) >> 8;
        uint8_t indexV= (*yuyv & 0x000000FF) >> 0;
        yuv_array[yuv_ind++] = indexY;
        yuv_array[yuv_ind++] = indexU;
        yuv_array[yuv_ind++] = indexV;
      }
      yuyv++;
    }
    // Skip every other line (to maintain image ratio)
    yuyv += m;
    j++;
  }

  // Pushing light data
  lua_pushlightuserdata(L, &yuv_array[0]);
  return 1;

}

static int lua_rgb_to_index(lua_State *L) {
  static std::vector<uint32_t> index;

  uint8_t *rgb = (uint8_t *) lua_touserdata(L, 1);
  if ((rgb == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input RGB not light user data");
  }
  int n = luaL_checkint(L, 2);

  index.resize(n);
  for (int i = 0; i < n; i++) {
    uint8_t r = *rgb++;
    uint8_t g = *rgb++;
    uint8_t b = *rgb++;

    uint8_t y = g;
    uint8_t u = 128 + (b-g)/2;
    uint8_t v = 128 + (r-g)/2;

    // Construct Y6U6V6 index
    index[i] = ((v & 0xFC) >> 2) | ((u & 0xFC) << 4) | ((y & 0xFC) << 10);
  }
  lua_pushlightuserdata(L, &index[0]);
  return 1;
}

static int lua_rgb_to_yuyv(lua_State *L) {
  static std::vector<uint32_t> yuyv;

  uint8_t *rgb = (uint8_t *) lua_touserdata(L, 1);
  if ((rgb == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input RGB not light user data");
  }
  int m = luaL_checkint(L, 2);
  int n = luaL_checkint(L, 3);

  yuyv.resize(m*n/2);

  int count=0;
  for (int i = 0; i < n; i++){
    for (int j = 0; j < m; j++) {
      uint8_t r = *rgb++;
      uint8_t g = *rgb++;
      uint8_t b = *rgb++;

      uint8_t y = g;
      uint8_t u = 128 + (b-g)/2;
      uint8_t v = 128 + (r-g)/2;

      // Construct Y6U6V6 index
      //SJ: only convert every other pixels (to make m/2 by n yuyv matrix)
      if (j%2==0)
        yuyv[count++] = (v << 24) | (y << 16) | (u << 8) | y;
    }
  }
  lua_pushlightuserdata(L, &yuyv[0]);
  return 1;
}

// Only labels every other pixel
static int lua_yuyv_to_label(lua_State *L) {
  static std::vector<uint8_t> label;

  // 1st Input: Original YUYV-format input image
  uint32_t *yuyv = (uint32_t *) lua_touserdata(L, 1);
  if ((yuyv == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input YUYV not light user data");
  }

  // 2nd Input: YUYV->Label Lookup Table
  uint8_t *cdt = (uint8_t *) lua_touserdata(L, 2);
  if (cdt == NULL) {
    return luaL_error(L, "Input CDT not light user data");
  }

  // 3rd Input: Width (in YUYV macropixels) of the original YUYV image
  int m = luaL_checkint(L, 3);

  // 4th Input: Height (in YUVY macropixels) of the original YUYV image
  int n = luaL_checkint(L, 4);

  // Label will be half the height and half the width of the original image
  label.resize(m*n/2);
  int label_ind = 0;

  for (int j = 0; j < n/2; j++){
    for (int i = 0; i < m; i++) {

      // Construct Y6U6V6 index
      uint32_t index = ((*yuyv & 0xFC000000) >> 26)  
        | ((*yuyv & 0x0000FC00) >> 4)
        | ((*yuyv & 0x000000FC) << 10);

      // Put labeled pixel into label vector
      label[label_ind] = cdt[index];

      yuyv++;
      label_ind++;
    }
    // Skip every other line (to maintain image ratio)
    yuyv += m;
  }
  // Pushing light data
  lua_pushlightuserdata(L, &label[0]);
  return 1;
}


// Only labels every other pixel for obstacle lut
static int lua_yuyv_to_label_obs(lua_State *L) {
  static std::vector<uint8_t> label;

  // 1st Input: Original YUYV-format input image
  uint32_t *yuyv = (uint32_t *) lua_touserdata(L, 1);
  if ((yuyv == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input YUYV not light user data");
  }

  // 2nd Input: YUYV->Label Lookup Table
  uint8_t *cdt = (uint8_t *) lua_touserdata(L, 2);
  if (cdt == NULL) {
    return luaL_error(L, "Input CDT not light user data");
  }

  // 3rd Input: Width (in YUYV macropixels) of the original YUYV image
  int m = luaL_checkint(L, 3);

  // 4th Input: Height (in YUVY macropixels) of the original YUYV image
  int n = luaL_checkint(L, 4);

  // Label will be half the height and half the width of the original image
  label.resize(m*n/2);
  int label_ind = 0;

  for (int j = 0; j < n/2; j++){
    for (int i = 0; i < m; i++) {

      // Construct Y6U6V6 index
      uint32_t index = ((*yuyv & 0xFC000000) >> 26)  
        | ((*yuyv & 0x0000FC00) >> 4)
        | ((*yuyv & 0x000000FC) << 10);

      // Put labeled pixel into label vector
      label[label_ind] = cdt[index];

      yuyv++;
      label_ind++;
    }
    // Skip every other line (to maintain image ratio)
    yuyv += m;
  }
  // Pushing light data
  lua_pushlightuserdata(L, &label[0]);
  return 1;
}


static int lua_rgb_to_label_obs(lua_State *L) {
  static std::vector<uint8_t> label;

  // 1st Input: Original RGB-format input image
  uint8_t *rgb = (uint8_t *) lua_touserdata(L, 1);
  if ((rgb == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input RGB not light user data");
  }

  // 2nd Input: YUYV->Label Lookup Table
  uint8_t *cdt = (uint8_t *) lua_touserdata(L, 2);
  if (cdt == NULL) {
    return luaL_error(L, "Input CDT not light user data");
  }

  // 3rd Input: Width (in pixels) of the original RGB image  
  int m = luaL_checkint(L, 3);
  // 4th Input: Width (in pixels) of the original RGB image
  int n = luaL_checkint(L, 4);

  label.resize(m*n);
  uint32_t label_ind = 0;
  for (int i = 0; i < n; i++){
    for (int j = 0; j < m; j++) {
      uint8_t r = *rgb++;
      uint8_t g = *rgb++;
      uint8_t b = *rgb++;

      uint8_t y = g;
      uint8_t u = 128 + (b-g)/2;
      uint8_t v = 128 + (r-g)/2;

      // Construct Y6U6V6 index
      uint32_t index = ((v & 0xFC) >> 2) | ((u & 0xFC) << 4) | ((y & 0xFC) << 10);
      label[label_ind] = cdt[index];
      label_ind++;
    }
  }
  lua_pushlightuserdata(L, &label[0]);
  return 1;
}


static int lua_rgb_to_label(lua_State *L) {
  static std::vector<uint8_t> label;

  // 1st Input: Original RGB-format input image
  uint8_t *rgb = (uint8_t *) lua_touserdata(L, 1);
  if ((rgb == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input RGB not light user data");
  }

  // 2nd Input: YUYV->Label Lookup Table
  uint8_t *cdt = (uint8_t *) lua_touserdata(L, 2);
  if (cdt == NULL) {
    return luaL_error(L, "Input CDT not light user data");
  }

  // 3rd Input: Width (in pixels) of the original RGB image  
  int m = luaL_checkint(L, 3);
  // 4th Input: Width (in pixels) of the original RGB image
  int n = luaL_checkint(L, 4);

  label.resize(m*n);
  uint32_t label_ind = 0;
  for (int i = 0; i < n; i++){
    for (int j = 0; j < m; j++) {
      uint8_t r = *rgb++;
      uint8_t g = *rgb++;
      uint8_t b = *rgb++;

      uint8_t y = g;
      uint8_t u = 128 + (b-g)/2;
      uint8_t v = 128 + (r-g)/2;

      // Construct Y6U6V6 index
      uint32_t index = ((v & 0xFC) >> 2) | ((u & 0xFC) << 4) | ((y & 0xFC) << 10);
      label[label_ind] = cdt[index];
      label_ind++;
    }
  }
  lua_pushlightuserdata(L, &label[0]);
  return 1;
}

static int lua_index_to_label(lua_State *L) {
  static std::vector<uint8_t> label;

  uint32_t *index = (uint32_t *) lua_touserdata(L, 1);
  if ((index == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input INDEX not light user data");
  }

  uint8_t *cdt = (uint8_t *) lua_touserdata(L, 2);
  if (cdt == NULL) {
    return luaL_error(L, "Input CDT not light user data");
  }

  int n = luaL_checkint(L, 3);

  label.resize(n);
  for (int i = 0; i < n; i++) {
    label[i] = cdt[index[i]];
  }
  lua_pushlightuserdata(L, &label[0]);
  return 1;
}

static int lua_block_bitor(lua_State *L) {
  uint8_t *label = (uint8_t *) lua_touserdata(L, 1);
  if ((label == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input LABEL not light user data");
  }
  int mx = luaL_checkint(L, 2);
  int nx = luaL_checkint(L, 3);
  int msub = luaL_checkint(L, 4);
  int nsub = luaL_checkint(L, 5);

  uint8_t *block = block_bitor(label, mx, nx, msub, nsub);
  lua_pushlightuserdata(L, block);
  return 1;
}

static int lua_block_bitor_obs(lua_State *L) {
  uint8_t *label = (uint8_t *) lua_touserdata(L, 1);
  if ((label == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input LABEL not light user data");
  }
  int mx = luaL_checkint(L, 2);
  int nx = luaL_checkint(L, 3);
  int msub = luaL_checkint(L, 4);
  int nsub = luaL_checkint(L, 5);

  uint8_t *block = block_bitor_obs(label, mx, nx, msub, nsub);
  lua_pushlightuserdata(L, block);
  return 1;
}

//For OP
//bitwise OR using tilted bounding box

static int lua_tilted_block_bitor(lua_State *L) {
  uint8_t *label = (uint8_t *) lua_touserdata(L, 1);
  if ((label == NULL) || !lua_islightuserdata(L, 1)) {
    return luaL_error(L, "Input LABEL not light user data");
  }
  int mx = luaL_checkint(L, 2);
  int nx = luaL_checkint(L, 3);
  int msub = luaL_checkint(L, 4);
  int nsub = luaL_checkint(L, 5);
  double tiltAngle = luaL_optnumber(L, 6, 0.0);

  uint8_t *block = tilted_block_bitor(label, mx, nx, msub, nsub, tiltAngle );
  lua_pushlightuserdata(L, block);
  return 1;
}

static const struct luaL_reg imageProc_lib [] = {
  {"label_to_mask", lua_label_to_mask},
  {"yuyv_mask_to_lut", lua_yuyv_mask_to_lut},
  {"rgb_mask_to_lut", lua_rgb_mask_to_lut},

  {"rgb_to_index", lua_rgb_to_index},
  {"rgb_to_yuyv", lua_rgb_to_yuyv},
  {"rgb_to_label", lua_rgb_to_label},
  {"rgb_to_label_obs", lua_rgb_to_label_obs},
  {"yuyv_to_label", lua_yuyv_to_label},
  {"yuyv_to_label_obs", lua_yuyv_to_label_obs},
  {"index_to_label", lua_index_to_label},

  {"color_count", lua_color_count},
  {"color_count_obs", lua_color_count_obs},

  {"color_stats", lua_color_stats},
  {"tilted_color_stats", lua_tilted_color_stats},

  {"block_bitor", lua_block_bitor},
  {"block_bitor_obs", lua_block_bitor_obs},
  {"tilted_block_bitor", lua_tilted_block_bitor},

  {"connected_regions", lua_connected_regions},
  {"connected_regions_obs", lua_connected_regions_obs},

  {"goal_posts", lua_goal_posts},
  {"tilted_goal_posts", lua_tilted_goal_posts},
  {"field_lines", lua_field_lines},
  {"field_spots", lua_field_spots},
  {"field_occupancy", lua_field_occupancy},
  {"robots", lua_robots},
  {"subsample_yuyv2yuv", lua_subsample_yuyv2yuv},
  {"subsample_yuyv2yuyv", lua_subsample_yuyv2yuyv},
  {NULL, NULL}
};

extern "C"
int luaopen_ImageProc (lua_State *L) {
  luaL_register(L, "ImageProc", imageProc_lib);

  return 1;
}
