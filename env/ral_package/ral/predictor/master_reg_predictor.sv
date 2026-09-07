`ifndef MASTER_REG_PREDICTOR_SV
`define MASTER_REG_PREDICTOR_SV

import uvm_pkg::*;
import reg_agent_pkg::*;

class master_reg_predictor extends uvm_reg_predictor #(reg_seq_item);

  `uvm_component_utils(master_reg_predictor)

  function new(string name = "master_reg_predictor", uvm_component parent = null);

    super.new(name, parent);

  endfunction

endclass

`endif
