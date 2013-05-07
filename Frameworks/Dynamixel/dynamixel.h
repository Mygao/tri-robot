#ifndef __DYNAMIXEL_H
#define __DYNAMIXEL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define DYNAMIXEL_PACKET_HEADER (255) // FF
#define DYNAMIXEL_PACKET_HEADER_2 (255) //FF
#define DYNAMIXEL_PACKET_HEADER_3 (253) //FD
#define DYNAMIXEL_PACKET_STUFFING (0) //XX stuffing
#define DYNAMIXEL_PARAMETER_MAX (250)
#define DYNAMIXEL_BROADCAST_ID (254)

#define INST_PING (1)
#define INST_READ (2)
#define INST_WRITE (3)
#define INST_REG_WRITE (4)
#define INST_ACTION (5)
#define INST_RESET (6)
#define INST_SYNC_WRITE (131)
#define INST_BULK_READ (146)

#define ERRBIT_VOLTAGE          (1)
#define ERRBIT_ANGLE            (2)
#define ERRBIT_OVERHEAT         (4)
#define ERRBIT_RANGE            (8)
#define ERRBIT_CHECKSUM         (16)
#define ERRBIT_OVERLOAD         (32)
#define ERRBIT_INSTRUCTION      (64)

#define DXL_LOBYTE(w) ((uint8_t)(((uint16_t)(w)) & 0xff))
#define DXL_HIBYTE(w) ((uint8_t)((((uint16_t)(w)) >> 8) & 0xff))

typedef struct DynamixelPacket {
  uint8_t header1;
  uint8_t header2;
  uint8_t id;
  uint8_t length; // length does not include first 4 bytes
  uint8_t instruction; // or error for status packets
  uint8_t parameter[DYNAMIXEL_PARAMETER_MAX]; // reserve for maximum packet size
  uint8_t checksum; // Needs to be copied at end of parameters
} DynamixelPacket;

  DynamixelPacket *dynamixel_instruction(uint8_t id,
					 uint8_t inst,
					 uint8_t *parameter,
					 uint8_t nparameter);
  DynamixelPacket *dynamixel_instruction_read_data(uint8_t id,
						   uint8_t address, uint8_t n);
  DynamixelPacket *dynamixel_instruction_write_data(uint8_t id,
						    uint8_t address,
						    uint8_t data[], uint8_t n);
  DynamixelPacket *dynamixel_instruction_reg_write(uint8_t id,
						   uint8_t address,
						   uint8_t data[], uint8_t n);
  DynamixelPacket *dynamixel_instruction_action();
  DynamixelPacket *dynamixel_instruction_ping(int id);
  DynamixelPacket *dynamixel_instruction_reset(int id);
  DynamixelPacket *dynamixel_instruction_sync_write(uint8_t address,
						    uint8_t len,
						    uint8_t data[], uint8_t n);


  //added for bulk read
  DynamixelPacket *dynamixel_instruction_bulk_read_data(
	uint8_t id_cm730, uint8_t id[], uint8_t address, uint8_t len, uint8_t n);
  

  int dynamixel_input(DynamixelPacket *pkt, uint8_t c, int n);

// Add for Version 2.0 checksum	
static uint16_t update_crc( uint16_t crc_accum, const unsigned char *data_blk_ptr, uint16_t data_blk_size );
  
#ifdef __cplusplus
}
#endif

#endif // __DYNAMIXEL_H
