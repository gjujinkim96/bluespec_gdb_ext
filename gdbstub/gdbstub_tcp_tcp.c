// Copyright (c) 2016-2020 Bluespec, Inc. All Rights Reserved
// Author: Rishiyur Nikhil

// ================================================================
// Standalone gdbstub communicating with TCP in both directions, i.e.,
//
//     [GDB]         [gdbstub_tcp_tcp]         [DM with RISC-V CPU]
//    client <-TCP-> server     client <-TCP-> server
//
// where DM is a RISC-V Debug Module adjunct to a RISC-V CPU

// ================================================================
// C lib includes

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

// ----------------
// Project includes

#include "TCP_Client_Lib.h"
#include "gdbstub.h"
#include "gdbstub_fe.h"
#include "gdbstub_be.h"
#include "bit_expander.h"

// ================================================================

// Logfile recording transactions with GDB and with DM
char            logfile_name[] = "log_gdbstub.txt";

// TCP port on which to listen for connection from GDB
unsigned short  gdb_port = 31000;

// Hostname and TCP port on which to connect to DM
char            dm_hostname[] = "127.0.0.1";

const char dm_stub_unix_socket[512];
const char stub_gdb_socket_file[512];

const char *dm_stub_name = "unix_socket/dm_stub_";
const char *stub_gdb_name = "unix_socket/stub_gdb_";
unsigned short  dm_port  = 30000;

extern FILE *logfile_dmi;

// ================================================================

int main (int argc, char **argv)
{
    if (argc > 3) {
        fprintf (stderr, "usage: %s [path_to_unix_socket]\n", argv[0]);
        fprintf (stderr, "  if path_to_unix_socket is none current directory is used\n");
	    return 1;
    }

    if (argc == 2) {
        sprintf(dm_stub_unix_socket, "%s/%s", argv[1], dm_stub_name);
        sprintf(stub_gdb_socket_file, "%s/%s", argv[1], stub_gdb_name);
    } else {
        strcpy(dm_stub_unix_socket, dm_stub_name);
        strcpy(stub_gdb_socket_file, stub_gdb_name);
    }


    fprintf (stdout, "INFO: logfile is %s\n", logfile_name);
    fprintf (stdout, "INFO: TCP port for GDB is %0d\n", gdb_port);
    fprintf (stdout, "INFO: TCP port for DM  is %0d\n", dm_port);

    // ----------------
    // Open logfile
    FILE *logfile = fopen (logfile_name, "w");
    if (logfile == NULL) {
	fprintf (stderr, "ERROR: could not open logfile: %s\n", logfile_name);
	return 1;
    }
    logfile_dmi = logfile;

    gdbstub_be_xlen = 32;


    // ----------------
    // TCP-connect to DM
    uint32_t status = tcp_client_open (dm_stub_unix_socket, dm_port);
    if (status != status_ok) {
	fprintf (stderr, "ERROR: could not TCP connection to DM: %s%d\n",
            dm_stub_unix_socket, dm_port);
	return 1;
    }
    fprintf (stdout,  "Connected to DM: %s%d\n", dm_stub_unix_socket, dm_port);
    fprintf (logfile, "Connected to DM: %s%d\n", dm_stub_unix_socket, dm_port);

    // Start gdbstub process after listening and connecting to GDB
    gdbstub_start_tcp (logfile, stub_gdb_socket_file, gdb_port);

    gdbstub_join ();
    return 0;
}
