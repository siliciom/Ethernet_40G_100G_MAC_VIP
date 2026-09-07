`ifndef MASTER_REG_ADAPTER_SV
`define MASTER_REG_ADAPTER_SV

import uvm_pkg::*;
import reg_agent_pkg::*;

class master_reg_adapter extends uvm_reg_adapter;

  `uvm_object_utils(master_reg_adapter)

  function new(string name = "master_reg_adapter");
    super.new(name);
    supports_byte_enable = 0;
    // Driver completes the transaction directly through the reg_seq_item.
    provides_responses   = 0;
  endfunction

  // RAL -> APB register agent transaction.
  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    reg_seq_item tr;
    tr = reg_seq_item::type_id::create("tr");
    tr.addr = rw.addr;
    tr.write = (rw.kind == UVM_WRITE);
    tr.wdata = (rw.kind == UVM_WRITE) ? rw.data : '0;

    `uvm_info("RAL_ADAPTER", $sformatf(
              "reg2bus: ADDR=0x%08h WRITE=%0d WDATA=0x%08h", tr.addr, tr.write, tr.wdata), UVM_LOW)
    return tr;
  endfunction

  // APB register agent transaction -> RAL response.
  virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
    reg_seq_item tr;

    if (!$cast(tr, bus_item)) begin
      `uvm_fatal("RAL_ADAPTER", "bus_item cannot be cast to reg_seq_item")
    end

    rw.addr   = tr.addr;
    rw.kind   = tr.write ? UVM_WRITE : UVM_READ;
    rw.data   = tr.write ? tr.wdata : tr.rdata;
    rw.status = tr.error ? UVM_NOT_OK : UVM_IS_OK;

    `uvm_info("RAL_ADAPTER", $sformatf(
              "bus2reg: ADDR=0x%08h WRITE=%0d DATA=0x%08h STATUS=%s",
              rw.addr,
              tr.write,
              rw.data,
              (rw.status == UVM_IS_OK) ? "OK" : "ERROR"
              ), UVM_LOW)
  endfunction

endclass

`endif
