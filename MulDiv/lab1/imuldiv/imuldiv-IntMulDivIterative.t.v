//========================================================================
// Test for Mul/Div Unit
//========================================================================

`include "imuldiv-MulDivReqMsg.v"
`include "imuldiv-IntMulDivIterative.v"
`include "vc-TestSource.v"
`include "vc-TestSink.v"
`include "vc-Test.v"

//------------------------------------------------------------------------
// Helper Module
//------------------------------------------------------------------------

module imuldiv_IntMulDivIterative_helper
(
  input       clk,
  input       reset,
  output      done
);

  wire [66:0] src_msg;
  wire  [2:0] src_msg_fn;
  wire [31:0] src_msg_a;
  wire [31:0] src_msg_b;
  wire        src_val;
  wire        src_rdy;
  wire        src_done;

  wire [63:0] sink_msg;
  wire        sink_val;
  wire        sink_rdy;
  wire        sink_done;

  assign done = src_done && sink_done;

  vc_TestSource#(67,3) src
  (
    .clk   (clk),
    .reset (reset),
    .bits  (src_msg),
    .val   (src_val),
    .rdy   (src_rdy),
    .done  (src_done)
  );

  imuldiv_MulDivReqMsgFromBits msgfrombits
  (
    .bits (src_msg),
    .func (src_msg_fn),
    .a    (src_msg_a),
    .b    (src_msg_b)
  );

  imuldiv_IntMulDivIterative imuldiv
  (
    .clk                   (clk),
    .reset                 (reset),
    .muldivreq_msg_fn      (src_msg_fn),
    .muldivreq_msg_a       (src_msg_a),
    .muldivreq_msg_b       (src_msg_b),
    .muldivreq_val         (src_val),
    .muldivreq_rdy         (src_rdy),
    .muldivresp_msg_result (sink_msg),
    .muldivresp_val        (sink_val),
    .muldivresp_rdy        (sink_rdy)
  );

  vc_TestSink#(64,3) sink
  (
    .clk   (clk),
    .reset (reset),
    .bits  (sink_msg),
    .val   (sink_val),
    .rdy   (sink_rdy),
    .done  (sink_done)
  );

endmodule

//------------------------------------------------------------------------
// Main Tester Module
//------------------------------------------------------------------------

module tester;

  // VCD Dump
  initial begin
    $dumpfile("imuldiv-IntMulDivIterative.vcd");
    $dumpvars;
  end

  `VC_TEST_SUITE_BEGIN( "imuldiv-IntMulDivIterative" )

  reg  t0_reset = 1'b1;
  wire t0_done;

  imuldiv_IntMulDivIterative_helper t0
  (
    .clk   (clk),
    .reset (t0_reset),
    .done  (t0_done)
  );

  `VC_TEST_CASE_BEGIN( 1, "mul" )
  `VC_TEST_CASE_INIT(67, 64)
  begin

    t0.src.m[0] = 67'h0_00000000_00000000; t0.sink.m[0] = 64'h00000000_00000000;
    t0.src.m[1] = 67'h0_00000001_00000001; t0.sink.m[1] = 64'h00000000_00000001;
    t0.src.m[2] = 67'h0_ffffffff_00000001; t0.sink.m[2] = 64'hffffffff_ffffffff;
    t0.src.m[3] = 67'h0_00000001_ffffffff; t0.sink.m[3] = 64'hffffffff_ffffffff;
    t0.src.m[4] = 67'h0_ffffffff_ffffffff; t0.sink.m[4] = 64'h00000000_00000001;
    t0.src.m[5] = 67'h0_00000008_00000003; t0.sink.m[5] = 64'h00000000_00000018;
    t0.src.m[6] = 67'h0_fffffff8_00000008; t0.sink.m[6] = 64'hffffffff_ffffffc0;
    t0.src.m[7] = 67'h0_fffffff8_fffffff8; t0.sink.m[7] = 64'h00000000_00000040;
    t0.src.m[8] = 67'h0_0deadbee_10000000; t0.sink.m[8] = 64'h00deadbe_e0000000;
    t0.src.m[9] = 67'h0_deadbeef_10000000; t0.sink.m[9] = 64'hfdeadbee_f0000000;

    #5;   t0_reset = 1'b1;
    #20;  t0_reset = 1'b0;
    #10000; `VC_TEST_CHECK( "Is sink finished?", t0_done )

  end
  `VC_TEST_CASE_END

  `VC_TEST_CASE_BEGIN( 2, "div/rem" )
  `VC_TEST_CASE_INIT(67, 64)
  begin

    t0.src.m[ 0] = 67'h1_00000000_00000001; t0.sink.m[ 0] = 64'h00000000_00000000;
    t0.src.m[ 1] = 67'h1_00000001_00000001; t0.sink.m[ 1] = 64'h00000000_00000001;
    t0.src.m[ 2] = 67'h1_00000000_ffffffff; t0.sink.m[ 2] = 64'h00000000_00000000;
    t0.src.m[ 3] = 67'h1_ffffffff_ffffffff; t0.sink.m[ 3] = 64'h00000000_00000001;
    t0.src.m[ 4] = 67'h1_00000222_0000002a; t0.sink.m[ 4] = 64'h00000000_0000000d;
    t0.src.m[ 5] = 67'h1_0a01b044_ffffb146; t0.sink.m[ 5] = 64'h00000000_ffffdf76;
    t0.src.m[ 6] = 67'h1_00000032_00000222; t0.sink.m[ 6] = 64'h00000032_00000000;
    t0.src.m[ 7] = 67'h1_00000222_00000032; t0.sink.m[ 7] = 64'h0000002e_0000000a;
    t0.src.m[ 8] = 67'h1_0a01b044_ffffb14a; t0.sink.m[ 8] = 64'h00003372_ffffdf75;
    t0.src.m[ 9] = 67'h1_deadbeef_0000beef; t0.sink.m[ 9] = 64'hffffda72_ffffd353;
    t0.src.m[10] = 67'h1_f5fe4fbc_00004eb6; t0.sink.m[10] = 64'hffffcc8e_ffffdf75;
    t0.src.m[11] = 67'h1_f5fe4fbc_ffffb14a; t0.sink.m[11] = 64'hffffcc8e_0000208b;

    #5;   t0_reset = 1'b1;
    #20;  t0_reset = 1'b0;
    #10000; `VC_TEST_CHECK( "Is sink finished?", t0_done )

  end
  `VC_TEST_CASE_END

  `VC_TEST_CASE_BEGIN( 3, "mixed" )
  `VC_TEST_CASE_INIT(67, 64)
  begin

    t0.src.m[ 0] = 67'h0_fffffff8_00000008; t0.sink.m[ 0] = 64'hffffffff_ffffffc0;
    t0.src.m[ 1] = 67'h0_fffffff8_fffffff8; t0.sink.m[ 1] = 64'h00000000_00000040;
    t0.src.m[ 2] = 67'h0_0deadbee_10000000; t0.sink.m[ 2] = 64'h00deadbe_e0000000;
    t0.src.m[ 3] = 67'h0_deadbeef_10000000; t0.sink.m[ 3] = 64'hfdeadbee_f0000000;
    t0.src.m[ 4] = 67'h1_0a01b044_ffffb14a; t0.sink.m[ 4] = 64'h00003372_ffffdf75;
    t0.src.m[ 5] = 67'h1_deadbeef_0000beef; t0.sink.m[ 5] = 64'hffffda72_ffffd353;
    t0.src.m[ 6] = 67'h1_f5fe4fbc_00004eb6; t0.sink.m[ 6] = 64'hffffcc8e_ffffdf75;
    t0.src.m[ 7] = 67'h1_f5fe4fbc_ffffb14a; t0.sink.m[ 7] = 64'hffffcc8e_0000208b;

    t0.src.m[ 8] = 67'h2_f2dae217_07f2ca05; t0.sink.m[ 8] = 64'h04673581_0000001e;
    t0.src.m[ 9] = 67'h2_f9b180c3_08640c8d; t0.sink.m[ 9] = 64'h065c14ca_0000001d;
    t0.src.m[10] = 67'h2_f1924927_09f79a11; t0.sink.m[10] = 64'h025bd78f_00000018;
    t0.src.m[11] = 67'h2_fbdcf624_0dc616cd; t0.sink.m[11] = 64'h03ef5bba_00000012;
    t0.src.m[12] = 67'h2_fcaa0f61_045860c4; t0.sink.m[12] = 64'h00a422f9_0000003a;
    t0.src.m[13] = 67'h2_fe0e24f7_021e8a6a; t0.sink.m[13] = 64'h01dbcdb1_00000077;
    t0.src.m[14] = 67'h2_fe5bfb9d_03c7ff3c; t0.sink.m[14] = 64'h01042ee9_00000043;
    t0.src.m[15] = 67'h2_f4fa6e5c_0b90d527; t0.sink.m[15] = 64'h0218f229_00000015;
    t0.src.m[16] = 67'h2_fbf3e3f3_08d35cdc; t0.sink.m[16] = 64'h04d5bbe3_0000001c;
    t0.src.m[17] = 67'h2_f101f8af_00e25199; t0.sink.m[17] = 64'h008b461f_00000110;

    // Add entries for divu/remu here

    #5;   t0_reset = 1'b1;
    #20;  t0_reset = 1'b0;
    #10000; `VC_TEST_CHECK( "Is sink finished?", t0_done )

  end
  `VC_TEST_CASE_END

   //---------------------------------------------------------------------
   // Add More Test Cases Here
   //---------------------------------------------------------------------

  `VC_TEST_CASE_BEGIN( 4, "self_created" )
  `VC_TEST_CASE_INIT(67, 64)
  begin

    t0.src.m[ 0] = 67'h0_18a17ab3_20ad636c; t0.sink.m[ 0] = 64'h0324de07_2189fc84;
    t0.src.m[ 1] = 67'h0_16019d7c_28d64907; t0.sink.m[ 1] = 64'h0382ac3c_159baa64;
    t0.src.m[ 2] = 67'h0_15deb872_25f6741c; t0.sink.m[ 2] = 64'h033e3e99_077bd478;
    t0.src.m[ 3] = 67'h0_18e809c5_23300b5d; t0.sink.m[ 3] = 64'h036c65f2_c8a70391;
    t0.src.m[ 4] = 67'h1_7dcf30cb_18bc9b35; t0.sink.m[ 4] = 64'h022028c2_00000005;
    t0.src.m[ 5] = 67'h1_662a22c9_3280c65a; t0.sink.m[ 5] = 64'h01289615_00000002;
    t0.src.m[ 6] = 67'h1_22a21585_751d7a79; t0.sink.m[ 6] = 64'h22a21585_00000000;
    t0.src.m[ 7] = 67'h1_0b17f6b8_118b1371; t0.sink.m[ 7] = 64'h0b17f6b8_00000000;
    t0.src.m[ 8] = 67'h2_2f02c388_16fe07b0; t0.sink.m[ 8] = 64'h0106b428_00000002;
    t0.src.m[ 9] = 67'h2_002d2aed_346ce33a; t0.sink.m[ 9] = 64'h002d2aed_00000000;
    t0.src.m[10] = 67'h2_2a3321b4_3dbcda5c; t0.sink.m[10] = 64'h2a3321b4_00000000;
    t0.src.m[11] = 67'h2_15ed025c_22dc8f21; t0.sink.m[11] = 64'h15ed025c_00000000;

    // Add entries for divu/remu here

    #5;   t0_reset = 1'b1;
    #20;  t0_reset = 1'b0;
    #10000; `VC_TEST_CHECK( "Is sink finished?", t0_done )

  end
  `VC_TEST_CASE_END

  `VC_TEST_SUITE_END( 4 /* replace with number of test cases */ )

endmodule
