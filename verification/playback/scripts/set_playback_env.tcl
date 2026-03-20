# set_playback_env.tcl
#
# usage:
#   source verification/playback/scripts/set_playback_env.tcl
#   playback_run_id 1
#   playback_run_all

namespace eval playback_test {
    variable simset_name playback_sim
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
        set repo_root [file normalize [file join $script_dir ..]]
        set input_csv  [file join $repo_root agc input  scenario_001_input.csv]
        set output_csv [file join $repo_root agc output scenario_001_hw.csv]
        set golden_csv [file join $repo_root agc golden scenario_001_golden.csv]
    }

    proc _set_csv_paths_by_scenario {scenario_id} {
        variable repo_root
        variable input_csv
        variable output_csv
        variable golden_csv

        set sid [format "%03d" $scenario_id]
        set input_csv  [file join $repo_root agc input  [format "scenario_%s_input.csv"  $sid]]
        set output_csv [file join $repo_root agc output [format "scenario_%s_hw.csv"     $sid]]
        set golden_csv [file join $repo_root agc golden [format "scenario_%s_golden.csv" $sid]]
    }

    proc _get_simset {} {
        variable simset_name
        if {[llength [get_filesets -quiet $simset_name]] > 0} {
            return $simset_name
        }
        if {[llength [get_filesets -quiet sim_1]] > 0} {
            return sim_1
        }
        error "No simulation fileset found (tried: $simset_name, sim_1)"
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
        puts [format {[PLAYBACK] set plusargs: %s} $opts]
        set_property -dict [list xsim.simulate.xsim.more_options $opts] $fs
    }

    proc _set_top {} {
        set fs [get_filesets [_get_simset]]
        set top_name "tb_agc_top"
        puts [format {[PLAYBACK] set top: %s} $top_name]
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
        puts [format {[PLAYBACK] done scenario=%s} $scenario_id]
    }

    proc run_all {} {
        run_id 1
        run_id 2
        run_id 3
        run_id 4
        run_id 5
        puts {[PLAYBACK] all scenarios done}
    }
}

proc playback_run_id {scenario_id} {
    playback_test::run_id $scenario_id
}

proc playback_run_all {} {
    playback_test::run_all
}

playback_test::_init_paths

puts {[PLAYBACK] loaded: set_playback_env.tcl}
puts {[PLAYBACK] use: playback_run_id <SCENARIO_ID>}
puts {[PLAYBACK] use: playback_run_all}
