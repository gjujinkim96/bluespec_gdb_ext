/*

Copyright (C) 2012

Arvind <arvind@csail.mit.edu>
Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


import Types::*;
import FShow::*;
import CMemTypes::*;

`ifdef INCLUDE_GDB_CONTROL
import ClientServer  :: *;
import ISA_Decls::*;
import CustomReg::*;
import DM_CPU_Req_Rsp::*;
import Memory_Common::*;
`endif

// cpu to host data type
typedef enum {
	ExitCode = 2'd0,
	PrintChar = 2'd1,
	PrintIntLow = 2'd2,
	PrintIntHigh = 2'd3
} CpuToHostType deriving(Bits, Eq, FShow);

typedef struct {
	CpuToHostType c2hType;
	Bit#(16) data;
	Data numInsts;
	Data cycles;
} CpuToHostData deriving(Bits, Eq, FShow);

interface Proc;
  method ActionValue#(CpuToHostData) cpuToHost;
  method Action hostToCpu(Addr startpc);

  interface MemInitIfc iMemInit;
  interface MemInitIfc dMemInit;

  `ifdef INCLUDE_GDB_CONTROL
  interface Server#(MemReq, MemResp) dmemory_server;
  interface Server#(MemReq, MemResp) imemory_server;

  interface Server#(Bool, Bool) hart0_server_reset;
  interface Server#(Bool, Bool) hart0_server_run_halt;
  interface Server#(DM_CPU_Req#(5, XLEN), DM_CPU_Rsp#(XLEN)) hart0_gpr_mem_server;
  interface Server#(DM_CPU_Req#(12, XLEN), DM_CPU_Rsp#(XLEN)) hart0_csr_mem_server;
  interface Server#(Bit#(13), DM_CPU_Rsp#(MAX_CUSTOM_REG_SIZE)) hart0_custom_reg_mem_server;
  interface Server#(DM_CPU_Req#(AddrSz, DataSz), Bool) hart0_mod_f2d_server;

  method Action reset_start(Addr startpc);
  `endif
endinterface

`ifdef INCLUDE_GDB_CONTROL

typedef enum {
  PROC_WAIT_RESET,
  PROC_WAIT_GDB,
  PROC_RUNNING
} PROC_State deriving (Eq, Bits, FShow);

`endif

// general purpose reg index
typedef Bit#(5) RIndx;
typedef enum {AOK, ADR, INS, HLT} ProcStatus deriving(Bits,Eq);

// opcode
typedef Bit#(7) Opcode;
Opcode opLoad    = 7'b0000011;
Opcode opMiscMem = 7'b0001111;
Opcode opOpImm   = 7'b0010011;
Opcode opAuipc   = 7'b0010111; // add 20 bit upper immediate to the PC
Opcode opStore   = 7'b0100011;

Opcode opAmo     = 7'b0101111; // atomic memory operation
Opcode opOp      = 7'b0110011;
Opcode opLui     = 7'b0110111; // load upper immediate
Opcode opBranch  = 7'b1100011;
Opcode opJalr    = 7'b1100111;
Opcode opJal     = 7'b1101111;
Opcode opSystem  = 7'b1110011;

// CSR index
typedef Bit#(12) CsrIndx;
CsrIndx csrInstret = 12'hc02;
CsrIndx csrCycle   = 12'hc00;
CsrIndx csrMhartid = 12'hf10;
CsrIndx csrMtohost = 12'h780;

`ifdef INCLUDE_GDB_CONTROL
CsrIndx csrDcsr    = 12'h7b0;
CsrIndx csrDpc     = 12'h7b1;
`endif

// LR, SC, FENCE not implemented
// LB(U), LH(U), SB, SH not implemented

// For CSR, only following two are implemented 
// CSRR rd csr (i.e. CSRRS rd csr x0)
// CSRW csr rs1 (i.e. CSRRW x0 csr rs1)

// SCALL, SBREAK not implemented

typedef enum {
	Unsupported, 
	Alu, 
	Ld, 
	St, 
	J, 
	Jr, 
	Br, 
	Csrr, 
	Csrw, 
	Auipc
} IType deriving(Bits, Eq, FShow);

typedef enum {
	Eq, 
	Neq, 
	Lt, 
	Ltu, 
	Ge, 
	Geu, 
	AT, 
	NT
} BrFunc deriving(Bits, Eq, FShow);

typedef enum {
	Add, 
	Sub, 
	And, 
	Or, 
	Xor, 
	Slt, 
	Sltu, 
	Sll, 
	Sra, 
	Srl
} AluFunc deriving(Bits, Eq, FShow);

typedef void Exception;

typedef struct {
    Addr pc;
    Addr nextPc;
    IType brType;
    Bool taken;
    Bool mispredict;
} Redirect deriving (Bits, Eq, FShow);

typedef struct {
    IType            iType;
    AluFunc          aluFunc;
    BrFunc           brFunc;
    Maybe#(RIndx)    dst;
    Maybe#(RIndx)    src1;
    Maybe#(RIndx)    src2;
	Maybe#(CsrIndx)  csr;
    Maybe#(Data)     imm;
  	//Maybe#(Data)     rVal1;
  	//Maybe#(Data)     rVal2;
  	Maybe#(Data)     copVal;
	//Maybe#(Data)     csrVal;
} DecodedInst deriving(Bits, Eq, FShow);

typedef struct {
    IType            iType;
    Maybe#(RIndx)    dst;
	Maybe#(CsrIndx)  csr;
    Data             data;
    Addr             addr;
    Bool             mispredict;
    Bool             brTaken;
} ExecInst deriving(Bits, Eq, FShow);

/* JAL & JALR are seperated to opcode */
// function code
// ALU
Bit#(3) fnADD   = 3'b000;
Bit#(3) fnSLL   = 3'b001;
Bit#(3) fnSLT   = 3'b010;
Bit#(3) fnSLTU  = 3'b011;
Bit#(3) fnXOR   = 3'b100;
Bit#(3) fnSR    = 3'b101;
Bit#(3) fnOR    = 3'b110;
Bit#(3) fnAND   = 3'b111;

