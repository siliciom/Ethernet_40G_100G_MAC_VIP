//******************************************************************//
//                  ETHERNET VIRTUAL SEQUENCE FILE
//
// Implements system-level Ethernet test scenarios by coordinating
// multiple lower-level sequences through the virtual sequencer. It is
// used to generate synchronized traffic and complex protocol
// interactions across multiple interfaces.
// TODO:- Extend the virtual sequence to configure and execute
//        Pause, PFC, and Fault Sequence frame tests.//
// Author: Dheeraj
//
//******************************************************************//

class base_virtual_seq extends uvm_sequence;
  `uvm_object_utils(base_virtual_seq)

  int unsigned wt_dist0;
  int unsigned wt_dist1;
  error_cb err_cb;
  bit ctrl_error_en;
  int ether_type;
  bit [47:0] da;
  bit payload_rand_en = 1;
  bit padding_en = 1;
  bit use_frame_mode_logic = 1;
  bit runt_en;
  bit jabber_en;
  rand bit custom_da;
  bit corrupt_fcs_en;
  bit multicast_en;
  bit broadcast_en;
  bit missing_terminate;
  bit bad_preamble_en;
  int no_of_pkts;
  bit vlan_en;
  bit outer_vlan_en;
  bit [2:0] PCP;
  bit DEI;
  bit [11:0] VID;
  bit [15:0] TPID; 
  bit [2:0] outer_PCP;
  bit outer_DEI;
  bit [11:0] outer_VID;
  bit [15:0] outer_TPID; 
  bit start_char;
  bit end_char;
  bit data_txc_error;
  int start_offset;
  int end_offset;
  int data_txc_offset;

  //------------------------------------------------------------------------------
  // Constructor
  // Creates and initializes the base virtual sequence object.
  //------------------------------------------------------------------------------
  function new (string name = "base_virtual_seq");
      super.new(name);
  endfunction  

  //------------------------------------------------------------------------------
  // Frame generation modes.
  // Selects the type of Ethernet frame or error scenario to be generated
  // by the virtual sequence.
  //------------------------------------------------------------------------------
  typedef enum {

    // Normal frame generation
    NORMAL_MODE,           // Normal Ethernet frame
    MULTICAST,             // Multicast frame
    BROADCAST,             // Broadcast frame

    // Frame size scenarios
    RUNT_MODE,             // Runt frame (<64 bytes)
    FRAGMENT_MODE,         // Runt frame with bad FCS
    JABBER_MODE,           // Jabber frame (>maximum size)

    // VLAN scenarios
    VLAN_MODE,             // Single VLAN tagged frame
    OUTER_VLAN_MODE,       // Double VLAN (Q-in-Q) frame

    // Padding scenarios
    NORMAL_PADDING,        // Padding check for normal frame
    VLAN_PADDING,          // Padding check for VLAN frame
    DOUBLE_VLAN_PADDING,   // Padding check for double VLAN frame

    // CRC and frame format error scenarios
    BAD_FCS,               // Corrupt FCS
    PREAMBLE_ERR,          // Corrupt preamble
    LEN_PAYLOAD_MISMATCH,  // Length/Payload mismatch

    // RS layer error scenarios
    ERR_DET,               // Insert Error control character (FE)
    INVALID_CHAR,          // Insert invalid control character
    DOUBLE_START_CHAR,     // Insert extra Start character
    NO_TERMINATE_CHAR,     // Omit Terminate character
    DOUBLE_TERMINATE,      // Insert extra Terminate character
    CONTROL_DATA_MISMATCH  // TXC/Data mismatch
    } frame_mode_e;
endclass

class virtual_seq extends base_virtual_seq;
  `uvm_object_utils(virtual_seq)
  `uvm_declare_p_sequencer(eth_virtual_seqr)
  eth_normal_frame_seq seq1, seq2;  
  frame_mode_e frame_mode; 
  //------------------------------------------------------------------------------
  // Constructor
  // Creates and initializes the virtual sequence object.
  //------------------------------------------------------------------------------
  function new (string name = "virtual_seq");
    super.new(name);
  endfunction  

  //------------------------------------------------------------------------------
  // Main sequence task.
  // Creates packet sequences, applies the required configuration,
  // and starts packet transmission on the MAC sequencers.
  //------------------------------------------------------------------------------
  task body();
    seq1 = eth_normal_frame_seq::type_id::create("seq1");
    seq2 = eth_normal_frame_seq::type_id::create("seq2");
    apply_config(seq1);
    apply_config(seq2);
    if(use_frame_mode_logic) 
      apply_frame_mode();
    if(multicast_en || broadcast_en) begin
      repeat(this.no_of_pkts) begin
        apply_config(seq1);
        seq1.start(p_sequencer.mac_seqr_h[0]);
      end
    end
    else begin
      fork 
        begin	    
       	  repeat(this.no_of_pkts) begin	
	    seq1 = eth_normal_frame_seq::type_id::create("seq1");
	    if(use_frame_mode_logic) 
              apply_frame_mode();
            apply_config(seq1);	      
	    seq1.start(p_sequencer.mac_seqr_h[0]);
      	  end  
        end
        begin	     
          repeat(this.no_of_pkts) begin	
            seq2 = eth_normal_frame_seq::type_id::create("seq2");
            if(use_frame_mode_logic) 
              apply_frame_mode();
            apply_config(seq2);	      
            seq2.start(p_sequencer.mac_seqr_h[1]);
          end  
        end 	
      join
    end
  endtask

  //------------------------------------------------------------------------------
  //  Configures packet parameters according to the selected frame mode
  // (Normal, VLAN, Runt, Jabber, Error Injection, etc..
  //------------------------------------------------------------------------------
  task apply_frame_mode();

    // Default values
    runt_en         = 0;
    jabber_en       = 0;
    vlan_en         = 0;
    payload_rand_en = 1;
    padding_en      = 1;
    corrupt_fcs_en  = 0;

    case(frame_mode)

      NORMAL_MODE: begin
      end

      MULTICAST: begin
        multicast_en = 1;
	custom_da = 1;
        da = 48'h01_50_40_30_20_10;
      end

      BROADCAST: begin
        broadcast_en = 1;
	custom_da = 1;
        da = 48'hFF_FF_FF_FF_FF_FF;
      end

      RUNT_MODE: begin
        void'(std::randomize(runt_en) with {runt_en dist {0:=wt_dist0,1:=wt_dist1};});
        if(runt_en) begin
          ether_type      = $urandom_range(0,45);
          payload_rand_en = 0;
          padding_en      = 0;
        end
	else 
	  ether_type = $urandom_range(46,1500);
      end

      FRAGMENT_MODE: begin
        void'(std::randomize(runt_en) with {runt_en dist {0:=wt_dist0,1:=wt_dist1};});
        if(runt_en) begin
          ether_type      = $urandom_range(0,45);
          payload_rand_en = 0;
          padding_en      = 0;
	  corrupt_fcs_en = 1;
        end
        else 
          ether_type = $urandom_range(46,1500);
      end
      ERR_DET: begin
        void'(std::randomize(err_cb.ctrl_error_en) with {err_cb.ctrl_error_en dist {0:=wt_dist0,1:=wt_dist1};});
      end

      BAD_FCS: begin
        void'(std::randomize(err_cb.bad_fcs_en) with {err_cb.bad_fcs_en dist {0:=wt_dist0,1:=wt_dist1};});
      end

      PREAMBLE_ERR: begin
        void'(std::randomize(err_cb.bad_preamble_en) with {err_cb.bad_preamble_en dist {0:=wt_dist0,1:=wt_dist1};});
      end
       
      LEN_PAYLOAD_MISMATCH: begin
        void'(std::randomize(err_cb.len_mismatch_en) with {err_cb.len_mismatch_en dist {0:=wt_dist0,1:=wt_dist1};});
      end

      JABBER_MODE: begin
        void'(std::randomize(jabber_en) with {jabber_en dist {0:=wt_dist0,1:=wt_dist1};});
        if(jabber_en) begin
          ether_type      = $urandom_range(1536,2000);
          payload_rand_en = 0;
          padding_en      = 0;
	  corrupt_fcs_en  = 1;
        end
	else 
	  ether_type = $urandom_range(46,1500);
      end

      VLAN_MODE: begin
        vlan_en         = 1;
        TPID            = 16'h8100;
        DEI             = 0;
        PCP             = $urandom_range(0,7);
        VID             = $urandom_range(0,4095);
      end

      OUTER_VLAN_MODE: begin
        outer_vlan_en  = 1;
        outer_TPID     = 16'h88A8;
        outer_DEI      = 0;
        outer_PCP      = $urandom_range(0,7);
        outer_VID      = $urandom_range(0,4095);
	vlan_en        = 1;
	TPID           = 16'h8100;
        DEI            = 0;
        PCP            = $urandom_range(0,7);
        VID            = $urandom_range(0,4095);
      end

      NORMAL_PADDING: begin
        payload_rand_en = 0;
        ether_type      = $urandom_range(0,45);
      end

      VLAN_PADDING: begin
        vlan_en         = 1;
        payload_rand_en = 0;
        ether_type      = $urandom_range(0,42);
        TPID            = 16'h8100;
        DEI             = 0;
        PCP             = $urandom_range(0,7);
        VID             = $urandom_range(0,4095);
      end

      DOUBLE_VLAN_PADDING: begin
        outer_vlan_en  = 1;
	payload_rand_en= 0;
	ether_type     = $urandom_range(0,38);
	vlan_en        = 1;
        outer_TPID     = 16'h88A8;
        outer_DEI      = 0;
        outer_PCP      = $urandom_range(0,7);
        outer_VID      = $urandom_range(0,4095);
	TPID            = 16'h8100;
        DEI             = 0;
        PCP             = $urandom_range(0,7);
        VID             = $urandom_range(0,4095);
      end
	

      //INVALID_CHAR: begin
      //  void'(std::randomize(err_cb.invalid_control_en) with {err_cb.invalid_control_en dist {0:=wt_dist0,1:=wt_dist1};});
      //end

      //DOUBLE_START_CHAR: begin
      //  void'(std::randomize(err_cb.start_char_en) with {err_cb.start_char_en dist {0:=wt_dist0,1:=wt_dist1};});
      //end

      //DOUBLE_TERMINATE: begin
      //  void'(std::randomize(err_cb.end_char_en) with {err_cb.end_char_en dist {0:=wt_dist0,1:=wt_dist1};});
      //end
      //
      //NO_TERMINATE_CHAR: begin
      //  void'(std::randomize(err_cb.missing_terminate_en) with {err_cb.missing_terminate_en dist {0:=wt_dist0,1:=wt_dist1};});
      //end
      //
      //CONTROL_DATA_MISMATCH: begin
      //  void'(std::randomize(err_cb.data_txc_error_en) with {err_cb.data_txc_error_en dist {0:=wt_dist0,1:=wt_dist1};});
      //end

    endcase
  endtask

  //------------------------------------------------------------------------------
  // Copies the configured packet parameters from the virtual sequence
  // to the packet sequence before transmission.
  //------------------------------------------------------------------------------
  task apply_config(ref eth_normal_frame_seq seq);
    seq.c_ether_type       = this.ether_type;
    seq.padding_en         = this.padding_en;
    seq.payload_rand_en    = this.payload_rand_en;
    seq.runt_en            = this.runt_en;
    seq.jabber_en          = this.jabber_en;
    seq.vlan_en            = this.vlan_en;
    seq.custom_da          = this.custom_da;      
    seq.da                 = this.da;
    seq.outer_vlan_en      = this.outer_vlan_en;
    seq.corrupt_fcs_en     = this.corrupt_fcs_en;
    seq.bad_preamble_en    = this.bad_preamble_en;
    seq.no_of_pkts         = this.no_of_pkts;
    seq.TPID               = this.TPID;
    seq.VID                = this.VID;
    seq.DEI                = this.DEI;
    seq.PCP                = this.PCP;
    seq.outer_TPID         = this.outer_TPID;
    seq.outer_VID          = this.outer_VID;
    seq.outer_DEI          = this.outer_DEI;
    seq.outer_PCP          = this.outer_PCP;
    seq.start_char         = this.start_char; 
    seq.end_char           = this.end_char; 
    seq.data_txc_error     = this.data_txc_error; 
    seq.start_offset       = this.start_offset; 
    seq.end_offset         = this.end_offset; 
    seq.data_txc_offset    = this.data_txc_offset; 
    seq.missing_terminate  = this.missing_terminate;
    
  endtask 
endclass

