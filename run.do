# ==========================================
# Default Compile/Run Switches
# ==========================================

set comp_opts ""
set run_opts ""

# ==========================================
# Test Specific Switches (Use the below method if any tests have comp or run options)
# ==========================================

if {$testname == "gmii_eth_normal_frame_test"} {

    #set comp_opts "+define+HALF_DUPLEX"
    #set run_opts "+NO_OF_PKTS=200"

}  elseif {$testname == "gmii_eth_jumbo_frame_test"} {

    #set comp_opts "+define+JUMBO_EN"
    #set run_opts "+NO_OF_PKTS=200"

}


# ==========================================
# Valid Tests
# ==========================================
transcript quietly
set valid_tests {
    gmii_eth_normal_frame_test
    gmii_eth_jumbo_frame_test
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
# Compile and checks whether compile is passed or not
# ==========================================

set comp_status [catch {

    eval vlog -work work -sv \
    ./top/eth_gmii_interface.sv \
    ./top/eth_ui_interface.sv \
    ./top/eth_top.sv \
    $comp_opts \
    -l $complog

} comp_result]

if {$comp_status != 0} {

    puts ""
    puts "Compile Log : [file normalize $complog]"
    
    puts "\033\[31m"
    puts "================================="
    puts "     COMPILATION FAILED"
    puts "================================="
    puts "\033\[0m"
    
    quit -f
}

set fp [open $complog a]

puts $fp ""
puts $fp "================================="
puts $fp "COMPILE PASSED"
puts $fp "Time : [clock format [clock seconds]]"
puts $fp "================================="


close $fp
# ==========================================
# Simulation
# ==========================================
eval vsim -debugDB -voptargs=+acc work.eth_top +UVM_TESTNAME=$testname +UVM_VERBOSITY=UVM_LOW $run_opts -l $logfile -qwavedb=+wavefile=$qwavefile -sv_seed $seed
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
    puts "Wave File : [file normalize $qwavefile]"
    puts ""

} else {

    puts ""
    puts "Log File  : [file normalize $logfile]"
    puts "Wave File : [file normalize $qwavefile]"
    puts ""
    
    puts "\033\[32m"
    puts "================================="
    puts "         TEST PASSED"
    puts "================================="
    puts "\033\[0m"

} 
quit -f

# Run Command: 		  vsim -c -do "set testname gmii_eth_normal_frame_test; do run.do"
# Run Command with Seed:  vsim -c -do "set testname gmii_eth_normal_frame_test; set seed 123; do run.do"