// Branch
Bit#(3) fnBEQ   = 3'b000;
Bit#(3) fnBNE   = 3'b001;
Bit#(3) fnBLT   = 3'b100;
Bit#(3) fnBGE   = 3'b101;
Bit#(3) fnBLTU  = 3'b110;
Bit#(3) fnBGEU  = 3'b111;

// Load
Bit#(3) fnLW    = 3'b010;
//Bit#(3) fnLB    = 3'b000;
//Bit#(3) fnLH    = 3'b001;
//Bit#(3) fnLBU   = 3'b100;
//Bit#(3) fnLHU   = 3'b101;

// Store
Bit#(3) fnSW    = 3'b010;
//Bit#(3) fnSB    = 3'b000;
//Bit#(3) fnSH    = 3'b001;

/****************************************************************/
/* Below functions are not highlighted at RISC-V reference card */
// Amo
Bit#(5) fnLR    = 5'b00010; // load reserved
Bit#(5) fnSC    = 5'b00011; // store conditional

//MiscMem
Bit#(3) fnFENCE  = 3'b000;
//Bit#(3) fnFENCEI = 3'b001;

// System
Bit#(3) fnCSRRW  = 3'b001;
Bit#(3) fnCSRRS  = 3'b010;

//Bit#(3) fnCSRRC  = 3'b011;
//Bit#(3) fnCSRRWI = 3'b101;
//Bit#(3) fnCSRRSI = 3'b110;
//Bit#(3) fnCSRRCI = 3'b111;
Bit#(3) fnPRIV   = 3'b000;
Bit#(12) privSCALL    = 12'h000;
/* End */
/****************************************************************/

/* for TestBenchDecode.bsv 
 * TestBenchDecode just simulte decode operation 
 * so, there are no results after jmp or call.
 * we must define temporal movement of pc
*/
typedef Bit#(7) ICode;

function Addr nextAddr(Addr pc, Opcode iCode);	
	let offset = case(iCode) 
					/*opOp, opOpImm, opBranch, opSystem, opSystem, opMiscMem : 4;
					opJal, opJalr : 9;
					opLoad, opStore, opLui, opAuipc, opAmo : 10;*/
					default : 4;
				  endcase;
	return pc + offset;
endfunction

function Opcode getICode(Instruction inst);
	return inst[  6 :  0 ];
endfunction


