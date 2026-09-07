#========================================================
#                    REGRESSION SCRIPT
#========================================================


#========================================================
# CLEAN WORK LIBRARY
#========================================================

if {[file exists work]} {
    vdel -all
}

catch {file delete -force work}
vlib work


#========================================================
# To pass Regression Name from the Command Line
#========================================================

if {![info exists regression_name]} {
    set regression_name "default_regression"
}


#========================================================
# COVERAGE ENABLE / DISABLE
#========================================================

if {![info exists enable_cov]} {
    set enable_cov 0
}


#========================================================
# TEST LIST
#========================================================

set test_list {

   eth_normal_frame_test
   eth_min_size_frame_test
   eth_max_size_frame_test
   eth_error_detection_test
   eth_bad_fcs_test
   eth_normal_payload_padding_test
   eth_single_vlan_tag_frame_test
   eth_vlan_payload_padding_test
   eth_double_vlan_tag_frame_test
   eth_double_vlan_payload_padding_test
   eth_unicast_frame_test
   eth_broadcast_frame_test
   eth_multicast_frame_test
   eth_runt_frame_test
   eth_fragment_frame_test
   eth_oversize_frame_test
   eth_jabber_frame_test
   eth_preamble_corruption_test
   eth_len_payload_mismatch_test 
   eth_invalid_control_character_test
   eth_start_character_in_between_payload_err_test
   eth_end_character_in_between_payload_err_test
   eth_missing_terminate_character_test
   eth_control_char_data_mismatch_test
   eth_local_and_remote_fault_test
   eth_pause_frame_basic_xoff_xon_test
   eth_pause_frame_with_updated_pause_time
   eth_simultaneous_pause_frame_test
   eth_pause_reserved_opcode_test
   eth_pause_frame_during_vlan_traffic_test
   eth_pfc_frame_test
   eth_pfc_with_random_priority_quanta_expiry_test
   eth_pfc_simultaneous_operation_test
   eth_xoff_xon_back_to_back_pfc_test
   eth_pfc_independent_timer_overlap_test
   eth_consec_multiple_same_pfc_xoff_imd_xon_test
   eth_consec_multiple_diff_pfc_xoff_imd_xon_test
   eth_pfc_multiple_priority_xoff_test
   eth_mac2_mac3_addr_cov_test
    }


#========================================================
# PASS / FAIL CHECK
#========================================================

