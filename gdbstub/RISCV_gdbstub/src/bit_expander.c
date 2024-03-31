#include <stdio.h>
#include <string.h>
#include <assert.h>
#include "bit_expander.h"

#define mn(x,y)  (((x)<(y)) ? (x) : (y))
#define mx(x,y)  (((x)<(y)) ? (y) : (x))


static
const char hexchars[] = "0123456789abcdef";

static
void val_to_hex16 (const uint64_t val, const uint8_t xlen, char *buf)
{
    assert ((xlen == 8)
	    || (xlen == 16)
	    || (xlen == 32)
	    || (xlen == 64));

    buf[0]  = hexchars [(val >>  4) & 0xF];
    buf[1]  = hexchars [(val >>  0) & 0xF];
    if (xlen == 8) return;

    buf[2]  = hexchars [(val >> 12) & 0xF];
    buf[3]  = hexchars [(val >>  8) & 0xF];
    if (xlen == 16) return;

    buf[4]  = hexchars [(val >> 20) & 0xF];
    buf[5]  = hexchars [(val >> 16) & 0xF];
    buf[6]  = hexchars [(val >> 28) & 0xF];
    buf[7]  = hexchars [(val >> 24) & 0xF];
    if (xlen == 32) return;

    buf[8]  = hexchars [(val >> 36) & 0xF];
    buf[9]  = hexchars [(val >> 32) & 0xF];
    buf[10] = hexchars [(val >> 44) & 0xF];
    buf[11] = hexchars [(val >> 40) & 0xF];
    buf[12] = hexchars [(val >> 52) & 0xF];
    buf[13] = hexchars [(val >> 48) & 0xF];
    buf[14] = hexchars [(val >> 60) & 0xF];
    buf[15] = hexchars [(val >> 56) & 0xF];
}

int get_line(int* dst, char* line_buffer, FILE* fp) {
    char *cur = line_buffer;
    char *token = NULL;
    int bit_cnt = 0;

    while ((token = strtok(cur, " \n"))) {
        sscanf(token, "%d", dst+bit_cnt);

        cur = NULL;
        bit_cnt++;
    }

    int total = 0;
    for (int i = 0; i < bit_cnt; i++)
        total += dst[i];
    return total;
}

void get_reg_orders(reg_orders* ro, char* filename) {
    char buffer[10]; 

    FILE *fp = fopen(filename, "r");
    if (fp == NULL) {
        fprintf(stderr, "failed to open file: %s\n", filename);

        exit(1);
    }

    int num_regs;
    int max_bit_cnts;

    if (fgets(buffer, sizeof(buffer), fp) == NULL) {
        fprintf(stderr, "num_regs read failed\n");

        exit(1);
    }


    sscanf(buffer, "%d", &num_regs);

    if (num_regs >= NUM_REGS) {
        fprintf(stderr, "Found %d regs when maximum %d regs are supported. Increase NUM_REGS in bit_expander.h\n",
                num_regs, NUM_REGS);
        exit(1);
    }

    if (fgets(buffer, sizeof(buffer), fp) == NULL) {
        fprintf(stderr, "max_bit_cnts read failed\n");

        exit(1);
    }

    sscanf(buffer, "%d", &max_bit_cnts);

    char line_buffer[MAX_BIT_CNTS * 3 * sizeof(char)];

    int reg_idx = 0;

    while (fgets(line_buffer, MAX_BIT_CNTS * 3 * sizeof(char), fp) != NULL) {
        ro->struct_size[reg_idx] = get_line(ro->raw_orders[reg_idx], line_buffer, fp);

        fgets(line_buffer, MAX_BIT_CNTS * 3 * sizeof(char), fp);
        get_line(ro->exp_orders[reg_idx], line_buffer, fp);
        reg_idx++;
    }
    
    fclose(fp);
}

uint32_t extract(uint32_t raw_bit_size, uint32_t* byte_idx, uint32_t* bit_idx, 
    uint32_t* reg_buf) {
    uint32_t ret = 0;

    while (raw_bit_size > 0) {
        uint32_t consuming = mn(32 - *bit_idx, raw_bit_size);
        ret <<= consuming;

        
        int shift_cnt = 32 - *bit_idx;
        uint32_t mask = shift_cnt == 32 ? -1 : (1<<shift_cnt) - 1;

        uint32_t lower = reg_buf[*byte_idx] & mask;
        uint32_t cur_value = (lower >> (shift_cnt - consuming));
        ret |= cur_value;
        raw_bit_size -= consuming;

        *bit_idx += consuming;
        while (*bit_idx >= 32) {
            *bit_idx -= 32;
            (*byte_idx)++;
        }
    }

    return ret;
}

void adding(uint32_t val, int write_bits, uint32_t *ret_bytes, uint32_t *ret_bits, char *ret) {
    while (write_bits > 0) {
        uint32_t consuming = mn(32 - *ret_bits, write_bits);

        uint32_t mask = write_bits == 32 ? -1 : (1<<write_bits)-1;
        uint32_t writing = (val & mask) >> (write_bits - consuming);

        ret[*ret_bytes] |= (writing << (32 - *ret_bits - consuming));
        write_bits -= consuming;

        *ret_bits += consuming;
        while (*ret_bits >= 32) {
            *ret_bits -= 32;
            (*ret_bytes)++;
        }
    }
}

uint32_t expand(uint16_t custom_addr, reg_orders* ro, uint32_t *reg_buf, uint32_t buf_len, char*response, uint32_t res_len) {
    memset(response, 0, res_len * sizeof(*response));

    uint32_t cur_bit = buf_len * 32 - ro->struct_size[custom_addr];
    uint32_t byte_idx = cur_bit / 32;
    uint32_t bit_idx = cur_bit % 32;

    int* raw_bit_sizes = ro->raw_orders[custom_addr];
    int* output_bit_sizes = ro->exp_orders[custom_addr];

    uint32_t ret_bytes = 0;
    uint32_t ret_bits = 0;

    uint32_t offset = 0;
    for (int i = 0; i < MAX_BIT_CNTS; i++) {
        if (raw_bit_sizes[i] == 0)
            break;

        uint32_t val = extract(raw_bit_sizes[i], &byte_idx, &bit_idx, reg_buf);
        val_to_hex16(val, output_bit_sizes[i], response + offset);
        offset += output_bit_sizes[i] / 4;
    }

    return offset;
}
