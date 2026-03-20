string TESTCASE;
string INPUT_CSV_PATH;
string OUTPUT_CSV_PATH;
string GOLDEN_CSV_PATH;

localparam string DEFAULT_TESTCASE   = "scenario_001";
localparam string DEFAULT_INPUT_CSV  = "../../../../verification/playback/agc/input/scenario_001_input.csv";
localparam string DEFAULT_OUTPUT_CSV = "../../../../verification/playback/agc/output/scenario_001_hw.csv";
localparam string DEFAULT_GOLDEN_CSV = "../../../../verification/playback/agc/golden/scenario_001_golden.csv";

localparam int CLK_FREQ_HZ          = 100_000_000;
localparam int AUDIO_SAMPLE_RATE_HZ = 48_000;
localparam int AUDIO_SAMPLE_CLKS    = CLK_FREQ_HZ / AUDIO_SAMPLE_RATE_HZ;
localparam int AUDIO_SAMPLE_REM_CLKS= CLK_FREQ_HZ % AUDIO_SAMPLE_RATE_HZ;
localparam int BAUD_RATE            = 115_200;
localparam int BAUD_DIV             = CLK_FREQ_HZ / BAUD_RATE;
localparam int UART_BITS_PER_BYTE   = 10;
localparam int UART_BYTES_PER_FRAME = 9;
localparam int UART_FRAME_CLKS      = BAUD_DIV * UART_BITS_PER_BYTE * UART_BYTES_PER_FRAME;
localparam int UART_STARTUP_CLKS    = 100;
localparam int FRAME_INTERVAL_CLKS  = 321_880;
localparam int UART_WAIT_FRAMES     = 1;
// uart_tx_model と同じ条件で、最初の1フレーム送信完了まで待つ
localparam int UART_PREROLL_CLKS    =
    UART_STARTUP_CLKS + (UART_WAIT_FRAMES * FRAME_INTERVAL_CLKS) + UART_FRAME_CLKS;
localparam int POST_FLUSH_CYCLES    = 20_000;
