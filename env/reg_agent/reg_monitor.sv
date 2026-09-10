class reg_monitor extends uvm_monitor;

  `uvm_component_utils(reg_monitor)

  virtual apb_if vif;
  uvm_analysis_port #(reg_seq_item) analysis_port;

  function new(string name = "reg_monitor", uvm_component parent = null);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("REG_MON_VIF", "virtual apb_if not found")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    reg_seq_item tr;

    forever begin
      // A valid APB transfer is sampled on PCLK rising edge during ACCESS.
      @(posedge vif.PCLK);

      if (vif.PSEL && vif.PENABLE && vif.PREADY) begin
        tr = reg_seq_item::type_id::create("tr", this);

        tr.addr = vif.PADDR;
        tr.write = vif.PWRITE;
        tr.wdata = vif.PWDATA;
        tr.rdata = vif.PRDATA;
        tr.error = vif.PSLVERR;
        tr.response = vif.PSLVERR ? 1'b1 : 1'b0;

        `uvm_info(
            "REG_MON",
            $sformatf(
                "APB MONITOR: ADDR=0x%08h WRITE=%0d WDATA=0x%08h RDATA=0x%08h PREADY=%0d PSLVERR=%0d",
                tr.addr, tr.write, tr.wdata, tr.rdata, vif.PREADY, tr.error), UVM_LOW)

        analysis_port.write(tr);
      end
    end
  endtask

endclass
