/*
Lua module to provide process dynamixel packets
*/

#include "dynamixel.h"
#include <lua.hpp>

static int lua_crc16(lua_State *L) {
	size_t nstr;
	const unsigned char *str = (unsigned char *)luaL_checklstring(L, 1, &nstr);
	uint16_t crc = dynamixel_crc(0, str, nstr);
	lua_pushnumber( L, DXL_LOBYTE(crc) );
	lua_pushnumber( L, DXL_HIBYTE(crc) );
	return 2;
}

static int lua_pushpacket(lua_State *L, DynamixelPacket *p) {
	if (p != NULL) {
		int nlen = p->length + 7;
		lua_pushlstring(L, (char *)p, nlen);
		return 1;
	}
	return 0;
}

static int lua_dynamixel_instruction_ping(lua_State *L) {
	int id = luaL_checkint(L, 1);
	DynamixelPacket *p = dynamixel_instruction_ping(id);
	return lua_pushpacket(L, p);
}

static int lua_dynamixel_instruction_read_data(lua_State *L) {
	int id = luaL_checkint(L, 1);
	unsigned char addr = luaL_checkint(L, 2);
	unsigned char len = luaL_optinteger(L, 3, 1);
	DynamixelPacket *p = dynamixel_instruction_read_data
		(id, addr, len);
	return lua_pushpacket(L, p);
}

//ADDED for bulk read
static int lua_dynamixel_instruction_bulk_read_data(lua_State *L) {
	uint8_t id_cm730 = luaL_checkint(L, 1);
	size_t nstr;
	const char *str = luaL_checklstring(L, 2, &nstr);
	uint8_t addr = luaL_checkint(L, 3);
	uint8_t len = luaL_checkint(L, 4);
	DynamixelPacket *p = dynamixel_instruction_bulk_read_data
		(id_cm730, (uint8_t *) str, addr, len, nstr);
	return lua_pushpacket(L, p);
}

static int lua_dynamixel_instruction_write_data(lua_State *L) {
	uint8_t id = luaL_checkint(L, 1);
	size_t naddr;
	const char *addr = luaL_checklstring(L, 2, &naddr);
	size_t nstr;
	const char *str = luaL_checklstring(L, 3, &nstr);
	DynamixelPacket *p = dynamixel_instruction_write_data
		(id, addr[0], addr[1], (uint8_t *)str, nstr);
	return lua_pushpacket(L, p);
}

static int lua_dynamixel_instruction_write_byte(lua_State *L) {
	uint8_t id = luaL_checkint(L, 1);
	size_t naddr;
	const char *addr = luaL_checklstring(L, 2, &naddr);
	uint8_t byte = luaL_checkint(L, 3);
	DynamixelPacket *p = dynamixel_instruction_write_data
		(id, addr[0], addr[1], &byte, 1); //TODO: endianness?????
	return lua_pushpacket(L, p);
}

static int lua_dynamixel_instruction_write_word(lua_State *L) {
	uint8_t id = luaL_checkint(L, 1);
	size_t naddr;
	const char *addr = luaL_checklstring(L, 2, &naddr);
	unsigned short word = luaL_checkint(L, 3);
	uint8_t byte[2];
	byte[0] = (word & 0x00FF);
	byte[1] = (word & 0xFF00) >> 8;
	DynamixelPacket *p = dynamixel_instruction_write_data
		(id, addr[0], addr[1], byte, 2);
	return lua_pushpacket(L, p);
}

static int lua_dynamixel_instruction_write_dword(lua_State *L) {
	uint8_t id = luaL_checkint(L, 1);
	size_t naddr;
	const char *addr = luaL_checklstring(L, 2, &naddr);
	unsigned short word = luaL_checkint(L, 3);
	uint8_t byte[4];
	byte[0] = (word & 0x00FF);
	byte[1] = (word & 0xFF00) >> 8;
	byte[2] = (word & 0xFF0000)>>16;
	byte[3] = (word & 0xFF000000)>>24;
	DynamixelPacket *p = dynamixel_instruction_write_data
		(id, addr[0], addr[1], byte, 4);
	return lua_pushpacket(L, p);
}

static int lua_dynamixel_instruction_sync_write(lua_State *L) {
	uint8_t addr = luaL_checkint(L, 1);
	uint8_t len = luaL_checkint(L, 2);
	size_t nstr;
	const char *str = luaL_checklstring(L, 3, &nstr);
	DynamixelPacket *p = dynamixel_instruction_sync_write
		(addr, len, (uint8_t *)str, nstr);
	return lua_pushpacket(L, p);
}

static int lua_dynamixel_input(lua_State *L) {
	size_t nstr;
	const char *str = luaL_checklstring(L, 1, &nstr);
	int nPacket = luaL_optinteger(L, 2, 1)-1;
	DynamixelPacket pkt;
	int ret = 0;
	if (str) {
		for (int i = 0; i < nstr; i++) {
			nPacket = dynamixel_input(&pkt, str[i], nPacket);
			if (nPacket < 0) {
				ret += lua_pushpacket(L, &pkt);
			}
		}
	}
	return ret;
}

static int lua_dynamixel_byte_to_word(lua_State *L) {
	int n = lua_gettop(L);
	int ret = 0;
	for (int i = 1; i < n; i += 2) {
		unsigned short byteLow = luaL_checkint(L, i);
		unsigned short byteHigh = luaL_checkint(L, i+1);
		unsigned short word = (byteHigh << 8) + byteLow;
		lua_pushnumber(L, word);
		ret++;
	}
	return ret;
}

static int lua_dynamixel_word_to_byte(lua_State *L) {
	int n = lua_gettop(L);
	int ret = 0;
	for (int i = 1; i <= n; i++) {
		unsigned short word = luaL_checkint(L, i);
		unsigned short byteLow = word & 0x00FF;
		lua_pushnumber(L, byteLow);
		ret++;
		unsigned short byteHigh = (word & 0xFF00)>>8;
		lua_pushnumber(L, byteHigh);
		ret++;
	}
	return ret;
}

static const struct luaL_reg dynamixelpacket_functions[] = {
	{"input", lua_dynamixel_input},
	{"ping", lua_dynamixel_instruction_ping},
	{"write_data", lua_dynamixel_instruction_write_data},
	{"write_byte", lua_dynamixel_instruction_write_byte},
	{"write_word", lua_dynamixel_instruction_write_word},
	{"write_dword", lua_dynamixel_instruction_write_dword},
	{"sync_write", lua_dynamixel_instruction_sync_write},
	{"read_data", lua_dynamixel_instruction_read_data},
	{"bulk_read_data", lua_dynamixel_instruction_bulk_read_data},
	{"word_to_byte", lua_dynamixel_word_to_byte},
	{"byte_to_word", lua_dynamixel_byte_to_word},
	{"crc16", lua_crc16},
	{NULL, NULL}
};

static const struct luaL_reg dynamixelpacket_methods[] = {
	{NULL, NULL}
};

#ifdef __cplusplus
extern "C"
#endif
int luaopen_DynamixelPacket (lua_State *L) {
	luaL_newmetatable(L, "dynamixelpacket_mt");

	// OO access: mt.__index = mt
	// Not compatible with array access
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_register(L, NULL, dynamixelpacket_methods);
	luaL_register(L, "DynamixelPacket", dynamixelpacket_functions);

	return 1;
}