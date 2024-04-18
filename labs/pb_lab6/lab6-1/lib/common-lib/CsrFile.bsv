/*

Copyright (C) 2012 Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


import Types::*;
import ProcTypes::*;
import Ehr::*;
import ConfigReg::*;
import Fifo::*;

`ifdef INCLUDE_GDB_CONTROL

import FIFOF:: *;
import SpecialFIFOs :: * ;
import Vector::*;
import ClientServer :: *;

`endif 

interface CsrFile;
    method Action start(Data id);
    method Bool started;
    method Data rd(CsrIndx idx);
    method Action wr(Maybe#(CsrIndx) idx, Data val);
    method ActionValue#(CpuToHostData) cpuToHost;

    `ifdef INCLUDE_GDB_CONTROL
    method Action resume;
    method Data rd2(CsrIndx idx);
    method Data readCycle;
    method Action setPc(Addr pc);
    method Action handleHaltRsp;
    method Action processFetchResult(Addr pc, Instruction inst);

    interface Server#(Bool, Bool) csrf_server;
    `endif
endinterface

(* synthesize *)
module mkCsrFile(CsrFile);
    Reg#(Bool) startReg <- mkConfigReg(False);

	// CSR 
    Reg#(Data) numInsts <- mkConfigReg(0); // csrInstret -- read only
    Reg#(Data) cycles <- mkReg(0); // csrCycle -- read only
	Reg#(Data) coreId <- mkConfigReg(0); // csrMhartid -- read only

    Fifo#(2, CpuToHostData) toHostFifo <- mkCFFifo; // csrMtohost -- write only

    `ifdef INCLUDE_GDB_CONTROL
    Reg#(Data) dcsr <- mkReg(32'hf0000117);
    Reg#(Addr) dpc <- mkReg(32'h0);
    Vector#(16, Reg#(Data)) extras <- replicateM(mkReg(0));

    Fifo#(2, CpuToHostData) toProcFifo <- mkCFFifo; // csrMtohost -- write only
    FIFOF#(Bool) haltRspFifo <- mkBypassFIFOF;
    FIFOF#(Bool) cycleHaltRspFifo <- mkBypassFIFOF;
    FIFOF#(Bool) fetchHaltRspFifo <- mkBypassFIFOF;
    Reg#(Bool) debug_stop <- mkReg(True);
    `endif

    `ifdef INCLUDE_GDB_CONTROL
    rule count (startReg && !debug_stop);
        cycles <= cycles + 1;
        $display("\nCycle %d ----------------------------------------------------", cycles);
    endrule

    rule gdbStopEveryCycle(startReg && !debug_stop && dcsr[2] == 1'b1);
        cycleHaltRspFifo.enq(True);
    endrule
    `else
    rule count (startReg);
        cycles <= cycles + 1;
        $display("\nCycle %d ----------------------------------------------------", cycles);
    endrule
    `endif

    method Action start(Data id) if(!startReg);
        startReg <= True;
        cycles <= 0;
		coreId <= id;
    endmethod

    `ifdef INCLUDE_GDB_CONTROL
    method Bool started;
        return startReg && !debug_stop;
    endmethod
    `else
    method Bool started;
        return startReg;
    endmethod
    `endif

    method Data rd(CsrIndx idx);
        return (case(idx)
                    csrCycle: cycles;
                    csrInstret: numInsts;
                    csrMhartid: coreId;
					default: ?;
                endcase);
    endmethod
    
    method Action wr(Maybe#(CsrIndx) csrIdx, Data val);
        if(csrIdx matches tagged Valid .idx) begin
            case (idx)
                csrMtohost: begin
                    // high 16 bits encodes type, low 16 bits are data
                    Bit#(16) hi = truncateLSB(val);
                    Bit#(16) lo = truncate(val);
                    toHostFifo.enq(CpuToHostData {
                        c2hType: unpack(truncate(hi)),
                        data: lo,
                        numInsts: numInsts,
                        cycles: cycles
                    });

                    `ifdef INCLUDE_GDB_CONTROL
                    haltRspFifo.enq(True);
                    `endif
                end
                `ifdef INCLUDE_GDB_CONTROL
                csrDcsr: dcsr <= val;
                `endif
            endcase
        end
        else
            numInsts <= numInsts + 1;
    endmethod

    method ActionValue#(CpuToHostData) cpuToHost;
        toHostFifo.deq;
        return toHostFifo.first;
    endmethod

    `ifdef INCLUDE_GDB_CONTROL

    method Action resume;
        debug_stop <= False;
    endmethod

    method Data rd2(CsrIndx idx);
        return (case(idx)
                    csrDcsr: dcsr;
                    csrDpc: dpc;
                    default: ?;
                endcase);
    endmethod

    method Data readCycle;
        return cycles;
    endmethod

    method Action setPc(Addr pc);
        dpc <= pc;
    endmethod

    method Action handleHaltRsp if (haltRspFifo.notEmpty || cycleHaltRspFifo.notEmpty || fetchHaltRspFifo.notEmpty);
        if (haltRspFifo.notEmpty)
            haltRspFifo.deq;

        if (cycleHaltRspFifo.notEmpty)
            cycleHaltRspFifo.deq;

        if (fetchHaltRspFifo.notEmpty)
            fetchHaltRspFifo.deq;

        debug_stop <= True;
    endmethod

    method Action processFetchResult(Addr pc, Instruction inst);
        dpc <= pc;
        if (inst ==  32'h00100073)
            fetchHaltRspFifo.enq(True);
    endmethod
    `endif
endmodule