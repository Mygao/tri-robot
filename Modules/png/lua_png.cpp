/*
 * Copyright 2002-2010 Guillaume Cottenceau.
 *
 * This software may be freely redistributed under the terms
 * of the X11 license.
 * 
 * lua wrapper by Yida Zhang <yida@seas.upenn.edu>
 * Stephen McGill <smcgill3@seas.upenn.edu>
 * University of Pennsylvania
 */

// http://www.libpng.org/pub/png/libpng-1.2.5-manual.html

#include <lua.hpp>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <sstream>
#include <istream>
#include <stdint.h>

#define MT_NAME "png_mt"
#include <png.h>

#ifdef TORCH
#include <torch/luaT.h>
#include <torch/TH/TH.h>
#endif

 typedef struct {
  int width, height, stride;
  png_byte color_type;
  png_byte bit_depth;
  
  png_structp png_ptr;
  png_infop info_ptr;
  int number_of_passes;
  png_bytep * row_pointers;
} structPNG;

struct mem_encode {
  char * buffer;
  int size;
};

void abort_(const char * s, ...)
{
  va_list args;
  va_start(args, s);
  vfprintf(stderr, s, args);
  fprintf(stderr, "\n");
  va_end(args);
  abort();
}

static structPNG * lua_checkpng(lua_State *L, int narg) {
  void *ud = luaL_checkudata(L, narg, MT_NAME);
  luaL_argcheck(L, *(structPNG **)ud != NULL, narg, "invalid png");
  return (structPNG *)ud;
}

static int lua_png_getValue(lua_State *L) {
  structPNG *p = lua_checkpng(L, 1);
  int index = luaL_checkint(L, 2) - 1; // Convert lua 1-index to C 0-index

  if ((index < 0) || (index >= p->height * p->stride)) {
    lua_pushnil(L);
    return 1;
  }
  
  int r = index / p->stride;
  int c = index - r * p->stride;
  
  lua_pushinteger(L, p->row_pointers[r][c]);

  return 1;
}

static int lua_png_delete(lua_State *L) {
  structPNG *p = lua_checkpng(L, 1);
  /* cleanup heap allocation */
  int y;
  for (y=0; y<p->height; y++)
    free(p->row_pointers[y]);
  free(p->row_pointers);

  return 1;
}

static int lua_png_setValue(lua_State *L) {
  structPNG *p = lua_checkpng(L, 1);
  int index = luaL_checkint(L, 2) - 1; // Convert lua 1-index to C 0-index

  if ((index < 0) || (index >= p->height * p->stride)) {
    lua_pushnil(L);
    return 1;
  }

  int val = lua_tointeger(L, 3);
  
  int r = index / p->stride;
  int c = index - r * p->stride;

  p->row_pointers[r][c] = val;
  
  return 1;
}

static int lua_png_len(lua_State *L) {
  structPNG *p = lua_checkpng(L, 1);
  lua_pushinteger(L, p->height * p->stride);
  return 1;
}

static int lua_png_index(lua_State *L) {
  structPNG *p = lua_checkpng(L, 1);
  if ((lua_type(L, 2) == LUA_TNUMBER) && lua_tointeger(L, 2)) {
    // Numeric index:
    return lua_png_getValue(L);
  }

  // Get index through metatable:
  if (!lua_getmetatable(L, 1)) {lua_pop(L, 1); return 0;} // push metatable
  lua_pushvalue(L, 2); // copy key
  lua_rawget(L, -2); // get metatable function
  lua_remove(L, -2); // delete metatable
  return 1;
}

