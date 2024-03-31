#pragma once

#include <inttypes.h>

#define NUM_REGS 256
#define MAX_BIT_CNTS 4

typedef struct reg_orders {
    uint32_t raw_orders[NUM_REGS][MAX_BIT_CNTS];
    uint32_t exp_orders[NUM_REGS][MAX_BIT_CNTS];
    uint32_t struct_size[NUM_REGS];
} reg_orders;


void get_reg_orders(reg_orders* ro, char* filename);

uint32_t expand(uint16_t custom_addr, reg_orders* ro, uint32_t *reg_buf, uint32_t buf_len, char *response, uint32_t res_len);
