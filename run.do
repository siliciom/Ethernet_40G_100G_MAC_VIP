# ==========================================
# Default Compile/Run Switches
# ==========================================

set comp_opts ""
set run_opts ""

# ==========================================
# Test Specific Switches
# ==========================================

if {$testname == "eth_normal_frame_test"} {

    #set comp_opts ""
}


# ==========================================
# Valid Tests
# ==========================================
transcript quietly
set valid_tests {
    eth_normal_frame_test
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

# ==========================================
# Library
# ==========================================

vlib work
vmap work work

# ==========================================
# Compile
# ==========================================

eval vlog -work work -sv \
./top/eth_interface.sv \
./top/eth_ui_interface.sv \
./top/eth_top.sv \
$comp_opts

# ==========================================
# Log/Wave files
# ==========================================
file mkdir sim/$testname
set logfile "./sim/$testname/${testname}.log"
set wavefile "./sim/$testname/${testname}.wlf"
set qwavefile "./sim/$testname/qwave.db"

# ==========================================
# Simulation
# ==========================================

eval vsim -debugDB -voptargs=+acc work.eth_top +UVM_TESTNAME=$testname +UVM_VERBOSITY=UVM_LOW $run_opts -l $logfile -qwavedb=+wavefile=$qwavefile
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

