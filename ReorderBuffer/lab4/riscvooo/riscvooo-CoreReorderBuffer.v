//=========================================================================
// 5-Stage RISCV Scoreboard
//=========================================================================

`ifndef RISCV_CORE_REORDERBUFFER_V
`define RISCV_CORE_REORDERBUFFER_V

module riscv_CoreReorderBuffer
(
  input         clk,
  input         reset,

  input         rob_alloc_req_val,
  output        rob_alloc_req_rdy,
  input  [ 4:0] rob_alloc_req_preg,
  output [ 3:0] rob_alloc_resp_slot,

  input         rob_fill_val,
  input  [ 3:0] rob_fill_slot,

  output        rob_commit_wen,
  output [ 3:0] rob_commit_slot,
  output [ 4:0] rob_commit_rf_waddr
);

  wire rob_alloc_req_rdy;
  wire rob_alloc_resp_slot;
  wire rob_commit_wen;
  wire rob_commit_rf_waddr;
  wire rob_commit_slot;

  // ROB configuration
  parameter ROB_SIZE = 16;
  parameter SLOT_BITS = 4;

  // ROB entry structure
  reg [ROB_SIZE-1:0] valid;                    // Valid bits
  reg [ROB_SIZE-1:0] pending;                  // Pending bits
  reg [4:0]          preg     [ROB_SIZE-1:0];  // Physical register

  // Head and tail pointers
  reg [SLOT_BITS-1:0] head;
  reg [SLOT_BITS-1:0] tail;

  // Allocation logic
  assign rob_alloc_req_rdy = (valid[tail] == 1'b0); // Ready if tail slot is empty
  assign rob_alloc_resp_slot = tail;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      valid <= 0;
      pending <= 0;
      head <= 0;
      tail <= 0;
    end else if (rob_alloc_req_val && rob_alloc_req_rdy) begin
      valid[tail] <= 1'b1;
      pending[tail] <= 1'b1;
      preg[tail] <= rob_alloc_req_preg;
      tail <= tail + 1; // Increment tail pointer
    end
  end

  // Writeback logic
  always @(posedge clk) begin
    if (rob_fill_val) begin
      pending[rob_fill_slot] <= 1'b0; // Clear pending bit
    end
  end

  // Commit logic
  assign rob_commit_wen = valid[head] && (pending[head] == 1'b0);
  assign rob_commit_slot = head;
  assign rob_commit_rf_waddr = preg[head];

  always @(posedge clk) begin
    if (rob_commit_wen) begin
      valid[head] <= 1'b0; // Clear valid bit
      head <= head + 1;    // Increment head pointer
    end
  end
  
endmodule

`endif

