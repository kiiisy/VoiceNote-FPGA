# set_arec_env.tcl
#
# 使い方:
#   source verification/recording/scripts/set_arec_env.tcl
#   arec_run_id 1
#   arec_run_all

namespace eval arec_test {
    variable simset_name recording_sim
    variable repo_root
    variable input_csv
    variable output_csv
    variable golden_csv

    proc _init_paths {} {
        variable repo_root
        variable input_csv
        variable output_csv
        variable golden_csv
        set script_dir [file dirname [info script]]
        # scriptsの1つ上(verification/recording)を基準にする
        set repo_root [file normalize [file join $script_dir ..]]
        set input_csv  [file join $repo_root arec input  scenario_001_input.csv]
        set output_csv [file join $repo_root arec output scenario_001_hw.csv]
        set golden_csv [file join $repo_root arec golden scenario_001_golden.csv]
    }

    proc _set_csv_paths_by_scenario {scenario_id} {
        variable repo_root
        variable input_csv
        variable output_csv
        variable golden_csv

        set sid [format "%03d" $scenario_id]
        set input_csv  [file join $repo_root arec input  [format "scenario_%s_input.csv"  $sid]]
        set output_csv [file join $repo_root arec output [format "scenario_%s_hw.csv"     $sid]]
        set golden_csv [file join $repo_root arec golden [format "scenario_%s_golden.csv" $sid]]
    }

    proc _get_simset {} {
        variable simset_name
        if {[llength [get_filesets -quiet $simset_name]] > 0} {
            return $simset_name
        }
        if {[llength [get_filesets -quiet recording_sim]] > 0} {
            return recording_sim
        }
        error "No simulation fileset found (tried: $simset_name, recording_sim)"
    }

    proc _set_plusargs {scenario_id} {
        variable input_csv
        variable output_csv
        variable golden_csv
        set fs [get_filesets [_get_simset]]
        set opts "-testplusarg SCENARIO_ID=$scenario_id"
        append opts " -testplusarg INPUT_CSV=$input_csv"
        append opts " -testplusarg OUTPUT_CSV=$output_csv"
        append opts " -testplusarg GOLDEN_CSV=$golden_csv"
        puts [format {[AREC] set plusargs: %s} $opts]
        set_property -dict [list xsim.simulate.xsim.more_options $opts] $fs
    }

    proc _set_top {} {
        set fs [get_filesets [_get_simset]]
        set top_name "tb_top"
        puts [format {[AREC] set top: %s} $top_name]
        set_property top $top_name $fs
    }

    proc _run_once {} {
        catch {close_sim -force}
        launch_simulation
        run all
        catch {wait_on_run [current_run -simset]}
        catch {close_sim -force}
    }

    proc run_id {scenario_id} {
        if {![string is integer -strict $scenario_id]} {
            error "scenario_id must be integer"
        }
        _set_csv_paths_by_scenario $scenario_id
        _set_top
        _set_plusargs $scenario_id
        _run_once
        puts [format {[AREC] done scenario=%s} $scenario_id]
    }

    proc run_all {} {
        run_id 1
        run_id 2
        run_id 3
        run_id 4
        run_id 5
        puts {[AREC] all scenarios done}
    }
}

# public commands
proc arec_run_id {scenario_id} {
    arec_test::run_id $scenario_id
}

proc arec_run_all {} {
    arec_test::run_all
}

arec_test::_init_paths

puts {[AREC] loaded: run_arec_tests.tcl}
puts {[AREC] use: arec_run_id <SCENARIO_ID>}
puts {[AREC] use: arec_run_all}
