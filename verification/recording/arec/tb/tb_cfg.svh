string TESTCASE;
string INPUT_CSV_PATH;
string OUTPUT_CSV_PATH;
string GOLDEN_CSV_PATH;

localparam string DEFAULT_TESTCASE      = "scenario_001";
localparam string DEFAULT_INPUT_CSV     = "../../../../verification/recording/arec/input/scenario_001_input.csv";
localparam string DEFAULT_OUTPUT_CSV    = "../../../../verification/recording/arec/output/scenario_001_hw.csv";
localparam string DEFAULT_GOLDEN_CSV    = "../../../../verification/recording/arec/golden/scenario_001_golden.csv";
localparam int    PASS_FLUSH_CYCLES     = 2000;
localparam int    AREC_PASS_TIMEOUT_CYCLES = 10000000;
localparam int    AREC_PASS_POLL_CYCLES = 50;
localparam int    IRQ_TIMEOUT_CYCLES    = 10000000;
localparam int    NO_DUMP_OBS_CYCLES    = 50000;
