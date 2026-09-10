//******************************************************************//
//                      ETHERNET TOP FILE
//
// Top-level module of the Ethernet verification environment. It
// instantiates the DUT, Ethernet interfaces, clock and reset
// generation logic, and connects the UVM testbench components.
// This file initializes the simulation environment and starts the
// execution of Ethernet UVM test cases using `run_test()`.
// TODO:- Need to add logic for interconnect connection between MAC's
//
// Author: Dheeraj
// 
//******************************************************************//

`timescale 1ns / 1ps
import uvm_pkg::*;
`include "uvm_macros.svh"
`include "../config/eth_pkg.sv"
`include "../env/reg_agent/apb_if.sv"
//------------------------------------------------------------------------------
// Top-level Ethernet testbench module.
//------------------------------------------------------------------------------
module eth_top;
  bit clk;
  bit rst;
  bit clk1;

  localparam int NUM_LANES = `DATA_WIDTH / 8;

  // XLGMII transmit and receive signals

  logic [  `DATA_WIDTH-1:0] txd          [`NO_OF_AGENTS];
  logic [  `CTRL_WIDTH-1:0] txc          [`NO_OF_AGENTS];
  logic [  `DATA_WIDTH-1:0] rxd          [`NO_OF_AGENTS];
  logic [  `CTRL_WIDTH-1:0] rxc          [`NO_OF_AGENTS];

  // MAC address and routing tables
  bit   [             47:0] mac_uni      [`NO_OF_AGENTS];
  bit                       mac_multi    [`NO_OF_AGENTS] [bit   [47:0]];
  int                       route_da     [`NO_OF_AGENTS] [int];

  bit   [              7:0] lane_data;
  bit                       lane_ctrl;

  // Variables used for frame capture and routing
  bit   [              7:0] txd_buffer   [`NO_OF_AGENTS] [$];
  bit                       txc_buffer   [`NO_OF_AGENTS] [$];

  int                       rd_ptr       [`NO_OF_AGENTS];
  bit                       routing      [`NO_OF_AGENTS];
  bit                       capturing    [`NO_OF_AGENTS];
  bit mac23_route_en = 0;

  // Temporary variables used during routing
  logic [  `DATA_WIDTH-1:0] rx_lane_data;
  logic [  `CTRL_WIDTH-1:0] rx_lane_ctrl;
  bit   [             47:0] da;
  int                       remaining;
  int                       hdr_base;
  logic [`NO_OF_AGENTS-1:0] hdr_found;
  logic [`NO_OF_AGENTS-1:0] route_ready;
  int                       hdr_base_pipe[`NO_OF_AGENTS];

  // Half clock period derived from configured interface frequency
  parameter real HALF_PERIOD = 1000 / (2.0 * real'(`FREQ_IN_MHZ));

  // Interface and statistics interfaces
  eth_interface eth_if[`NO_OF_AGENTS] (rst);
  eth_ui_interface ui_inf[`NO_OF_AGENTS] ();
  apb_if apb_vif[`NO_OF_AGENTS] (clk1);

  // XLGMII / RS layer control characters
  typedef enum logic [7:0] {
    RS_IDLE      = 8'h07,
    RS_START     = 8'hFB,
    RS_TERMINATE = 8'hFD,
    RS_ERROR     = 8'hFE,
    RS_SEQUENCE  = 8'h9C
  } rs_control_characters;

  //initial begin
  //uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env_h.ral_reg_agent.*", "vif", apb_vif);
  //end

  // Configure virtual interfaces for each Ethernet agent
  genvar gi;
  generate
    for (gi = 0; gi < `NO_OF_AGENTS; gi++) begin : gen_config
      initial begin
        uvm_config_db#(virtual eth_interface)::set(
            null, $sformatf("uvm_test_top.env_h.agnt_mac[%0d]*", gi), "vif", eth_if[gi]);
        uvm_config_db#(virtual apb_if)::set(
            null, $sformatf("uvm_test_top.env_h.ral_reg_agent_%0d.*", gi), "vif", apb_vif[gi]);
        //uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top.env_h.ral_reg_agent.*", "vif", apb_vif);
      end
      assign eth_if[gi].TX_CLK = clk;
      assign eth_if[gi].RX_CLK = clk;
      assign txd[gi]           = eth_if[gi].TXD;
      assign txc[gi]           = eth_if[gi].TXC;
      assign eth_if[gi].RXD    = rxd[gi];
      assign eth_if[gi].RXC    = rxc[gi];
    end
  endgenerate

  // Initialize unicast and multicast MAC address tables
  initial begin
    mac_unicast(mac_uni);
    mac_multicast(mac_multi);
  end

  // Register statistics interface for each MAC
  genvar gj;
  generate
    for (gj = 0; gj < `NO_OF_AGENTS; gj++) begin : user_int
      initial begin
        statistics::v_uif[mac_uni[gj]] = ui_inf[gj];
        uvm_config_db#(virtual eth_interface)::set(null, "uvm_test_top.env_h.pause_h", $sformatf(
                                                   "vinf%0d", gj), eth_if[gj]);
        uvm_config_db#(virtual eth_interface)::set(null, "uvm_test_top.env_h.ipg_chkr_h", $sformatf(
                                                   "vinf%0d", gj), eth_if[gj]);
        uvm_config_db#(virtual eth_interface)::set(null, "uvm_test_top.env_h.pfc_h", $sformatf(
                                                   "virf%0d", gj), eth_if[gj]);
      end
    end
  endgenerate

  //------------------------------------------------------------------------------
  // Captures transmitted frames, determines the destination MAC address,
  // routes frames to the appropriate receiver(s), and drives the RX interface.
  //------------------------------------------------------------------------------
  always @(posedge clk) begin
    if (!rst) begin
      for (int i = 0; i < `NO_OF_AGENTS; i++) begin
        routing[i]   = 1'b0;
        capturing[i] = 1'b0;
        rd_ptr[i]    = 0;
        txd_buffer[i].delete();
        txc_buffer[i].delete();
        for (int j = 0; j < `NO_OF_AGENTS; j++) if (route_da[i].exists(j)) route_da[i].delete(j);
      end
      hdr_found   = 'b0;
      route_ready = 'b0;
      for (int i = 0; i < `NO_OF_AGENTS; i++) begin
        rxd[i] = {NUM_LANES{1'b0}};
        rxc[i] = {NUM_LANES{1'b0}};
      end
    end else begin
      // Capture transmitted XLGMII data
      for (int i = 0; i < `NO_OF_AGENTS; i++) begin
        for (int lane = 0; lane < NUM_LANES; lane++) begin
          lane_data = txd[i][lane*8+:8];
          lane_ctrl = txc[i][lane];

          if (lane_ctrl && lane_data == RS_START) begin
            capturing[i] = 1'b1;
          end

          if (capturing[i]) begin
            txd_buffer[i].push_back(lane_data);
            txc_buffer[i].push_back(lane_ctrl);
          end
        end
      end

      // ===== STAGE 1: Find hdr_base =====
      for (int i = 0; i < `NO_OF_AGENTS; i++) begin
        if (capturing[i] && !hdr_found[i]) begin
          for (int b = 0; b < txd_buffer[i].size(); b++) begin
            if (txc_buffer[i][b] == 1'b1 && txd_buffer[i][b] == RS_START) begin
              hdr_base_pipe[i] = b;
              hdr_found[i] = 1'b1;
              break;
            end
          end
        end
      end

      // ===== STAGE 2: Extract DA and set routing =====
      for (int i = 0; i < `NO_OF_AGENTS; i++) begin
        if (!routing[i] && hdr_found[i] && !route_ready[i]) begin
          // Extract destination MAC address
          if ((hdr_base_pipe[i] + 14) <= txd_buffer[i].size()) begin
            da = {
              txd_buffer[i][hdr_base_pipe[i]+8],
              txd_buffer[i][hdr_base_pipe[i]+9],
              txd_buffer[i][hdr_base_pipe[i]+10],
              txd_buffer[i][hdr_base_pipe[i]+11],
              txd_buffer[i][hdr_base_pipe[i]+12],
              txd_buffer[i][hdr_base_pipe[i]+13]
            };

            for (int j = 0; j < `NO_OF_AGENTS; j++)
            if (route_da[i].exists(j)) route_da[i].delete(j);

            // Broadcast frame
            if (da == 48'hFFFF_FFFF_FFFF) begin
              for (int j = 0; j < `NO_OF_AGENTS; j++) if (i != j) route_da[i][j] = 1;
            end  // Unicast frame
            else if (!da[40]) begin
              if (mac23_route_en && i == 2 && da == 48'h005343332313)
                route_da[i][3] = 1;       // MAC2 -> MAC3
              else if (mac23_route_en && i == 3 && da == 48'h005242322212) 
                route_da[i][2] = 1;       // MAC3 -> MAC2
              else begin  
                for (int j = 0; j < `NO_OF_AGENTS; j++)
                if (i != j && mac_uni[j] == da) route_da[i][j] = 1;
                if (route_da[i].num() == 0) route_da[i][(i+1)%`NO_OF_AGENTS] = 1;
	      end
            end  // Multicast frame
            else begin
              for (int j = 0; j < `NO_OF_AGENTS; j++)
              if (i != j && mac_multi[j].exists(da)) route_da[i][j] = 1;
              if (route_da[i].num() == 0) route_da[i][(i+1)%`NO_OF_AGENTS] = 1;
            end

            routing[i] = 1'b1;  // Enable routing NOW!
            route_ready[i] = 1'b1;
          end
        end
      end

      // Drive routed frame onto the selected RX interface
      for (int j = 0; j < `NO_OF_AGENTS; j++) begin
        rx_lane_data = {NUM_LANES{RS_IDLE}};
        rx_lane_ctrl = {NUM_LANES{1'b1}};

        for (int i = 0; i < `NO_OF_AGENTS; i++) begin
          if (i != j && routing[i] && route_da[i].exists(j)) begin
            for (int lane = 0; lane < NUM_LANES; lane++) begin
              if (rd_ptr[i] + lane < txd_buffer[i].size()) begin
                rx_lane_data[lane*8+:8] = txd_buffer[i][rd_ptr[i]+lane];
                rx_lane_ctrl[lane]      = txc_buffer[i][rd_ptr[i]+lane];
              end else begin
                rx_lane_data[lane*8+:8] = RS_IDLE;
                rx_lane_ctrl[lane]      = 1'b1;
              end
            end
          end
        end
        rxd[j] = rx_lane_data;
        rxc[j] = rx_lane_ctrl;
      end

      for (int i = 0; i < `NO_OF_AGENTS; i++) begin
        if (routing[i] && rd_ptr[i] < txd_buffer[i].size()) begin
          remaining = txd_buffer[i].size() - rd_ptr[i];
          rd_ptr[i] += (remaining < NUM_LANES) ? remaining : NUM_LANES;
          if (rd_ptr[i] >= txd_buffer[i].size()) begin
            routing[i] = 1'b0;
            hdr_found[i] = 1'b0;
            route_ready[i] = 1'b0;
          end
        end
      end
    end
  end
  // Generate system clock
  initial begin
    clk = 0;
    forever #(HALF_PERIOD) clk = ~clk;
  end

  // Apply reset before starting the test
  initial begin
    rst = 0;
    repeat (`RESET_PERIOD) @(posedge clk);
    rst = 1;
  end
  initial begin
    forever #0.01 clk1 = ~clk1;
  end

  // Give UI interface to RAL register agent
  initial begin

    //uvm_config_db#(virtual eth_ui_interface)::set( null, "uvm_test_top.env_h.ral_reg_agent.*", "vif", ui_inf[0]);

    // Start the UVM test
    run_test("");
  end

endmodule


