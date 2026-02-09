// csv_input_dpi.c
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <limits.h>
#include "svdpi.h"

static FILE *g_fp = NULL;

void csv_init(const char *path)
{
    if (g_fp)
    {
        fclose(g_fp);
        g_fp = NULL;
    }
    g_fp = fopen(path, "r");
    if (!g_fp)
    {
        fprintf(stderr, "[csv_input_dpi] failed to open %s\n", path);
    }
}

// 1 サンプル取得: 戻り値 1=OK, 0=EOF or error
int csv_next_sample_q15(short *out)
{
    if (!g_fp)
    {
        return 0;
    }

    char line[256];
    if (!fgets(line, sizeof line, g_fp))
    {
        return 0; // EOF
    }

    long v = strtol(line, NULL, 10); // 10進整数として読む

    if (v > 32767)
    {
        v = 32767;
    }
    if (v < -32768)
    {
        v = -32768;
    }

    *out = (short)v;
    return 1;
}
