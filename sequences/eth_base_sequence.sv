//******************************************************************//
//                     ETHERNET SEQUENCE FILE
//
// Implements Ethernet stimulus sequences. Sequences generate Ethernet
// frames and protocol scenarios such as data traffic, pause frames,
// control frames, error injection, VLAN packets, jumbo frames, and
// other protocol-specific test cases.
// TODO:- Extend the sequence to support Ethernet control frames
//        such as Pause, PFC, and Fault Sequences..
//
// Author: Dheeraj
//
//******************************************************************//

`ifndef ETH_BASE_SEQUENCE_SV
`define ETH_BASE_SEQUENCE_SV 

class base_seq extends uvm_sequence #(eth_seq_item);

  `uvm_object_utils(base_seq)

  eth_seq_item        req;

  // Common frame configuration
  int                 ether_type;
  bit                 payload_rand_en            = 1;
  bit                 padding_en                 = 1;
  bit                 runt_en                    = 0;
  bit          [47:0] da;
  bit                 custom_da                  = 0;
  bit                 jabber_en                  = 0;
  bit                 corrupt_fcs_en             = 0;
  bit                 bad_preamble_en            = 0;
  rand int            c_ether_type;
  int                 no_of_pkts;

  // VLAN
  bit                 vlan_en                    = 0;
  bit          [ 2:0] PCP;
  bit                 DEI;
  bit          [11:0] VID;
  bit          [15:0] TPID;
  bit                 outer_vlan_en;
  bit          [ 2:0] outer_PCP;
  bit                 outer_DEI;
  bit          [11:0] outer_VID;
  bit          [15:0] outer_TPID;
  bit                 jumbo_en;

  // RS/error configuration
  bit                 start_char;
  bit                 end_char;
  bit                 data_txc_error;
  bit                 missing_terminate;
  int                 start_offset;
  int                 end_offset;
  int                 data_txc_offset;

  // Pause
  bit                 pause_frame_en;
  bit          [15:0] pause_opc;
  bit          [15:0] pause_time;
  bit                 pause_sel;
  bit                 pause_rsd_en;

  // PFC
  // NOTE: these mirror fields also declared on eth_seq_item, which is
  // what all PFC sequences actually stamp (req.pfc_sel, req.temp_pcp,
  // etc.) per the "item as single source of truth" convention. These
  // sequence-level copies are currently unused by body() in any PFC
  // sequence -- verify against eth_seq_item.sv and remove if confirmed
  // redundant.
  bit                 pfc_frame_en;
  bit          [15:0] priority_en_vector;
  bit          [15:0] pfc_pause_time        [8];
  bit                 pfc_sel;
  int                 temp_pcp;
  bit                 basic_pfc_en;
  bit                 pfc_rand_pri_en;
  bit                 force_pcp_en;
  bit          [ 2:0] force_pcp;
  bit                 pfc_overlap_en;

  bit                 tx_single_vlan_enable;
  bit                 rx_single_vlan_enable;

  `uvm_declare_p_sequencer(eth_seqr)
  error_cb err_cb;

  function new(string name = "base_seq");
    super.new(name);
  endfunction


  task randomise_item();
    if (!req.randomize() with {
          sa == p_sequencer.mac_addr;
          soft ether_type inside {[46 : 1500]};
          payload.size() == ether_type;
        }) begin
      `uvm_fatal("RAND_FAIL", $sformatf("%s: packet randomization failed", get_name()))
    end
  endtask


  task fixed_ethertype_item(int unsigned len);

    if (!req.randomize() with {
          sa == p_sequencer.mac_addr;
          ether_type == len;
        }) begin
      `uvm_fatal("RAND_FAIL", $sformatf("%s: fixed-length randomization failed, len=%0d",
                                        get_name(), len))
    end

  endtask

  function void clear_error_flags();
    if (err_cb == null) return;

    err_cb.bad_fcs_en           = 0;
    err_cb.ctrl_error_en        = 0;
    err_cb.len_mismatch_en      = 0;
    err_cb.bad_preamble_en      = 0;
    err_cb.invalid_control_en   = 0;
    err_cb.start_char_en        = 0;
    err_cb.end_char_en          = 0;
    err_cb.missing_terminate_en = 0;
    err_cb.data_txc_error_en    = 0;
  endfunction

  function bit weighted_bit(int unsigned w0, int unsigned w1);
    bit value;
    void'(std::randomize(
        value
    ) with {
      value dist {
        0 := w0,
        1 := w1
      };
    });
    return value;
  endfunction

  class pfc_randc_pcp;
    randc bit [2:0] rand_pcp;
  endclass

endclass

`endif