static int lua_png_load(lua_State *L) {
  const char* file_name = luaL_checkstring(L, 1);
  unsigned char* data = (unsigned char*) lua_touserdata(L, 2);
  if ((data == NULL) || !lua_islightuserdata(L, 2) )
    return luaL_error(L, "Input not light userdata");

  char header[8];    // 8 is the maximum size that can be checked

  /* open file and test for it being a png */
  FILE *fp = fopen(file_name, "rb");
  if (!fp)
    abort_("[read_png_file] File %s could not be opened for reading", file_name);
  int ret = fread(header, 1, 8, fp);
  if (png_sig_cmp((const png_bytep)header, 0, 8))
    abort_("[read_png_file] File %s is not recognized as a PNG file", file_name);

  /* initialize stuff */
  png_structp png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);

  if (!png_ptr)
    abort_("[read_png_file] png_create_read_struct failed");

  png_infop info_ptr = png_create_info_struct(png_ptr);
  if (!info_ptr)
    abort_("[read_png_file] png_create_info_struct failed");

  if (setjmp(png_jmpbuf(png_ptr)))
    abort_("[read_png_file] Error during init_io");

  png_init_io(png_ptr, fp);
  png_set_sig_bytes(png_ptr, 8);

  png_read_info(png_ptr, info_ptr);

  int width = png_get_image_width(png_ptr, info_ptr);
  int height = png_get_image_height(png_ptr, info_ptr);
  png_byte color_type = png_get_color_type(png_ptr, info_ptr);
  png_byte bit_depth = png_get_bit_depth(png_ptr, info_ptr);

  int number_of_passes = png_set_interlace_handling(png_ptr);
  png_read_update_info(png_ptr, info_ptr);

  /* read file */
  if (setjmp(png_jmpbuf(png_ptr)))
    abort_("[read_png_file] Error during read_image");

  int x, y, stride;
  stride = png_get_rowbytes(png_ptr, info_ptr);
  png_bytep * row_pointers = (png_bytep*) malloc(sizeof(png_bytep) * height);
  for (y=0; y<height; y++)
    row_pointers[y] = (png_byte*) malloc(png_get_rowbytes(png_ptr, info_ptr));

  png_read_image(png_ptr, row_pointers);

//  png_byte * ptr = data;
  for (y=0; y<height; y++) {
    memcpy(data, row_pointers[y], stride); 
    data += stride;
  }

  fclose(fp);

  return 1;
}

static int lua_png_new(lua_State *L) {
  structPNG *ud = (structPNG *)lua_newuserdata(L, sizeof(structPNG));

  const char* file_name = luaL_checkstring(L, 1);

  char header[8];    // 8 is the maximum size that can be checked

  /* open file and test for it being a png */
  FILE *fp = fopen(file_name, "rb");
  if (!fp)
    abort_("[read_png_file] File %s could not be opened for reading", file_name);
  int ret = fread(header, 1, 8, fp);
  if (png_sig_cmp((const png_bytep)header, 0, 8))
    abort_("[read_png_file] File %s is not recognized as a PNG file", file_name);

  /* initialize stuff */
  ud->png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);

  if (!ud->png_ptr)
    abort_("[read_png_file] png_create_read_struct failed");

  ud->info_ptr = png_create_info_struct(ud->png_ptr);
  if (!ud->info_ptr)
    abort_("[read_png_file] png_create_info_struct failed");

  if (setjmp(png_jmpbuf(ud->png_ptr)))
    abort_("[read_png_file] Error during init_io");

  png_init_io(ud->png_ptr, fp);
  png_set_sig_bytes(ud->png_ptr, 8);

  png_read_info(ud->png_ptr, ud->info_ptr);

  ud->width = png_get_image_width(ud->png_ptr, ud->info_ptr);
  ud->height = png_get_image_height(ud->png_ptr, ud->info_ptr);
  ud->color_type = png_get_color_type(ud->png_ptr, ud->info_ptr);
  ud->bit_depth = png_get_bit_depth(ud->png_ptr, ud->info_ptr);

  ud->number_of_passes = png_set_interlace_handling(ud->png_ptr);
  png_read_update_info(ud->png_ptr, ud->info_ptr);


  /* read file */
  if (setjmp(png_jmpbuf(ud->png_ptr)))
    abort_("[read_png_file] Error during read_image");

  ud->row_pointers = (png_bytep*) malloc(sizeof(png_bytep) * ud->height);

  int x, y;
  ud->stride = png_get_rowbytes(ud->png_ptr,ud->info_ptr);
  for (y=0; y<ud->height; y++)
    ud->row_pointers[y] = (png_byte*) malloc(png_get_rowbytes(ud->png_ptr,ud->info_ptr));

  png_read_image(ud->png_ptr, ud->row_pointers);

  fclose(fp);


  luaL_getmetatable(L, MT_NAME);
  lua_setmetatable(L, -2);
  return 1;
}

