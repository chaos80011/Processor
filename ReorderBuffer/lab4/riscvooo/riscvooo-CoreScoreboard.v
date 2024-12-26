//=========================================================================
// 5-Stage RISCV Scoreboard
//=========================================================================

`ifndef RISCV_CORE_SCOREBOARD_V
`define RISCV_CORE_SCOREBOARD_V

`define FUNC_UNIT_ALU 1
`define FUNC_UNIT_MEM 2
`define FUNC_UNIT_MUL 3

// Didn't check whether the reg id is 0 or not.
// Thus may have unnecessary stalls

module riscv_CoreScoreboard
(
  input         clk,
  input         reset,
  input  [ 4:0] src0,             // Source register 0
  input         src0_en,          // Use source register 0
  input  [ 4:0] src1,             // Source register 1
  input         src1_en,          // Use source register 1
  input  [ 4:0] dst,              // Destination register
  input         dst_en,           // Write to destination register
  input  [ 2:0] func_unit,        // Functional Unit
  input  [ 4:0] latency,          // Instruction latency (one-hot)
  input         inst_val_Dhl,     // Instruction valid
  input         stall_Dhl,

  input  [ 3:0] rob_alloc_slot,   // ROB slot allocated to dst reg
  input  [ 3:0] rob_commit_slot,  // ROB slot emptied during commit
  input         rob_commit_wen,   // ROB slot emptied during commit

  input  [ 4:0] stalls,           // Input stall signals

  output [ 2:0] src0_byp_mux_sel, // Source reg 0 byp mux
  output [ 3:0] src0_byp_rob_slot,// Source reg 0 ROB slot
  output [ 2:0] src1_byp_mux_sel, // Source reg 1 byp mux
  output [ 3:0] src1_byp_rob_slot,// Source reg 1 ROB slot

  output        stall_hazard,     // Destination register ready
  output [ 1:0] wb_mux_sel,       // Writeback mux sel out
  output        stall_wb_hazard_M,
  output        stall_wb_hazard_X
);

  reg       pending          [31:0];
  reg [2:0] functional_unit  [31:0];
  reg [4:0] reg_latency      [31:0];
  reg [3:0] reg_rob_slot     [31:0];

  // Wires for pending array
  wire pending_0  = pending[0];
  wire pending_1  = pending[1];
  wire pending_2  = pending[2];
  wire pending_3  = pending[3];
  wire pending_4  = pending[4];
  wire pending_5  = pending[5];
  wire pending_6  = pending[6];
  wire pending_7  = pending[7];
  wire pending_8  = pending[8];
  wire pending_9  = pending[9];
  wire pending_10 = pending[10];
  wire pending_11 = pending[11];
  wire pending_12 = pending[12];
  wire pending_13 = pending[13];
  wire pending_14 = pending[14];
  wire pending_15 = pending[15];
  wire pending_16 = pending[16];
  wire pending_17 = pending[17];
  wire pending_18 = pending[18];
  wire pending_19 = pending[19];
  wire pending_20 = pending[20];
  wire pending_21 = pending[21];
  wire pending_22 = pending[22];
  wire pending_23 = pending[23];
  wire pending_24 = pending[24];
  wire pending_25 = pending[25];
  wire pending_26 = pending[26];
  wire pending_27 = pending[27];
  wire pending_28 = pending[28];
  wire pending_29 = pending[29];
  wire pending_30 = pending[30];
  wire pending_31 = pending[31];

  // Wires for functional_unit array
  wire [2:0] fu_0  = functional_unit[0];
  wire [2:0] fu_1  = functional_unit[1];
  wire [2:0] fu_2  = functional_unit[2];
  wire [2:0] fu_3  = functional_unit[3];
  wire [2:0] fu_4  = functional_unit[4];
  wire [2:0] fu_5  = functional_unit[5];
  wire [2:0] fu_6  = functional_unit[6];
  wire [2:0] fu_7  = functional_unit[7];
  wire [2:0] fu_8  = functional_unit[8];
  wire [2:0] fu_9  = functional_unit[9];
  wire [2:0] fu_10 = functional_unit[10];
  wire [2:0] fu_11 = functional_unit[11];
  wire [2:0] fu_12 = functional_unit[12];
  wire [2:0] fu_13 = functional_unit[13];
  wire [2:0] fu_14 = functional_unit[14];
  wire [2:0] fu_15 = functional_unit[15];
  wire [2:0] fu_16 = functional_unit[16];
  wire [2:0] fu_17 = functional_unit[17];
  wire [2:0] fu_18 = functional_unit[18];
  wire [2:0] fu_19 = functional_unit[19];
  wire [2:0] fu_20 = functional_unit[20];
  wire [2:0] fu_21 = functional_unit[21];
  wire [2:0] fu_22 = functional_unit[22];
  wire [2:0] fu_23 = functional_unit[23];
  wire [2:0] fu_24 = functional_unit[24];
  wire [2:0] fu_25 = functional_unit[25];
  wire [2:0] fu_26 = functional_unit[26];
  wire [2:0] fu_27 = functional_unit[27];
  wire [2:0] fu_28 = functional_unit[28];
  wire [2:0] fu_29 = functional_unit[29];
  wire [2:0] fu_30 = functional_unit[30];
  wire [2:0] fu_31 = functional_unit[31];

  // Wires for reg_latency array
  wire [4:0] reg_lat_0  = reg_latency[0];
  wire [4:0] reg_lat_1  = reg_latency[1];
  wire [4:0] reg_lat_2  = reg_latency[2];
  wire [4:0] reg_lat_3  = reg_latency[3];
  wire [4:0] reg_lat_4  = reg_latency[4];
  wire [4:0] reg_lat_5  = reg_latency[5];
  wire [4:0] reg_lat_6  = reg_latency[6];
  wire [4:0] reg_lat_7  = reg_latency[7];
  wire [4:0] reg_lat_8  = reg_latency[8];
  wire [4:0] reg_lat_9  = reg_latency[9];
  wire [4:0] reg_lat_10 = reg_latency[10];
  wire [4:0] reg_lat_11 = reg_latency[11];
  wire [4:0] reg_lat_12 = reg_latency[12];
  wire [4:0] reg_lat_13 = reg_latency[13];
  wire [4:0] reg_lat_14 = reg_latency[14];
  wire [4:0] reg_lat_15 = reg_latency[15];
  wire [4:0] reg_lat_16 = reg_latency[16];
  wire [4:0] reg_lat_17 = reg_latency[17];
  wire [4:0] reg_lat_18 = reg_latency[18];
  wire [4:0] reg_lat_19 = reg_latency[19];
  wire [4:0] reg_lat_20 = reg_latency[20];
  wire [4:0] reg_lat_21 = reg_latency[21];
  wire [4:0] reg_lat_22 = reg_latency[22];
  wire [4:0] reg_lat_23 = reg_latency[23];
  wire [4:0] reg_lat_24 = reg_latency[24];
  wire [4:0] reg_lat_25 = reg_latency[25];
  wire [4:0] reg_lat_26 = reg_latency[26];
  wire [4:0] reg_lat_27 = reg_latency[27];
  wire [4:0] reg_lat_28 = reg_latency[28];
  wire [4:0] reg_lat_29 = reg_latency[29];
  wire [4:0] reg_lat_30 = reg_latency[30];
  wire [4:0] reg_lat_31 = reg_latency[31];

  // Wires for reg_rob_slot array
  wire [3:0] rob_slot_0  = reg_rob_slot[0];
  wire [3:0] rob_slot_1  = reg_rob_slot[1];
  wire [3:0] rob_slot_2  = reg_rob_slot[2];
  wire [3:0] rob_slot_3  = reg_rob_slot[3];
  wire [3:0] rob_slot_4  = reg_rob_slot[4];
  wire [3:0] rob_slot_5  = reg_rob_slot[5];
  wire [3:0] rob_slot_6  = reg_rob_slot[6];
  wire [3:0] rob_slot_7  = reg_rob_slot[7];
  wire [3:0] rob_slot_8  = reg_rob_slot[8];
  wire [3:0] rob_slot_9  = reg_rob_slot[9];
  wire [3:0] rob_slot_10 = reg_rob_slot[10];
  wire [3:0] rob_slot_11 = reg_rob_slot[11];
  wire [3:0] rob_slot_12 = reg_rob_slot[12];
  wire [3:0] rob_slot_13 = reg_rob_slot[13];
  wire [3:0] rob_slot_14 = reg_rob_slot[14];
  wire [3:0] rob_slot_15 = reg_rob_slot[15];
  wire [3:0] rob_slot_16 = reg_rob_slot[16];
  wire [3:0] rob_slot_17 = reg_rob_slot[17];
  wire [3:0] rob_slot_18 = reg_rob_slot[18];
  wire [3:0] rob_slot_19 = reg_rob_slot[19];
  wire [3:0] rob_slot_20 = reg_rob_slot[20];
  wire [3:0] rob_slot_21 = reg_rob_slot[21];
  wire [3:0] rob_slot_22 = reg_rob_slot[22];
  wire [3:0] rob_slot_23 = reg_rob_slot[23];
  wire [3:0] rob_slot_24 = reg_rob_slot[24];
  wire [3:0] rob_slot_25 = reg_rob_slot[25];
  wire [3:0] rob_slot_26 = reg_rob_slot[26];
  wire [3:0] rob_slot_27 = reg_rob_slot[27];
  wire [3:0] rob_slot_28 = reg_rob_slot[28];
  wire [3:0] rob_slot_29 = reg_rob_slot[29];
  wire [3:0] rob_slot_30 = reg_rob_slot[30];
  wire [3:0] rob_slot_31 = reg_rob_slot[31];

  reg [4:0] wb_alu_latency;
  reg [4:0] wb_mem_latency;
  reg [4:0] wb_mul_latency;

  // Store ROB slots (for bypassing)

  always @(posedge clk) begin
    if( accept && (!stall_Dhl)) begin
      reg_rob_slot[dst] <= rob_alloc_slot;
    end
  end

  wire src0_byp_rob_slot = reg_rob_slot[src0];
  wire src1_byp_rob_slot = reg_rob_slot[src1];

  // Check if src registers are ready

  wire src0_can_byp = pending[src0] && (reg_latency[src0] < 5'b00100);
  wire src1_can_byp = pending[src1] && (reg_latency[src1] < 5'b00100);

  wire src0_ok = !pending[src0] || src0_can_byp || !src0_en;
  wire src1_ok = !pending[src1] || src1_can_byp || !src1_en;

  reg [2:0] src0_byp_mux_sel;
  reg [2:0] src1_byp_mux_sel;
  wire [4:0] stalls_alu = {3'b0, stalls[4], stalls[0]};
  wire [4:0] stalls_mem = {2'b0, stalls[4:3], stalls[0]};
  wire [4:0] stalls_muldiv = stalls;

  wire [4:0] reg_latency_cur = reg_latency[src0];

  always @(*) begin
    if (!pending[src0] || src0 == 5'b0)
      src0_byp_mux_sel = 3'b0;
    else if (reg_latency[src0] == 5'b00001)
      src0_byp_mux_sel = 3'd4;
    else if (reg_latency[src0] == 5'b00000)
      src0_byp_mux_sel = 3'd5; // UNCOMMENT THIS WHEN YOUR ROB IS READY!
      // src0_byp_mux_sel = 3'd0;   // DELETE THIS WHEN YOUR ROB IS READY!
    else
      src0_byp_mux_sel = functional_unit[src0];
  end

  always @(*) begin
    if (!pending[src1] || src1 == 5'b0)
      src1_byp_mux_sel = 3'b0;
    else if (reg_latency[src1] == 5'b00001)
      src1_byp_mux_sel = 3'd4;
    else if (reg_latency[src1] == 5'b00000)
      src1_byp_mux_sel = 3'd5; // UNCOMMENT THIS WHEN YOUR ROB IS READY!
      // src1_byp_mux_sel = 3'd0;   // DELETE THIS WHEN YOUR ROB IS READY!
    else
      src1_byp_mux_sel = functional_unit[src1];
  end

  // Check for hazards

  wire stall_wb_hazard =
    ((wb_alu_latency >> 1) & latency) > 5'b0 ? 1'b1 :
    ((wb_mem_latency >> 1) & latency) > 5'b0 ? 1'b1 :
    ((wb_mul_latency >> 1) & latency) > 5'b0 ? 1'b1 : 1'b0;

  wire accept =
    src0_ok && src1_ok && !stall_wb_hazard && inst_val_Dhl;

  wire stall_hazard = ~accept;

  
  // Advance one cycle
  
  genvar r;
  generate
  for( r = 0; r < 32; r = r + 1)
  begin: sb_entry
    always @(posedge clk) begin
      if (reset) begin
        reg_latency[r]     <= 5'b0;
        pending[r]         <= 1'b0;
        functional_unit[r] <= 3'b0; 
      end else if ( accept && (r == dst) && (!stall_Dhl)) begin
        reg_latency[r]     <= latency;
        pending[r]         <= 1'b1;
        functional_unit[r] <= func_unit;
      end else begin
        //reg_latency[r]     <= 
        //  (reg_latency[r] & stalls) | 
        //  ((reg_latency[r] & ~stalls) >> 1);
        pending[r]         <= pending[r] &&
          !(rob_commit_wen && rob_commit_slot == reg_rob_slot[r]);

        // Depending on what functional unit we're talking about,
        // we need to shift the stall vector over so that its stages
        // line up with the latency vector.
        if ((functional_unit[r] == `FUNC_UNIT_ALU)) begin
          reg_latency[r]     <= ( ( reg_latency[r] & (stalls_alu) ) |
                                ( ( reg_latency[r] & ~(stalls_alu) ) >> 1) );
        end
        else if ( functional_unit[r] == `FUNC_UNIT_MEM ) begin
          reg_latency[r]     <= ( ( reg_latency[r] & (stalls_mem) ) |
                                ( ( reg_latency[r] & ~(stalls_mem) ) >> 1) );
        end
        else begin
          reg_latency[r]     <= ( ( reg_latency[r] & stalls ) |
                                ( ( reg_latency[r] & ~stalls ) >> 1) );
        end
      end
    end
  end
  endgenerate

  // ALU Latency 

  always @(posedge clk) begin
    if (reset) begin
      wb_alu_latency <= 5'b0;
    end else if (accept && (func_unit == 2'd1) && (!stall_Dhl)) begin
      wb_alu_latency <= 
        (wb_alu_latency & (stalls_alu)) |
        ((wb_alu_latency & ~(stalls_alu)) >> 1) |
        latency;
    end else begin
      wb_alu_latency <= 
        (wb_alu_latency & (stalls_alu)) |
        ((wb_alu_latency & ~(stalls_alu)) >> 1);
    end
  end

  // MEM Latency 

  always @(posedge clk) begin
    if (reset) begin
      wb_mem_latency <= 5'b0;
    end else if (accept && (func_unit == 2'd2) && (!stall_Dhl)) begin
      wb_mem_latency <= 
        (wb_mem_latency & (stalls_mem)) |
        ((wb_mem_latency & ~(stalls_mem)) >> 1) |
        latency;
    end else begin
      wb_mem_latency <= 
        (wb_mem_latency & (stalls_mem)) |
        ((wb_mem_latency & ~(stalls_mem)) >> 1);
    end
  end

  // MUL Latency 

  always @(posedge clk) begin
    if (reset) begin
      wb_mul_latency <= 5'b0;
    end else if (accept && (func_unit == 2'd3) && (!stall_Dhl)) begin
      wb_mul_latency <= 
        (wb_mul_latency & stalls) |
        ((wb_mul_latency & ~stalls) >> 1) |
        latency;
    end else begin
      wb_mul_latency <= 
        (wb_mul_latency & stalls) |
        ((wb_mul_latency & ~stalls) >> 1);
    end
  end

  assign stall_wb_hazard_X = wb_alu_latency[1] && (wb_mul_latency[1] || wb_mem_latency[1]);
  assign stall_wb_hazard_M = wb_mem_latency[1] && (wb_mul_latency[1]);
//  wire wb_mux_sel = (wb_alu_latency & 5'b10) ? 2'd1 :
//                    (wb_mem_latency & 5'b10) ? 2'd2 :
//                    (wb_mul_latency & 5'b10) ? 2'd3 : 2'd0;

  wire wb_mux_sel = (wb_mul_latency[1]) ? 2'd3 :
                    (wb_mem_latency[1]) ? 2'd2 :
                    (wb_alu_latency[1]) ? 2'd1 : 2'd0;

endmodule

`endif

