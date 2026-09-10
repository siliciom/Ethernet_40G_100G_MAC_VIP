`ifndef DEFINE_SV
`define DEFINE_SV
//******************************************************************//
//                    ETHERNET DEFINES FILE
//
// Defines common macros, protocol constants, data types, and
// utility functions used throughout the Ethernet UVM verification
// environment. This file also provides global Ethernet MAC address
// initialization routines and shared definitions for frame handling.
//
//******************************************************************//

`define NO_OF_AGENTS              2
`define RAL_AGENTS                2
`define DATA_WIDTH                64
`define CTRL_WIDTH                8
`define BITS_PER_BYTE             8
`define VLAN_PCP                  8
`define FREQ_IN_MHZ               625

`define START_CH                  8'hFB
`define TERMINATE_CH              8'hFD
`define IDLE_CH                   8'h07
`define ERROR_CH                  8'hFE
`define PREAMBLE                  8'h55
`define SFD                       8'hD5

`define PAUSE_PAYLOAD_SIZE        42
`define PFC_PAYLOAD_SIZE          26
`define VLAN_PAYLOAD_SIZE         42
`define DOUBLE_VLAN_PAYLOAD_SIZE  38
`define MIN_PAYLOAD_SIZE          46

`define HEADER                    18
`define CRC                       32
`define MAC_ADDR                  48

`define REMOTE_FAULT_SEQ          32'h9c_00_00_02
`define LOCAL_FAULT_SEQ           32'h9c_00_00_01
`define IDLE_BYTES                32'h07_07_07_07
`define FAULT_PERIOD              500
`define RESET_PERIOD              5
`define HALF_CLOCK_DELAY          0.8

`define IPG_GAP                  12
`define MAX_DIC                  7
`define MIN_IPG                  5

`define NO_OF_PKTS               1000


// ------------------------------------------------------------------
// MAC Control Frame Identification (802.3x Pause / 802.1Qbb PFC)
// -- these are WIRE-CONTENT constants (what actually appears in the
// frame), used to identify pause/PFC frames on the wire. They are
// NOT testbench intent flags (e.g. pause_frame_en/pfc_frame_en) --
// identification of a pause/PFC frame should be driven by these
// values, matching the same philosophy as the VLAN TPID constants
// below.
// ------------------------------------------------------------------
`define MAC_CTRL_ETHERTYPE        16'h8808        // EtherType for all 802.3 MAC control frames
`define PAUSE_OPCODE              16'h0001        // Opcode identifying a standard 802.3x PAUSE frame
`define PAUSE_DA                  48'h0180_C200_0001  // Reserved MAC control multicast address (802.3x pause + PFC)

// PFC (802.1Qbb) uses the same MAC_CTRL_ETHERTYPE + reserved DA as
// pause, but is distinguished by its own opcode and by carrying a
// non-zero priority_enable_vector (indicates per-priority XOFF/XON
// rather than a single global pause).
`define PFC_OPCODE                16'h0101        // Opcode identifying a PFC (Priority-based Flow Control) frame

// ------------------------------------------------------------------
// VLAN Tag Identification (802.1Q / 802.1ad QinQ)
// -- WIRE-CONTENT TPID constants. A frame is only legitimately
// single- or double-tagged if the corresponding TPID field on the
// wire matches these values -- not merely because a sequence set an
// intent flag like vlan_en/outer_vlan_en.
// ------------------------------------------------------------------
`define SINGLE_VLAN_TPID          16'h8100        // 802.1Q single VLAN tag
`define OUTER_VLAN_TPID           16'h88A8        // 802.1ad (QinQ) outer VLAN tag, double-tagged frames

`define COMPARE_COUNTER(tx_cnt, rx_cnt, name) \
  if(statistics::tx_cnt[mac0_addr] != statistics::rx_cnt[mac1_addr]) \
    `uvm_error("COUNTERS_ERR", $sformatf("%s mismatch : TX_MAC[%0d]=%0d RX_MAC[%0d]=%0d", \
      name, i, statistics::tx_cnt[mac0_addr],  j, statistics::rx_cnt[mac1_addr]))

typedef enum {
  NORMAL_FRAME,
  VLAN_FRAME,
  DOUBLE_VLAN_FRAME,
  PAUSE_FRAME,
  PFC_FRAME
} frame_type_e;

typedef struct packed {
  time         t;
  logic [63:0] txd;
  logic [7:0]  txc;
} intf_trace_t;

// Global mac addresses functions
function automatic void mac_unicast(ref bit [47:0] mac_t[`NO_OF_AGENTS]);
  for (int i = 0; i < `NO_OF_AGENTS; i++) begin
    mac_t[i] = {8'h00, 8'(8'h50 + i), 8'(8'h40 + i), 8'(8'h30 + i), 8'(8'h20 + i), 8'(8'h10 + i)};
  end
endfunction

function automatic void mac_multicast(ref bit mac_t[`NO_OF_AGENTS][bit [47:0]]);
  for (int i = 0; i < `NO_OF_AGENTS; i++) begin
    if (i % 2 == 1) mac_t[i][{8'h01, 8'h50, 8'h40, 8'h30, 8'h20, 8'h10}] = 1;
    mac_t[i][{8'h01, 8'h80, 8'hc2, 8'h00, 8'h00, 8'h01}] = 1;
  end
endfunction

`endif
