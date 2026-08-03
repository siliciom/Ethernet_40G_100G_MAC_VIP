//******************************************************************//
//                      ETHERNET MONITOR FILE
//
// Implements the Ethernet UVM monitor. The monitor passively samples
// the Ethernet interface, reconstructs transmitted or received frames,
// performs protocol decoding, and publishes transactions through an
// analysis port for checking, coverage, and scoreboard.
// TODO:- Need to update the basic, pause and pfc scenarios.
//
// Author: Nitheesh
//
//******************************************************************//
class eth_mon extends uvm_monitor;
  `uvm_component_utils(eth_mon)

  uvm_analysis_port #(eth_seq_item) tx_ap;
  uvm_analysis_port #(eth_seq_item) rx_ap;
  virtual eth_interface v_intf;

  function new(string name="eth_mon", uvm_component parent=null);
    super.new(name,parent);
  endfunction

  //**********************************************************//
  // This task build the transmitter and receiver analysis
  // port
  //**********************************************************//
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tx_ap = new("tx_ap", this);
    rx_ap = new("rx_ap", this);

    if(!uvm_config_db #(virtual eth_interface)::get(this,"","vif",v_intf))
      `uvm_fatal(get_type_name(),"VIF CONNECTION FAILED")
    else
      `uvm_info(get_type_name(),"CONNECTION_PASSED",UVM_LOW) 
  endfunction

  //**********************************************************//
  // This task triggers the sampling methods parallely 
  //**********************************************************//
  task run_phase(uvm_phase phase);
    wait(v_intf.rst);
    fork
      tx_mon();
      rx_mon();
    join_none
  endtask

  //**********************************************************//
  // This task samples the transmitter monitor data from the 
  // interface 
  //**********************************************************//
  task tx_mon();
    bit [63:0] last_txd;
    bit [7:0]  last_txc;
    eth_seq_item tr;

    forever begin
      @(v_intf.mon_cb);
      tr = eth_seq_item::type_id::create("tr", this);

      tr.txd = v_intf.mon_cb.TXD ;
      tr.txc = v_intf.mon_cb.TXC;
      `uvm_info(get_type_name(),$sformatf("TX MON TXD=%0h TXC=%0h -- %h -- %h", tr.txd, tr.txc,v_intf.mon_cb.TXD,v_intf.mon_cb.TXC),UVM_LOW)
      tx_ap.write(tr);
    end
  endtask

  //**********************************************************//
  // This task samples the receiver monitor data from the 
  // interface 
  //**********************************************************//
  task rx_mon();
    bit [63:0] last_rxd;
    bit [7:0]  last_rxc;
    eth_seq_item tr;

    forever begin
      @(v_intf.mon_cb);
      tr = eth_seq_item::type_id::create("tr", this);

      tr.rxd = v_intf.RXD;
      tr.rxc = v_intf.RXC;
      `uvm_info(get_type_name(),$sformatf("rx_mon rxd=%0h rxc=%0h", tr.rxd, tr.rxc),UVM_LOW)
      rx_ap.write(tr);
    end
  endtask
	
endclass



