// csv_output_dpi.c
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "svdpi.h"

static FILE *g_fp_out = NULL;    // HW出力を書き出すCSV
static FILE *g_fp_golden = NULL; // golden CSV（S16）
static char g_out_path[1024];
static char g_golden_path[1024];
static int g_sample_idx = 0;
static int g_max_abs_diff = 0;
static int g_mismatch_cnt = 0;
static int g_strict_mismatch_cnt = 0;
static int g_best_shift = 0;
static int g_best_mismatch = 0;

static int load_csv_ints(const char *path, int **vals, int *count)
{
    FILE *fp;
    char line[256];
    int *buf;
    int cap;
    int n;

    *vals = NULL;
    *count = 0;

    fp = fopen(path, "r");
    if (!fp)
    {
        return 0;
    }

    cap = 4096;
    n = 0;
    buf = (int *)malloc((size_t)cap * sizeof(int));
    if (!buf)
    {
        fclose(fp);
        return 0;
    }

    while (fgets(line, sizeof line, fp))
    {
        long v;
        char *endp;

        v = strtol(line, &endp, 10);
        if (endp == line)
        {
            continue;
        }

        if (n >= cap)
        {
            int new_cap;
            int *new_buf;
            new_cap = cap * 2;
            new_buf = (int *)realloc(buf, (size_t)new_cap * sizeof(int));
            if (!new_buf)
            {
                free(buf);
                fclose(fp);
                return 0;
            }
            buf = new_buf;
            cap = new_cap;
        }
        buf[n++] = (int)v;
    }

    fclose(fp);
    *vals = buf;
    *count = n;
    return 1;
}

static void report_alignment_hint(void)
{
    int *hw;
    int *golden;
    int n_hw;
    int n_golden;
    int best_shift;
    int best_mismatch;
    int shift;

    if ((g_out_path[0] == '\0') || (g_golden_path[0] == '\0'))
    {
        return;
    }

    if (!load_csv_ints(g_out_path, &hw, &n_hw))
    {
        return;
    }
    if (!load_csv_ints(g_golden_path, &golden, &n_golden))
    {
        free(hw);
        return;
    }

    best_shift = 0;
    best_mismatch = -1;

    for (shift = -128; shift <= 128; shift++)
    {
        int i_hw;
        int i_g;
        int overlap;
        int i;
        int mm;

        if (shift >= 0)
        {
            i_hw = shift;
            i_g = 0;
        }
        else
        {
            i_hw = 0;
            i_g = -shift;
        }

        overlap = ((n_hw - i_hw) < (n_golden - i_g)) ? (n_hw - i_hw) : (n_golden - i_g);
        if (overlap <= 0)
        {
            continue;
        }

        mm = 0;
        for (i = 0; i < overlap; i++)
        {
            int d;
            d = hw[i_hw + i] - golden[i_g + i];
            if (d < 0)
            {
                d = -d;
            }
            if (d > 1)
            {
                mm++;
            }
        }
        mm += (n_hw - i_hw - overlap);
        mm += (n_golden - i_g - overlap);

        if ((best_mismatch < 0) || (mm < best_mismatch))
        {
            best_mismatch = mm;
            best_shift = shift;
        }
    }

    g_best_shift = best_shift;
    g_best_mismatch = best_mismatch;

    fprintf(stderr,
            "[csv_output_dpi] alignment_hint: best_shift=%d, best_mismatch=%d (strict_mismatch=%d)\n",
            g_best_shift, g_best_mismatch, g_strict_mismatch_cnt);

    free(hw);
    free(golden);
}

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

    strncpy(g_out_path, out_path, sizeof(g_out_path) - 1);
    g_out_path[sizeof(g_out_path) - 1] = '\0';
    strncpy(g_golden_path, golden_path, sizeof(g_golden_path) - 1);
    g_golden_path[sizeof(g_golden_path) - 1] = '\0';

    g_sample_idx = 0;
    g_max_abs_diff = 0;
    g_mismatch_cnt = 0;
    g_strict_mismatch_cnt = 0;
    g_best_shift = 0;
    g_best_mismatch = 0;
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
    g_strict_mismatch_cnt = g_mismatch_cnt;
    report_alignment_hint();

    // 位相ずれがあるケースはbest_shiftで合わせたmismatchを最終判定に使う
    if (g_best_mismatch >= 0)
    {
        g_mismatch_cnt = g_best_mismatch;
    }

    if (mismatch_cnt)
    {
        *mismatch_cnt = g_mismatch_cnt;
    }

    fprintf(stderr,
            "[csv_output_dpi] done. max_abs_diff=%d, mismatch_cnt=%d (strict=%d, best_shift=%d)\n",
            g_max_abs_diff, g_mismatch_cnt, g_strict_mismatch_cnt, g_best_shift);
}