static int lua_png_read(lua_State *L) {
  unsigned char* data = (unsigned char*) lua_touserdata(L, 2);
  if ((data == NULL) || !lua_islightuserdata(L, 2) )
    return luaL_error(L, "Input not light userdata");
  
  data[0] = 34;
  for (int i = 0; i < 4; i++)
    printf("data %d\n", data[i]);

  return 1;
}

static int lua_png_write(lua_State *L) {
  structPNG *ud = lua_checkpng(L, 1);
  const char* file_name = luaL_checkstring(L, 2);

  /* create file */
  FILE *fp = fopen(file_name, "wb");
  if (!fp)
    abort_("[write_png_file] File %s could not be opened for writing", file_name);


  /* initialize stuff */
  ud->png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);

  if (!ud->png_ptr)
    abort_("[write_png_file] png_create_write_struct failed");

  ud->info_ptr = png_create_info_struct(ud->png_ptr);
  if (!ud->info_ptr)
    abort_("[write_png_file] png_create_info_struct failed");

  if (setjmp(png_jmpbuf(ud->png_ptr)))
    abort_("[write_png_file] Error during init_io");

  png_init_io(ud->png_ptr, fp);


  /* write header */
  if (setjmp(png_jmpbuf(ud->png_ptr)))
    abort_("[write_png_file] Error during writing header");

  png_set_IHDR(ud->png_ptr, ud->info_ptr, ud->width, ud->height,
   ud->bit_depth, ud->color_type, PNG_INTERLACE_NONE,
   PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);

  png_write_info(ud->png_ptr, ud->info_ptr);


  /* write bytes */
  if (setjmp(png_jmpbuf(ud->png_ptr)))
    abort_("[write_png_file] Error during writing bytes");

  png_write_image(ud->png_ptr, ud->row_pointers);


  /* end write */
  if (setjmp(png_jmpbuf(ud->png_ptr)))
    abort_("[write_png_file] Error during end of write");

  png_write_end(ud->png_ptr, NULL);

  fclose(fp);
  return 1;
}

