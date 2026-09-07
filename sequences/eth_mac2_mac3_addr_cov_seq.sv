//******************************************************************//
//               ETHERNET VLAN PAYLOAD PADDING SEQUENCE
//
// Generates VLAN-tagged Ethernet frames with payload sizes smaller
// than the minimum for VLAN frames (42 bytes) to verify automatic
// padding insertion. VLAN frames add 4 bytes of tag, so payload
// must be at least 42 bytes (46 - 4 = 42).
//******************************************************************//

class eth_mac2_mac3_addr_cov_seq extends base_seq;

  `uvm_object_utils(eth_mac2_mac3_addr_cov_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_mac2_mac3_addr_cov_seq");
    super.new(name);
  endfunction

  task body();

    repeat (no_of_pkts) begin

      //============================================================
      // MAC2 -> MAC3
      //============================================================
      req = eth_seq_item::type_id::create("req_mac2_to_mac3");

      start_item(req);
      randomise_item();
      req.custom_da    = 1;
      req.da           = 48'h005343332313; // MAC3
      finish_item(req);

      //============================================================
      // MAC3 -> MAC2
      //============================================================
      req = eth_seq_item::type_id::create("req_mac3_to_mac2");
      start_item(req);
      randomise_item();
      req.custom_da    = 1;
      req.da           = 48'h005242322212; // MAC2

      finish_item(req);

    end

  endtask

endclass

