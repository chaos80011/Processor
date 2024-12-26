//========================================================================
// Lab 1 - Iterative Mul Unit
//========================================================================

`ifndef RISCV_INT_MUL_ITERATIVE_V
`define RISCV_INT_MUL_ITERATIVE_V

module MuxMul
#(parameter N = 64)
(
  input  [N-1:0] in0, in1,
  input          sel,
  output [N-1:0] out
);

  assign out = (sel == 1'b0) ? in0 : in1;

endmodule

module RegisterMul
#(parameter N = 64)
(
  input          clk,
  input          reset,
  input          write,
  input  [N-1:0] in,
  output [N-1:0] out
);

  reg    [N-1:0] regout;

  always @(posedge clk) begin
    if (reset)
        regout <= 0;
    else if (write)
        regout <= in;
  end

  assign out = regout;

endmodule

module imuldiv_IntMulIterative
(
  input                clk,
  input                reset,

  input  [31:0] mulreq_msg_a,
  input  [31:0] mulreq_msg_b,
  output [63:0] mulresp_msg_result,

  input         mulreq_val,
  output        mulreq_rdy,
  input         mulresp_rdy,
  output        mulresp_val
);

  wire compute, idle;

  imuldiv_IntMulIterativeCtrl ctrl
  (
    .clk                      (clk),
    .reset                    (reset),
    .mulreq_val               (mulreq_val),
    .mulreq_rdy               (mulreq_rdy),
    .mulresp_rdy              (mulresp_rdy),
    .mulresp_val              (mulresp_val),
    .idle                     (idle),
		.compute                  (compute)
  );

  imuldiv_IntMulIterativeDpath dpath
  (
    .clk                      (clk),
    .reset                    (reset),
    .mulreq_msg_a             (mulreq_msg_a),
    .mulreq_msg_b             (mulreq_msg_b),
    .mulresp_msg_result       (mulresp_msg_result),
		.idle                     (idle),
		.compute                  (compute)
  );

endmodule

module imuldiv_IntMulIterativeCtrl
(
  input         clk,
  input         reset,
  input         mulreq_val,         // Request valid signal
  output        mulreq_rdy,         // Request ready signal
  input         mulresp_rdy,        // Response ready signal
  output        mulresp_val,        // Response valid signal
  output        idle,
	output        compute
);

  reg [1:0]     state, next_state;
  reg [4:0]     counter;
  reg           counter_reset;
  reg           val_reg;
  localparam    IDLE    = 2'b00;
  localparam    COMPUTE = 2'b01;
  localparam    DONE    = 2'b10;

  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always @(posedge clk) begin
    if (reset || counter_reset) begin
      counter <= 31;
    end else if (state == COMPUTE) begin
      counter <= counter - 1;
    end else begin
        counter <= counter;
    end
  end

  always @* begin
    case (state)
      IDLE: begin
        counter_reset = 0;
        val_reg       = 0;
        if (mulreq_val && mulreq_rdy) begin
          next_state = COMPUTE;
        end else begin
          next_state = IDLE;
        end
      end

      COMPUTE: begin
        counter_reset = 0;
        val_reg       = 0;
        if (counter == 0) begin
          next_state = DONE;
        end else begin
          next_state = COMPUTE;
        end
      end

      DONE: begin
        counter_reset = 1;
        val_reg       = 1;
        if (mulresp_val && mulresp_rdy) begin
          next_state = IDLE;
        end else begin
          next_state = DONE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

assign idle         = (state == IDLE)    ? 1 : 
                      (state == COMPUTE) ? 0 : 
                      (state == DONE)    ? 0 : 1'b0;

assign compute      = (state == IDLE)    ? 0 : 
                      (state == COMPUTE) ? 1 : 
                      (state == DONE)    ? 0 : 1'b0;

assign mulreq_rdy   = (state == IDLE)    ? 1 : 
                      (state == COMPUTE) ? 0 : 
                      (state == DONE)    ? 0 : 1'b0;

assign mulresp_val = val_reg;

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module imuldiv_IntMulIterativeDpath
(
  input         clk,
  input         reset,
  input  [31:0] mulreq_msg_a,
  input  [31:0] mulreq_msg_b,
  output [63:0] mulresp_msg_result,
	input         idle,
	input         compute
);

  wire [63:0] acc_in;
  wire [63:0] acc_out;

  RegisterMul #(64) acc_reg (
		.clk(clk),
		.reset(idle | reset),
		.write(1'b1),
		.in(acc_in),
		.out(acc_out)
	);

  wire is_signed;
  wire [31:0] a_abs;
  wire [31:0] b_abs;

  wire [63:0] a_in;
	wire [63:0] a_out;

	RegisterMul #(64) a_reg (
		.clk(clk),
		.reset(reset),
		.write(1'b1),
		.in(a_in),
		.out(a_out)
	);
  
  wire [31:0] b_in;
	wire [31:0] b_out;

	RegisterMul #(32) b_reg (
		.clk(clk),
		.reset(reset),
		.write(1'b1),
		.in(b_in),
		.out(b_out)
	);
  
	RegisterMul #(1) sign_reg (
		.clk(clk),
		.reset(reset),
		.write(idle),
		.in(mulreq_msg_a[31] ^ mulreq_msg_b[31]),
		.out(is_signed)
	);

	MuxMul #(64) a_sel (
		.in0(a_out << 1),
		.in1({32'b0, a_abs}),
		.sel(idle),
		.out(a_in)
	);

	MuxMul #(32) b_sel (
		.in0(b_out >> 1),
		.in1(b_abs),
		.sel(idle),
		.out(b_in)
	);

	MuxMul #(64) add_sel (
		.in0(acc_out),
		.in1(acc_out + a_out),
		.sel(compute & b_out[0]),
		.out(acc_in)
	);


	assign mulresp_msg_result = is_signed ? ~acc_out+1'b1 : acc_out;

  assign a_abs = mulreq_msg_a[31] ? (~mulreq_msg_a + 1'b1) : mulreq_msg_a;
  assign b_abs = mulreq_msg_b[31] ? (~mulreq_msg_b + 1'b1) : mulreq_msg_b;

endmodule

`endif
