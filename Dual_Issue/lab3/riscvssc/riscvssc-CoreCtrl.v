//=========================================================================
// 7-Stage RISCV Control Unit
//=========================================================================

`ifndef RISCV_CORE_CTRL_V
`define RISCV_CORE_CTRL_V

`include "riscvssc-InstMsg.v"

module riscv_CoreCtrl
(
  input clk,
  input reset,

  // Instruction Memory Port
  output        imemreq0_val,
  input         imemreq0_rdy,
  input  [31:0] imemresp0_msg_data,
  input         imemresp0_val,

  // Instruction Memory Port
  output        imemreq1_val,
  input         imemreq1_rdy,
  input  [31:0] imemresp1_msg_data,
  input         imemresp1_val,

  // Data Memory Port

  output        dmemreq_msg_rw,
  output  [1:0] dmemreq_msg_len,
  output        dmemreq_val,
  input         dmemreq_rdy,
  input         dmemresp_val,

  // Controls Signals (ctrl->dpath)

  output  [1:0] pc_mux_sel_Phl,
  output        steering_mux_sel_Dhl,
  output  [3:0] opA0_byp_mux_sel_Dhl,
  output  [1:0] opA0_mux_sel_Dhl,
  output  [3:0] opA1_byp_mux_sel_Dhl,
  output  [2:0] opA1_mux_sel_Dhl,
  output  [3:0] opB0_byp_mux_sel_Dhl,
  output  [1:0] opB0_mux_sel_Dhl,
  output  [3:0] opB1_byp_mux_sel_Dhl,
  output  [2:0] opB1_mux_sel_Dhl,
  output [31:0] instA_Dhl,
  output [31:0] instB_Dhl,
  output  [3:0] aluA_fn_X0hl,
  output  [3:0] aluB_fn_X0hl,
  output  [2:0] muldivreq_msg_fn_Dhl,
  output        muldivreq_val,
  input         muldivreq_rdy,
  input         muldivresp_val,
  output        muldivresp_rdy,
  output        muldiv_stall_mult1,
  output  [2:0] dmemresp_mux_sel_X1hl,
  output        dmemresp_queue_en_X1hl,
  output        dmemresp_queue_val_X1hl,
  output        muldiv_mux_sel_X3hl,
  output        execute_mux_sel_X3hl,
  output        memex_mux_sel_X1hl,
  output        rfA_wen_out_Whl,
  output  [4:0] rfA_waddr_Whl,
  output        rfB_wen_out_Whl,
  output  [4:0] rfB_waddr_Whl,
  output        stall_Fhl,
  output        stall_Dhl,
  output        stall_A_X0hl,
  output        stall_A_X1hl,
  output        stall_A_X2hl,
  output        stall_A_X3hl,
  output        stall_A_Whl,

  // Control Signals (dpath->ctrl)

  input         branch_cond_eq_X0hl,
  input         branch_cond_ne_X0hl,
  input         branch_cond_lt_X0hl,
  input         branch_cond_ltu_X0hl,
  input         branch_cond_ge_X0hl,
  input         branch_cond_geu_X0hl,
  input  [31:0] proc2csr_data_Whl,

  // CSR Status

  output [31:0] csr_status
);

  //----------------------------------------------------------------------
  // PC Stage: Instruction Memory Request
  //----------------------------------------------------------------------

  // PC Mux Select

  assign pc_mux_sel_Phl
    = brj_taken_X0hl    ? pm_b
    : brj_taken_Dhl    ? pc_mux_sel_Dhl
    :                    pm_p;

  // Only send a valid imem request if not stalled

  wire   imemreq_val_Phl = reset || !stall_Phl;
  assign imemreq0_val     = imemreq_val_Phl;
  assign imemreq1_val     = imemreq_val_Phl;

  // Dummy Squash Signal

  wire squash_Phl = 1'b0;

  // Stall in PC if F is stalled

  wire stall_Phl = stall_Fhl;

  // Next bubble bit

  wire bubble_next_Phl = ( squash_Phl || stall_Phl );

  //----------------------------------------------------------------------
  // F <- P
  //----------------------------------------------------------------------

  reg imemreq_val_Fhl;

  reg bubble_Fhl;

  always @ ( posedge clk ) begin
    // Only pipeline the bubble bit if the next stage is not stalled
    if ( reset ) begin
      imemreq_val_Fhl <= 1'b0;

      bubble_Fhl <= 1'b0;
    end
    else if( !stall_Fhl ) begin 
      imemreq_val_Fhl <= imemreq_val_Phl;

      bubble_Fhl <= bubble_next_Phl;
    end
    else begin 
      imemreq_val_Fhl <= imemreq_val_Phl;
    end
  end

  //----------------------------------------------------------------------
  // Fetch Stage: Instruction Memory Response
  //----------------------------------------------------------------------

  // Is the current stage valid?

  wire inst_val_Fhl = ( !bubble_Fhl && !squash_Fhl );

  // Squash instruction in F stage if branch taken for a valid
  // instruction or if there was an exception in X stage

  wire squash_Fhl
    = ( inst_val_A_Dhl && brj_taken_Dhl )
   || ( inst_val_A_X0hl && brj_taken_X0hl );

  // Stall in F if D is stalled

  assign stall_Fhl = stall_Dhl;

  // Next bubble bit

  wire bubble_sel_Fhl  = ( squash_Fhl || stall_Fhl );
  wire bubble_next_Fhl = ( !bubble_sel_Fhl ) ? bubble_Fhl
                       : ( bubble_sel_Fhl )  ? 1'b1
                       :                       1'bx;

  //----------------------------------------------------------------------
  // Queue for instruction memory response
  //----------------------------------------------------------------------

  wire imemresp0_queue_en_Fhl = ( stall_Dhl && imemresp0_val );
  wire imemresp0_queue_val_next_Fhl
    = stall_Dhl && ( imemresp0_val || imemresp0_queue_val_Fhl );

  wire imemresp1_queue_en_Fhl = ( stall_Dhl && imemresp1_val );
  wire imemresp1_queue_val_next_Fhl
    = stall_Dhl && ( imemresp1_val || imemresp1_queue_val_Fhl );

  reg [31:0] imemresp0_queue_reg_Fhl;
  reg        imemresp0_queue_val_Fhl;

  reg [31:0] imemresp1_queue_reg_Fhl;
  reg        imemresp1_queue_val_Fhl;

  always @ ( posedge clk ) begin
    if ( imemresp0_queue_en_Fhl ) begin
      imemresp0_queue_reg_Fhl <= imemresp0_msg_data;
    end
    if ( imemresp1_queue_en_Fhl ) begin
      imemresp1_queue_reg_Fhl <= imemresp1_msg_data;
    end
    imemresp0_queue_val_Fhl <= imemresp0_queue_val_next_Fhl;
    imemresp1_queue_val_Fhl <= imemresp1_queue_val_next_Fhl;
  end

  //----------------------------------------------------------------------
  // Instruction memory queue mux
  //----------------------------------------------------------------------

  wire [31:0] imemresp0_queue_mux_out_Fhl
    = ( !imemresp0_queue_val_Fhl ) ? imemresp0_msg_data
    : ( imemresp0_queue_val_Fhl )  ? imemresp0_queue_reg_Fhl
    :                               32'bx;

  wire [31:0] imemresp1_queue_mux_out_Fhl
    = ( !imemresp1_queue_val_Fhl ) ? imemresp1_msg_data
    : ( imemresp1_queue_val_Fhl )  ? imemresp1_queue_reg_Fhl
    :                               32'bx;

  //----------------------------------------------------------------------
  // D <- F
  //----------------------------------------------------------------------

  reg [31:0] prev_irA_Dhl;
  reg [31:0] prev_irB_Dhl;
  reg [31:0] irA_Dhl;
  reg [31:0] irB_Dhl;
  reg        bubble_Dhl;

  always @ ( posedge clk ) begin
    if ( reset ) begin
      prev_irA_Dhl <= 32'b0;
      prev_irB_Dhl <= 32'b0;
    end
    else begin
      prev_irA_Dhl    <= irA_Dhl;
      prev_irB_Dhl    <= irB_Dhl;
    end
  end

  // wire squash_first_D_inst =
  //   (inst_val_Dhl && !stall_0_Dhl && stall_1_Dhl);

  always @ ( posedge clk ) begin
    if ( reset ) begin
      bubble_Dhl <= 1'b1;
    end
    else if( !stall_Dhl ) begin
      irA_Dhl    <= imemresp0_queue_mux_out_Fhl;
      irB_Dhl    <= imemresp1_queue_mux_out_Fhl;
      bubble_Dhl <= bubble_next_Fhl;
    end
  end

  //----------------------------------------------------------------------
  // Decode Stage: Constants
  //----------------------------------------------------------------------

  // Generic Parameters

  localparam n = 1'd0;
  localparam y = 1'd1;

  // Register specifiers

  localparam rx = 5'bx;
  localparam r0 = 5'd0;

  // Branch Type

  localparam br_x    = 3'bx;
  localparam br_none = 3'd0;
  localparam br_beq  = 3'd1;
  localparam br_bne  = 3'd2;
  localparam br_blt  = 3'd3;
  localparam br_bltu = 3'd4;
  localparam br_bge  = 3'd5;
  localparam br_bgeu = 3'd6;

  // PC Mux Select

  localparam pm_x   = 2'bx;  // Don't care
  localparam pm_p   = 2'd0;  // Use pc+4
  localparam pm_b   = 2'd1;  // Use branch address
  localparam pm_j   = 2'd2;  // Use jump address
  localparam pm_r   = 2'd3;  // Use jump register

  // Operand 0 Bypass Mux Select

  localparam am_r0    = 4'd0; // Use rdata0
  localparam am_AX0_byp = 4'd1; // Bypass from X0
  localparam am_AX1_byp = 4'd2; // Bypass from X1
  localparam am_AX2_byp = 4'd3; // Bypass from X2
  localparam am_AX3_byp = 4'd4; // Bypass from X3
  localparam am_AW_byp = 4'd5; // Bypass from W
  localparam am_BX0_byp = 4'd6; // Bypass from X0
  localparam am_BX1_byp = 4'd7; // Bypass from X1
  localparam am_BX2_byp = 4'd8; // Bypass from X2
  localparam am_BX3_byp = 4'd9; // Bypass from X3
  localparam am_BW_byp = 4'd10; // Bypass from W

  // Operand 0 Mux Select

  localparam am_x     = 2'bx;
  localparam am_rdat  = 2'd0; // Use output of bypass mux for rs1
  localparam am_pc    = 2'd1; // Use current PC
  localparam am_pc4   = 2'd2; // Use PC + 4
  localparam am_0     = 2'd3; // Use constant 0

  // Operand 1 Bypass Mux Select

  localparam bm_r1    = 4'd0; // Use rdata1
  localparam bm_AX0_byp = 4'd1; // Bypass from X0
  localparam bm_AX1_byp = 4'd2; // Bypass from X1
  localparam bm_AX2_byp = 4'd3; // Bypass from X2
  localparam bm_AX3_byp = 4'd4; // Bypass from X3
  localparam bm_AW_byp = 4'd5; // Bypass from W
  localparam bm_BX0_byp = 4'd6; // Bypass from X0
  localparam bm_BX1_byp = 4'd7; // Bypass from X1
  localparam bm_BX2_byp = 4'd8; // Bypass from X2
  localparam bm_BX3_byp = 4'd9; // Bypass from X3
  localparam bm_BW_byp = 4'd10; // Bypass from W

  // Operand 1 Mux Select

  localparam bm_x      = 3'bx; // Don't care
  localparam bm_rdat   = 3'd0; // Use output of bypass mux for rs2
  localparam bm_shamt  = 3'd1; // Use shift amount
  localparam bm_imm_u  = 3'd2; // Use U-type immediate
  localparam bm_imm_sb = 3'd3; // Use SB-type immediate
  localparam bm_imm_i  = 3'd4; // Use I-type immediate
  localparam bm_imm_s  = 3'd5; // Use S-type immediate
  localparam bm_0      = 3'd6; // Use constant 0

  // ALU Function

  localparam alu_x    = 4'bx;
  localparam alu_add  = 4'd0;
  localparam alu_sub  = 4'd1;
  localparam alu_sll  = 4'd2;
  localparam alu_or   = 4'd3;
  localparam alu_lt   = 4'd4;
  localparam alu_ltu  = 4'd5;
  localparam alu_and  = 4'd6;
  localparam alu_xor  = 4'd7;
  localparam alu_nor  = 4'd8;
  localparam alu_srl  = 4'd9;
  localparam alu_sra  = 4'd10;

  // Muldiv Function

  localparam md_x    = 3'bx;
  localparam md_mul  = 3'd0;
  localparam md_div  = 3'd1;
  localparam md_divu = 3'd2;
  localparam md_rem  = 3'd3;
  localparam md_remu = 3'd4;

  // MulDiv Mux Select

  localparam mdm_x = 1'bx; // Don't Care
  localparam mdm_l = 1'd0; // Take lower half of 64-bit result, mul/div/divu
  localparam mdm_u = 1'd1; // Take upper half of 64-bit result, rem/remu

  // Execute Mux Select

  localparam em_x   = 1'bx; // Don't Care
  localparam em_alu = 1'd0; // Use ALU output
  localparam em_md  = 1'd1; // Use muldiv output

  // Memory Request Type

  localparam nr = 2'b0; // No request
  localparam ld = 2'd1; // Load
  localparam st = 2'd2; // Store

  // Subword Memop Length

  localparam ml_x  = 2'bx;
  localparam ml_w  = 2'd0;
  localparam ml_b  = 2'd1;
  localparam ml_h  = 2'd2;

  // Memory Response Mux Select

  localparam dmm_x  = 3'bx;
  localparam dmm_w  = 3'd0;
  localparam dmm_b  = 3'd1;
  localparam dmm_bu = 3'd2;
  localparam dmm_h  = 3'd3;
  localparam dmm_hu = 3'd4;

  // Writeback Mux 1

  localparam wm_x   = 1'bx; // Don't care
  localparam wm_alu = 1'd0; // Use ALU output
  localparam wm_mem = 1'd1; // Use data memory response

  //----------------------------------------------------------------------
  // Decode Stage: Logic
  //----------------------------------------------------------------------

  // Is the current stage valid?

  // wire inst_val_Dhl = ( !bubble_Dhl && !squash_Dhl );

  // Parse instruction fields

  wire   [4:0] inst0_rs1_Dhl;
  wire   [4:0] inst0_rs2_Dhl;
  wire   [4:0] inst0_rd_Dhl;

  riscv_InstMsgFromBits inst0_msg_from_bits
  (
    .msg      (instA_Dhl),
    .opcode   (),
    .rs1      (inst0_rs1_Dhl),
    .rs2      (inst0_rs2_Dhl),
    .rd       (inst0_rd_Dhl),
    .funct3   (),
    .funct7   (),
    .shamt    (),
    .imm_i    (),
    .imm_s    (),
    .imm_sb   (),
    .imm_u    (),
    .imm_uj   ()
  );

  wire   [4:0] inst1_rs1_Dhl;
  wire   [4:0] inst1_rs2_Dhl;
  wire   [4:0] inst1_rd_Dhl;

  riscv_InstMsgFromBits inst1_msg_from_bits
  (
    .msg      (instB_Dhl),
    .opcode   (),
    .rs1      (inst1_rs1_Dhl),
    .rs2      (inst1_rs2_Dhl),
    .rd       (inst1_rd_Dhl),
    .funct3   (),
    .funct7   (),
    .shamt    (),
    .imm_i    (),
    .imm_s    (),
    .imm_sb   (),
    .imm_u    (),
    .imm_uj   ()
  );

  // Shorten register specifier name for table

  wire [4:0] rs10 = inst0_rs1_Dhl;
  wire [4:0] rs20 = inst0_rs2_Dhl;
  wire [4:0] rd0 = inst0_rd_Dhl;

  wire [4:0] rs11 = inst1_rs1_Dhl;
  wire [4:0] rs21 = inst1_rs2_Dhl;
  wire [4:0] rd1 = inst1_rd_Dhl;

  // Instruction Decode

  localparam cs_sz = 39;
  reg [cs_sz-1:0] cs0;
  reg [cs_sz-1:0] cs1;

  always @ (*) begin

    cs0 = {cs_sz{1'bx}}; // Default to invalid instruction

    casez ( instA_Dhl )

      //                                j     br       pc      op0      rs1 op1       rs2 alu       md       md md     ex      mem  mem   memresp wb      rf      csr
      //                            val taken type     muxsel  muxsel   en  muxsel    en  fn        fn       en muxsel muxsel  rq   len   muxsel  muxsel  wen wa  wen
      `RISCV_INST_MSG_LUI     :cs0={ y,  n,    br_none, pm_p,   am_0,    n,  bm_imm_u, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_AUIPC   :cs0={ y,  n,    br_none, pm_p,   am_pc,   n,  bm_imm_u, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };

      `RISCV_INST_MSG_ADDI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_ORI     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_or,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLTI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_lt,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLTIU   :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_ltu,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_XORI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_xor,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_ANDI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_and,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLLI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_sll,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SRLI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_srl,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SRAI    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_sra,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };

      `RISCV_INST_MSG_ADD     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SUB     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLL     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sll,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLT     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_lt,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SLTU    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_ltu,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_XOR     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SRL     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_srl,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_SRA     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sra,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_OR      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_or,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_AND     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_and,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };

      `RISCV_INST_MSG_LW      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_w, dmm_w,  wm_mem, y,  rd0, n   };
      `RISCV_INST_MSG_LB      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_b, dmm_b,  wm_mem, y,  rd0, n   };
      `RISCV_INST_MSG_LH      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_h, dmm_h,  wm_mem, y,  rd0, n   };
      `RISCV_INST_MSG_LBU     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_b, dmm_bu, wm_mem, y,  rd0, n   };
      `RISCV_INST_MSG_LHU     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_h, dmm_hu, wm_mem, y,  rd0, n   };
      `RISCV_INST_MSG_SW      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_w, dmm_w,  wm_mem, n,  rx, n   };
      `RISCV_INST_MSG_SB      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_b, dmm_b,  wm_mem, n,  rx, n   };
      `RISCV_INST_MSG_SH      :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_h, dmm_h,  wm_mem, n,  rx, n   };

      `RISCV_INST_MSG_JAL     :cs0={ y,  y,    br_none, pm_j,   am_pc4,  n,  bm_0,     n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_JALR    :cs0={ y,  y,    br_none, pm_r,   am_pc4,  y,  bm_0,     n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };

      `RISCV_INST_MSG_BNE     :cs0={ y,  n,    br_bne,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BEQ     :cs0={ y,  n,    br_beq,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BLT     :cs0={ y,  n,    br_blt,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BGE     :cs0={ y,  n,    br_bge,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BLTU    :cs0={ y,  n,    br_bltu, pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BGEU    :cs0={ y,  n,    br_bgeu, pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };

      `RISCV_INST_MSG_MUL     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_mul,  y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_DIV     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_div,  y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_REM     :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_rem,  y, mdm_u, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_DIVU    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_divu, y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };
      `RISCV_INST_MSG_REMU    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_remu, y, mdm_u, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd0, n   };

      `RISCV_INST_MSG_CSRW    :cs0={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_0,     y,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, n,  rx, y   };

    endcase

  end

  always @ (*) begin

    cs1 = {cs_sz{1'bx}}; // Default to invalid instruction

    casez ( instB_Dhl )

      //                                j     br       pc      op0      rs1 op1       rs2 alu       md       md md     ex      mem  mem   memresp wb      rf      csr
      //                            val taken type     muxsel  muxsel   en  muxsel    en  fn        fn       en muxsel muxsel  rq   len   muxsel  muxsel  wen wa  wen
      `RISCV_INST_MSG_LUI     :cs1={ y,  n,    br_none, pm_p,   am_0,    n,  bm_imm_u, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_AUIPC   :cs1={ y,  n,    br_none, pm_p,   am_pc,   n,  bm_imm_u, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };

      `RISCV_INST_MSG_ADDI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_ORI     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_or,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLTI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_lt,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLTIU   :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_ltu,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_XORI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_xor,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_ANDI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_and,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLLI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_sll,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SRLI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_srl,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SRAI    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_sra,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };

      `RISCV_INST_MSG_ADD     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SUB     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLL     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sll,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLT     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_lt,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SLTU    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_ltu,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_XOR     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SRL     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_srl,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_SRA     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_sra,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_OR      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_or,   md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_AND     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_and,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };

      `RISCV_INST_MSG_LW      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_w, dmm_w,  wm_mem, y,  rd1, n   };
      `RISCV_INST_MSG_LB      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_b, dmm_b,  wm_mem, y,  rd1, n   };
      `RISCV_INST_MSG_LH      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_h, dmm_h,  wm_mem, y,  rd1, n   };
      `RISCV_INST_MSG_LBU     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_b, dmm_bu, wm_mem, y,  rd1, n   };
      `RISCV_INST_MSG_LHU     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_i, n,  alu_add,  md_x,    n, mdm_x, em_x,   ld,  ml_h, dmm_hu, wm_mem, y,  rd1, n   };
      `RISCV_INST_MSG_SW      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_w, dmm_w,  wm_mem, n,  rx, n   };
      `RISCV_INST_MSG_SB      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_b, dmm_b,  wm_mem, n,  rx, n   };
      `RISCV_INST_MSG_SH      :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_imm_s, y,  alu_add,  md_x,    n, mdm_x, em_x,   st,  ml_h, dmm_h,  wm_mem, n,  rx, n   };

      `RISCV_INST_MSG_JAL     :cs1={ y,  y,    br_none, pm_j,   am_pc4,  n,  bm_0,     n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_JALR    :cs1={ y,  y,    br_none, pm_r,   am_pc4,  y,  bm_0,     n,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };

      `RISCV_INST_MSG_BNE     :cs1={ y,  n,    br_bne,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BEQ     :cs1={ y,  n,    br_beq,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_xor,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BLT     :cs1={ y,  n,    br_blt,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BGE     :cs1={ y,  n,    br_bge,  pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BLTU    :cs1={ y,  n,    br_bltu, pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };
      `RISCV_INST_MSG_BGEU    :cs1={ y,  n,    br_bgeu, pm_b,   am_rdat, y,  bm_rdat,  y,  alu_sub,  md_x,    n, mdm_x, em_x,   nr,  ml_x, dmm_x,  wm_x,   n,  rx, n   };

      `RISCV_INST_MSG_MUL     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_mul,  y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_DIV     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_div,  y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_REM     :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_rem,  y, mdm_u, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_DIVU    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_divu, y, mdm_l, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };
      `RISCV_INST_MSG_REMU    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_rdat,  y,  alu_x,    md_remu, y, mdm_u, em_md,  nr,  ml_x, dmm_x,  wm_alu, y,  rd1, n   };

      `RISCV_INST_MSG_CSRW    :cs1={ y,  n,    br_none, pm_p,   am_rdat, y,  bm_0,     y,  alu_add,  md_x,    n, mdm_x, em_alu, nr,  ml_x, dmm_x,  wm_alu, n,  rx, y   };

    endcase

  end

  assign opA0_mux_sel_Dhl = cs0[`RISCV_INST_MSG_OP0_SEL];
  assign opA1_mux_sel_Dhl = cs0[`RISCV_INST_MSG_OP1_SEL];
  assign opB0_mux_sel_Dhl = cs1[`RISCV_INST_MSG_OP0_SEL];
  assign opB1_mux_sel_Dhl = cs1[`RISCV_INST_MSG_OP1_SEL];

  wire [4:0] writeA = cs0[`RISCV_INST_MSG_RF_WEN];
  wire [4:0] writeB = cs1[`RISCV_INST_MSG_RF_WEN];

  wire instA_is_muldiv = cs0[`RISCV_INST_MSG_MULDIV_EN];
  wire instB_is_muldiv = cs1[`RISCV_INST_MSG_MULDIV_EN];

  wire [1:0] opA_Dhl = instA_is_muldiv ? 2'd2
                     : (instA_Dhl[6:0] == 7'b0010111 || instA_Dhl[6:0] == 7'b0110111 || instA_Dhl[6:0] == 7'b0010011 || instA_Dhl[6:0] == 7'b0110011 || instA_Dhl[6:0] == 7'b1100011 || instA_Dhl[6:0] == 7'b1101111 || instA_Dhl[6:0] == 7'b1100111) ? 2'd0
                     : (instA_Dhl[6:0] == 7'b0000011 || instA_Dhl[6:0] == 7'b0100011) ? 2'd1
                     : 2'bx;
  wire [1:0] opB_Dhl = instB_is_muldiv ? 2'd2
                     : (instB_Dhl[6:0] == 7'b0010111 || instB_Dhl[6:0] == 7'b0110111 || instB_Dhl[6:0] == 7'b0010011 || instB_Dhl[6:0] == 7'b0110011 || instB_Dhl[6:0] == 7'b1100011 || instB_Dhl[6:0] == 7'b1101111 || instB_Dhl[6:0] == 7'b1100111) ? 2'd0
                     : (instB_Dhl[6:0] == 7'b0000011 || instB_Dhl[6:0] == 7'b0100011) ? 2'd1
                     : 2'bx;
  
  reg  [31:0] fu;
  reg  [31:0] countdown_4;
  reg  [31:0] countdown_3;
  reg  [31:0] countdown_2;
  reg  [31:0] countdown_1;
  reg  [31:0] countdown_0;
  reg  [31:0] byp_4;
  reg  [31:0] byp_3;
  reg  [31:0] byp_2;
  reg  [31:0] byp_1;
  reg  [31:0] byp_0;
  wire [31:0] pending;
  wire [31:0] byp;

  genvar j;
  generate
      for (j = 0; j < 32; j = j + 1) begin
          assign pending[j] = (countdown_4[j] || countdown_3[j] || countdown_2[j] || countdown_1[j] || countdown_0[j]) ? 1'b1 : 1'b0;
          assign byp[j] = (((countdown_4[j] && byp_4[j]) || (countdown_3[j] && byp_3[j]) ||(countdown_2[j] && byp_2[j]) ||(countdown_1[j] && byp_1[j]) ||(countdown_0[j] && byp_0[j])) ? 1'b1 : 1'b0);
      end
  endgenerate

  integer i;
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      for (i = 0; i < 32; i = i + 1) begin
        fu[i] <= 1'b0;
        countdown_4[i] <= 1'b0;
        countdown_3[i] <= 1'b0;
        countdown_2[i] <= 1'b0;
        countdown_1[i] <= 1'b0;
        countdown_0[i] <= 1'b0;
        byp_4[i] <= 1'b0;    
        byp_3[i] <= 1'b0;          
        byp_2[i] <= 1'b0;          
        byp_1[i] <= 1'b0;          
        byp_0[i] <= 1'b0;          
      end
    end else begin      
        for (i = 0; i < 32; i = i + 1) begin
            if (inst_val_A_Dhl && !stall_A_Dhl && rfA_wen_Dhl && (i == rfA_waddr_Dhl)) begin
              if (opA_Dhl == 2'd0) begin
                byp_4[i] <= 1'b1;
                byp_3[i] <= 1'b1;
                byp_2[i] <= 1'b1;
                byp_1[i] <= 1'b1;
                byp_0[i] <= 1'b1;
              end else if (opA_Dhl == 2'd1) begin
                byp_4[i] <= 1'b0;
                byp_3[i] <= 1'b1;
                byp_2[i] <= 1'b1;
                byp_1[i] <= 1'b1;
                byp_0[i] <= 1'b1;
              end else if (opA_Dhl == 2'd2)begin
                byp_4[i] <= 1'b0;
                byp_3[i] <= 1'b0;
                byp_2[i] <= 1'b0;
                byp_1[i] <= 1'b1;
                byp_0[i] <= 1'b1;
              end
            end else if (inst_val_B_Dhl && !stall_B_Dhl && rfB_wen_Dhl && (i == rfB_waddr_Dhl)) begin
              if (opB_Dhl == 2'd0) begin
                byp_4[i] <= 1'b1;
                byp_3[i] <= 1'b1;
                byp_2[i] <= 1'b1;
                byp_1[i] <= 1'b1;
                byp_0[i] <= 1'b1;
              end else if (opB_Dhl == 2'd1) begin
                byp_3[i] <= 1'b1;
                byp_2[i] <= 1'b1;
                byp_1[i] <= 1'b1;
                byp_0[i] <= 1'b1;
              end else if (opB_Dhl == 2'd2)begin
                byp_1[i] <= 1'b1;
                byp_0[i] <= 1'b1;
              end            
            end else if (!pending[i]) begin
              byp_4[i] <= 1'b0;    
              byp_3[i] <= 1'b0;          
              byp_2[i] <= 1'b0;          
              byp_1[i] <= 1'b0;          
              byp_0[i] <= 1'b0;  
            end

            if (inst_val_A_Dhl && (i == rfA_waddr_Dhl) && !stall_A_Dhl && writeA && rfA_waddr_Dhl != 5'b0) begin
              fu[i] = 1'b0;
              countdown_4[i] <= 1'b1;
              countdown_3[i] <= 1'b0;
              countdown_2[i] <= 1'b0;
              countdown_1[i] <= 1'b0;
              countdown_0[i] <= 1'b0;
            end else if (inst_val_B_Dhl && (i == rfB_waddr_Dhl) && !stall_B_Dhl && writeB && rfB_waddr_Dhl != 5'b0) begin
              fu[i] = 1'b1;
              countdown_4[i] <= 1'b1;
              countdown_3[i] <= 1'b0;
              countdown_2[i] <= 1'b0;
              countdown_1[i] <= 1'b0;
              countdown_0[i] <= 1'b0;
            end else begin
              countdown_4[i] <= 1'b0;
              if (fu[i] == 1'b0) begin
                if(!stall_A_X0hl) countdown_3[i] <= countdown_4[i];
                if(!stall_A_X1hl) countdown_2[i] <= countdown_3[i];
                if(!stall_A_X2hl) countdown_1[i] <= countdown_2[i];
                if(!stall_A_X3hl) countdown_0[i] <= countdown_1[i];
              end
              if (fu[i] == 1'b1) begin
                if(!stall_B_X0hl) countdown_3[i] <= countdown_4[i];
                if(!stall_B_X1hl) countdown_2[i] <= countdown_3[i];
                if(!stall_B_X2hl) countdown_1[i] <= countdown_2[i];
                if(!stall_B_X3hl) countdown_0[i] <= countdown_1[i];
              end
            end
          end
      end
  end



  wire       rs10_en_Dhl     = cs0[`RISCV_INST_MSG_RS1_EN];
  wire       rs20_en_Dhl     = cs0[`RISCV_INST_MSG_RS2_EN];
  wire       rs11_en_Dhl     = cs1[`RISCV_INST_MSG_RS1_EN];
  wire       rs21_en_Dhl     = cs1[`RISCV_INST_MSG_RS2_EN];

  wire [4:0] rs10_addr_Dhl  = inst0_rs1_Dhl;
  wire [4:0] rs20_addr_Dhl  = inst0_rs2_Dhl;
  wire [4:0] rs11_addr_Dhl  = inst1_rs1_Dhl;
  wire [4:0] rs21_addr_Dhl  = inst1_rs2_Dhl;

/*AX*/
  //opA
  wire rs10_AX0_byp_Dhl = rs10_en_Dhl 
                        && !(rs10 == 5'd0)
                        && countdown_4[rs10]
                        && byp_4[rs10]
                        && (fu[rs10] == 1'b0)
                        && inst_val_A_X0hl;
  wire rs10_AX1_byp_Dhl = rs10_en_Dhl 
                        && !(rs10 == 5'd0)
                        && countdown_3[rs10]
                        && byp_3[rs10]
                        && (fu[rs10] == 1'b0)
                        && inst_val_A_X1hl;
  wire rs10_AX2_byp_Dhl = rs10_en_Dhl 
                        && !(rs10 == 5'd0)
                        && countdown_2[rs10]
                        && byp_2[rs10]
                        && (fu[rs10] == 1'b0)
                        && inst_val_A_X2hl;
  wire rs10_AX3_byp_Dhl = rs10_en_Dhl 
                        && !(rs10 == 5'd0)
                        && countdown_1[rs10]
                        && byp_1[rs10]
                        && (fu[rs10] == 1'b0)
                        && inst_val_A_X3hl;
  wire rs10_AW_byp_Dhl = rs10_en_Dhl 
                        && !(rs10 == 5'd0)
                        && countdown_0[rs10]
                        && byp_0[rs10]
                        && (fu[rs10] == 1'b0)
                        && inst_val_A_Whl;
  wire rs20_AX0_byp_Dhl = rs20_en_Dhl 
                        && !(rs20 == 5'd0)
                        && countdown_4[rs20]
                        && byp_4[rs20]
                        && (fu[rs20] == 1'b0)
                        && inst_val_A_X0hl;
  wire rs20_AX1_byp_Dhl = rs20_en_Dhl 
                        && !(rs20 == 5'd0)
                        && countdown_3[rs20]
                        && byp_3[rs20]
                        && (fu[rs20] == 1'b0)
                        && inst_val_A_X1hl;
  wire rs20_AX2_byp_Dhl = rs20_en_Dhl 
                        && !(rs20 == 5'd0)
                        && countdown_2[rs20]
                        && byp_2[rs20]
                        && (fu[rs20] == 1'b0)
                        && inst_val_A_X2hl;
  wire rs20_AX3_byp_Dhl = rs20_en_Dhl 
                        && !(rs20 == 5'd0)
                        && countdown_1[rs20]
                        && byp_1[rs20]
                        && (fu[rs20] == 1'b0)
                        && inst_val_A_X3hl;
  wire rs20_AW_byp_Dhl = rs20_en_Dhl 
                        && !(rs20 == 5'd0)
                        && countdown_0[rs20]
                        && byp_0[rs20]
                        && (fu[rs20] == 1'b0)
                        && inst_val_A_Whl;

  //opB
  wire rs11_AX0_byp_Dhl = rs11_en_Dhl 
                        && !(rs11 == 5'd0)
                        && countdown_4[rs11]
                        && byp_4[rs11]
                        && (fu[rs11] == 1'b0)
                        && inst_val_A_X0hl;
  wire rs11_AX1_byp_Dhl = rs11_en_Dhl 
                        && !(rs11 == 5'd0)
                        && countdown_3[rs11]
                        && byp_3[rs11]
                        && (fu[rs11] == 1'b0)
                        && inst_val_A_X1hl;
  wire rs11_AX2_byp_Dhl = rs11_en_Dhl 
                        && !(rs11 == 5'd0)
                        && countdown_2[rs11]
                        && byp_2[rs11]
                        && (fu[rs11] == 1'b0)
                        && inst_val_A_X2hl;
  wire rs11_AX3_byp_Dhl = rs11_en_Dhl 
                        && !(rs11 == 5'd0)
                        && countdown_1[rs11]
                        && byp_1[rs11]
                        && (fu[rs11] == 1'b0)
                        && inst_val_A_X3hl;
  wire rs11_AW_byp_Dhl = rs11_en_Dhl 
                        && !(rs11 == 5'd0)
                        && countdown_0[rs11]
                        && byp_0[rs11]
                        && (fu[rs11] == 1'b0)
                        && inst_val_A_Whl;

  wire rs21_AX0_byp_Dhl = rs21_en_Dhl 
                        && !(rs21 == 5'd0)
                        && countdown_4[rs21]
                        && byp_4[rs21]
                        && (fu[rs21] == 1'b0)
                        && inst_val_A_X0hl;        
  wire rs21_AX1_byp_Dhl = rs21_en_Dhl 
                        && !(rs21 == 5'd0)
                        && countdown_3[rs21]
                        && byp_3[rs21]
                        && (fu[rs21] == 1'b0)
                        && inst_val_A_X1hl;
  wire rs21_AX2_byp_Dhl = rs21_en_Dhl 
                        && !(rs21 == 5'd0)
                        && countdown_2[rs21]
                        && byp_2[rs21]
                        && (fu[rs21] == 1'b0)
                        && inst_val_A_X2hl;        
  wire rs21_AX3_byp_Dhl = rs21_en_Dhl 
                        && !(rs21 == 5'd0)
                        && countdown_1[rs21]
                        && byp_1[rs21]
                        && (fu[rs21] == 1'b0)
                        && inst_val_A_X3hl;
  wire rs21_AW_byp_Dhl = rs21_en_Dhl 
                        && !(rs21 == 5'd0)
                        && countdown_0[rs21]
                        && byp_0[rs21]
                        && (fu[rs21] == 1'b0)
                        && inst_val_A_Whl;   

/*BX*/
  //opA
  wire rs10_BX0_byp_Dhl = rs10_en_Dhl 
                        && !(rs10 == 5'd0)
                        && countdown_4[rs10]
                        && byp_4[rs10]
                        && (fu[rs10] == 1'b1)
                        && inst_val_B_X0hl;
  wire rs10_BX1_byp_Dhl = rs10_en_Dhl 
                        && !(rs10 == 5'd0)
                        && countdown_3[rs10]
                        && byp_3[rs10]
                        && (fu[rs10] == 1'b1)
                        && inst_val_B_X1hl;
  wire rs10_BX2_byp_Dhl = rs10_en_Dhl 
                        && !(rs10 == 5'd0)
                        && countdown_2[rs10]
                        && byp_2[rs10]
                        && (fu[rs10] == 1'b1)
                        && inst_val_B_X2hl;
  wire rs10_BX3_byp_Dhl = rs10_en_Dhl 
                        && !(rs10 == 5'd0)
                        && countdown_1[rs10]
                        && byp_1[rs10]
                        && (fu[rs10] == 1'b1)
                        && inst_val_B_X3hl;
  wire rs10_BW_byp_Dhl = rs10_en_Dhl 
                        && !(rs10 == 5'd0)
                        && countdown_0[rs10]
                        && byp_0[rs10]
                        && (fu[rs10] == 1'b1)
                        && inst_val_B_Whl;
  wire rs20_BX0_byp_Dhl = rs20_en_Dhl 
                        && !(rs20 == 5'd0)
                        && countdown_4[rs20]
                        && byp_4[rs20]
                        && (fu[rs20] == 1'b1)
                        && inst_val_B_X0hl;
  wire rs20_BX1_byp_Dhl = rs20_en_Dhl 
                        && !(rs20 == 5'd0)
                        && countdown_3[rs20]
                        && byp_3[rs20]
                        && (fu[rs20] == 1'b1)
                        && inst_val_B_X1hl;
  wire rs20_BX2_byp_Dhl = rs20_en_Dhl 
                        && !(rs20 == 5'd0)
                        && countdown_2[rs20]
                        && byp_2[rs20]
                        && (fu[rs20] == 1'b1)
                        && inst_val_B_X2hl;
  wire rs20_BX3_byp_Dhl = rs20_en_Dhl 
                        && !(rs20 == 5'd0)
                        && countdown_1[rs20]
                        && byp_1[rs20]
                        && (fu[rs20] == 1'b1)
                        && inst_val_B_X3hl;
  wire rs20_BW_byp_Dhl = rs20_en_Dhl 
                        && !(rs20 == 5'd0)
                        && countdown_0[rs20]
                        && byp_0[rs20]
                        && (fu[rs20] == 1'b1)
                        && inst_val_B_Whl;

  //opB
  wire rs11_BX0_byp_Dhl = rs11_en_Dhl 
                        && !(rs11 == 5'd0)
                        && countdown_4[rs11]
                        && byp_4[rs11]
                        && (fu[rs11] == 1'b1)
                        && inst_val_B_X0hl;
  wire rs11_BX1_byp_Dhl = rs11_en_Dhl 
                        && !(rs11 == 5'd0)
                        && countdown_3[rs11]
                        && byp_3[rs11]
                        && (fu[rs11] == 1'b1)
                        && inst_val_B_X1hl;
  wire rs11_BX2_byp_Dhl = rs11_en_Dhl 
                        && !(rs11 == 5'd0)
                        && countdown_2[rs11]
                        && byp_2[rs11]
                        && (fu[rs11] == 1'b1)
                        && inst_val_B_X2hl;
  wire rs11_BX3_byp_Dhl = rs11_en_Dhl 
                        && !(rs11 == 5'd0)
                        && countdown_1[rs11]
                        && byp_1[rs11]
                        && (fu[rs11] == 1'b1)
                        && inst_val_B_X3hl;
  wire rs11_BW_byp_Dhl = rs11_en_Dhl 
                        && !(rs11 == 5'd0)
                        && countdown_0[rs11]
                        && byp_0[rs11]
                        && (fu[rs11] == 1'b1)
                        && inst_val_B_Whl;

  wire rs21_BX0_byp_Dhl = rs21_en_Dhl 
                        && !(rs21 == 5'd0)
                        && countdown_4[rs21]
                        && byp_4[rs21]
                        && (fu[rs21] == 1'b1)
                        && inst_val_B_X0hl;        
  wire rs21_BX1_byp_Dhl = rs21_en_Dhl 
                        && !(rs21 == 5'd0)
                        && countdown_3[rs21]
                        && byp_3[rs21]
                        && (fu[rs21] == 1'b1)
                        && inst_val_B_X1hl;
  wire rs21_BX2_byp_Dhl = rs21_en_Dhl 
                        && !(rs21 == 5'd0)
                        && countdown_2[rs21]
                        && byp_2[rs21]
                        && (fu[rs21] == 1'b1)
                        && inst_val_B_X2hl;        
  wire rs21_BX3_byp_Dhl = rs21_en_Dhl 
                        && !(rs21 == 5'd0)
                        && countdown_1[rs21]
                        && byp_1[rs21]
                        && (fu[rs21] == 1'b1)
                        && inst_val_B_X3hl;
  wire rs21_BW_byp_Dhl = rs21_en_Dhl 
                        && !(rs21 == 5'd0)
                        && countdown_0[rs21]
                        && byp_0[rs21]
                        && (fu[rs21] == 1'b1)
                        && inst_val_B_Whl;                                      


  // Operand Bypass Mux Select

  assign opA0_byp_mux_sel_Dhl
    = (rs10_AX0_byp_Dhl) ? am_AX0_byp
    : (rs10_AX1_byp_Dhl) ? am_AX1_byp
    : (rs10_AX2_byp_Dhl) ? am_AX2_byp
    : (rs10_AX3_byp_Dhl) ? am_AX3_byp
    : (rs10_AW_byp_Dhl)  ? am_AW_byp
    : (rs10_BX0_byp_Dhl) ? am_BX0_byp
    : (rs10_BX1_byp_Dhl) ? am_BX1_byp
    : (rs10_BX2_byp_Dhl) ? am_BX2_byp
    : (rs10_BX3_byp_Dhl) ? am_BX3_byp
    : (rs10_BW_byp_Dhl)  ? am_BW_byp
    :                      am_r0;

  assign opA1_byp_mux_sel_Dhl
    = (rs20_AX0_byp_Dhl) ? bm_AX0_byp
    : (rs20_AX1_byp_Dhl) ? bm_AX1_byp
    : (rs20_AX2_byp_Dhl) ? bm_AX2_byp
    : (rs20_AX3_byp_Dhl) ? bm_AX3_byp
    : (rs20_AW_byp_Dhl)  ? bm_AW_byp
    : (rs20_BX0_byp_Dhl) ? bm_BX0_byp
    : (rs20_BX1_byp_Dhl) ? bm_BX1_byp
    : (rs20_BX2_byp_Dhl) ? bm_BX2_byp
    : (rs20_BX3_byp_Dhl) ? bm_BX3_byp
    : (rs20_BW_byp_Dhl)  ? bm_BW_byp
    :                      bm_r1;

  assign opB0_byp_mux_sel_Dhl
    = (rs11_AX0_byp_Dhl) ? am_AX0_byp
    : (rs11_AX1_byp_Dhl) ? am_AX1_byp
    : (rs11_AX2_byp_Dhl) ? am_AX2_byp
    : (rs11_AX3_byp_Dhl) ? am_AX3_byp
    : (rs11_AW_byp_Dhl)  ? am_AW_byp
    : (rs11_BX0_byp_Dhl) ? am_BX0_byp
    : (rs11_BX1_byp_Dhl) ? am_BX1_byp
    : (rs11_BX2_byp_Dhl) ? am_BX2_byp
    : (rs11_BX3_byp_Dhl) ? am_BX3_byp
    : (rs11_BW_byp_Dhl)  ? am_BW_byp
    :                      am_r0;

  assign opB1_byp_mux_sel_Dhl
    = (rs21_AX0_byp_Dhl) ? bm_AX0_byp
    : (rs21_AX1_byp_Dhl) ? bm_AX1_byp
    : (rs21_AX2_byp_Dhl) ? bm_AX2_byp
    : (rs21_AX3_byp_Dhl) ? bm_AX3_byp
    : (rs21_AW_byp_Dhl)  ? bm_AW_byp
    : (rs21_BX0_byp_Dhl) ? bm_BX0_byp
    : (rs21_BX1_byp_Dhl) ? bm_BX1_byp
    : (rs21_BX2_byp_Dhl) ? bm_BX2_byp
    : (rs21_BX3_byp_Dhl) ? bm_BX3_byp
    : (rs21_BW_byp_Dhl)  ? bm_BW_byp
    :                      bm_r1;

  // Steering Logic
  assign instA_Dhl = stall_ls_A_Dhl ? instA_Dhl :
                    stall_double_nALU_reg ? irB_Dhl : 
                    steering_mux_sel_Dhl ? irB_Dhl : irA_Dhl;
  assign instB_Dhl = stall_ls_A_Dhl ? instB_Dhl : 
                    stall_double_nALU_reg ? 32'bx : 
                    steering_mux_sel_Dhl ? irA_Dhl : irB_Dhl;   

  wire [31:0] instA_Dhl;
  wire [31:0] instB_Dhl;

  wire irA_is_store = ( irA_Dhl[6:0] == 7'b0100011 );
  wire irB_is_load  = ( irB_Dhl[6:0] == 7'b0000011 );
  wire should_stall_ls_Dhl = irA_is_store && irB_is_load;

  wire irA_is_muldiv = ( irA_Dhl[31:25] == 7'b0000001 && irA_Dhl[6:0] == 7'b0110011);
  wire irB_is_muldiv = ( irB_Dhl[31:25] == 7'b0000001 && irB_Dhl[6:0] == 7'b0110011);

  wire irA_is_ALU = !irA_is_muldiv && ( irA_Dhl[6:0] == 7'b0010011 || irA_Dhl[6:0] == 7'b0110011 || irA_Dhl[6:0] == 7'b0110111 || irA_Dhl[6:0] == 7'b0010111);
  wire irB_is_ALU = !irB_is_muldiv && ( irB_Dhl[6:0] == 7'b0010011 || irB_Dhl[6:0] == 7'b0110011 || irB_Dhl[6:0] == 7'b0110111 || irB_Dhl[6:0] == 7'b0010111);
  wire steering_mux_sel_Dhl = (irA_is_ALU && !irB_is_ALU) ? 1'b1 : 1'b0;
  wire stall_double_nALU_Dhl = inst_val_A_Dhl && !irA_is_ALU && inst_val_B_Dhl && !irB_is_ALU;

  reg stall_double_nALU_reg;  
  always @(posedge clk) begin
    if (reset) begin
      stall_double_nALU_reg <= 1'b0;
    end else if (stall_double_nALU_Dhl) begin
      stall_double_nALU_reg <= 1'b1;
    end else begin
      stall_double_nALU_reg <= 1'b0;
    end
  end


  // Jump and Branch Controls
  wire brj_taken_Dhl = (inst_val_A_Dhl && cs0[`RISCV_INST_MSG_J_EN]);

  // wire irA_is_br = ( instA_Dhl[6:0] == 7'b1100011 || instA_Dhl[6:0] == 7'b1100011);
  // wire irB_is_br = ( instB_Dhl[6:0] == 7'b1100011 || instB_Dhl[6:0] == 7'b1100011);
  wire [2:0] br_sel_Dhl = cs0[`RISCV_INST_MSG_BR_SEL];



  // PC Mux Select

  wire [1:0] pc_mux_sel_Dhl = cs0[`RISCV_INST_MSG_PC_SEL];

  // ALU Function

  wire [3:0] aluA_fn_Dhl = cs0[`RISCV_INST_MSG_ALU_FN];
  wire [3:0] aluB_fn_Dhl = cs1[`RISCV_INST_MSG_ALU_FN];

  // Muldiv Function

  wire [2:0] muldivreq_msg_fn_Dhl = cs0[`RISCV_INST_MSG_MULDIV_FN];

  // Muldiv Controls

  wire muldivreq_val_Dhl = cs0[`RISCV_INST_MSG_MULDIV_EN];

  // Muldiv Mux Select

  wire muldiv_mux_sel_Dhl = cs0[`RISCV_INST_MSG_MULDIV_SEL];

  // Execute Mux Select

  wire execute_mux_sel_Dhl = cs0[`RISCV_INST_MSG_MULDIV_EN];

  // wire       is_load_Dhl         = ( cs0[`RISCV_INST_MSG_MEM_REQ] == ld );

  wire       dmemreq_msg_rw_Dhl  = ( cs0[`RISCV_INST_MSG_MEM_REQ] == st );
  wire [1:0] dmemreq_msg_len_Dhl = cs0[`RISCV_INST_MSG_MEM_LEN];
  wire       dmemreq_val_Dhl     = ( cs0[`RISCV_INST_MSG_MEM_REQ] != nr );

  // Memory response mux select

  wire [2:0] dmemresp_mux_sel_Dhl = cs0[`RISCV_INST_MSG_MEM_SEL];

  // Writeback Mux Select

  wire memex_mux_sel_Dhl = cs0[`RISCV_INST_MSG_WB_SEL];

  // Register Writeback Controls

  wire rfA_wen_Dhl         = cs0[`RISCV_INST_MSG_RF_WEN];
  wire rfB_wen_Dhl         = cs1[`RISCV_INST_MSG_RF_WEN];
  wire [4:0] rfA_waddr_Dhl = cs0[`RISCV_INST_MSG_RF_WADDR];
  wire [4:0] rfB_waddr_Dhl = cs1[`RISCV_INST_MSG_RF_WADDR];

  // CSR register write enable

  wire csr_wen_Dhl = cs0[`RISCV_INST_MSG_CSR_WEN];

  // CSR register address

  wire [11:0] csr_addr_Dhl  = instA_Dhl[31:20];

  //----------------------------------------------------------------------
  // Squash and Stall Logic
  //----------------------------------------------------------------------

  wire inst_val_A_Dhl = !bubble_Dhl && !squash_A_Dhl;
  wire inst_val_B_Dhl = !bubble_Dhl && !squash_B_Dhl;

  //squash
  wire squash_br = ( inst_val_A_X0hl && brj_taken_X0hl );
  wire squash_j = ( inst_val_A_Dhl && brj_taken_Dhl );
  wire squash_A_Dhl = ( (!stall_A_Dhl && stall_B_reg && !stall_A_reg) || squash_br );
  wire squash_B_Dhl = ( (!stall_B_Dhl && stall_A_reg && !stall_B_reg) || squash_br || stall_double_nALU_reg);
  
  //stall
  wire stall_SB_A_Dhl = inst_val_A_Dhl && ((pending[rs10] && !byp[rs10]) || (pending[rs20] && !byp[rs20]));
  wire stall_SB_B_Dhl = inst_val_B_Dhl && ((pending[rs11] && !byp[rs11]) || (pending[rs21] && !byp[rs21]));

  wire stall_RAW_A_Dhl = steering_mux_sel_Dhl && (inst_val_A_Dhl && inst_val_B_Dhl && rfB_wen_Dhl && (rfB_waddr_Dhl != 5'b0) && ((rs10_en_Dhl && (rs10 == rfB_waddr_Dhl)) || (rs20_en_Dhl && (rs20 == rfB_waddr_Dhl))));
  wire stall_RAW_B_Dhl = (inst_val_B_Dhl && inst_val_A_Dhl && rfA_wen_Dhl && (rfA_waddr_Dhl != 5'b0) && ((rs11_en_Dhl && (rs11 == rfA_waddr_Dhl)) || (rs21_en_Dhl && (rs21 == rfA_waddr_Dhl))));

  wire stall_WAR_B_Dhl = !steering_mux_sel_Dhl && stall_A_Dhl && (inst_val_A_Dhl && inst_val_B_Dhl && rfB_wen_Dhl && (rfB_waddr_Dhl != 5'b0) && ((rs10_en_Dhl && (rs10 == rfB_waddr_Dhl)) || (rs20_en_Dhl && (rs20 == rfB_waddr_Dhl))));
  wire stall_WAW_B_Dhl = !steering_mux_sel_Dhl && (inst_val_B_Dhl && inst_val_A_Dhl && rfA_wen_Dhl && rfB_wen_Dhl && (rfA_waddr_Dhl != 5'b0) && (rfB_waddr_Dhl == rfA_waddr_Dhl));
  wire stall_ls_A_Dhl = inst_val_A_Dhl && (stall_ls_reg || stall_ls_reg2);
  
  wire stall_A_Dhl = ( stall_SB_A_Dhl || (stall_RAW_A_Dhl && !stall_WAW_B_Dhl) || stall_A_X0hl );
  wire stall_B_Dhl = ( stall_SB_B_Dhl || stall_RAW_B_Dhl || stall_double_nALU_Dhl || stall_B_X0hl || stall_WAW_B_Dhl || stall_WAR_B_Dhl);

  wire stall_Dhl = (stall_A_Dhl || stall_B_Dhl);
  wire squash_Dhl = (squash_A_Dhl || squash_B_Dhl);

  reg stall_A_reg;
  reg stall_B_reg;

  always @(posedge clk) begin
    if(reset) begin
      stall_A_reg = 1'b0;
      stall_B_reg = 1'b0;
    end else begin
      if(stall_A_Dhl) begin
        stall_A_reg <= 1'b1;
      end else begin
        stall_A_reg <= 1'b0;
      end
      if(stall_B_Dhl) begin
        stall_B_reg <= 1'b1;
      end else begin
        stall_B_reg <= 1'b0;
      end
    end
  end

  reg stall_ls_reg;
  reg stall_ls_reg2;

  always @(posedge clk) begin
    if(reset) begin
      stall_ls_reg = 1'b0;
    end else begin
      if(should_stall_ls_Dhl) begin
        stall_ls_reg <= 1'b1;
      end else begin
        stall_ls_reg <= 1'b0;
      end
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      stall_ls_reg2 = 1'b0;
    end else begin
      if(stall_ls_reg) begin
        stall_ls_reg2 <= 1'b1;
      end else begin
        stall_ls_reg2 <= 1'b0;
      end
    end
  end

  // Next bubble bit
  wire bubble_sel_A_Dhl  = ( squash_A_Dhl || stall_A_Dhl );
  wire bubble_next_A_Dhl = ( !bubble_sel_A_Dhl ) ? bubble_Dhl
                         : ( bubble_sel_A_Dhl )  ? 1'b1
                         :                         1'bx;
  wire bubble_sel_B_Dhl  = ( squash_B_Dhl || stall_B_Dhl );
  wire bubble_next_B_Dhl = ( !bubble_sel_B_Dhl ) ? bubble_Dhl
                         : ( bubble_sel_B_Dhl )  ? 1'b1
                         :                         1'bx;                         

  //----------------------------------------------------------------------
  // X0 <- D
  //----------------------------------------------------------------------

  reg [31:0] instA_X0hl;
  reg [31:0] instB_X0hl;
  reg  [2:0] br_sel_X0hl;
  reg  [3:0] aluA_fn_X0hl;
  reg  [3:0] aluB_fn_X0hl;
  reg        muldivreq_val_X0hl;
  reg  [2:0] muldivreq_msg_fn_X0hl;
  reg        muldiv_mux_sel_X0hl;
  reg        execute_mux_sel_X0hl;
  reg        dmemreq_msg_rw_X0hl;
  reg  [1:0] dmemreq_msg_len_X0hl;
  reg        dmemreq_val_X0hl;
  reg  [2:0] dmemresp_mux_sel_X0hl;
  reg        memex_mux_sel_X0hl;
  reg        rfA_wen_X0hl;
  reg  [4:0] rfA_waddr_X0hl;
  reg        rfB_wen_X0hl;
  reg  [4:0] rfB_waddr_X0hl;
  reg        csr_wen_X0hl;
  reg [11:0] csr_addr_X0hl;
  reg        bubble_A_X0hl;
  reg        bubble_B_X0hl;
  reg [1:0]  opA_X0hl;
  reg [1:0]  opB_X0hl;

  // Pipeline Controls

  always @ ( posedge clk ) begin
    if ( reset ) begin
      bubble_A_X0hl <= 1'b1;
      bubble_B_X0hl <= 1'b1;
    end
    else begin
      if( !stall_A_X0hl ) begin
        instA_X0hl              <= instA_Dhl;
        br_sel_X0hl           <= br_sel_Dhl;
        aluA_fn_X0hl          <= aluA_fn_Dhl;
        muldivreq_val_X0hl    <= muldivreq_val_Dhl;
        muldivreq_msg_fn_X0hl <= muldivreq_msg_fn_Dhl;
        muldiv_mux_sel_X0hl   <= muldiv_mux_sel_Dhl;
        execute_mux_sel_X0hl  <= execute_mux_sel_Dhl;
        dmemreq_msg_rw_X0hl   <= dmemreq_msg_rw_Dhl;
        dmemreq_msg_len_X0hl  <= dmemreq_msg_len_Dhl;
        dmemreq_val_X0hl      <= dmemreq_val_Dhl;
        dmemresp_mux_sel_X0hl <= dmemresp_mux_sel_Dhl;
        memex_mux_sel_X0hl    <= memex_mux_sel_Dhl;
        rfA_wen_X0hl          <= rfA_wen_Dhl;
        rfA_waddr_X0hl        <= rfA_waddr_Dhl;
        csr_wen_X0hl          <= csr_wen_Dhl;
        csr_addr_X0hl         <= csr_addr_Dhl;
        bubble_A_X0hl         <= bubble_next_A_Dhl;
        opA_X0hl              <= opA_Dhl;
      end
      if( !stall_B_X0hl ) begin
        instB_X0hl              <= instB_Dhl;
        aluB_fn_X0hl          <= aluB_fn_Dhl;
        rfB_wen_X0hl          <= rfB_wen_Dhl;
        rfB_waddr_X0hl        <= rfB_waddr_Dhl;
        bubble_B_X0hl         <= bubble_next_B_Dhl;
        opB_X0hl              <= opB_Dhl;
      end
    end
  end

  //----------------------------------------------------------------------
  // Execute Stage
  //----------------------------------------------------------------------

  // Is the current stage valid?

  wire inst_val_A_X0hl = ( !bubble_A_X0hl && !squash_A_X0hl );
  wire inst_val_B_X0hl = ( !bubble_B_X0hl );

  // Muldiv request

  assign muldivreq_val = muldivreq_val_Dhl && inst_val_A_Dhl && (!bubble_next_A_Dhl);
  assign muldivresp_rdy = 1'b1;
  wire muldiv_stall_mult1 = stall_A_X1hl;

  // Only send a valid dmem request if not stalled

  assign dmemreq_msg_rw  = dmemreq_msg_rw_X0hl;
  assign dmemreq_msg_len = dmemreq_msg_len_X0hl;
  assign dmemreq_val     = ( inst_val_A_X0hl && !stall_A_X0hl && dmemreq_val_X0hl );

  // Resolve Branch

  wire bne_taken_X0hl  = ( ( br_sel_X0hl == br_bne ) && branch_cond_ne_X0hl );
  wire beq_taken_X0hl  = ( ( br_sel_X0hl == br_beq ) && branch_cond_eq_X0hl );
  wire blt_taken_X0hl  = ( ( br_sel_X0hl == br_blt ) && branch_cond_lt_X0hl );
  wire bltu_taken_X0hl = ( ( br_sel_X0hl == br_bltu) && branch_cond_ltu_X0hl);
  wire bge_taken_X0hl  = ( ( br_sel_X0hl == br_bge ) && branch_cond_ge_X0hl );
  wire bgeu_taken_X0hl = ( ( br_sel_X0hl == br_bgeu) && branch_cond_geu_X0hl);


  wire any_br_taken_X0hl
    = ( beq_taken_X0hl
   ||   bne_taken_X0hl
   ||   blt_taken_X0hl
   ||   bltu_taken_X0hl
   ||   bge_taken_X0hl
   ||   bgeu_taken_X0hl );

  wire brj_taken_X0hl = ( inst_val_A_X0hl && any_br_taken_X0hl );

  // Dummy Squash Signal

  wire squash_A_X0hl = 1'b0;
  wire squash_B_X0hl = 1'b0;


  // Stall in X if muldiv reponse is not valid and there was a valid request

  wire stall_muldiv_X0hl = 1'b0; //( muldivreq_val_X0hl && inst_val_X0hl && !muldivresp_val );

  // Stall in X if imem is not ready

  wire stall_imem_X0hl = !imemreq0_rdy || !imemreq1_rdy;

  // Stall in X if dmem is not ready and there was a valid request

  wire stall_dmem_X0hl = ( dmemreq_val_X0hl && inst_val_A_X0hl && !dmemreq_rdy );

  // Aggregate Stall Signal

  wire stall_A_X0hl = ( stall_A_X1hl || stall_muldiv_X0hl || stall_imem_X0hl || stall_dmem_X0hl );
  wire stall_B_X0hl = ( stall_B_X1hl );


  // Next bubble bit

  wire bubble_sel_A_X0hl  = ( squash_A_X0hl || stall_A_X0hl );
  wire bubble_next_A_X0hl = ( !bubble_sel_A_X0hl ) ? bubble_A_X0hl
                          : ( bubble_sel_A_X0hl )  ? 1'b1
                          :                          1'bx;
  wire bubble_sel_B_X0hl  = ( squash_B_X0hl );
  wire bubble_next_B_X0hl = ( !bubble_sel_B_X0hl ) ? bubble_B_X0hl
                          : ( bubble_sel_B_X0hl )  ? 1'b1
                          :                          1'bx;                          

  //----------------------------------------------------------------------
  // X1 <- X0
  //----------------------------------------------------------------------

  reg [31:0] instA_X1hl;
  reg [31:0] instB_X1hl;
  reg        dmemreq_val_X1hl;
  reg  [2:0] dmemresp_mux_sel_X1hl;
  reg        memex_mux_sel_X1hl;
  reg        execute_mux_sel_X1hl;
  reg        muldiv_mux_sel_X1hl;
  reg        rfA_wen_X1hl;
  reg  [4:0] rfA_waddr_X1hl;
  reg        rfB_wen_X1hl;
  reg  [4:0] rfB_waddr_X1hl;
  reg        csr_wen_X1hl;
  reg  [11:0] csr_addr_X1hl;
  reg        bubble_A_X1hl;
  reg        bubble_B_X1hl;
  reg [1:0]  opA_X1hl;
  reg [1:0]  opB_X1hl;

  // Pipeline Controls

  always @ ( posedge clk ) begin
    if ( reset ) begin
      dmemreq_val_X1hl <= 1'b0;
      bubble_A_X1hl <= 1'b1;
      bubble_B_X1hl <= 1'b1;
    end
    else begin
      if( !stall_A_X1hl ) begin
        instA_X1hl              <= instA_X0hl;
        dmemreq_val_X1hl      <= dmemreq_val;
        dmemresp_mux_sel_X1hl <= dmemresp_mux_sel_X0hl;
        memex_mux_sel_X1hl    <= memex_mux_sel_X0hl;
        execute_mux_sel_X1hl  <= execute_mux_sel_X0hl;
        muldiv_mux_sel_X1hl   <= muldiv_mux_sel_X0hl;
        rfA_wen_X1hl          <= rfA_wen_X0hl;
        rfA_waddr_X1hl        <= rfA_waddr_X0hl;
        csr_wen_X1hl          <= csr_wen_X0hl;
        csr_addr_X1hl         <= csr_addr_X0hl;
        bubble_A_X1hl           <= bubble_next_A_X0hl;
        opA_X1hl              <= opA_X0hl;       
      end
      if( !stall_B_X1hl ) begin
        instB_X1hl              <= instB_X0hl;
        rfB_wen_X1hl          <= rfB_wen_X0hl;
        rfB_waddr_X1hl        <= rfB_waddr_X0hl;
        bubble_B_X1hl           <= bubble_next_B_X0hl;
        opB_X1hl              <= opB_X0hl;        
      end      
    end
  end
  //----------------------------------------------------------------------
  // X1 Stage
  //----------------------------------------------------------------------

  // Is current stage valid?

  wire inst_val_A_X1hl = ( !bubble_A_X1hl && !squash_A_X1hl );
  wire inst_val_B_X1hl = ( !bubble_B_X1hl );

  // Data memory queue control signals

  assign dmemresp_queue_en_X1hl = ( stall_A_X1hl && dmemresp_val );
  wire   dmemresp_queue_val_next_X1hl
    = stall_A_X1hl && ( dmemresp_val || dmemresp_queue_val_X1hl );

  // Dummy Squash Signal

  wire squash_A_X1hl = 1'b0;
  wire squash_B_X1hl = 1'b0;

  // Stall in X1 if memory response is not returned for a valid request

  wire stall_dmem_A_X1hl
    = ( !reset && dmemreq_val_X1hl && inst_val_A_X1hl && !dmemresp_val && !dmemresp_queue_val_X1hl );
  wire stall_imem_A_X1hl
    = ( !reset && imemreq_val_Fhl && inst_val_Fhl && !imemresp0_val && !imemresp0_queue_val_Fhl )
   || ( !reset && imemreq_val_Fhl && inst_val_Fhl && !imemresp1_val && !imemresp1_queue_val_Fhl );

  // Aggregate Stall Signal

  wire stall_A_X1hl = ( stall_imem_A_X1hl || stall_dmem_A_X1hl );
  wire stall_B_X1hl = 1'b0;


  // Next bubble bit

  wire bubble_sel_A_X1hl  = ( squash_A_X1hl || stall_A_X1hl );
  wire bubble_next_A_X1hl = ( !bubble_sel_A_X1hl ) ? bubble_A_X1hl
                       : ( bubble_sel_A_X1hl )  ? 1'b1
                       :                       1'bx;
  wire bubble_sel_B_X1hl  = ( squash_B_X1hl );
  wire bubble_next_B_X1hl = ( !bubble_sel_B_X1hl ) ? bubble_B_X1hl
                       : ( bubble_sel_B_X1hl )  ? 1'b1
                       :                       1'bx;                       

  //----------------------------------------------------------------------
  // X2 <- X1
  //----------------------------------------------------------------------

  reg [31:0] instA_X2hl;
  reg [31:0] instB_X2hl;
  reg        dmemresp_queue_val_X1hl;
  reg        rfA_wen_X2hl;
  reg  [4:0] rfA_waddr_X2hl;
  reg        rfB_wen_X2hl;
  reg  [4:0] rfB_waddr_X2hl;
  reg        csr_wen_X2hl;
  reg  [11:0] csr_addr_X2hl;
  reg        execute_mux_sel_X2hl;
  reg        muldiv_mux_sel_X2hl;
  reg        bubble_A_X2hl;
  reg        bubble_B_X2hl;
  reg [1:0]  opA_X2hl;
  reg [1:0]  opB_X2hl;


  // Pipeline Controls

  always @ ( posedge clk ) begin
    if ( reset ) begin
      bubble_A_X2hl <= 1'b1;
      bubble_B_X2hl <= 1'b1;
    end
    else begin
      if( !stall_A_X2hl ) begin
        instA_X2hl              <= instA_X1hl;
        muldiv_mux_sel_X2hl   <= muldiv_mux_sel_X1hl;
        rfA_wen_X2hl          <= rfA_wen_X1hl;
        rfA_waddr_X2hl        <= rfA_waddr_X1hl;
        csr_wen_X2hl          <= csr_wen_X1hl;
        csr_addr_X2hl         <= csr_addr_X1hl;
        execute_mux_sel_X2hl  <= execute_mux_sel_X1hl;
        bubble_A_X2hl           <= bubble_next_A_X1hl;
        opA_X2hl              <= opA_X1hl;
      end
      if( !stall_B_X2hl ) begin
        instB_X2hl              <= instB_X1hl;
        rfB_wen_X2hl          <= rfB_wen_X1hl;
        rfB_waddr_X2hl        <= rfB_waddr_X1hl;
        bubble_B_X2hl           <= bubble_next_B_X1hl;
        opB_X2hl              <= opB_X1hl;
      end      
    end
    dmemresp_queue_val_X1hl <= dmemresp_queue_val_next_X1hl;
  end

  //----------------------------------------------------------------------
  // X2 Stage
  //----------------------------------------------------------------------

  // Is current stage valid?

  wire inst_val_A_X2hl = ( !bubble_A_X2hl && !squash_A_X2hl );
  wire inst_val_B_X2hl = ( !bubble_B_X2hl && !squash_B_X2hl );

  // Dummy Squash Signal

  wire squash_A_X2hl = 1'b0;
  wire squash_B_X2hl = 1'b0;

  // Dummy Stall Signal

  wire stall_A_X2hl = 1'b0;
  wire stall_B_X2hl = 1'b0;

  // Next bubble bit

  wire bubble_sel_A_X2hl  = ( squash_A_X2hl || stall_A_X2hl );
  wire bubble_next_A_X2hl = ( !bubble_sel_A_X2hl ) ? bubble_A_X2hl
                       : ( bubble_sel_A_X2hl )  ? 1'b1
                       :                       1'bx;
  wire bubble_sel_B_X2hl  = ( squash_B_X2hl );
  wire bubble_next_B_X2hl = ( !bubble_sel_B_X2hl ) ? bubble_B_X2hl
                       : ( bubble_sel_B_X2hl )  ? 1'b1
                       :                       1'bx;                       

  //----------------------------------------------------------------------
  // X3 <- X2
  //----------------------------------------------------------------------

  reg [31:0] instA_X3hl;
  reg [31:0] instB_X3hl;
  reg        rfA_wen_X3hl;
  reg  [4:0] rfA_waddr_X3hl;
  reg        rfB_wen_X3hl;
  reg  [4:0] rfB_waddr_X3hl;
  reg        csr_wen_X3hl;
  reg  [11:0] csr_addr_X3hl;
  reg        execute_mux_sel_X3hl;
  reg        muldiv_mux_sel_X3hl;
  reg        bubble_A_X3hl;
  reg        bubble_B_X3hl;
  reg [1:0]  opA_X3hl;
  reg [1:0]  opB_X3hl;

  // Pipeline Controls

  always @ ( posedge clk ) begin
    if ( reset ) begin
      bubble_A_X3hl <= 1'b1;
      bubble_B_X3hl <= 1'b1;
    end
    else begin
      if( !stall_A_X3hl ) begin
        instA_X3hl              <= instA_X2hl;
        muldiv_mux_sel_X3hl   <= muldiv_mux_sel_X2hl;
        rfA_wen_X3hl          <= rfA_wen_X2hl;
        rfA_waddr_X3hl        <= rfA_waddr_X2hl;
        csr_wen_X3hl          <= csr_wen_X2hl;
        csr_addr_X3hl         <= csr_addr_X2hl;
        execute_mux_sel_X3hl  <= execute_mux_sel_X2hl;
        bubble_A_X3hl           <= bubble_next_A_X2hl;
        opA_X3hl              <= opA_X2hl;
      end
      if( !stall_B_X3hl ) begin
        instB_X3hl              <= instB_X2hl;
        rfB_wen_X3hl          <= rfB_wen_X2hl;
        rfB_waddr_X3hl        <= rfB_waddr_X2hl;
        bubble_B_X3hl           <= bubble_next_B_X2hl;
        opB_X3hl              <= opB_X2hl;
      end      
    end
  end

  //----------------------------------------------------------------------
  // X3 Stage
  //----------------------------------------------------------------------

  // Is current stage valid?

  wire inst_val_A_X3hl = ( !bubble_A_X3hl && !squash_A_X3hl );
  wire inst_val_B_X3hl = ( !bubble_B_X3hl && !squash_B_X3hl );

  // Dummy Squash Signal

  wire squash_A_X3hl = 1'b0;
  wire squash_B_X3hl = 1'b0;

  // Dummy Stall Signal

  wire stall_A_X3hl = 1'b0;
  wire stall_B_X3hl = 1'b0;


  // Next bubble bit

  wire bubble_sel_A_X3hl  = ( squash_A_X3hl || stall_A_X3hl );
  wire bubble_next_A_X3hl = ( !bubble_sel_A_X3hl ) ? bubble_A_X3hl
                       : ( bubble_sel_A_X3hl )  ? 1'b1
                       :                       1'bx;
  wire bubble_sel_B_X3hl  = ( squash_B_X3hl );
  wire bubble_next_B_X3hl = ( !bubble_sel_B_X3hl ) ? bubble_B_X3hl
                       : ( bubble_sel_B_X3hl )  ? 1'b1
                       :                       1'bx;
  //----------------------------------------------------------------------
  // W <- X3
  //----------------------------------------------------------------------

  reg [31:0] instA_Whl;
  reg [31:0] instB_Whl;
  reg        rfA_wen_Whl;
  reg  [4:0] rfA_waddr_Whl;
  reg        rfB_wen_Whl;
  reg  [4:0] rfB_waddr_Whl;
  reg        csr_wen_Whl;
  reg  [11:0] csr_addr_Whl;
  reg        bubble_A_Whl;
  reg        bubble_B_Whl;
  reg [1:0]  opA_Whl;
  reg [1:0]  opB_Whl;

  // Pipeline Controls

  always @ ( posedge clk ) begin
    if ( reset ) begin
      bubble_A_Whl <= 1'b1;
      bubble_B_Whl <= 1'b1;
    end
    else begin
      if( !stall_A_Whl ) begin
        instA_Whl          <= instA_X3hl;
        rfA_wen_Whl      <= rfA_wen_X3hl;
        rfA_waddr_Whl    <= rfA_waddr_X3hl;
        bubble_A_Whl       <= bubble_next_A_X3hl;
        opA_Whl              <= opA_X3hl;
        csr_wen_Whl       <= csr_wen_X3hl;
        csr_addr_Whl      <= csr_addr_X3hl;
      end
      if( !stall_B_Whl ) begin
        instB_Whl          <= instB_X3hl;
        rfB_wen_Whl      <= rfB_wen_X3hl;
        rfB_waddr_Whl    <= rfB_waddr_X3hl;
        bubble_B_Whl       <= bubble_next_B_X3hl;
        opB_Whl              <= opB_X3hl;
      end      
    end
  end

  //----------------------------------------------------------------------
  // Writeback Stage
  //----------------------------------------------------------------------

  // Is current stage valid?

  wire inst_val_A_Whl = ( !bubble_A_Whl && !squash_A_Whl );
  wire inst_val_B_Whl = ( !bubble_B_Whl && !squash_B_Whl );

  // Only set register file wen if stage is valid

  assign rfA_wen_out_Whl = ( inst_val_A_Whl && !stall_A_Whl && rfA_wen_Whl );
  assign rfB_wen_out_Whl = ( inst_val_B_Whl && rfB_wen_Whl );


  // Dummy squash and stall signals

  wire squash_A_Whl = 1'b0;
  wire stall_A_Whl  = 1'b0;
  wire squash_B_Whl = 1'b0;
  wire stall_B_Whl  = 1'b0;

  //----------------------------------------------------------------------
  // Debug registers for instruction disassembly
  //----------------------------------------------------------------------

  reg [31:0] irA_debug;
  reg [31:0] irB_debug;
  reg        inst_val_debug;

  always @ ( posedge clk ) begin
    irA_debug       <= instA_Whl;
    irB_debug       <= instB_Whl;
    inst_val_debug <= inst_val_A_Whl;
  end

  //----------------------------------------------------------------------
  // CSR register
  //----------------------------------------------------------------------

  reg  [31:0] csr_status;
  reg         csr_stats;

  always @ ( posedge clk ) begin
    if ( csr_wen_Whl && inst_val_A_Whl ) begin
      case ( csr_addr_Whl )
        12'd10 : csr_stats  <= proc2csr_data_Whl[0];
        12'd21 : csr_status <= proc2csr_data_Whl;
      endcase
    end
  end

//========================================================================
// Disassemble instructions
//========================================================================

  `ifndef SYNTHESIS

  riscv_InstMsgDisasm inst0_msg_disasm_D
  (
    .msg ( instA_Dhl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_X0
  (
    .msg ( instA_X0hl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_X1
  (
    .msg ( instA_X1hl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_X2
  (
    .msg ( instA_X2hl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_X3
  (
    .msg ( instA_X3hl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_W
  (
    .msg ( instA_Whl )
  );

  riscv_InstMsgDisasm instA_msg_disasm_debug
  (
    .msg ( irA_debug )
  );

  riscv_InstMsgDisasm inst1_msg_disasm_D
  (
    .msg ( instB_Dhl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_X0
  (
    .msg ( instB_X0hl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_X1
  (
    .msg ( instB_X1hl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_X2
  (
    .msg ( instB_X2hl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_X3
  (
    .msg ( instB_X3hl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_W
  (
    .msg ( instB_Whl )
  );

  riscv_InstMsgDisasm instB_msg_disasm_debug
  (
    .msg ( irB_debug )
  );

  `endif

//========================================================================
// Assertions
//========================================================================
// Detect illegal instructions and terminate the simulation if multiple
// illegal instructions are detected in succession.

  `ifndef SYNTHESIS

  reg overload = 1'b0;

  always @ ( posedge clk ) begin
    if (( !cs0[`RISCV_INST_MSG_INST_VAL] && !reset ) 
     || ( !cs1[`RISCV_INST_MSG_INST_VAL] && !reset )) begin
      $display(" RTL-ERROR : %m : Illegal instruction!");

      if ( overload == 1'b1 ) begin
        $finish;
      end

      overload = 1'b1;
    end
    else begin
      overload = 1'b0;
    end
  end

  `endif

//========================================================================
// Stats
//========================================================================

  `ifndef SYNTHESIS

  wire [31:0] num_inst = num_inst_A + num_inst_B;
  reg [31:0] num_inst_A    = 32'b0;
  reg [31:0] num_inst_B    = 32'b0;
  reg [31:0] num_cycles  = 32'b0;
  reg        stats_en    = 1'b0; // Used for enabling stats on asm tests

  always @( posedge clk ) begin
    if ( !reset ) begin

      // Count cycles if stats are enabled

      if ( stats_en || csr_stats ) begin
        num_cycles = num_cycles + 1;

        // Count instructions for every cycle not squashed or stalled

        // FIXME: fix this when you can have at most two instructions issued per cycle!
        if ( prev_irA_Dhl != irA_Dhl ) begin
          num_inst_A = num_inst_A + 1;
        end
        if ( prev_irB_Dhl != irB_Dhl ) begin
          num_inst_B = num_inst_B + 1;
        end
      end

    end
  end

  `endif

endmodule

`endif

// vim: set textwidth=0 ts=2 sw=2 sts=2 :