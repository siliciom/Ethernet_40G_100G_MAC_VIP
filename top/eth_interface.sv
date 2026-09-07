//******************************************************************//
//                    ETHERNET INTERFACE FILE
//
// Defines the SystemVerilog interface representing the Ethernet
// physical interface signals. It provides the signal connectivity 
// between the DUT and UVM components through virtual interface handles.
//
// Author: Dheeraj, Lavanya, Nitheesh
//
//******************************************************************//
`include "../config/defines.sv"
`include "uvm_macros.svh"
import uvm_pkg::*;
`timescale 1ns / 1ps
interface eth_interface (
    input bit rst
);

  // Transmit path
  logic [`DATA_WIDTH-1:0] TXD;
  logic [`CTRL_WIDTH-1:0] TXC;
  logic                   TX_CLK;

  // Receive path
  logic [`DATA_WIDTH-1:0] RXD;
  logic [`CTRL_WIDTH-1:0] RXC;
  logic                   RX_CLK;
  //========================================================
  // Clocking block for driver
  //========================================================
  clocking drv_cb @(posedge TX_CLK);
    default input #1 output #0;
    output TXD;
    output TXC;
  endclocking

  //========================================================
  // Clocking block for monitor
  //========================================================
  clocking tx_mon_cb @(negedge TX_CLK);
    // default input #1 output #0;
    input TXD;
    input TXC;
  endclocking

  //========================================================
  // Clocking block for monitor
  //========================================================
  clocking rx_mon_cb @(negedge RX_CLK);
    //default input #1 output #0;
    input RXD;
    input RXC;
  endclocking
  //========================================================
  // Modports
  //========================================================

  // For UVM driver
  modport DRV_MP(clocking drv_cb);


  // For UVM monitor
  modport TX_MON_MP(clocking tx_mon_cb);
  modport RX_MON_MP(clocking rx_mon_cb);
  
  //========================================================
  // ASSERTIONS
  //========================================================
  //------------------------------------------------------------
  // Detect Start (`START_CH) on ANY lane
  //------------------------------------------------------------
  function automatic bit start_detected();
    for (int i = 0; i < `CTRL_WIDTH; i++) begin
      if (TXC[i] && (TXD[i*8+:8] == `START_CH)) return 1'b1;
    end
    return 1'b0;
  endfunction
  //------------------------------------------------------------
  // Detect Terminate (`TERMINATE_CH) on ANY lane
  //------------------------------------------------------------
  function automatic bit terminate_detected();
    for (int i = 0; i < `CTRL_WIDTH; i++) begin
      if (TXC[i] && (TXD[i*8+:8] == `TERMINATE_CH)) return 1'b1;
    end
    return 1'b0;
  endfunction
  //------------------------------------------------------------
  // Detect Start (`START_CH) on ANY lane
  //------------------------------------------------------------     
  function automatic bit rx_start_detected();
    for (int i = 0; i < `CTRL_WIDTH; i++) begin
      if ($sampled(RXC[i]) && ($sampled(RXD[i*8+:8]) == `START_CH)) return 1'b1;
    end
    return 1'b0;
  endfunction
  //------------------------------------------------------------
  // Detect Terminate (`TERMINATE_CH) on ANY RX lane
  //------------------------------------------------------------
  function automatic bit rx_terminate_detected();
    for (int i = 0; i < `CTRL_WIDTH; i++) begin
      if (RXC[i] && (RXD[i*8+:8] == `TERMINATE_CH)) return 1'b1;
    end
    return 1'b0;
  endfunction
  //---------------------------------------------------------------------------------
  // Property: Lane 0 Start (`START_CH) must be followed by Terminate (`TERMINATE_CH)
  //           ON ANY LANE with NO unexpected Start (`START_CH) in between.
  //---------------------------------------------------------------------------------
  property p_start_followed_by_terminate;
    @(posedge TX_CLK) disable iff (!rst)
         (TXC[0] && (TXD[7:0] == `START_CH)) |=> (!start_detected()) s_until_with terminate_detected();//start_character_in_between
  endproperty
  a_start_followed_by_terminate :
  assert property (p_start_followed_by_terminate)
  else
    `uvm_error("TX_START_TERM_ERR", $sformatf(
               "Protocol Violation: Start (`START_CH) on lane 0 was either followed by an unexpected `START_CH or missing a Terminate Time=%0t",
               $time
               ))
  //----------------------------------------------------------------------------
  // Property: RX Start (`START_CH) must be followed by Terminate (`TERMINATE_CH)
  //           on any lane with no unexpected Start (`START_CH) in between.
  //-----------------------------------------------------------------------------
  property p_rx_start_followed_by_terminate;
    @(posedge RX_CLK) disable iff (!rst)
         (RXC[0] && (RXD[7:0] == `START_CH)) |=> (!rx_start_detected()) s_until_with rx_terminate_detected();//start_character_in_between
  endproperty
  a_rx_start_followed_by_terminate :
  assert property (p_rx_start_followed_by_terminate)
  else
    `uvm_error("RX_START_TERM_ERR", $sformatf(
               "RX Protocol Violation: Start (`START_CH) on lane 0 was followed by an unexpected Start (`START_CH) or missing Terminate (`TERMINATE_CH). Time=%0t",
               $time));
  //------------------------------------------------------------
  // Helper function to validate TX control characters
  //------------------------------------------------------------
  function automatic bit is_valid_tx_control_char();
    for (int i = 0; i < `CTRL_WIDTH; i++) begin
      if (TXC[i] && !(TXD[i*8 +: 8] inside {`IDLE_CH, `START_CH, `TERMINATE_CH, `ERROR_CH, 8'h9C}))//control_char_data_mismatch testcase
        return 1'b0;
    end
    return 1'b1;
  endfunction
  property p_tx_control_data_mismatch_func;
    @(posedge TX_CLK) disable iff (!rst) is_valid_tx_control_char();
  endproperty
  a_tx_control_data_mismatch_func :
  assert property (p_tx_control_data_mismatch_func)
  else
    `uvm_error("TX_CTRL_DATA_MISMATCH", $sformatf(
               "Control/Data Mismatch Detected! TXC=0x%0h TXD=0x%0h Time=%0t", TXC, TXD, $time));
  //------------------------------------------------------------
  // Helper function to validate RX control characters
  //------------------------------------------------------------
  function automatic bit is_valid_rx_control_char();
    for (int i = 0; i < `CTRL_WIDTH; i++) begin
      if (RXC[i] && !(RXD[i*8 +: 8] inside {`IDLE_CH, `START_CH, `TERMINATE_CH, `ERROR_CH, 8'h9C}))//control_char_data_mismatch testcase
        return 1'b0;
    end
    return 1'b1;
  endfunction
  property p_rx_control_data_mismatch_func;
    @(posedge RX_CLK) disable iff (!rst) is_valid_rx_control_char();
  endproperty
  a_rx_control_data_mismatch_func :
  assert property (p_rx_control_data_mismatch_func)
  else
    `uvm_error("RX_CTRL_DATA_MISMATCH", $sformatf(
               "Control/Data Mismatch Detected! RXC=0x%0h RXD=0x%0h Time=%0t", RXC, RXD, $time));
  //----------------------------------------------------------------------------------
  // Helper: Checks intra-word boundary (Lanes 0 through 6)
  // If lane `i` is TERMINATE (0xFD), lane `i+1` in the SAME cycle MUST be IDLE (0x07)
  //----------------------------------------------------------------------------------
  function automatic bit is_tx_term_followed_by_idle_same_cycle();
    for (int i = 0; i < `CTRL_WIDTH - 1; i++) begin
      if (TXC[i] && (TXD[i*8+:8] == `TERMINATE_CH)) begin
        if (!TXC[i+1] || (TXD[(i+1)*8+:8] != `IDLE_CH))
          return 1'b0;  // Lane i+1 failed to transmit IDLE with TXC=1
      end
    end
    return 1'b1;
  endfunction
  //===================================================================
  // TRANSMIT PATH (TX): Merged Terminate-to-Idle Check
  // Checks that TERMINATE (0xFD) on any lane is immediately 
  // followed by IDLE (0x07) on the very next byte/lane.
  //===================================================================
  property p_tx_terminate_followed_by_idle_all_lanes;
    @(posedge TX_CLK) disable iff (!rst)
    // 1. Same-cycle check for Lanes 0..6
    is_tx_term_followed_by_idle_same_cycle() and
    // 2. Cross-cycle check for Lane 7 -> Next cycle Lane 0
    ((TXC[`CTRL_WIDTH-1] && (TXD[(`CTRL_WIDTH-1)*8 +: 8] == `TERMINATE_CH)) |=> (TXC[0] && (TXD[7:0] == `IDLE_CH)));

  endproperty
  a_tx_terminate_followed_by_idle_all_lanes :
  assert property (p_tx_terminate_followed_by_idle_all_lanes)
  else
    `uvm_error("TX_TERM_TO_IDLE_VIOLATION", $sformatf(
               "Protocol Violation: TX TERMINATE character (0xFD) was NOT immediately followed by IDLE (0x07)! TXC=0x%0h TXD=0x%0h Time=%0t",
               TXC,
               TXD,
               $time));
  //----------------------------------------------------------------------------------
  // Helper: Checks intra-word boundary on RX (Lanes 0 through 6)
  // If lane `i` is TERMINATE (0xFD), lane `i+1` in the SAME cycle MUST be IDLE (0x07)
  //-----------------------------------------------------------------------------------
  function automatic bit is_rx_term_followed_by_idle_same_cycle();
    for (int i = 0; i < `CTRL_WIDTH - 1; i++) begin
      if (RXC[i] && (RXD[i*8+:8] == `TERMINATE_CH)) begin
        if (!RXC[i+1] || (RXD[(i+1)*8+:8] != `IDLE_CH))
          return 1'b0;  // Lane i+1 failed to receive IDLE with RXC=1
      end
    end
    return 1'b1;
  endfunction
  //===================================================================
  // Checks that TERMINATE (0xFD) on any lane is immediately 
  // followed by IDLE (0x07) on the very next byte/lane.
  //===================================================================
  property p_rx_terminate_followed_by_idle_all_lanes;
    @(posedge RX_CLK) disable iff (!rst)
    // 1. Same-cycle check for Lanes 0..6
    is_rx_term_followed_by_idle_same_cycle() and
    // 2. Cross-cycle check for Lane 7 -> Next cycle Lane 0
    ((RXC[`CTRL_WIDTH-1] && (RXD[(`CTRL_WIDTH-1)*8 +: 8] == `TERMINATE_CH))
       |=> (RXC[0] && (RXD[7:0] == `IDLE_CH)));//Missing terminate testcase
  endproperty
  a_rx_terminate_followed_by_idle_all_lanes :
  assert property (p_rx_terminate_followed_by_idle_all_lanes)
  else
    `uvm_error("RX_TERM_TO_IDLE_VIOLATION", $sformatf(
               "RX Protocol Violation: RX TERMINATE character (0xFD) was NOT immediately followed by IDLE (0x07)! RXC=0x%0h RXD=0x%0h Time=%0t",
               RXC,
               RXD,
               $time));

  //------------------------------------------------------------
  // Assertion: TXD/TXC must not contain X or Z after reset
  //------------------------------------------------------------
  property p_tx_no_xz;
    @(posedge TX_CLK) disable iff (!rst) !$isunknown(
        {TXD, TXC}
    );
  endproperty
  a_tx_no_xz :
  assert property (p_tx_no_xz)
  else `uvm_error("TX_XZ", $sformatf("TXD/TXC contains X or Z at time %0t", $time));
  //------------------------------------------------------------
  // Assertion: RXD/RXC must not contain X or Z after reset
  //------------------------------------------------------------
  property p_rx_no_xz;
    @(posedge RX_CLK) disable iff (!rst) !$isunknown(
        {RXD, RXC}
    );
  endproperty
  a_rx_no_xz :
  assert property (p_rx_no_xz)
  else `uvm_error("RX_XZ", $sformatf("RXD/RXC contains X or Z at time %0t", $time));

  //-----------------------------------------------------------------------
  // Assert: Validates START (0xFB) character alignment on Lane 0 (TX Side)
  // ---------------------------------------------------------------------- 
  property p_fb_lane0_only;
    @(posedge TX_CLK) disable iff (!rst) start_detected() |-> (TXC[0] && (TXD[7:0] == `START_CH));
  endproperty
  a_fb_lane0_only :
  assert property (p_fb_lane0_only)
  else `uvm_error("FB_LANE_ERROR", $sformatf("[%0t] 0xFB detected, but not on lane 0", $time))
  //-----------------------------------------------------------------------
  // Assert: Validates START (0xFB) character alignment on Lane 0 (RX Side)
  // ---------------------------------------------------------------------- 
  property rx_p_fb_lane0_only;
    @(posedge RX_CLK) disable iff (!rst)
          rx_start_detected() |-> (RXC[0] && (RXD[7:0] ==`START_CH));
  endproperty
  rx_a_fb_lane0_only :
  assert property (rx_p_fb_lane0_only)
  else
    `uvm_error("RX_FB_LANE_ERROR", $sformatf(
               "Time=%0t | Start detected on invalid lane! | RXC=0x%0h RXD=0x%0h | Lane0: RXC[0]=%0b RXD[7:0]=0x%0h",
               $time,
               RXC,
               RXD,
               RXC[0],
               RXD[7:0]
               ))
  //---------------------------------------------------------------------------------
  // Property: TX Start (`START_CH ) on Lane 0 must be preceded by IDLE on Lane 7
  //           of the previous clock cycle.
  //---------------------------------------------------------------------------------
  property p_tx_start_after_idle;
    @(posedge TX_CLK) disable iff (!rst) (TXC[0] && (TXD[7:0] == `START_CH)) |-> $past(
        TXC[`CTRL_WIDTH-1] && (TXD[(`CTRL_WIDTH-1)*8+:8] == `IDLE_CH)
    );
  endproperty
  a_tx_start_after_idle :
  assert property (p_tx_start_after_idle)
  else
    `uvm_error("TX_START_AFTER_IDLE_ERR", $sformatf(
               "Protocol Violation: TX Start (`START_CH 0x%0h) appeared on Lane 0, but previous cycle Lane %0d was NOT IDLE (0x%0h)! Prev TXD=0x%0h Time=%0t",
               `START_CH,
               `CTRL_WIDTH - 1,
               $past(
                   TXD[(`CTRL_WIDTH-1)*8+:8]
               ),
               $past(
                   TXD
               ),
               $time));
  //---------------------------------------------------------------------------------
  // Property: RX Start (`START_CH`) on Lane 0 must be preceded by IDLE on Lane 7
  //           of the previous clock cycle.
  //---------------------------------------------------------------------------------
  property p_rx_start_after_idle;
    @(posedge RX_CLK) disable iff (!rst) (RXC[0] && (RXD[7:0] == `START_CH)) |-> $past(
        RXC[`CTRL_WIDTH-1] && (RXD[(`CTRL_WIDTH-1)*8+:8] == `IDLE_CH)
    );
  endproperty
  a_rx_start_after_idle :
  assert property (p_rx_start_after_idle)
  else
    `uvm_error("RX_START_AFTER_IDLE_ERR", $sformatf(
               "Protocol Violation: RX Start (`START_CH 0x%0h) appeared on Lane 0, but previous cycle Lane %0d was NOT IDLE (0x%0h)! Prev RXD=0x%0h Time=%0t",
               `START_CH,
               `CTRL_WIDTH - 1,
               $past(
                   RXD[(`CTRL_WIDTH-1)*8+:8]
               ),
               $past(
                   RXD
               ),
               $time));
  function automatic bit is_preamble_sfd_valid(logic [`CTRL_WIDTH*8-1:0] data_in);
    // Lanes 1 to 6 must be 0x55 (preamble)
    for (int i = 1; i <= 6; i++) begin
      if (data_in[i*8+:8] != `PREAMBLE) return 1'b0;
    end
    // Lane 7 must be 0xD5 (SFD)
    if (data_in[63:56] != 8'hD5) return 1'b0;
    return 1'b1;
  endfunction
  property p_tx_start_vector_preamble;
    @(posedge TX_CLK) disable iff (!rst)
         (TXC[0] && (TXD[7:0] == `START_CH)) |-> is_preamble_sfd_valid(
        TXD
    );
  endproperty
  a_tx_start_vector_preamble :
  assert property (p_tx_start_vector_preamble)
  else
    `uvm_error("TX_START_VEC_ERR", $sformatf(
               "TX Preamble/SFD mismatch! Time=%0t TXD=0x%0h", $time, TXD));

  property p_rx_start_vector_preamble;
    @(posedge RX_CLK) disable iff (!rst)
         (RXC[0] && (RXD[7:0] == `START_CH)) |-> is_preamble_sfd_valid(
        RXD
    );
  endproperty
  a_rx_start_vector_preamble :
  assert property (p_rx_start_vector_preamble)
  else
    `uvm_error("RX_START_VEC_ERR", $sformatf(
               "RX Preamble/SFD mismatch! Time=%0t RXD=0x%0h", $time, RXD));
  //------------------------------------------------------------
  // Assertion: TX signals must be LOW immediately after reset deasserts
  //------------------------------------------------------------
  property p_tx_signals_low_during_reset;
    @(posedge TX_CLK) $rose(
        !rst
    ) |=> (TXD == {`DATA_WIDTH{1'b0}} && TXC == {`CTRL_WIDTH{1'b0}});
  endproperty
  a_tx_signals_low_during_reset :
  assert property (p_tx_signals_low_during_reset) begin
    `uvm_info("TX_RESET_ASSERT", "TX signals are LOW during reset", UVM_LOW)
  end else begin
    `uvm_error("TX_RESET_ASSERT", "TX signals are not LOW during reset")
  end
  //------------------------------------------------------------
  // Assertion: RX signals must be LOW immediately after reset deasserts
  //------------------------------------------------------------
  property p_rx_signals_low_during_reset;
    @(posedge RX_CLK) $rose(
        !rst
    ) |=> (RXD == {`DATA_WIDTH{1'b0}} && RXC == {`CTRL_WIDTH{1'b0}});
  endproperty
  a_rx_signals_low_during_reset :
  assert property (p_rx_signals_low_during_reset) begin
    `uvm_info("RX_RESET_ASSERT", "RX signals are LOW during reset", UVM_LOW)
  end else begin
    `uvm_error("RX_RESET_ASSERT", "RX signals are not LOW during reset")
  end
  //----------------------------------------------------------------------
  // Dynamic Period & Duty Cycle Calculation from `FREQ_IN_MHZ
  //----------------------------------------------------------------------
  // Period in ns = 1000 / FREQ_IN_MHZ (e.g., 1000 / 625 = 1.6ns)
  localparam real TARGET_PERIOD_NS = 1000.0 / `FREQ_IN_MHZ;
  localparam real TARGET_HALF_PERIOD_NS = TARGET_PERIOD_NS / 2.0;
  localparam real TOLERANCE_NS = 0.01;  // +/- 10ps margin for sim jitter
  //------------------------------------------------------------
  // Assertion: TX_CLK Period Validation (Supports 40G & 100G)
  //------------------------------------------------------------
  property p_tx_clk_freq;
    realtime current_time;
    @(posedge TX_CLK) disable iff (!rst) (1,
    current_time = $realtime
    ) |=> (($realtime - current_time) >= (TARGET_PERIOD_NS - TOLERANCE_NS)) &&
        (($realtime - current_time) <= (TARGET_PERIOD_NS + TOLERANCE_NS));
  endproperty
  a_tx_clk_freq :
  assert property (p_tx_clk_freq)
  else
    `uvm_error("CLK_FREQ", $sformatf(
               "Clock period mismatch for %0dMHz! Target: %.3fns, Measured: %.3fns at Time=%0t",
               `FREQ_IN_MHZ,
               TARGET_PERIOD_NS,
               ($realtime - $past(
                   $realtime
               )),
               $time));
  //------------------------------------------------------------
  // Assertion: TX_CLK Duty Cycle Validation (50% Duty Cycle)
  //------------------------------------------------------------
  property p_tx_duty_cycle;
    realtime current_time;
    @(TX_CLK) disable iff (!rst) (1,
    current_time = $realtime
    ) |=> (($realtime - current_time) >= (TARGET_HALF_PERIOD_NS - TOLERANCE_NS)) &&
        (($realtime - current_time) <= (TARGET_HALF_PERIOD_NS + TOLERANCE_NS));
  endproperty
  a_tx_duty_cycle :
  assert property (p_tx_duty_cycle)
  else
    `uvm_error("DUTY", $sformatf(
               "Duty cycle mismatch for %0dMHz! Target Half-Period: %.3fns at Time=%0t",
               `FREQ_IN_MHZ,
               TARGET_HALF_PERIOD_NS,
               $time));
  //------------------------------------------------------------
  // Assertion: RX_CLK Period Validation (Supports 40G & 100G)
  //------------------------------------------------------------
  property p_rx_clk_freq;
    realtime current_time;
    @(posedge RX_CLK) disable iff (!rst) (1,
    current_time = $realtime
    ) |=> (($realtime - current_time) >= (TARGET_PERIOD_NS - TOLERANCE_NS)) &&
        (($realtime - current_time) <= (TARGET_PERIOD_NS + TOLERANCE_NS));
  endproperty
  a_rx_clk_freq :
  assert property (p_rx_clk_freq)
  else
    `uvm_error("RX_CLK_FREQ", $sformatf(
               "RX_CLK period mismatch for %0dMHz! Target: %.3fns, Measured: %.3fns at Time=%0t",
               `FREQ_IN_MHZ,
               TARGET_PERIOD_NS,
               ($realtime - $past(
                   $realtime
               )),
               $time));
  //------------------------------------------------------------
  // Assertion: RX_CLK Duty Cycle Validation (50% Duty Cycle)
  //------------------------------------------------------------
  property p_rx_duty_cycle;
    realtime current_time;
    @(RX_CLK) disable iff (!rst) (1,
    current_time = $realtime
    ) |=> (($realtime - current_time) >= (TARGET_HALF_PERIOD_NS - TOLERANCE_NS)) &&
        (($realtime - current_time) <= (TARGET_HALF_PERIOD_NS + TOLERANCE_NS));
  endproperty
  a_rx_duty_cycle :
  assert property (p_rx_duty_cycle)
  else
    `uvm_error("RX_DUTY", $sformatf(
               "RX_CLK duty cycle mismatch for %0dMHz! Target Half-Period: %.3fns at Time=%0t",
               `FREQ_IN_MHZ,
               TARGET_HALF_PERIOD_NS,
               $time));

  // Function to detect 4-byte Sequence Ordered Set (0x9C 00 00 02)
  function automatic bit seq_9c_detected();
    bit [7:0] lane[`CTRL_WIDTH];

    for (int i = 0; i < `CTRL_WIDTH; i++) begin
      lane[i] = TXD[i*8+:8];
    end

    // Check every 4-byte aligned block across CTRL_WIDTH
    for (int i = 0; i <= `CTRL_WIDTH - 4; i += 4) begin
      if ((TXC[i] && TXC[i+1] && TXC[i+2] && TXC[i+3]) &&
              (lane[i]   == 8'h02) &&
              (lane[i+1] == 8'h00) &&
              (lane[i+2] == 8'h00) &&
              (lane[i+3] == 8'h9C)) begin
        return 1;
      end
    end

    return 0;
  endfunction
   
      // Bounded Property Definition
      property p_start_eventually_after_seq;
        @(posedge TX_CLK) disable iff (!rst)
          seq_9c_detected() |-> ##[1:`FAULT_PERIOD] (TXC[0] && TXD[7:0] == 8'hFB);
      endproperty
       
      a_start_eventually_after_seq:
        assert property (p_start_eventually_after_seq)
        else
          `uvm_error("FB_NOT_FOUND",
            "0xFB start character did not occur after 9C_00_00_02 sequence");
	    

endinterface