function Bool dataHazard(Maybe#(RIndx) src1, Maybe#(RIndx) src2, Maybe#(RIndx) dst);
    return (isValid(dst) && ((isValid(src1) && fromMaybe(?, dst)==fromMaybe(?, src1)) ||
                             (isValid(src2) && fromMaybe(?, dst)==fromMaybe(?, src2))));
endfunction

// pretty print instuction
function Fmt showInst(Instruction inst);
	Fmt ret = $format("");

	Opcode opcode = inst[  6 :  0 ];
	let rd     = inst[ 11 :  7 ];
	let funct3 = inst[ 14 : 12 ];
	let rs1    = inst[ 19 : 15 ];
	let rs2    = inst[ 24 : 20 ];
//	let funct7 = inst[ 31 : 25 ];
	let aluSel = inst[30]; // select between Add/Sub, Srl/Sra

	Bit#(32) immI   = signExtend(inst[31:20]);
	Bit#(32) immS   = signExtend({ inst[31:25], inst[11:7] });
	Bit#(32) immB   = signExtend({ inst[31], inst[7], inst[30:25], inst[11:8], 1'b0});
	Bit#(32) immU   = { inst[31:12], 12'b0 };
	Bit#(32) immJ   = signExtend({ inst[31], inst[19:12], inst[20], inst[30:25], inst[24:21], 1'b0});

	case (opcode)
		opOpImm: begin
			ret = case (funct3)
				fnADD: $format("addi");
				fnSLT: $format("slti");
				fnSLTU: $format("sltiu");
				fnAND: $format("andi");
				fnOR: $format("ori");
				fnXOR: $format("xori");
				fnSLL: $format("slli");
				fnSR: (aluSel == 0 ? $format("srli") : $format("srai"));
				default: $format("unsupport OpImm 0x%0x", inst);
			endcase;
			ret = ret + $format(" r%d = r%d ", rd, rs1);
			ret = ret + (case (funct3)
				fnSLL, fnSR: $format("0x%0x", immI[4:0]); // only low 5 bits for shift
				default: $format("0x%0x", immI);
			endcase);
		end

		opOp: begin
			ret = case (funct3)
				fnADD: (aluSel == 0 ? $format("add") : $format("sub"));
				fnSLT: $format("slt");
				fnSLTU: $format("sltu");
				fnAND: $format("and");
				fnOR: $format("or");
				fnXOR: $format("xor");
				fnSLL: $format("sll");
				fnSR: (aluSel == 0 ? $format("srl") : $format("sra"));
				default: $format("unsupport Op 0x%0x", inst);
			endcase;
			ret = ret + $format(" r%d = r%d r%d", rd, rs1, rs2);
		end

		opLui: begin
			ret = $format("lui r%d 0x%0x", rd, immU);
		end

		opAuipc: begin
			ret = $format("auipc r%d 0x%0x", rd, immU);
		end

		opJal: begin
			ret = $format("jal r%d 0x%0x", rd, immJ);
		end

		opJalr: begin
			ret = $format("jalr r%d [r%d 0x%0x]", rd, rs1, immI);
		end

		opBranch: begin
			ret = case(funct3)
				fnBEQ: $format("beq");
				fnBNE: $format("bne");
				fnBLT: $format("blt");
				fnBLTU: $format("bltu");
				fnBGE: $format("bge");
				fnBGEU: $format("bgeu");
				default: $format("unsupport Branch 0x%0x", inst);
			endcase;
			ret = ret + $format(" r%d r%d 0x%0x", rs1, rs2, immB);
		end

		opLoad: begin
			ret = case(funct3)
				fnLW: $format("lw");
				default: $format("unsupport Load 0x%0x", inst);
			endcase;
			ret = ret + $format(" r%d = [r%d 0x%0x]", rd, rs1, immI);
		end

		opStore: begin
			ret = case(funct3)
				fnSW: $format("sw");
				default: $format("unsupport Store 0x%0x", inst);
			endcase;
			ret = ret + $format(" [r%d 0x%0x] = r%d", rs1, immS, rs2);
		end

		opMiscMem: begin
			ret = case (funct3)
				//fnFENCE: $format("fence");
				//fnFENCEI: $format("fence.i");
				default: $format("unsupport MiscMem 0x%0x", inst);
			endcase;
		end

		opAmo: begin
			ret = $format("unsupport Amo 0x%0x", inst);
		end

		opSystem: begin
			case (funct3)
				fnCSRRW, fnCSRRS: begin //fnCSRRC, fnCSRRWI, fnCSRRSI, fnCSRRCI: begin
					ret = case(funct3)
						fnCSRRW: $format("csrrw");
						fnCSRRS: $format("csrrs");
					endcase;
					ret = ret + $format(" r%d csr0x%0x r%d", rd, immI[11:0], rs1);
				end

				fnPRIV: begin
					ret = case (truncate(immI))
						//privSCALL: $format("scall");
						default: $format("unsupport System PRIV 0x%0x", inst);
					endcase;
				end

				default: begin
					ret = $format("unsupport System 0x%0x", inst);
				end
			endcase
		end

		default: begin
			ret = $format("unsupport 0x%0x", inst);
		end
	endcase

  return ret;

endfunction

