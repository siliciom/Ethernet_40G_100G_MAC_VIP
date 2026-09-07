# ==========================================
# Default Compile/Run Switches
# ==========================================

set comp_opts ""
set run_opts ""

# ==========================================
# Test Specific Switches
# ==========================================

if {$testname == "eth_normal_frame_test"} {
 
    set comp_opts ""
} elseif {$testname == "eth_multicast_frame_test"} {
 
    set comp_opts "+define+NO_OF_AGENTS=4"
 
 
}  elseif {$testname == "eth_jabber_frame_test"} {
 
    set comp_opts "+define+JUMBO_EN"
 
} elseif {$testname == "eth_broadcast_frame_test"} {
 
    set comp_opts "+define+NO_OF_AGENTS=4"

} elseif {$testname == "eth_mac2_mac3_addr_cov_test"} {

        set comp_opts "+define+NO_OF_AGENTS=4"
    }



# ==========================================
# Valid Tests
# ==========================================
transcript quietly
set valid_tests {
    eth_normal_frame_test
    eth_reg_test
    eth_min_size_frame_test
    eth_max_size_frame_test
    eth_error_detection_test
    eth_bad_fcs_test
    eth_normal_payload_padding_test
    eth_single_vlan_tag_frame_test
    eth_vlan_payload_padding_test
    eth_runt_frame_test
    eth_fragment_frame_test
    eth_jabber_frame_test
    eth_multicast_frame_test
    eth_preamble_corruption_test
    eth_double_vlan_tag_frame_test
    eth_unicast_frame_test
    eth_broadcast_frame_test
    eth_double_vlan_payload_padding_test
    eth_len_payload_mismatch_test
    eth_oversize_frame_test
    eth_invalid_control_character_test
    eth_start_character_in_between_payload_err_test
    eth_end_character_in_between_payload_err_test
    eth_missing_terminate_character_test
    eth_control_char_data_mismatch_test
    eth_pause_frame_basic_xoff_xon_test
    eth_simultaneous_pause_frame_test
    eth_pause_frame_during_vlan_traffic_test
    eth_pause_frame_with_updated_pause_time
    eth_pause_reserved_opcode_test
    eth_pfc_frame_test
    eth_pfc_with_random_priority_quanta_expiry_test
    eth_pfc_simultaneous_operation_test
    eth_pfc_independent_timer_overlap_test
    eth_xoff_xon_back_to_back_pfc_test
    eth_pfc_multiple_priority_xoff_test
    eth_consec_multiple_same_pfc_xoff_imd_xon_test
    eth_consec_multiple_diff_pfc_xoff_imd_xon_test     
    eth_local_and_remote_fault_test
    eth_mac2_mac3_addr_cov_test
ral_smoke_test
}
# ==========================================
# Check whether test is valid
# ==========================================

if {[lsearch $valid_tests $testname] == -1} {

 

    puts "\033\[31m"

 

    puts ""
    puts "================================="
    puts "ERROR : INVALID TESTNAME"
    puts "================================="
    puts ""

 

    puts "Given Test : $testname"
    puts ""

 

    puts "\033\[0m"

 

    quit -f
}
# ==========================================
# Print Switches
# ==========================================

puts ""
puts "================================="
puts "Running Test      : $testname"
puts "Compile Switches : $comp_opts"
puts "Run Switches     : $run_opts"
puts "================================="

#=========================================
# Seed Handling
#=========================================
if {![info exists seed]} {
    set seed [expr {int(rand()*1000000)}]
}


# ==========================================
# Log/Wave files
# ==========================================
#file mkdir sim/$testname
#set complog "./sim/$testname/comp.log"
#set logfile "./sim/$testname/${testname}.log"
#set qwavefile "./sim/$testname/qwave.db"
#set wavefile "./sim/$testname/${testname}.wlf"
# ==========================================
# Log/Wave files
# ==========================================
file mkdir sim/$testname/seed_$seed
set complog "./sim/$testname/seed_$seed/comp.log"
set logfile "./sim/$testname/seed_$seed/${testname}.log"
set qwavefile "./sim/$testname/seed_$seed/qwave.db"
set wavefile "./sim/$testname/seed_$seed/${testname}.wlf"

puts "================================="
puts "Seed : $seed"
puts "================================="

# ==========================================
# Library
# ==========================================

vlib work
vmap work work

# ==========================================
# Compile
# ==========================================

eval vlog -work work -sv \
-f ./env/ral_package/ral/ral.f \
./env/ral_package/ral/ral_pkg.sv \
./env/reg_agent/reg_agent_pkg.sv \
./top/eth_interface.sv \
./top/eth_ui_interface.sv \
./top/eth_top.sv \
$comp_opts

eval vlog -work work -sv \
./top/eth_interface.sv \
./top/eth_ui_interface.sv \
./env/reg_agent/reg_agent_pkg.sv \
-f ./env/ral_package/ral/ral.f \
./top/eth_top.sv \
$comp_opts


## ==========================================
## Log/Wave files
## ==========================================
#file mkdir sim/$testname
#set logfile "./sim/$testname/${testname}.log"
#set wavefile "./sim/$testname/${testname}.wlf"
#set qwavefile "./sim/$testname/qwave.db"

# ==========================================
# Simulation
# ==========================================

eval vsim -debugDB -voptargs=+acc work.eth_top +UVM_TESTNAME=$testname +UVM_VERBOSITY=UVM_LOW $run_opts -l $logfile -wlf $wavefile
# ==========================================
# Logging
# ==========================================

add log -r /eth_top/*
add wave -r /eth_top/*

# ==========================================
# Prevent auto exit
# ==========================================

onfinish stop

# ==========================================
# Run Simulation
# ==========================================

run -all

after 1000

# ==========================================
# Read logfile
# ==========================================

set fp [open $logfile r]
set log_data [read $fp]
close $fp

# ==========================================
# PASS / FAIL
# ==========================================

if {[regexp {UVM_ERROR :\s+[1-9]} $log_data] || \
    [regexp {UVM_FATAL :\s+[1-9]} $log_data]} {

    puts "\033\[31m"
    puts "================================="
    puts "         TEST FAILED"
    puts "================================="
    puts "\033\[0m"

    puts ""
    puts "Log File  : [file normalize $logfile]"
    puts "Wave File : [file normalize $wavefile]"
    puts ""

} else {

    puts "\033\[32m"
    puts "================================="
    puts "         TEST PASSED"
    puts "================================="
    puts "\033\[0m"

    puts ""
    puts "Log File  : [file normalize $logfile]"
    puts "Wave File : [file normalize $wavefile]"
    puts ""
} 
quit -f



