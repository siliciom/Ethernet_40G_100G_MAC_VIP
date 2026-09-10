`ifndef ETH_REG_SEQ_ITEM_SV
`define ETH_REG_SEQ_ITEM_SV
class reg_seq_item extends uvm_sequence_item;

  rand bit [31:0] addr;
  rand bit        write;
  rand bit [31:0] wdata;
  bit      [31:0] rdata;
  bit             response;
  bit             error;

  `uvm_object_utils_begin(reg_seq_item)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(write, UVM_ALL_ON)
    `uvm_field_int(wdata, UVM_ALL_ON)
    `uvm_field_int(rdata, UVM_ALL_ON)
    `uvm_field_int(response, UVM_ALL_ON)
    `uvm_field_int(error, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "reg_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf(
        "ADDR=0x%08h WRITE=%0d WDATA=0x%08h RDATA=0x%08h RESPONSE=%0d ERROR=%0d",
        addr,
        write,
        wdata,
        rdata,
        response,
        error
    );
  endfunction

endclass
`endif
