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

class base_seq extends uvm_sequence #(eth_seq_item);
  `uvm_object_utils(base_seq)
  // Common frame configuration
  int ether_type;
  bit payload_rand_en;
  bit padding_en;
  bit runt_en;
  bit [47:0] da;
  bit custom_da;
  bit jabber_en;
  bit corrupt_fcs_en;
  bit bad_preamble_en;
  rand int c_ether_type;
  int no_of_pkts;

  //VLAN Fields
  bit vlan_en;
  bit [2:0] PCP;
  bit DEI;
  bit [11:0] VID;
  bit [15:0] TPID;
  bit outer_vlan_en;
  bit [2:0] outer_PCP;
  bit outer_DEI;
  bit [11:0] outer_VID;
  bit [15:0] outer_TPID; 

  // RS layer error configuration
  bit start_char;
  bit end_char;
  bit data_txc_error;
  bit missing_terminate;
  int start_offset;
  int end_offset;
  int data_txc_offset;


  //------------------------------------------------------------------------------
  // Constructor
  // Creates and initializes the base sequence.
  //------------------------------------------------------------------------------
  function new (string name = "base_seq");
    super.new(name);
  endfunction
endclass

//------------------------------------------------------------------------------
//                        ETH_NORMAL_FRAME_SEQ
// Normal frame sequence.
// Generates an Ethernet frame using the configured packet parameters.
//------------------------------------------------------------------------------
class eth_normal_frame_seq extends base_seq;
  eth_seq_item req;
  `uvm_object_utils(eth_normal_frame_seq)
  `uvm_declare_p_sequencer(eth_seqr)
  
  //------------------------------------------------------------------------------
  // Constructor
  // Creates and initializes the normal frame sequence.
  //------------------------------------------------------------------------------
  function new (string name = "eth_normal_frame_seq");
    super.new(name);
  endfunction

  //------------------------------------------------------------------------------
  // Main sequence task.
  // Creates a sequence item, randomizes the frame fields, applies the configured
  // frame settings (VLAN, padding, errors, control characters, etc.), and sends
  // the packet to the driver.
  //------------------------------------------------------------------------------
  task body();
    `uvm_info(get_type_name(), "eth_normal_frame_seq: Inside Body", UVM_LOW)
    req = eth_seq_item::type_id::create("req");
    start_item(req);

    // Randomize the frame. Use a fixed EtherType only when
    // payload randomization is disabled.
    if(payload_rand_en == 1) 
      req.randomize() with {sa == p_sequencer.mac_addr;};   
    else
      req.randomize() with {sa == p_sequencer.mac_addr;       
                            ether_type == c_ether_type;};  

    if(this.padding_en == 1)
      req.padding_en = 1;

    if(this.runt_en == 1)
      c_ether_type = $urandom_range(0,45);

    if(this.corrupt_fcs_en)
      req.corrupt_fcs_en = 1;

    if(this.bad_preamble_en)
      req.bad_preamble_en = 1;

    if(this.jabber_en)
      req.jabber_en = 1;

    if(this.custom_da)
      req.da = da;

    if(this.start_char)
      req.start_char = 1;

    if(this.end_char)
      req.end_char = 1;

    if(this.data_txc_error)
      req.data_txc_error = 1;

    if(this.start_offset)
      req.start_offset = 1;

    if(this.end_offset)
      req.end_offset = 1;

    if(this.data_txc_offset)
      req.data_txc_offset = 1;

    if(this.vlan_en) begin
      req.vlan_en = this.vlan_en;
      req.TPID    = this.TPID;
      req.PCP     = this.PCP;
      req.DEI     = this.DEI;
      req.VID     = this.VID;
    end

    if(this.outer_vlan_en) begin
      req.vlan_en        = this.vlan_en;
      req.outer_vlan_en  = this.outer_vlan_en;
      req.outer_TPID     = this.outer_TPID;
      req.outer_VID      = this.outer_VID;
      req.outer_DEI      = this.outer_DEI;
      req.outer_PCP      = this.outer_PCP;
    end

    finish_item(req);
  endtask
endclass

