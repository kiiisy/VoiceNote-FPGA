`timescale 1ns/1ps

package csv_pkg;
    import "DPI-C" context function void csv_init(input string path);
    import "DPI-C" function int csv_next_sample_q15(output shortint sample);
    import "DPI-C" function void csv_output_init(input string out_path, input string golden_path);
    import "DPI-C" function void csv_output_write_q15(input shortint sample_q15);
    import "DPI-C" function void csv_output_close(output int max_abs_diff, output int mismatch_cnt);
endpackage
