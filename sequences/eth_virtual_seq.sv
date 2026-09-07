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
  eth_cnfg cfg_h;
  int unsigned wt_dist0;
  int unsigned wt_dist1;
  bit config_reg_en = 0;  
  bit reg_config_rand;
  error_cb err_cb;
  bit ctrl_error_en;
  int ether_type;
  bit [47:0] da;
  bit payload_rand_en = 1;
  bit padding_en = 1;
  bit use_frame_mode_logic = 1;
  bit runt_en;
  bit jabber_en = 1;
  rand bit custom_da;
  bit corrupt_fcs_en;
  bit multicast_en;
  bit broadcast_en;
  bit missing_terminate;
  bit bad_preamble_en;
  int no_of_pkts;
  bit vlan_en;
  bit jumbo_en;
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
  // pause
  bit pause_frame_en;
  bit [15:0] pause_opc;
  bit [15:0] pause_time; 
  bit pause_normal_traffic;
  bit normal_xon_xoff_en;   
  int pause_gap_cnt;
  bit pause_simul_en;
  bit simul_pause_en2;
  bit simul_pause_time2;
  bit vlan_pause_en;
  bit pause_update_time_en;  
  bit send_immediate_xon;
  bit pause_rsd_en;
  int count;
  bit waiting_for_xon;
  int invalid_char_pkt_cnt = 0;
  int unsigned SKIP_FRAMES = 2;

  // pfc
  bit pfc_frame_en;   
  bit pfc_with_vlan_traffic;
  bit basic_pfc_en;
  bit pfc_overlap_en;
  bit pfc_simul_en;
  bit simul_pfc_en2;
  bit pfc_rand_pri_en;
  bit pfc_stress_en;
  bit multiple_pfc_stress_en;
  bit multi_priority_pfc_en;
  bit back_to_back_xoff_xon_en;
  bit pcp_rand_en;
  bit pkt_gap_cnt;
  bit [2:0]pcp_temp;
  bit seq2_pcp_en;
  int paused_pcp_q[$];
  int paused_pcp_q2[$];
  int temp;
  int paused_pcp_q1[$];
  bit [2:0] paused_prio;
  bit vlan_phase;
  bit [2:0] t_pcp;
  int t_cnt;   
  
  class randc_pcp;
    randc bit [2:0] rand_pcp;
  endclass  

  randc_pcp pcp_gen;

  function new (string name = "base_virtual_seq");
    super.new(name);
    pcp_gen = new();
  endfunction  

  function bit get_weighted_bit();
    bit val;
    void'(std::randomize(val) with {val dist {0:=wt_dist0, 1:=wt_dist1};});
    return val;
  endfunction

  //------------------------------------------------------------------------------
  // Frame generation modes.
  // Selects the type of Ethernet frame or error scenario to be generated
  // by the virtual sequence.
  //------------------------------------------------------------------------------
  typedef enum {

    // Normal frame generation
    NORMAL_MODE,           // Normal Ethernet frame
    MIN_MODE,              // Min frame
    MAX_MODE,              // Max frame
    MULTICAST,             // Multicast frame
    BROADCAST,             // Broadcast frame

    // Frame size scenarios
    RUNT_MODE,             // Runt frame (<64 bytes)
    FRAGMENT_MODE,         // Runt frame with bad FCS
    JABBER_MODE,           // Jabber frame (>maximum size)
    OVERSIZE_MODE,         // Oversize frame

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

    // XLGMII / RS layer error scenarios
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
  eth_reg_config_seq reg_seq1, reg_seq2;  
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
    if(!pause_normal_traffic & !pfc_with_vlan_traffic) begin 	  

      // Create normal frame sequences for both MAC agents.    
      seq1 = eth_normal_frame_seq::type_id::create("seq1");
      seq2 = eth_normal_frame_seq::type_id::create("seq2");

      // Pass the register configuration corresponding to each MAC agent into its normal frame sequence.
      //seq1.cfg_h = p_sequencer.cfg_h[0];
      //seq2.cfg_h = p_sequencer.cfg_h[1];

      // Apply the common/default frame configuration to both sequences.    
      apply_config(seq1);
      apply_config(seq2);

      // Create register configuration sequences for both MAC agents.
      // These sequences are responsible for configuring/randomizing the
      // register-based Ethernet features.
      reg_seq1 = eth_reg_config_seq::type_id::create("reg_seq1");
      reg_seq2 = eth_reg_config_seq::type_id::create("reg_seq2");

      // Associate each register configuration sequence with its MAC agent.    
      reg_seq1.agent_id = 0;
      reg_seq2.agent_id = 1;

      //--------------------------------------------------------------------------
      // Multicast/Broadcast traffic
      // Only agent 0 is used in this mode. Packets are generated and sent
      // sequentially through MAC sequencer 0.
      //--------------------------------------------------------------------------
      if(multicast_en || broadcast_en) begin
        repeat(this.no_of_pkts) begin
          apply_config(seq1);
	  if(use_frame_mode_logic) 
            apply_frame_mode();
	  if(config_reg_en)
            reg_seq1.start(p_sequencer);
          seq1.start(p_sequencer.mac_seqr_h[0]);
        end
      end
   

      //--------------------------------------------------------------------------
      // Normal full-duplex traffic
      // Agent 0 and Agent 1 generate packets independently and concurrently.
      //--------------------------------------------------------------------------
      else begin
        fork 
          // MAC Agent 0 traffic          
          begin	    
            repeat(this.no_of_pkts) begin	
              seq1 = eth_normal_frame_seq::type_id::create("seq1");
              //seq1.cfg_h = p_sequencer.cfg_h[0];
              if(use_frame_mode_logic) 
                apply_frame_mode();
              apply_config(seq1);	      
	      if(config_reg_en)
                reg_seq1.start(p_sequencer);
              seq1.start(p_sequencer.mac_seqr_h[0]);
       	    end  
          end
          begin	     
            // MAC Agent 1 traffic	    
            repeat(this.no_of_pkts) begin	
              seq2 = eth_normal_frame_seq::type_id::create("seq2");
              //seq2.cfg_h = p_sequencer.cfg_h[1];
              if(use_frame_mode_logic) 
                apply_frame_mode();
              apply_config(seq2);	      
	      if(config_reg_en)
                reg_seq2.start(p_sequencer);
              seq2.start(p_sequencer.mac_seqr_h[1]);
            end  
          end 	
        join
      end
    end
    else begin
      if(pause_normal_traffic) begin
	fork 
          begin
            repeat(this.no_of_pkts) begin
              seq1 = eth_normal_frame_seq::type_id::create("seq1");
	      apply_config(seq1);
	      if(pause_gap_cnt > 0)
		pause_gap_cnt--; 
	      if(send_immediate_xon) begin
                seq1.pause_sel=1;
                seq1.pause_time=0; //Xon
                send_immediate_xon=0;
              end 
              //Normal_pause +(Xon & Xoff)
              else if(normal_xon_xoff_en && pause_gap_cnt==0 && $urandom_range(1,100)<10) begin
                seq1.pause_sel = 1;
                if($urandom_range(1,100)<=3)
                  seq1.pause_time=0; //xon
                else begin
                  seq1.pause_time=$urandom_range(1,10); //xoff
                  if($urandom_range(1,100)<=70)
                    send_immediate_xon=1;
                end   
                pause_gap_cnt = $urandom_range(5,6);
              end 
              //reserved_opcode
              else if(pause_rsd_en && $urandom_range(0,100)<5) begin
                seq1.pause_sel=1;
                seq1.pause_rsd_en=pause_rsd_en;
                seq1.pause_time=$urandom_range(1,10);
              end
              //pause_update_time
              else if(this.pause_update_time_en  && ($urandom_range(1,100)<30) ) begin
                seq1.pause_sel =1;
                seq1.pause_time=$urandom_range(1,10);
              end
              //simultaneous_pause_frames
              else if(this.pause_simul_en && $urandom_range(1,50)<20) begin
                seq1.pause_sel  = 1;
                seq1.pause_time = $urandom_range(1,10);
                //simul_pause_en2   = 1;
                //simul_pause_time2 = $urandom_range(1,10);
              end
              //pause_with_vlan_frames
              else if(this.vlan_pause_en && $urandom_range(1,100)<7) begin
                seq1.pause_sel=1;
                seq1.pause_time=$urandom_range(1,10);
	       // seq1.vlan_en=0;
              end          
              else     
                seq1.pause_sel=0;
              seq1.start(p_sequencer.mac_seqr_h[0]);
            end
          end
          begin
            repeat(this.no_of_pkts) begin
              seq2 = eth_normal_frame_seq::type_id::create("seq2");
              apply_config(seq2);
	      /*if(this.pause_simul_en && $urandom_range(1,50)<20) begin
                seq2.pause_sel  = 1;
                seq2.pause_time = $urandom_range(1,10);
              end  */
	      if(this.pause_simul_en && $urandom_range(1,50)<20) begin
                seq2.pause_sel  = 1;
                seq2.pause_time = $urandom_range(1,10);
              end
              else
                seq2.pause_sel = 0;
              seq2.start(p_sequencer.mac_seqr_h[1]);
            end
          end
        join
      end 
      //=================== VLAN TRAFFIC + PFC =========================//
      if(pfc_with_vlan_traffic) begin
        fork
          begin
            repeat(this.no_of_pkts) begin
              seq2 = eth_normal_frame_seq::type_id::create($sformatf("vlan_seq_%0d",$time));
              apply_config(seq1);
              if(pfc_stress_en && !pcp_rand_en)
                void'(std::randomize(seq1.pfc_sel) with {seq1.pfc_sel dist {0:=90, 1:=10};});
              if(pkt_gap_cnt >0)
                pkt_gap_cnt--;
              //Basic_pfc  
              if(basic_pfc_en && $urandom_range(1,50)<10) begin
                seq1.pfc_sel=1;    
                seq1.temp_pcp=3;//$urandom_range(1,4);
                seq1.priority_en_vector[seq1.temp_pcp] = 1;// priority[3] 
                for(int i=0;i<8;i++)
                  seq1.pfc_pause_time[i]=$urandom_range(1,5);  
              end 
              //multiple_priority_vector_enable	
              else if(multi_priority_pfc_en && (count != 0) && ((count+1)%20==0)) begin
                int pri[$];
                seq1.pfc_sel = 1;
                foreach(seq1.pfc_pause_time[i])
                  seq1.pfc_pause_time[i] = $urandom_range(6,9);         // Give quanta to all priorities
                seq1.priority_en_vector = '0;                           // Clear enable vector
                for(int i=0;i<8;i++)                                    // Create priority list
                  pri.push_back(i);
                pri.shuffle();                                          // Shuffle priorities
                for(int i=0;i<4;i++)                                    // Enable any four priorities
                    seq1.priority_en_vector[pri[i]] = 1;
                `uvm_info("MULTI_PFC", $sformatf("Packet=%0d Vector=%b Pause=%p", count+1, seq1.priority_en_vector, seq1.pfc_pause_time), UVM_LOW)
              end	
              //random_priority
              else if(pfc_rand_pri_en && $urandom_range(1,100)<=10) begin
                seq1.pfc_sel=1;
      	        assert(pcp_gen.randomize());
                pcp_temp=pcp_gen.rand_pcp;
                seq1.temp_pcp=pcp_temp;
                seq2_pcp_en=1; 
                seq1.priority_en_vector[seq1.temp_pcp]=1;
                for(int i=0;i<8;i++) 
                  seq1.pfc_pause_time[i]=$urandom_range(1,10);
              end  
              //Simulataneous_pfc
              else if(pfc_simul_en && $urandom_range(1,50) <=10) begin
                seq1.pfc_sel=1;
      	        assert(pcp_gen.randomize());
                seq1.temp_pcp=pcp_gen.rand_pcp;
                paused_pcp_q.push_back(seq1.temp_pcp);
                seq1.priority_en_vector[seq1.temp_pcp]=1;
                for(int i=0;i<=7;i++) begin
                  seq1.pfc_pause_time[seq1.temp_pcp]=$urandom_range(5,10);
                end
                `uvm_info("seqqq_mac0",$sformatf("pcp=%0d, pfc_pause_time=%0d",seq1.temp_pcp,seq1.pfc_pause_time[seq1.temp_pcp]),UVM_LOW)
                simul_pfc_en2=1;
                if($urandom_range(1,50)<=30) begin
                  assert(pcp_gen.randomize());
                  temp=pcp_gen.rand_pcp;
                  if(temp inside {paused_pcp_q})
                    seq1.pfc_pause_time[temp]=0;
                end 
              end  
              //Back_to_back_xoff_xon
              else if(back_to_back_xoff_xon_en &&(waiting_for_xon || $urandom_range(1,100)<10) && pkt_gap_cnt==0) begin
                seq1.pfc_sel = 1;
                if(!waiting_for_xon) begin
      	          assert(pcp_gen.randomize());
                  paused_prio = pcp_gen.rand_pcp;
                  seq1.temp_pcp = paused_prio;
                  seq1.priority_en_vector[paused_prio] = 1;
                  for(int i=0;i<8;i++)
                    seq1.pfc_pause_time[i] = $urandom_range(5,10);
                  waiting_for_xon = 1; 
                  `uvm_info("VIRTUAL_SEQ",$sformatf(" XOFF sent for prio=%0d,priority_en[%0d]=%0d,pfc_pause_time[%0d]= %0d", paused_prio,
                           seq1.temp_pcp,seq1.priority_en_vector[paused_prio], seq1.temp_pcp,seq1.pfc_pause_time[paused_prio]),UVM_LOW)
                end 
                else begin
                  seq1.temp_pcp = paused_prio;
                  seq1.priority_en_vector[paused_prio] = 1;
                  seq1.pfc_pause_time[paused_prio] = 0;
                  waiting_for_xon = 0;
                  `uvm_info("VIRTUAL_SEQ",$sformatf(" XON sent for prio=%0d,priority_en[%0d]=%0d,pfc_pause_time[%0d]= %0d", paused_prio,
                      seq1.temp_pcp,seq1.priority_en_vector[paused_prio], seq1.temp_pcp,seq1.pfc_pause_time[paused_prio]),UVM_LOW)
                end 
                pkt_gap_cnt=2;
              end
              else if(pfc_overlap_en) begin //independent_priority_overlap
                if(!vlan_phase) begin
                  if(paused_pcp_q1.size()==0) begin
                    paused_pcp_q1='{0,1,2,3,4,5,6,7};
                    paused_pcp_q1.shuffle();
                  end 
                  else begin
                    seq1.pfc_sel=1;
                    seq1.pfc_overlap_en=pfc_overlap_en;
                    seq1.temp_pcp=paused_pcp_q1.pop_back();
                    seq1.priority_en_vector[seq1.temp_pcp]=1;
                    for(int i=0;i<8;i++) 
                      seq1.pfc_pause_time[i]=$urandom_range(5,10);
                    if(paused_pcp_q1.size()==0) begin
                      vlan_phase=1;
                      pause_gap_cnt=$urandom_range(50,100);
                      this.pfc_overlap_en=0;
                    end  
                  end
                end 
              end 
              else if(pfc_stress_en && (seq1.pfc_sel || pcp_rand_en)) begin
                if(!pcp_rand_en) begin
      	          assert(pcp_gen.randomize());
                  seq1.temp_pcp= pcp_gen.rand_pcp;
                  t_pcp = seq1.temp_pcp;
                  pcp_rand_en = 1;
                  t_cnt = count;
                end
                seq1.temp_pcp = t_pcp;
                //seq1.pfc_sel = pcp_rand_en;
                seq1.priority_en_vector[seq1.temp_pcp] = 1;      
                seq1.pfc_pause_time[seq1.temp_pcp]     = 10;                
                if(count == t_cnt+1) seq1.pfc_pause_time[seq1.temp_pcp]=6;                
                else if(count == t_cnt+2) seq1.pfc_pause_time[seq1.temp_pcp]=3;                
                else if(count == t_cnt+3) begin
                  seq1.pfc_pause_time[seq1.temp_pcp]=0;                
                  pcp_rand_en = 0;
                end
                `uvm_info("Sending Stress",$sformatf("Sending PFC with PCP = %0d, Pause Time = %0d, Count = %0d, Pause_en_vector = %0d",
                  seq1.temp_pcp,seq1.pfc_pause_time[seq1.temp_pcp], count ,seq1.priority_en_vector[seq1.temp_pcp]),UVM_LOW)
              end 
              else if(multiple_pfc_stress_en && count >=2 && count <=9) begin      
                set_multiple_pfc_stress(count, seq1);
              end        
              else begin
                seq1.pfc_sel = 0;
                pause_gap_cnt--;
                if(pause_gap_cnt==0) begin
                  vlan_phase = 0;
                  pfc_overlap_en=1;
                end  
              end  
              count++;
              seq1.start(p_sequencer.mac_seqr_h[0]);
            end
          end
          begin
            repeat(this.no_of_pkts) begin
              seq2 = eth_normal_frame_seq::type_id::create ($sformatf("pfc_seq_%0d",$time));
              apply_config(seq2);
              seq2.basic_pfc_en=this.basic_pfc_en;
              seq2.pfc_rand_pri_en=this.pfc_rand_pri_en;
              if(seq2_pcp_en) begin
                seq2.temp_pcp=pcp_temp;
                seq2_pcp_en=0;
              end 
              if(simul_pfc_en2) begin
                seq2.pfc_sel=1;
                assert(pcp_gen.randomize());
                seq2.temp_pcp=pcp_gen.rand_pcp;
                paused_pcp_q2.push_back(seq2.temp_pcp);
                seq2.priority_en_vector[seq2.temp_pcp]=1;
      	        for(int i=0;i<=7;i++) begin
                  seq2.pfc_pause_time[seq2.temp_pcp]=$urandom_range(1,10);
                end
                `uvm_info("seqqq_mac1",$sformatf("pcp=%0d, pfc_pause_time=%0d",seq2.temp_pcp,seq2.pfc_pause_time[seq2.temp_pcp]),UVM_LOW)
                simul_pfc_en2=0;
                if($urandom_range(1,50)<=30) begin
      	          assert(pcp_gen.randomize());
                  temp=pcp_gen.rand_pcp;
                  if(temp inside {paused_pcp_q2})
                    seq2.pfc_pause_time[temp]=0;
                end  
              end
              else begin
                if(waiting_for_xon && $urandom_range(1,10)<5) begin
                  seq2.force_pcp_en = 1;
                  seq2.force_pcp = paused_prio;
                end
                else begin
                  seq2.force_pcp_en = 0;
                end
                seq2.pfc_sel =0;
              end 
              seq2.start(p_sequencer.mac_seqr_h[1]);
            end
          end
        join
      end
    end
  endtask

  task set_multiple_pfc_stress(int count,eth_normal_frame_seq seq1);
    seq1.pfc_sel=1;    
    if(count % 2 == 0) begin
      seq1.temp_pcp=3;//$urandom_range(1,4);
    end
    else begin
      seq1.temp_pcp=4;//$urandom_range(1,4);
    end
    seq1.priority_en_vector[seq1.temp_pcp] = 1;// priority[3]      
    if(count == 2 || count == 3) begin
      seq1.pfc_pause_time[seq1.temp_pcp]=10;                
    end
    else if(count == 4 || count == 5) begin
      seq1.pfc_pause_time[seq1.temp_pcp]=6;                
    end
    else if(count == 6 || count == 7) begin
      seq1.pfc_pause_time[seq1.temp_pcp]=3;                
    end
    else begin
      seq1.pfc_pause_time[seq1.temp_pcp]=0;                
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
      end

      FRAGMENT_MODE: begin
        void'(std::randomize(runt_en) with {runt_en dist {0:=wt_dist0,1:=wt_dist1};});
        if(runt_en) begin
          ether_type      = $urandom_range(0,45);
          payload_rand_en = 0;
          padding_en      = 0;
	  corrupt_fcs_en = 1;
        end
        else begin
	  ether_type = $urandom_range(46,1500);	
        end
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
      end

      OVERSIZE_MODE: begin
        void'(std::randomize(jumbo_en) with {jumbo_en dist {0:=wt_dist0,1:=wt_dist1};});
	if(jumbo_en) begin
          ether_type      = $urandom_range(1536, 2000);
          payload_rand_en = 0;
          padding_en      = 0;
          corrupt_fcs_en  = 0;
        end	
	else
          ether_type     = $urandom_range(1536,4000);
      end
      VLAN_MODE: begin
        TPID = 16'h8100;
        DEI  = 0;
        PCP  = $urandom_range(0,7);
        VID  = $urandom_range(0,4095);
      end
      OUTER_VLAN_MODE: begin
        	
        outer_TPID     = 16'h88A8;
        outer_DEI      = 0;
        outer_PCP      = $urandom_range(0,7);
        outer_VID      = $urandom_range(0,4095);
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
	

      INVALID_CHAR: begin
  	if (invalid_char_pkt_cnt > SKIP_FRAMES) begin
          void'(std::randomize(err_cb.invalid_control_en) with {err_cb.invalid_control_en dist {0:=wt_dist0, 1:=wt_dist1};});
  	end
  	else begin
    	  err_cb.invalid_control_en = 0;   // force normal/clean frame
  	end
  	invalid_char_pkt_cnt++;
      end

      DOUBLE_START_CHAR: begin
        void'(std::randomize(err_cb.start_char_en) with {err_cb.start_char_en dist {0:=wt_dist0,1:=wt_dist1};});
      end

      DOUBLE_TERMINATE: begin
        void'(std::randomize(err_cb.end_char_en) with {err_cb.end_char_en dist {0:=wt_dist0,1:=wt_dist1};});
      end
      
      NO_TERMINATE_CHAR: begin
        void'(std::randomize(err_cb.missing_terminate_en) with {err_cb.missing_terminate_en dist {0:=wt_dist0,1:=wt_dist1};});
      end
      
      CONTROL_DATA_MISMATCH: begin
        void'(std::randomize(err_cb.data_txc_error_en) with {err_cb.data_txc_error_en dist {0:=wt_dist0,1:=wt_dist1};});
      end

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
    seq.jumbo_en           = this.jumbo_en;
    seq.start_char         = this.start_char; 
    seq.end_char           = this.end_char; 
    seq.data_txc_error     = this.data_txc_error; 
    seq.start_offset       = this.start_offset; 
    seq.end_offset         = this.end_offset; 
    seq.data_txc_offset    = this.data_txc_offset; 
    seq.missing_terminate  = this.missing_terminate;
    seq.pause_rsd_en        = this.pause_rsd_en;
    
  endtask 
endclass








