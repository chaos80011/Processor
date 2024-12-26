//========================================================================
// Lab 1 - Iterative Div Unit
//========================================================================

`ifndef RISCV_INT_DIV_ITERATIVE_V
`define RISCV_INT_DIV_ITERATIVE_V

`include "imuldiv-DivReqMsg.v"

module MuxDiv
#(parameter N = 64)
(
  input  [N-1:0] in0, in1,
  input          sel,
  output [N-1:0] out
);

  assign out = (sel == 1'b0) ? in0 : in1;

endmodule

module RegisterDiv
#(parameter N = 64)
(
    input          clk,
    input          reset,
    input          write,
    input  [N-1:0] in,
    output [N-1:0] out
);
    
    reg  [N-1:0] regout;

    always @(posedge clk) begin
      if (reset)
          regout <= 0;
      else if (write)
          regout <= in;
    end
    
    assign out = regout;

endmodule

module imuldiv_IntDivIterative
(
  input                clk,
  input                reset,

  input                divreq_msg_fn,
  input  [31:0]        divreq_msg_a,
  input  [31:0]        divreq_msg_b,
  output [63:0]        divresp_msg_result,

  input                divreq_val,
  output               divreq_rdy,
  input                divresp_rdy,
  output               divresp_val
);

  wire       idle;
  wire       compute;
  wire       fn;

  imuldiv_IntDivIterativeCtrl ctrl
  (
    .clk                      (clk),
    .reset                    (reset),
    .divreq_val               (divreq_val),
    .divreq_rdy               (divreq_rdy),
    .divresp_rdy              (divresp_rdy),
    .divresp_val              (divresp_val),
    .idle                     (idle),
		.compute                  (compute)
  );

  imuldiv_IntDivIterativeDpath dpath
  (
    .clk                      (clk),
    .reset                    (reset),
    .divreq_msg_a             (divreq_msg_a),
    .divreq_msg_b             (divreq_msg_b),
    .divresp_msg_result       (divresp_msg_result),
		.idle                     (idle),
		.compute                  (compute),
    .fn                       (fn)
  );

  assign fn = divreq_msg_fn;

endmodule

module imuldiv_IntDivIterativeCtrl
(
  input         clk,
  input         reset,
  input         divreq_val,
  output        divreq_rdy,
  input         divresp_rdy,
  output        divresp_val,
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
      counter = counter - 1;
    end else begin
        counter <= counter;
    end
  end

  always @* begin
    case (state)
      IDLE: begin
        counter_reset = 0;
        val_reg       = 0;
        if (divreq_val) begin
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
        if (divresp_val && divresp_rdy) begin
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

assign divreq_rdy   = (state == IDLE)    ? 1 : 
                      (state == COMPUTE) ? 0 : 
                      (state == DONE)    ? 0 : 1'b0;

assign divresp_val = val_reg;

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module imuldiv_IntDivIterativeDpath
(
  input         clk,
  input         reset,
  input  [31:0] divreq_msg_a,
  input  [31:0] divreq_msg_b,
  output [63:0] divresp_msg_result,
	input         idle,
	input         compute,
  input         fn
);

  wire        q_is_signed;
  wire        r_is_signed;
  wire        final_sign;
  wire [31:0] signed_q;
  wire [31:0] signed_r;
  wire [31:0] a_abs;
  wire [31:0] b_abs;
  wire [31:0] a_abs_signed;
  wire [31:0] b_abs_signed;
  wire [31:0] a_abs_unsigned;
  wire [31:0] b_abs_unsigned;
  wire [63:0] signed_result;
  wire [63:0] unsigned_result;

  wire [64:0] a_in;
	wire [64:0] a_out;
  wire [64:0] b_in;
	wire [64:0] b_out;
  wire [64:0] sub_out;
  wire [64:0] diff;

	RegisterDiv #(65) a_reg (
		.clk(clk),
		.reset(reset),
		.write(1'b1),
		.in(a_in),
		.out(a_out)
	);

	RegisterDiv #(65) b_reg (
		.clk(clk),
		.reset(reset),
		.write(idle),
		.in({1'b0, b_abs, 32'b0}),
		.out(b_out)
	);
  
	RegisterDiv #(1) q_sign_reg (
		.clk(clk),
		.reset(reset),
		.write(idle),
		.in(divreq_msg_a[31] ^ divreq_msg_b[31]),
		.out(q_is_signed)
	);

  RegisterDiv #(1) r_sign_reg (
		.clk(clk),
		.reset(reset),
		.write(idle),
		.in(divreq_msg_a[31]),
		.out(r_is_signed)
	);

  RegisterDiv #(1) final_sign_reg (
		.clk(clk),
		.reset(reset),
		.write(idle),
		.in(fn),
		.out(final_sign)
	);

	MuxDiv #(65) a_sel (
		.in0(sub_out),
		.in1({33'b0, a_abs}),
		.sel(idle),
		.out(a_in)
	);

	MuxDiv #(65) sub_sel (
		.in0({diff[64:1], 1'b1}),
		.in1((a_out << 1)),
		.sel(((a_out << 1) < b_out)),
		.out(sub_out)
	);

  assign diff = ((a_out << 1) - b_out);

  assign a_abs = (fn) ? a_abs_signed : a_abs_unsigned;
  assign b_abs = (fn) ? b_abs_signed : b_abs_unsigned;
  
  assign a_abs_signed = divreq_msg_a[31] ? (~divreq_msg_a + 1'b1) : divreq_msg_a;
  assign b_abs_signed = divreq_msg_b[31] ? (~divreq_msg_b + 1'b1) : divreq_msg_b;

  assign a_abs_unsigned = divreq_msg_a;
  assign b_abs_unsigned = divreq_msg_b;

  assign signed_q = q_is_signed ? ~a_out[31:0] + 1'b1 : a_out[31:0];
  assign signed_r = r_is_signed ? ~a_out[63:32] + 1'b1 : a_out[63:32];

  assign signed_result = {signed_r, signed_q};
  assign unsigned_result = a_out[63:0];

	assign divresp_msg_result = (final_sign) ? signed_result : unsigned_result;

endmodule

`endif
