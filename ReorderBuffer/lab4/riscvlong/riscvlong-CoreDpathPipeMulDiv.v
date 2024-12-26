//========================================================================
// Functional Pipelined Mul/Div Unit
//========================================================================

`ifndef RISCV_PIPE_MULDIV_ITERATIVE_V
`define RISCV_PIPE_MULDIV_ITERATIVE_V

`include "imuldiv-MulDivReqMsg.v"

module riscv_CoreDpathPipeMulDiv
(
  input         clk,
  input         reset,

  input   [2:0] muldivreq_msg_fn,
  input  [31:0] muldivreq_msg_a,
  input  [31:0] muldivreq_msg_b,
  input         muldivreq_val,
  output        muldivreq_rdy,

  output [63:0] muldivresp_msg_result,
  output        muldivresp_val,
  input         muldivresp_rdy,
  //These need to be hooked up to something!
  input         stall_Xhl,
  input         stall_Mhl,
  input         stall_X2hl,
  input         stall_X3hl
);

  // Set request ready if not stalled

  assign muldivreq_rdy = !stall;
  wire   muldivreq_go  = muldivreq_val && muldivreq_rdy;

  //----------------------------------------------------------------------
  // Input Registers
  //----------------------------------------------------------------------

  reg [63:0] result1_reg;
  reg [63:0] result2_reg;
  reg [63:0] result3_reg;
  
  reg        val0_reg;
  reg        val1_reg;
  reg        val2_reg;
  reg        val3_reg;
  wire val1_next = (stall_Xhl) ? 1'b0: (val0_reg);
  wire val2_next = (stall_Mhl) ? 1'b0: (val1_reg);
 
  always @ ( posedge clk ) begin
    if ( reset ) begin
      result1_reg <= 0;
      result2_reg <= 0;
      result3_reg <= 0;
  
      val0_reg <= 0;
      val1_reg <= 0;
      val2_reg <= 0;
      val3_reg <= 0;
    end else begin
      if ( muldivreq_go ) begin
        val0_reg <= 1'b1;
      end else if (!stall_Xhl) begin
        val0_reg <= 1'b0;
      end
      if (! stall_Mhl) begin
          result1_reg <= result0;
          val1_reg <= val1_next;
      end
      if ( !stall  ) begin
        result2_reg <= result1_reg;
        result3_reg <= result2_reg;
        val2_reg    <= val2_next;
        val3_reg    <= val2_reg;
      end
    end
  end
  

 
  //----------------------------------------------------------------------
  // Functional Computation
  //----------------------------------------------------------------------

  // Sign of mul and div

  wire sign = ( muldivreq_msg_a[31] ^ muldivreq_msg_b[31] );

  // Unsigned operands

  wire [31:0] a_unsign   = ( muldivreq_msg_a[31] == 1'b1 ) ? ( ~muldivreq_msg_a + 1'b1 )
                         :                         muldivreq_msg_a;
  wire [31:0] b_unsign   = ( muldivreq_msg_b[31] == 1'b1 ) ? ( ~muldivreq_msg_b + 1'b1 )
                         :                         muldivreq_msg_b;

  // Unsigned computation

  wire [31:0] quotientu  = muldivreq_msg_a / muldivreq_msg_b;
  wire [31:0] remainderu = muldivreq_msg_a % muldivreq_msg_b;

  // Signed computation

  wire [63:0] product_raw   = a_unsign * b_unsign;
  wire [31:0] quotient_raw  = a_unsign / b_unsign;
  wire [31:0] remainder_raw = a_unsign % b_unsign;

  // Signed Product

  wire [63:0] product
    = ( sign ) ? ( ~product_raw + 1'b1 )
               : product_raw;

  // Signed Quotient

  wire [31:0] quotient
    = ( sign ) ? ( ~quotient_raw + 1'b1 )
               : quotient_raw;

  // Remainder is same sign as dividend

  wire [31:0] remainder
    = ( muldivreq_msg_a[31] ) ? ( ~remainder_raw + 1'b1 )
    :                 remainder_raw;

  // Result mux

  wire [63:0] result0
    = ( muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MUL  ) ? product
    : ( muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_DIV  ) ? { remainder, quotient }
    : ( muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_DIVU ) ? { remainderu, quotientu }
    : ( muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_REM  ) ? { remainder, quotient }
    : ( muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_REMU ) ? { remainderu, quotientu }
    :                                                  32'bx;

  //----------------------------------------------------------------------
  // Dummy Pipeline Stages
  //----------------------------------------------------------------------

  
  // Set response data

  assign muldivresp_msg_result = result3_reg;

  // Set response valid

  assign muldivresp_val = val3_reg;

  // Stall signal

  wire stall = val3_reg && !muldivresp_rdy;

endmodule

`endif
