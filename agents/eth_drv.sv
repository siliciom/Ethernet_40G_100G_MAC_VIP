//******************************************************************//
//                       ETHERNET DRIVER FILE
//
// Implements the Ethernet UVM driver. The driver receives Ethernet
// sequence items from the sequencer and converts them into pin-level
// signal activity on the configured Ethernet interface.
// It is responsible for transmitting frames, idles,
// control characters, errors, and protocol-specific signaling.
// TODO:- Need to update the basic, pause and pfc scenarios.
//
// Author: Ankitha, Sanjeev
//
//******************************************************************//
class eth_drv extends uvm_driver#(eth_seq_item);
  `uvm_component_utils(eth_drv);

  eth_seq_item tr;
  virtual eth_interface v_intf;
  virtual eth_ui_interface  user_if;
 
  function new(string name = "eth_drv", uvm_component parent = null);
    super.new(name,parent);
  endfunction   
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
    if(!uvm_config_db#(virtual eth_interface)::get(this,"","vif",v_intf))
      `uvm_fatal(get_type_name(),"CONNECTION_FAILED")
    else
      `uvm_info(get_type_name(),"CONNECTION_PASSED",UVM_LOW)

    if(!uvm_config_db#(virtual eth_ui_interface)::get(this,"","u_vif",user_if))
      `uvm_fatal(get_type_name(),"CONNECTION_FAILED")
    else
      `uvm_info(get_type_name(),"CONNECTION_PASSED",UVM_LOW) 
  endfunction    
 

  //**********************************************************//
  // This task do the handshake mechanism and get the data
  // from sequence.
  //**********************************************************//
  task run_phase(uvm_phase phase);
    drive_reset();
    wait(v_intf.rst);
    forever begin
       seq_item_port.get_next_item(tr);
       drive_transfer(tr);
       `uvm_info(get_type_name(),$sformatf("TXD=%0h TXC=%0h", tr.txd, tr.txc),UVM_LOW)
       seq_item_port.item_done();
     end 
  endtask
    
  //**********************************************************//
  // This tasks do the reset of all signals. Since it is basic
  // tb, it just drive zero all signals
  //**********************************************************//
  task drive_reset();
    v_intf.TXD  <= 0;
    v_intf.TXC  <= 0;
  endtask
   
  //**********************************************************//
  // This tasks drive the data in interface signals. Since it
  // is basic tb, it just drive data whatever it gets from sequence
  //**********************************************************//
  task drive_transfer(eth_seq_item tr);
    @(v_intf.drv_cb);
    v_intf.TXD  <= tr.txd;
    v_intf.TXC  <= tr.txc;
  endtask
endclass