static int lua_png_save(lua_State *L) {
  const char* file_name = luaL_checkstring(L, 1);
  unsigned char* data = (unsigned char*) lua_touserdata(L, 2);
  if ((data == NULL) || !lua_islightuserdata(L, 2) )
    return luaL_error(L, "Input not light userdata");

  int h = lua_tointeger(L, 3);
  int stride = lua_tointeger(L, 4);
  png_byte color_type = lua_tointeger(L, 5);
  int bit_depth = 8;
  int bytes_per_pixel = 3;
  if (color_type == PNG_COLOR_TYPE_GRAY)
    bytes_per_pixel = 1;
  else if (color_type == PNG_COLOR_TYPE_RGB)
    bytes_per_pixel = 3;
  else if (color_type == PNG_COLOR_TYPE_RGB_ALPHA)
    bytes_per_pixel = 4;
  else if (color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
    bytes_per_pixel = 2;
  else
    bytes_per_pixel = 0;

  int w = stride / bytes_per_pixel;

  /* create file */
  FILE *fp = fopen(file_name, "wb");
  if (!fp)
    abort_("[write_png_file] File %s could not be opened for writing", file_name);

  /* initialize stuff */
  png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);

  if (!png_ptr)
    abort_("[write_png_file] png_create_write_struct failed");

  png_infop info_ptr = png_create_info_struct(png_ptr);
  if (!info_ptr)
    abort_("[write_png_file] png_create_info_struct failed");

  if (setjmp(png_jmpbuf(png_ptr)))
    abort_("[write_png_file] Error during init_io");

  png_init_io(png_ptr, fp);

  /* write header */
  if (setjmp(png_jmpbuf(png_ptr)))
    abort_("[write_png_file] Error during writing header");

  png_set_IHDR(png_ptr, info_ptr, w, h,
   bit_depth, color_type, PNG_INTERLACE_NONE,
   PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);

  png_write_info(png_ptr, info_ptr);

  /* write bytes */
  if (setjmp(png_jmpbuf(png_ptr)))
    abort_("[write_png_file] Error during writing bytes");

  png_bytep * row_pointers = (png_bytep*) malloc(sizeof(png_bytep) * h);
  int x, y;
  stride = png_get_rowbytes(png_ptr,info_ptr);
  for (y=0; y<h; y++) {
    row_pointers[y] = (png_byte*) malloc(stride);
    memcpy(row_pointers[y], data, stride);
    data += stride;
  }

  png_write_image(png_ptr, row_pointers);

  /* end write */
  if (setjmp(png_jmpbuf(png_ptr)))
    abort_("[write_png_file] Error during end of write");

  png_write_end(png_ptr, NULL);

  fclose(fp);
  return 1;
}

static int lua_png_pointer(lua_State *L) {
  structPNG *p = lua_checkpng(L, 1);
  return 1;
}

static int lua_png_width(lua_State *L) {
  structPNG *p = lua_checkpng(L, 1);
  lua_pushinteger(L, p->width);
  return 1;
}

static int lua_png_height(lua_State *L) {
  structPNG *p = lua_checkpng(L, 1);
  lua_pushinteger(L, p->height);
  return 1;
}

static int lua_png_color_type(lua_State *L) {
  structPNG *p = lua_checkpng(L, 1);
  lua_pushinteger(L, p->color_type);
  return 1;
}

static int lua_png_bit_depth(lua_State *L) {
  structPNG *p = lua_checkpng(L, 1);
  lua_pushinteger(L, p->bit_depth);
  return 1;
}

static int lua_png_stride(lua_State *L) {
  structPNG *p = lua_checkpng(L, 1);
  lua_pushinteger(L, p->stride);
  return 1;
}


void lua_png_write_string(png_structp png_ptr, png_bytep data, png_size_t length) {
//  printf("io string %ld\n", length);
  struct mem_encode * p = (struct mem_encode*) png_get_io_ptr(png_ptr);
  int nsize = p->size + length;

  if (p->buffer)
    p->buffer = (char *) realloc(p->buffer, nsize);
  else
    p->buffer = (char *) malloc(nsize);

  if (!p->buffer)
    png_error(png_ptr, "Init Buffer Error");

  memcpy(p->buffer + p->size, data, length);
  p->size += length;
}

