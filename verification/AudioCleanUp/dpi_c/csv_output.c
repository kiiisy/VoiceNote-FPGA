// csv_output_dpi.c
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "svdpi.h"

static FILE *g_fp_out = NULL;    // HW出力を書き出すCSV
static FILE *g_fp_golden = NULL; // golden CSV（S16）
static int g_sample_idx = 0;
static int g_max_abs_diff = 0;
static int g_mismatch_cnt = 0;

void csv_output_init(const char *out_path, const char *golden_path)
{
    if (g_fp_out)
    {
        fclose(g_fp_out);
        g_fp_out = NULL;
    }
    if (g_fp_golden)
    {
        fclose(g_fp_golden);
        g_fp_golden = NULL;
    }

    g_fp_out = fopen(out_path, "w");
    if (!g_fp_out)
    {
        fprintf(stderr, "[csv_output_dpi] failed to open out: %s\n", out_path);
    }

    g_fp_golden = fopen(golden_path, "r");
    if (!g_fp_golden)
    {
        fprintf(stderr, "[csv_output_dpi] failed to open golden: %s\n", golden_path);
    }

    g_sample_idx = 0;
    g_max_abs_diff = 0;
    g_mismatch_cnt = 0;
}

// 1 サンプル分を書き出し＋golden と比較
// sample_hw : HW からの S16 (Q15)
void csv_output_write_q15(short sample_hw)
{
    // 出力 CSV へ書き出し（デバッグ用）
    if (g_fp_out)
    {
        fprintf(g_fp_out, "%d\n", (int)sample_hw);
    }

    // golden と比較
    if (g_fp_golden)
    {
        char line[256];
        if (fgets(line, sizeof line, g_fp_golden))
        {
            long sample_golden = strtol(line, NULL, 10);

            int diff = (int)sample_hw - (int)sample_golden;
            int ad = (diff >= 0) ? diff : -diff;

            if (ad > g_max_abs_diff)
            {
                g_max_abs_diff = ad;
            }

            // 許容誤差 ±1 LSB 以内 → OK
            if (ad > 1)
            {
                g_mismatch_cnt++;
            }
        }
        else
        {
            // golden 側が先に EOF になった
            g_mismatch_cnt++;
        }
    }

    g_sample_idx++;
}

// 終了処理: ファイルを閉じて結果を返す
void csv_output_close(int *max_abs_diff, int *mismatch_cnt)
{
    if (g_fp_out)
    {
        fclose(g_fp_out);
        g_fp_out = NULL;
    }
    if (g_fp_golden)
    {
        fclose(g_fp_golden);
        g_fp_golden = NULL;
    }

    if (max_abs_diff)
    {
        *max_abs_diff = g_max_abs_diff;
    }
    if (mismatch_cnt)
    {
        *mismatch_cnt = g_mismatch_cnt;
    }

    fprintf(stderr,
            "[csv_output_dpi] done. max_abs_diff=%d, mismatch_cnt=%d\n",
            g_max_abs_diff, g_mismatch_cnt);
}
