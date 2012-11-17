#include "lualcm_rpc_t.h"
#include "lualcm.h"
#include "lcm_rpc_t.h"
#include <lcm/lcm.h>
#include <stdint.h>

/****************************************************************************
** This file should be generated automatically
*****************************************************************************/

static void lua_lcm_rpc_t_encode(lua_State *L, lcm_rpc_t *msg)
{
  /***************************  Type Specific Code ****************************/
  lua_getfield(L, 3, "process_id");
  if (!lua_isnil(L, 4))
    msg->process_id = (int32_t)lua_tonumber(L, 4);
  lua_pop(L, 1);

  lua_getfield(L, 3, "request_id");
  if (!lua_isnil(L, 4))
    msg->request_id = (int32_t)lua_tonumber(L, 4);
  lua_pop(L, 1);

  lua_getfield(L, 3, "nbytes");
  if (!lua_isnil(L, 4))
    msg->nbytes = (int32_t)lua_tonumber(L, 4);
  lua_pop(L, 1);

  lua_getfield(L, 3, "eval_string");
  if (!lua_isnil(L, 4))
    memcpy(msg->eval_string, lua_tostring(L, 4), msg->nbytes);
  lua_pop(L, 1);
  /****************************************************************************/
}

static void lua_lcm_rpc_t_decode(lua_State *L, lcm_rpc_t *msg)
{
  /***************************  Type Specific Code ****************************/
  lua_pushstring(L, "process_id");
  lua_pushinteger(L, msg->process_id);
  lua_settable(L, -3);

  lua_pushstring(L, "request_id");
  lua_pushinteger(L, msg->request_id);
  lua_settable(L, -3);

  lua_pushstring(L, "nbytes");
  lua_pushinteger(L, msg->nbytes);
  lua_settable(L, -3);

  lua_pushstring(L, "eval_string");
  lua_pushlstring(L, msg->eval_string, msg->nbytes);
  lua_settable(L, -3);
  /****************************************************************************/
}

static void lua_lcm_rpc_t_handler(const lcm_recv_buf_t *rbuf, const char *channel,
                                  const lcm_rpc_t *msg, void *userdata)
{
  /* push message handler */
  lua_lcm_handler_t *handler = (lua_lcm_handler_t *)userdata;
  lua_State *L = handler->L;
  lua_rawgeti(L, LUA_REGISTRYINDEX, handler->reference);

  /* push channel name */
  lua_pushstring(L, channel);

  /* push message table */
  lua_newtable(L);
  lua_lcm_rpc_t_decode(L, msg);

  /* call handler */
  lua_call(L, 2, 0);
} 

static int lua_lcm_rpc_t_publish(lua_State *L)
{
  lua_lcm_t *lcm = lua_checklcm(L, 1);
  const char *channel = luaL_checkstring(L, 2);
  lcm_rpc_t msg;
  int result;

  /* get message struct */
  if (!lua_istable(L, 3))
   return luaL_error(L, "invalid message type");
  lua_lcm_rpc_t_encode(L, &msg);

  /* publish message */
  result = lcm_rpc_t_publish(lcm->lcm, channel, &msg);
  lua_pushinteger(L, result);
  return 1;
};

static int lua_lcm_rpc_t_subscribe(lua_State *L)
{
  lua_lcm_t *lcm = lua_checklcm(L, 1);
  const char *channel = luaL_checkstring(L, 2);
  lcm_rpc_t_subscription_t *subs;
  lua_lcm_handler_t *handler;

  /* initialize handler for lua callback */
  if (!lua_isfunction(L, 3))
    return luaL_error(L, "invalid callback function");
  if (lcm->n_handlers >= MAX_HANDLERS)
  {
    /* max handlers exceeded */
    lua_pushnil(L);
    return 1;
  }
  handler = &(lcm->handlers[lcm->n_handlers++]);
  handler->reference = luaL_ref(L, LUA_REGISTRYINDEX);
  handler->L = L;

  /* subscribe to message */
  subs = lcm_rpc_t_subscribe(lcm->lcm, channel, lua_lcm_rpc_t_handler, handler);
  lua_pushlightuserdata(L, subs);
  return 1;
}

static int lua_lcm_rpc_t_unsubscribe(lua_State *L)
{
  lua_lcm_t *lcm = lua_checklcm(L, 1);
  lcm_rpc_t_subscription_t *subs = NULL;
  int result;

  if (!lua_islightuserdata(L, 2))
    return luaL_error(L, "invalid subscription handle");
  subs = (lcm_rpc_t_subscription_t *)lua_touserdata(L, 2);

  /* unsubscribe from message */
  result = lcm_rpc_t_unsubscribe(lcm->lcm, subs);
  lua_pushinteger(L, result);
  return 1;
}

static int lua_lcm_rpc_t_subscription_set_queue_capacity(lua_State *L)
{
  lua_lcm_t *lcm = lua_checklcm(L, 1);
  lcm_rpc_t_subscription_t *subs = NULL;
  int num_messages, result;

  if (!lua_islightuserdata(L, 2))
    return luaL_error(L, "invalid subscription handle");
  subs = (lcm_rpc_t_subscription_t *)lua_touserdata(L, 2);

  /* set queue capacity for subscription */
  num_messages = luaL_checkint(L, 3);
  result = lcm_rpc_t_subscription_set_queue_capacity(subs, num_messages);
  lua_pushinteger(L, result);
  return 1;
}

static const struct luaL_reg lcm_rpc_t_methods[] = {
  {"rpc_t_publish", lua_lcm_rpc_t_publish},
  {"rpc_t_subscribe", lua_lcm_rpc_t_subscribe},
  {"rpc_t_unsubscribe", lua_lcm_rpc_t_unsubscribe},
  {"rpc_t_subscription_set_queue_capacity",
    lua_lcm_rpc_t_subscription_set_queue_capacity},
  {NULL, NULL}
};

int luaopen_lcm_rpc_t(lua_State *L)
{
  /* register type-specific methods in lcm module */
  if (luaL_loadstring(L, "require('lcm')") || lua_pcall(L, 0, 0, 0))
    return luaL_error(L, "unable to require lcm module"); 
  luaL_getmetatable(L, "lcm_mt");
  luaL_register(L, NULL, lcm_rpc_t_methods);
  return 1;
};
