//******************************************************************//
//       ETHERNET SIMULTANEOUS PAUSE FRAME TEST
//
// Defines the Ethernet simultaneous pause frame test. This test
// verifies Ethernet flow control by generating pause frames while
// normal data traffic is active, ensuring correct handling of
// simultaneous pause frame and data traffic conditions.
//
// Author: Arun
//
//******************************************************************//
typedef struct packed {
  bit [7:0] dat;
  bit       is_ctrl;
} xlgmii_lane_s;


class eth_pause_checker extends uvm_component;
  `uvm_component_utils(eth_pause_checker)

  virtual eth_interface v_intf[`NO_OF_AGENTS];

  mailbox #(xlgmii_lane_s) rx_lane_mbx[`NO_OF_AGENTS];

  localparam int BYTES_PER_CLK = `CTRL_WIDTH;

  bit [7:0] frame_q[`NO_OF_AGENTS][$];
  int byte_cnt[`NO_OF_AGENTS];
  int pause_override_cnt[`NO_OF_AGENTS];
  bit [15:0] opcode[`NO_OF_AGENTS];
  bit [15:0] ether_type[`NO_OF_AGENTS];
  bit [47:0] da[`NO_OF_AGENTS];
  bit [47:0] sa[`NO_OF_AGENTS];
  bit pause_xoff_en[`NO_OF_AGENTS];
  bit start_pause_xoff_timing[`NO_OF_AGENTS];
  bit pause_override_en[`NO_OF_AGENTS];
  bit override_time_en[`NO_OF_AGENTS];
  bit [15:0] pause_time[`NO_OF_AGENTS];
  longint clk[`NO_OF_AGENTS];  // elapsed idle BYTES (not clocks) during pause
  longint p_time[`NO_OF_AGENTS];  // countdown in bytes
  localparam int PAUSE_QUANTUM_BYTES = 64;
  localparam int CLOCKS_PER_QUANTA = PAUSE_QUANTUM_BYTES / BYTES_PER_CLK;  // 64/8 = 8 for your config

  function new(string name = "eth_pause_checker", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      if (!uvm_config_db#(virtual eth_interface)::get(this, "", $sformatf("vinf%0d", i), v_intf[i]))
        `uvm_fatal("PCH_CHK", $sformatf("Unable to get vif_%0d", i))
      rx_lane_mbx[i] = new();
    end
  endfunction

  task run_phase(uvm_phase phase);
    wait (v_intf[0].rst);

    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      automatic int agent = i;
      fork
        sample_xlgmii_bus(agent);
        process_frame_bytes(agent);
        check_pausing_time(agent);
      join_none
    end
  endtask

  //-----------------------------------------------------------------
  // Bus sampler: runs every RX_CLK, peels BYTES_PER_CLK bytes off the
  // wide bus and streams them one byte at a time into the mailbox.
  // Frame boundaries are found using XLGMII START/TERMINATE control
  // characters (per-lane), exactly like real XLGMII framing.
  //-----------------------------------------------------------------
  task sample_xlgmii_bus(int i);
    bit                             frame_in_progress;
    bit           [`DATA_WIDTH-1:0] word_d;
    bit           [`CTRL_WIDTH-1:0] word_c;
    xlgmii_lane_s                   lane;

    frame_in_progress = 0;

    forever begin
      @(negedge v_intf[i].RX_CLK);
      word_d = v_intf[i].RXD;
      word_c = v_intf[i].RXC;

      for (int l = 0; l < `CTRL_WIDTH; l++) begin
        bit [7:0] cur_byte = word_d[l*8+:8];
        bit       cur_ctrl = word_c[l];

        if (!frame_in_progress) begin
          if (cur_ctrl && (cur_byte == `START_CH)) begin
            frame_in_progress = 1;
            lane.dat          = `PREAMBLE;
            lane.is_ctrl      = 0;
            rx_lane_mbx[i].put(lane);
          end
          // idle/error lanes seen outside a frame are simply dropped
        end else begin
          if (cur_ctrl && (cur_byte == `TERMINATE_CH)) begin
            frame_in_progress = 0;
            lane.dat          = `TERMINATE_CH;  // end-of-frame sentinel
            lane.is_ctrl      = 1;
            rx_lane_mbx[i].put(lane);
            break;
          end else begin
            lane.dat     = cur_byte;
            lane.is_ctrl = cur_ctrl;
            rx_lane_mbx[i].put(lane);
          end
        end
      end
    end
  endtask

  //-----------------------------------------------------------------
  // Byte-oriented frame processor - identical logic/semantics to the
  // original GMII byte state machine, just fed from the mailbox
  // instead of directly from the interface, so it is bus-width agnostic.
  //-----------------------------------------------------------------
  task process_frame_bytes(int i);
    xlgmii_lane_s lane;
    bit           is_pause;

    forever begin
      byte_cnt[i]   = 0;
      opcode[i]     = 0;
      ether_type[i] = 0;
      is_pause      = 0;
      frame_q[i].delete();

      forever begin
        rx_lane_mbx[i].get(lane);

        if (lane.is_ctrl && lane.dat == `TERMINATE_CH) begin
          // end of frame (normal end, or runt frame shorter than expected)
          break;
        end

        if (byte_cnt[i] < 7) begin  // Preamble
          if (lane.dat != `PREAMBLE)
            `uvm_info("PCH_PREAMBLE_ERR", $sformatf(
                      "Agent - %0d, Incorrect Preamble Received =%h", i, lane.dat), UVM_LOW)
        end else if (byte_cnt[i] == 7) begin  // SFD
          if (lane.dat != `SFD)
            `uvm_info("PCH_SFD_ERR", $sformatf(
                      "Agent - %0d, Incorrect SFD Received =%h", i, lane.dat), UVM_LOW)
        end

        frame_q[i].push_back(lane.dat);

        if (byte_cnt[i] == 23) begin
          opcode[i][7:0]      = frame_q[i].pop_back();
          opcode[i][15:8]     = frame_q[i].pop_back();
          ether_type[i][7:0]  = frame_q[i].pop_back();
          ether_type[i][15:8] = frame_q[i].pop_back();

          `uvm_info("PCH_OPC", $sformatf("Agent - %0d, Received Opcode = %h, Ethertype = %h", i,
                                         opcode[i], ether_type[i]), UVM_LOW)

          if (opcode[i] == 16'h0001 && ether_type[i] == 16'h8808) begin
            is_pause = 1;
            for (int j = 0; j < 6; j++) sa[i][j*8+:8] = frame_q[i].pop_back();
            for (int j = 0; j < 6; j++) da[i][j*8+:8] = frame_q[i].pop_back();

            `uvm_info("PCH_DA_SA", $sformatf("Agent - %0d, Received DA = %h, SA = %h", i, da[i],
                                             sa[i]), UVM_LOW)

            frame_q[i].delete();
            if (start_pause_xoff_timing[i]) pause_override_en[i] = 1;
            pause_xoff_en[i] = 1;
          end else begin
            // Not a PAUSE frame - drain remaining bytes until EOF sentinel
            frame_q[i].delete();
          end
        end

        byte_cnt[i]++;
      end

      if (is_pause) begin
        if (byte_cnt[i] == 72)
          `uvm_info("PCH_RX_PAUSE", $sformatf("Agent - %0d, Received Pause with correct size", i),
                    UVM_LOW)
        else
          `uvm_error("PCH_INC_RX_PAUSE", $sformatf(
                     "Agent - %0d, Received Pause with incorrect size (bytes=%0d)", i, byte_cnt[i]))

        if (pause_override_en[i]) begin
          override_time_en[i]  = 1;
          pause_override_en[i] = 0;
        end
        if (pause_xoff_en[i]) begin
          start_pause_xoff_timing[i] = 1;
          pause_xoff_en[i] = 0;
        end

        if (frame_q[i].size() >= 2) begin
          pause_time[i][15:8] = frame_q[i].pop_front();
          pause_time[i][7:0]  = frame_q[i].pop_front();
        end

        `uvm_info("PCH_RX_PAUSE_TIME", $sformatf("Agent - %0d, Received Pause Quanta = %0d", i,
                                                 pause_time[i]), UVM_LOW)
      end

      frame_q[i].delete();
    end
  endtask

  //-----------------------------------------------------------------
  // TX bus idle check: true only if every lane in the current word is
  // a control byte carrying IDLE. Replaces the single TX_EN bit.
  //-----------------------------------------------------------------
  function automatic bit is_tx_idle(int i);
    bit idle = 1;
    for (int l = 0; l < `CTRL_WIDTH; l++) begin
      if (!(v_intf[i].TXC[l] && (v_intf[i].TXD[l*8+:8] == `IDLE_CH))) idle = 0;
    end
    return idle;
  endfunction

  //-----------------------------------------------------------------
  // Pause-timer checker. Pause quanta = 64 byte-times regardless of
  // bus width; a wider bus reaches that many bytes in fewer clocks,
  // so bookkeeping is done in bytes (BYTES_PER_CLK per idle clock),
  // not raw clock ticks - this is the part that makes the checker
  // correct for any DATA_WIDTH.
  //-----------------------------------------------------------------

  task check_pausing_time(int i);
    int prev_pause_time[`NO_OF_AGENTS];
    bit tx_idle;
    bit override_pending[`NO_OF_AGENTS];
    int override_gap_clks = 24;  // now a plain clock count again, no scaling needed

    forever begin
      wait (v_intf[i].TX_CLK && is_tx_idle(i) && start_pause_xoff_timing[i] == 1);

      p_time[i] = pause_time[i] * CLOCKS_PER_QUANTA;  // e.g. 5 * 8 = 40 clocks, done
      override_pending[i] = 0;

      while (p_time[i] > 0) begin
        tx_idle = is_tx_idle(i);

        #0;
        if (override_time_en[i] && start_pause_xoff_timing[i] == 1) begin
          prev_pause_time[i] = pause_time[i];
          p_time[i] = pause_time[i] * CLOCKS_PER_QUANTA;  // reset countdown to new value
          //p_time[i]--;
          clk[i] = 0;
          `uvm_info("PCH_PAUSE_OVERWRITE",
                    $sformatf(
                        "Agent - %0d, DUE TO OVERRIDING, UPDATING THE PAUSE TIME = %0d clocks", i,
                        p_time[i]), UVM_LOW)
          override_time_en[i] = 0;
          override_pending[i] = 1;
        end

        if (tx_idle) begin
          clk[i]++;
        end else begin
          pause_override_cnt[i]++;
          if (override_pending[i]) begin
            `uvm_error(
                "PCH_OVERRIDE_PAUSE_VIOLATION",
                $sformatf(
                    {"Agent - %0d, PAUSE was overridden to %0d quanta (%0d clocks) but ",
                     "transmitter resumed with %0d clocks of the overridden pause still remaining, Data=%h"
                      }, i, pause_time[i], pause_time[i] * CLOCKS_PER_QUANTA, p_time[i],
                      v_intf[i].TXD))
            override_pending[i] = 0;
          end
        end

        if (pause_override_cnt[i] >= override_gap_clks && pause_time[i] == prev_pause_time[i]) begin
          `uvm_error(
              "PCH_PAUSE_ERR0",
              $sformatf(
                  {"Agent - %0d, Overriding Within pause not happening, Data %h is driving in interface %0d\n",
                   "Expected clocks = %0d, Actual Clocks Completed= %0d"}, i, v_intf[i].TXD, i,
                    pause_time[i] * CLOCKS_PER_QUANTA, clk[i]))
        end else if (pause_override_cnt[i] > 0 && !tx_idle) begin
          `uvm_error(
              "PCH_PAUSE_ERR1",
              $sformatf(
                  {"Agent - %0d, Within pause timer expiration, Data %h is driving in interface %0d\n",
                   "Expected clocks = %0d, Actual Clocks Completed= %0d"}, i, v_intf[i].TXD, i,
                    pause_time[i] * CLOCKS_PER_QUANTA, clk[i]))
        end

        p_time[i]--;  // exactly one decrement, every clock, no exceptions
        @(posedge v_intf[i].TX_CLK);
      end

      `uvm_info("PCH_DATA", $sformatf(
                "Agent - %0d, Expected clocks = %0d, Actual Clocks Completed= %0d",
                i,
                pause_time[i] * CLOCKS_PER_QUANTA,
                clk[i]
                ), UVM_LOW)
      @(posedge v_intf[i].TX_CLK);
      #1step;
      if (is_tx_idle(i)) begin
        `uvm_error(
            "PCH_PAUSE_OVERHOLD",
            $sformatf(
                "Agent - %0d, PAUSE timer expired (Quanta=%0d, %0d clocks) but transmitter still idle -- %0h -- %0h",
                i, pause_time[i], pause_time[i] * CLOCKS_PER_QUANTA, v_intf[i].TXC, v_intf[i].TXD))
      end


      start_pause_xoff_timing[i] = 0;
      pause_time[i]              = 0;
      clk[i]                     = 0;
      p_time[i]                  = 0;
      pause_override_cnt[i]      = 0;
    end
  endtask
endclass