static int lua_png_compress(lua_State *L) {

  unsigned char * data = NULL;
  size_t sz = 0;
	int w, h, bytes_per_pixel;
	int bit_depth = 8;
	
  if (lua_isstring(L, 1)) {
    data = (uint8_t *) lua_tolstring(L, 1, &sz); 
		w = lua_tointeger(L, 2);
		h = lua_tointeger(L, 3);
		bytes_per_pixel = luaL_optinteger(L, 4, 3);
  } else if (lua_islightuserdata(L, 1)) {
    if ( (data=(uint8_t *)lua_touserdata(L, 1))==NULL ){
      return luaL_error(L, "NULL userdata");
    }
		w = lua_tointeger(L, 2);
		h = lua_tointeger(L, 3);
		bytes_per_pixel = luaL_optinteger(L, 4, 3);
  }
	else if( lua_type(L, 1) == LUA_TNUMBER ){
		data = (uint8_t *)luaL_optlong(L, 1, 0);
    if (data == NULL) {
      return luaL_error(L, "Input image bad");
    }
		w = luaL_checkint(L, 2);
		h = luaL_checkint(L, 3);
    bytes_per_pixel = luaL_optinteger(L, 4, 3);
	}
#ifdef TORCH
	else if ( luaT_isudata(L, 1, "torch.ByteTensor") ) {
		// TODO: Make a bit more type safe
		THByteTensor* b_t = 
			(THByteTensor *) luaT_checkudata(L, 1, "torch.ByteTensor");
		// TODO: Check continguous (or add stride support)
		data = b_t->storage->data;
		// TODO: Ensure nDimension is 2
		// Use Torch dims if none given
		w  = luaL_optint(L, 2, b_t->size[1]);
		h = luaL_optint(L, 3, b_t->size[0]);
		// Must give dims to set this, else assumed to be a byte tensor
		bytes_per_pixel = luaL_optinteger(L, 4, 1);
	}
#endif
	else {
		//printf("luaT_typename(L, 1): %s\n", luaT_typename(L, 1));
    return luaL_error(L, "Bad PNG Compress input");
  }

  png_byte color_type;
  switch(bytes_per_pixel) {
    case 1:
    color_type = PNG_COLOR_TYPE_GRAY;
    break;
    case 2:
    color_type = PNG_COLOR_TYPE_GRAY_ALPHA;
    break;
    case 3:
    color_type = PNG_COLOR_TYPE_RGB;
    break;
    case 4:
    color_type = PNG_COLOR_TYPE_RGB_ALPHA;
    break;
    default:
    return luaL_error(L, "Bad PNG Color type");
  }

  int stride = w * bytes_per_pixel;
  struct mem_encode state;
  state.buffer = NULL;
  state.size = 0;

  /* initialize stuff */
  png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
png_set_compression_level(png_ptr,9);

  if (!png_ptr)
    abort_("[write_png_file] png_create_write_struct failed");

  png_set_write_fn(png_ptr, &state, lua_png_write_string, NULL);

  png_infop info_ptr = png_create_info_struct(png_ptr);
  if (!info_ptr)
    abort_("[write_png_file] png_create_info_struct failed");

  if (setjmp(png_jmpbuf(png_ptr)))
    abort_("[write_png_file] Error during init_io");

  /* write header */
  if (setjmp(png_jmpbuf(png_ptr)))
    abort_("[write_png_file] Error during writing header");

  png_set_IHDR(png_ptr, info_ptr, w, h,
   bit_depth, color_type, PNG_INTERLACE_NONE,
   PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);

  png_write_info(png_ptr, info_ptr);

  /* write bytes */
  if (setjmp(png_jmpbuf(png_ptr)))
    abort_("[write_png_file] Error during writing bytes");

  png_bytep * row_pointers = (png_bytep*) malloc(sizeof(png_bytep) * h);
  int x, y;
  for (y=0; y<h; y++) {
    row_pointers[y] = (png_byte*) malloc(stride);
    memcpy(row_pointers[y], data, stride);
    data += stride;
  }

  png_write_image(png_ptr, row_pointers);

  /* end write */
  if (setjmp(png_jmpbuf(png_ptr)))
    abort_("[write_png_file] Error during end of write");

  png_write_end(png_ptr, NULL);

  if (state.size > 0)
    lua_pushlstring(L, (const char*)state.buffer, state.size);
  else
    return luaL_error(L, "Compress Error");

  if (state.buffer)
    free(state.buffer);

  return 1;
}