proc check_result {logfile testname} {

    #----------------------------------------------------
    # Check whether log exists
    #----------------------------------------------------

    if {![file exists $logfile]} {

        puts ""
        puts "########################################"
        puts "FAILED : $testname"
        puts "REASON : Log file not found"
        puts "########################################"
        puts ""

        return "FAIL"
    }


    #----------------------------------------------------
    # Read complete log file
    #----------------------------------------------------

    set fh [open $logfile r]
    set content [read $fh]
    close $fh


    #----------------------------------------------------
    # Initialize counters
    #----------------------------------------------------

    set error_count 0
    set fatal_count 0

    set error_found 0
    set fatal_found 0


    #----------------------------------------------------
    # Extract UVM_ERROR from UVM Report Summary
    #
    # Handles:
    #   UVM_ERROR : 8000
    #   # UVM_ERROR : 8000
    #   UVM_ERROR: 8000
    #----------------------------------------------------

    if {[regexp -line {^\s*#?\s*UVM_ERROR\s*:\s*([0-9]+)\s*$} \
        $content -> error_count]} {

        set error_found 1
        puts "DEBUG : UVM_ERROR count = $error_count"

    } else {

        puts "DEBUG : UVM_ERROR count not found"
    }


    #----------------------------------------------------
    # Extract UVM_FATAL from UVM Report Summary
    #----------------------------------------------------

    if {[regexp -line {^\s*#?\s*UVM_FATAL\s*:\s*([0-9]+)\s*$} \
        $content -> fatal_count]} {

        set fatal_found 1
        puts "DEBUG : UVM_FATAL count = $fatal_count"

    } else {

        puts "DEBUG : UVM_FATAL count not found"
    }


    #----------------------------------------------------
    # UVM Report Summary must exist
    #
    # If either UVM_ERROR or UVM_FATAL count cannot be
    # found, do NOT assume zero. Mark the test FAILED.
    #----------------------------------------------------

    if {!$error_found || !$fatal_found} {

        puts ""
        puts "########################################"
        puts "FAILED : $testname"
        puts "REASON : UVM Report Summary not found"
        puts "UVM_ERROR_FOUND : $error_found"
        puts "UVM_FATAL_FOUND : $fatal_found"
        puts "########################################"
        puts ""

        return "FAIL"
    }


    #----------------------------------------------------
    # Print result information
    #----------------------------------------------------

    puts ""
    puts "----------------------------------------"
    puts "TEST             : $testname"
    puts "UVM_ERROR COUNT  : $error_count"
    puts "UVM_FATAL COUNT  : $fatal_count"
    puts "----------------------------------------"


    #----------------------------------------------------
    # FAIL if UVM_ERROR > 0
    # FAIL if UVM_FATAL > 0
    #----------------------------------------------------

    if {$error_count > 0 || $fatal_count > 0} {

        puts ""
        puts "****************************************"
        puts "FAILED : $testname"
        puts "UVM_ERROR = $error_count"
        puts "UVM_FATAL = $fatal_count"
        puts "****************************************"
        puts ""

        return "FAIL"
    }


    #----------------------------------------------------
    # PASS
    #----------------------------------------------------

    puts ""
    puts "****************************************"
    puts "PASSED : $testname"
    puts "UVM_ERROR = $error_count"
    puts "UVM_FATAL = $fatal_count"
    puts "****************************************"
    puts ""

    return "PASS"
}


#========================================================
# REGRESSION LOOP
#========================================================

set pass_count 0
set fail_count 0
set fail_list {}

set last_comp_opts "__NONE__"


foreach testname $test_list {


    #====================================================
    # SEED HANDLING
    #====================================================

    set seed [expr {int(rand()*1000000)}]


    #====================================================
    # DEFAULT COMPILE / RUN OPTIONS
    #====================================================

    set comp_opts ""
    set run_opts ""


    #====================================================
    # TEST SPECIFIC COMPILE OPTIONS
    #====================================================

    if {$testname == "eth_normal_frame_test"} {

        set comp_opts ""

    } elseif {$testname == "eth_multicast_frame_test"} {

        set comp_opts "+define+NO_OF_AGENTS=4"

    } elseif {$testname == "eth_jabber_frame_test"} {

        set comp_opts "+define+JUMBO_EN"

    } elseif {$testname == "eth_broadcast_frame_test"} {

        set comp_opts "+define+NO_OF_AGENTS=4"
    } elseif {$testname == "eth_mac2_mac3_addr_cov_test"} {

        set comp_opts "+define+NO_OF_AGENTS=4"
    }


    #====================================================
    # PRINT TEST INFORMATION
    #====================================================

    puts ""
    puts "======================================="
    puts "TEST      : $testname"
    puts "COMP_OPTS : $comp_opts"
    puts "RUN_OPTS  : $run_opts"
    puts "SEED      : $seed"
    puts "======================================="
    puts ""

    echo "======================================="
    echo "RUNNING TEST : $testname"
    echo "======================================="


    #====================================================
    # DIRECTORY CREATION
    #====================================================

    set test_dir "./Regression/$regression_name/$testname"

    file mkdir $test_dir

    set logfile  "$test_dir/run.log"
    set complog  "$test_dir/comp.log"
    set wavefile "$test_dir/${testname}.wlf"


    #====================================================
    # COVERAGE DIRECTORY
    #====================================================

    if {$enable_cov} {

        set cov_dir "./coverage_reports/$regression_name"

        file mkdir $cov_dir

        set ucdb_file "$cov_dir/$testname.ucdb"
    }


    #====================================================
    # COMPILE
    #
    # Recompile only when compile options change.
    #====================================================

    if {$comp_opts ne $last_comp_opts} {

        puts ""
        puts "================================="
        puts "COMPILING"
        puts "TEST      : $testname"
        puts "COMP_OPTS : <$comp_opts>"
        puts "================================="
        puts ""


        #------------------------------------------------
        # Coverage compile options
        #------------------------------------------------

        if {$enable_cov} {

            set cov_compile_opts "-cover bsectf +fcover"

        } else {

            set cov_compile_opts ""
        }


        #------------------------------------------------
        # Redirect compilation transcript
        #------------------------------------------------

        transcript file $complog


        #------------------------------------------------
        # Compile
        #------------------------------------------------

        set comp_status [catch {

            eval vlog -work work \
                $cov_compile_opts \
                -sv \
                -incr \
                env/reg_agent/reg_agent_pkg.sv \
                env/ral_package/ral/ral_pkg.sv \
                top/eth_interface.sv \
                top/eth_ui_interface.sv \
                top/eth_top.sv \
                $comp_opts

        } comp_result]


        #------------------------------------------------
        # Stop transcript
        #------------------------------------------------

        transcript file ""


        #------------------------------------------------
        # Check compilation status
        #------------------------------------------------

        if {$comp_status != 0} {

            puts ""
            puts "########################################"
            puts "COMPILE FAILED : $testname"
            puts "########################################"
            puts ""

            puts $comp_result

            incr fail_count
            lappend fail_list $testname

            continue
        }


        puts ""
        puts "COMPILE PASSED : $testname"
        puts ""

        set last_comp_opts $comp_opts

    } else {

        puts ""
        puts "================================="
        puts "SKIPPING COMPILE"
        puts "TEST      : $testname"
        puts "COMP_OPTS : <$comp_opts>"
        puts "================================="
        puts ""
    }


    #====================================================
    # SIMULATION COMMAND
    #
    # Waveform is always recorded.
    # add log records signals.
    # add wave records signals into the WLF.
    #====================================================

    if {$enable_cov} {

        set sim_cov_opts "-coverage -cvgperinstance"
        set voptargs     "+acc -cover bsectf"

        set do_cmd \
            "add log -r /eth_top/*; add wave -r /eth_top/*; run -all; coverage save $ucdb_file; quit -f"

    } else {

        set sim_cov_opts ""
        set voptargs     "+acc"
        set do_cmd \
            "add log -r /eth_top/*; add wave -r /eth_top/*; run -all; quit -f"
    }


    #====================================================
    # SIMULATION
    #====================================================

    puts ""
    puts "======================================="
    puts "STARTING SIMULATION"
    puts "TEST     : $testname"
    puts "SEED     : $seed"
    puts "WAVE     : $wavefile"
    puts "======================================="
    puts ""


    set sim_status [catch {

        exec vsim -c \
            {*}$sim_cov_opts \
            -debugDB \
            -voptargs=$voptargs \
            -onfinish stop \
            work.eth_top \
            +UVM_VERBOSITY=UVM_NONE \
            +UVM_TESTNAME=$testname \
            -l $logfile \
            -wlf $wavefile \
            -sv_seed $seed \
            $run_opts \
            -do "$do_cmd"

    } sim_result]


    #====================================================
    # CHECK SIMULATION / ELABORATION STATUS
    #====================================================

    if {$sim_status != 0} {

        puts ""
        puts "########################################"
        puts "ELAB / SIM FAILED : $testname"
        puts "########################################"
        puts ""

        puts $sim_result

        incr fail_count
        lappend fail_list $testname

        continue
    }


    #====================================================
    # CHECK UVM PASS / FAIL
    #====================================================

    puts ""
    puts "======================================="
    puts "CHECKING UVM RESULT"
    puts "TEST : $testname"
    puts "======================================="
    puts ""

    set result [check_result $logfile $testname]


    #====================================================
    # UPDATE REGRESSION COUNTERS
    #====================================================

    if {$result == "PASS"} {

        incr pass_count

    } else {

        incr fail_count
        lappend fail_list $testname
    }


    echo "COMPLETED : $testname"
}


#========================================================
# SHOW GENERATED UCDB FILES
#========================================================

if {$enable_cov} {

    echo ""
    echo "======================================="
    echo "GENERATED COVERAGE FILES"
    echo "======================================="


    set ucdb_files [glob -nocomplain \
        "./coverage_reports/$regression_name/*.ucdb"]


    if {[llength $ucdb_files] == 0} {

        echo "NO UCDB FILES FOUND"

    } else {

        foreach f $ucdb_files {
            echo $f
        }
    }
}


#========================================================
# MERGE COVERAGE
#========================================================

if {$enable_cov} {

    echo ""
    echo "======================================="
    echo "MERGING COVERAGE DATABASES"
    echo "======================================="
    echo ""


    set all_ucdb_files [glob -nocomplain \
        "./coverage_reports/$regression_name/*.ucdb"]


    #----------------------------------------------------
    # Remove merged_coverage.ucdb from input list
    #----------------------------------------------------

    set input_ucdb_files {}

    foreach f $all_ucdb_files {

        if {[file tail $f] ne "merged_coverage.ucdb"} {

            lappend input_ucdb_files $f
        }
    }


    if {[llength $input_ucdb_files] == 0} {

        echo "NO UCDB FILES TO MERGE"

    } else {

        set merged_ucdb \
            "./coverage_reports/$regression_name/merged_coverage.ucdb"


        #------------------------------------------------
        # Remove old merged database before rebuilding
        #------------------------------------------------

        if {[file exists $merged_ucdb]} {
            file delete -force $merged_ucdb
        }


        puts "Input UCDB count : [llength $input_ucdb_files]"
        puts "Merging coverage files..."


        # Tcl list expansion is required.
        vcover merge \
            $merged_ucdb \
            {*}$input_ucdb_files


        if {[file exists $merged_ucdb]} {

            puts "Coverage merge completed."
            puts "Merged UCDB : [file normalize $merged_ucdb]"

        } else {

            puts "ERROR : Coverage merge failed."
        }
    }
}


#========================================================
# GENERATE COVERAGE REPORT
#========================================================

if {$enable_cov} {

    echo ""
    echo "======================================="
    echo "GENERATING COVERAGE REPORT"
    echo "======================================="
    echo ""


    set merged_ucdb \
        "./coverage_reports/$regression_name/merged_coverage.ucdb"


    set html_dir \
        "./covhtmlreport/$regression_name/html"


    file mkdir $html_dir


    if {[file exists $merged_ucdb]} {

        # QuestaSim 10.7c uses -htmldir, not -output.
        vcover report \
            -details \
            -html \
            -htmldir $html_dir \
            $merged_ucdb


        puts ""
        puts "Coverage HTML report generated."
        puts "HTML directory : [file normalize $html_dir]"
        puts ""

    } else {

        puts "NO MERGED UCDB FOUND"
        puts "Coverage report was not generated."
    }
}


#========================================================
# FINAL REGRESSION SUMMARY
#========================================================

echo ""
echo "======================================="
echo "        REGRESSION SUMMARY"
echo "======================================="

echo "TOTAL  TESTS : [llength $test_list]"
echo "PASSED TESTS : $pass_count"
echo "FAILED TESTS : $fail_count"

echo "======================================="


#========================================================
# PRINT FAILED TESTS
#========================================================

if {$fail_count > 0} {

    echo ""
    echo "FAILED TESTCASES:"
    echo ""

    foreach ft $fail_list {
        echo "   $ft"
    }

} else {

    echo ""
    echo "ALL TESTS PASSED"
}


echo "======================================="
echo "REGRESSION COMPLETED"
echo "======================================="


#========================================================
# EXIT
#========================================================

quit -f


#======================================================================================================
# REGRESSION RUN COMMANDS
#======================================================================================================

# Normal regression:
# vsim -c -do .\regression.do

# Regression with regression name:
# vsim -c -do "set regression_name march_regr; do regression.do"

# Regression with coverage:
# vsim -c -do "set regression_name regr_cov1; set enable_cov 1; do regression.do"


#======================================================================================================
# LOG PATH
#======================================================================================================

# Regression logs:
# Regression/regression_name/test_name/run.log

# Compilation logs:
# Regression/regression_name/test_name/comp.log

# Waveform:
# Regression/regression_name/test_name/test_name.wlf


#======================================================================================================
# COVERAGE PATH
#======================================================================================================

# Single coverage:
# coverage_reports/regression_name/test_name.ucdb

# Merged coverage:
# coverage_reports/regression_name/merged_coverage.ucdb

# HTML coverage:
# covhtmlreport/regression_name/html

#======================================================================================================

