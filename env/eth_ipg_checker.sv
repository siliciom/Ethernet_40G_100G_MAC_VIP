class eth_ipg_checker extends uvm_component;
  `uvm_component_utils(eth_ipg_checker)

  bit frame_start[`NO_OF_AGENTS];
  int ipg_cnt[`NO_OF_AGENTS];
  int term_char_cnt[`NO_OF_AGENTS];
  bit ipg_checker_en;
  virtual eth_interface v_intf[`NO_OF_AGENTS];

  function new (string name = "eth_ipg_checker", uvm_component parent = null);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      if (!uvm_config_db#(virtual eth_interface)::get(this, "", $sformatf("vinf%0d", i), v_intf[i]))
        `uvm_fatal("IPG_CHECKER", $sformatf("Unable to get vif_%0d", i))
    end    
  endfunction    

  task run_phase(uvm_phase phase);
    wait(v_intf[0].rst);
      for (int i = 0; i < `NO_OF_AGENTS; i++) begin
        automatic int agnt = i; 
        fork
          check_ipg(agnt);
        join_none
      end

  endtask

  task check_ipg(int i);
    bit [`DATA_WIDTH-1 : 0] data;
    bit [`CTRL_WIDTH-1 : 0] ctrl;

    if(!ipg_checker_en) begin
      return;
    end
    forever begin
      if(v_intf[i].RXC[0] == 1 && v_intf[i].RXD[7:0] == `START_CH) begin
	frame_start[i] = 1;
      end
      if(frame_start[i] == 1) begin
	data = v_intf[i].RXD;
	ctrl = v_intf[i].RXC;
        for (int lane = 0; lane < `CTRL_WIDTH; lane++) begin
          bit [7:0] lane_data = data[lane*8 +: 8];
          bit       lane_ctrl = ctrl[lane];

	  if(lane_ctrl == 1 && lane_data == 8'hfd) begin
	    term_char_cnt[i]++;
	  end
	  else if(lane_ctrl == 1 && lane_data == 8'h07) begin
	    ipg_cnt[i]++;
	  end

	  if(term_char_cnt[i] == `NO_OF_PKTS) begin
	    frame_start[i] = 0;
	    `uvm_info("Average IPG", $sformatf("Calculated Average IPG = %0.2f", real'(ipg_cnt[i])/`NO_OF_PKTS), UVM_LOW)
	    break;
	  end
        end
      end
      @(negedge v_intf[i].RX_CLK);
    end

  endtask
endclass