void lua_png_read_string(png_structp png_ptr, png_bytep data, png_size_t length) {
//  printf("length %d \n", length);
  struct mem_encode* a = (struct mem_encode*) png_get_io_ptr(png_ptr);
  memcpy(data, a->buffer, length);
  a->buffer += length;
}

static int lua_png_uncompress(lua_State *L) {
  struct mem_encode state;
  state.buffer = (char*)luaL_checkstring(L, 1);
  state.size = 0;

  structPNG *ud = (structPNG *)lua_newuserdata(L, sizeof(structPNG));

  char header[8];    // 8 is the maximum size that can be checked
  memcpy(header, state.buffer, 8);
  state.buffer += 8;
  state.size += 8;

  if (png_sig_cmp((const png_bytep)header, 0, 8))
    abort_("[read_png_stream] stream is not recognized as a PNG file");

  /* initialize stuff */
  ud->png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);

  if (!ud->png_ptr)
    abort_("[read_png_file] png_create_read_struct failed");

  ud->info_ptr = png_create_info_struct(ud->png_ptr);
  if (!ud->info_ptr)
    abort_("[read_png_file] png_create_info_struct failed");

  png_set_read_fn(ud->png_ptr, &state, lua_png_read_string);

  if (setjmp(png_jmpbuf(ud->png_ptr)))
    abort_("[read_png_file] Error during init_io");

  png_set_sig_bytes(ud->png_ptr, 8);
  png_read_info(ud->png_ptr, ud->info_ptr);
  png_set_keep_unknown_chunks(ud->png_ptr, 1, NULL, 0);

  ud->width = png_get_image_width(ud->png_ptr, ud->info_ptr);
  ud->height = png_get_image_height(ud->png_ptr, ud->info_ptr);
  ud->color_type = png_get_color_type(ud->png_ptr, ud->info_ptr);
  ud->bit_depth = png_get_bit_depth(ud->png_ptr, ud->info_ptr);

  ud->number_of_passes = png_set_interlace_handling(ud->png_ptr);
  png_read_update_info(ud->png_ptr, ud->info_ptr);

  /* read file */
  if (setjmp(png_jmpbuf(ud->png_ptr)))
    abort_("[read_png_file] Error during read_image");

  ud->row_pointers = (png_bytep*) malloc(sizeof(png_bytep) * ud->height);

  int x, y;
  ud->stride = png_get_rowbytes(ud->png_ptr,ud->info_ptr);
  for (y=0; y<ud->height; y++)
    ud->row_pointers[y] = (png_byte*) malloc(png_get_rowbytes(ud->png_ptr,ud->info_ptr));

  png_read_image(ud->png_ptr, ud->row_pointers);

  luaL_getmetatable(L, MT_NAME);
  lua_setmetatable(L, -2);
  return 1;
}

static const struct luaL_Reg png_Functions [] = {
  {"new", lua_png_new},
  {"load", lua_png_load},
  {"save", lua_png_save},
  {"compress", lua_png_compress},
  {"uncompress", lua_png_uncompress},
  {NULL, NULL}
};

static const struct luaL_Reg png_Methods [] = {
  {"pointer", lua_png_pointer},
  {"read", lua_png_read},
  {"write", lua_png_write},
  {"width", lua_png_width},
  {"height", lua_png_height},
  {"stride", lua_png_stride},
  {"color_type", lua_png_color_type},
  {"bit_depth", lua_png_bit_depth},
  {"__gc", lua_png_delete},
  {"__newindex", lua_png_setValue},
  {"__len", lua_png_len},
  {NULL, NULL}
};

#ifdef __cplusplus
extern "C"
#endif
int luaopen_png(lua_State *L) {
  luaL_newmetatable(L, MT_NAME);

  // Implement index method:
  lua_pushstring(L, "__index");
  lua_pushcfunction(L, lua_png_index);
  lua_settable(L, -3);

  luaL_register(L, NULL, png_Methods);
  luaL_register(L, "png", png_Functions);

  return 1;
}
