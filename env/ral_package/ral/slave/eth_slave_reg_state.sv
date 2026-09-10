`ifndef ETH_SLAVE_REG_STATE_SV
`define ETH_SLAVE_REG_STATE_SV

class eth_slave_reg_state extends uvm_component;

  `uvm_component_utils(eth_slave_reg_state)

  bit [31:0] reg_mem[bit [31:0]];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void reset();
    reg_mem.delete();
  endfunction

  function bit is_valid_addr(bit [31:0] addr);
    case (addr)
      'h0000, 'h0004, 'h0008, 'h000C,
      'h0010, 'h0014, 'h0018, 'h001C,
      'h0020, 'h0024, 'h0028, 'h002C,
      'h0030, 'h0034, 'h0038, 'h003C,
      'h0040, 'h0044, 'h0048, 'h004C,
      'h0050, 'h0054, 'h0058, 'h005C,
      'h0060:
      return 1;
      default: return 0;
    endcase
  endfunction

  function void write(bit [31:0] addr, bit [31:0] data);
    if (is_valid_addr(addr)) reg_mem[addr] = data;
  endfunction

  function bit [31:0] read(bit [31:0] addr);
    if (!is_valid_addr(addr)) return 32'hXXXX_XXXX;

    if (reg_mem.exists(addr)) return reg_mem[addr];

    return 32'h0000_0000;
  endfunction

endclass

`endif
