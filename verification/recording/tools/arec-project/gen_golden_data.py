#!/usr/bin/env python3
from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

DEPTH = 2048
DEFAULT_INPUT_DIR = Path("input")
DEFAULT_GOLDEN_DIR = Path("golden")

def parse_int_auto_base(text: str) -> int:
    # accepts decimal (e.g. 768) and base-prefixed values (e.g. 0x300)
    return int(text, 0)

@dataclass
class Beat:
    sample: int
    tid: int  # 0:L, 1:R


@dataclass
class ArecCfg:
    enable: bool
    threshold: int
    window_shift: int
    required_windows: int
    pretrig_samples: int


def read_input_csv(path: Path) -> list[int]:
    vals: list[int] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s:
            continue
        vals.append(int(s))
    return vals


def write_output_csv(path: Path, values: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(str(v) for v in values) + ("\n" if values else ""), encoding="utf-8")


def clamp_dump_len(raw: int) -> int:
    if raw <= 0:
        raw = 1
    if raw > DEPTH:
        raw = DEPTH
    # keep even beats (L/R pair)
    if raw & 1:
        return 2 if raw == 1 else raw - 1
    return raw


def abs16(v: int) -> int:
    # mimic 16-bit signed abs with -32768 saturation to 32767
    if v < 0:
        return 32767 if v == -32768 else -v
    return v


def expand_to_beats(mono: list[int]) -> list[Beat]:
    out: list[Beat] = []
    for s in mono:
        out.append(Beat(sample=s, tid=0))
        out.append(Beat(sample=s, tid=1))
    return out


def select_left_channel(out_beats: list[Beat]) -> list[int]:
    # tb monitor writes one sample per 2 transactions (starts from first beat)
    out: list[int] = []
    ch_idx = 0
    for b in out_beats:
        if ch_idx == 0:
            out.append(b.sample)
        ch_idx ^= 1
    return out


def simulate_arec(beats: list[Beat], cfg: ArecCfg) -> list[Beat]:
    # state
    S_PASS = 0
    S_ARMED = 1
    S_DUMP = 2

    state = S_PASS
    rearm_block = False
    trigger_flag = False
    triggered_latched = False

    # detector
    sum_abs = 0
    window_cnt = 0
    consec_cnt = 0
    is_threshold_over = False
    window_size = 1 << cfg.window_shift
    window_last = window_size - 1
    need_windows = max(1, cfg.required_windows)

    # ring buffer
    ring: list[Beat] = [Beat(sample=0, tid=0) for _ in range(DEPTH)]
    wr_ptr = 0
    armed_sample_cnt = 0
    dump_len = clamp_dump_len(cfg.pretrig_samples)

    # dump
    dump_start_ptr = 0
    dump_rem = 0
    dump_idx = 0

    out_beats: list[Beat] = []

    i = 0
    n = len(beats)
    while i < n:
        b = beats[i]

        # control enable behavior by scenario
        enable = cfg.enable

        # enter ARMED from PASS
        if state == S_PASS and enable and not rearm_block:
            state = S_ARMED

        if state == S_PASS:
            out_beats.append(b)
            i += 1
            continue

        if state == S_ARMED:
            # accept + write ring
            ring[wr_ptr] = b
            wr_ptr = (wr_ptr + 1) % DEPTH

            # pretrigger counter
            if armed_sample_cnt < dump_len:
                armed_sample_cnt += 1
            pretrig_ready = armed_sample_cnt >= dump_len

            # detector update
            abs_s = abs16(b.sample)
            window_done = (window_cnt == window_last)
            mean_now = (sum_abs + abs_s) >> cfg.window_shift
            threshold_over = mean_now >= cfg.threshold

            if window_done:
                sum_abs = 0
                window_cnt = 0
                is_threshold_over = threshold_over
                consec_cnt = (consec_cnt + 1) if is_threshold_over else 0
                trigger_hit = is_threshold_over and (consec_cnt >= need_windows)
            else:
                sum_abs += abs_s
                window_cnt += 1
                trigger_hit = False

            if trigger_hit:
                triggered_latched = True
                trigger_flag = True

            dump_start_ok = (b.tid == 1)
            dump_start = pretrig_ready and trigger_flag and dump_start_ok
            if dump_start:
                # start_ptr uses current wr_ptr (next write pointer)
                start_ptr = (wr_ptr - dump_len) % DEPTH
                if start_ptr & 1:
                    start_ptr = (start_ptr + 1) % DEPTH
                dump_start_ptr = start_ptr
                dump_rem = dump_len
                dump_idx = 0
                state = S_DUMP
                trigger_flag = False
            i += 1
            continue

        # state == S_DUMP
        if dump_rem > 0:
            out_b = ring[(dump_start_ptr + dump_idx) % DEPTH]
            out_beats.append(out_b)
            dump_idx += 1
            dump_rem -= 1
        if dump_rem == 0:
            state = S_PASS
            rearm_block = True
        # while DUMP, input side is back-pressured (do not consume input beat)
        continue

    # optional: if dump started near EOF, flush remaining dump
    while state == S_DUMP and dump_rem > 0:
        out_b = ring[(dump_start_ptr + dump_idx) % DEPTH]
        out_beats.append(out_b)
        dump_idx += 1
        dump_rem -= 1
    return out_beats


def cfg_for_scenario(name: str) -> ArecCfg:
    # matches current TB setup intent
    if name == "scenario_001":
        return ArecCfg(enable=False, threshold=0x300, window_shift=6, required_windows=2, pretrig_samples=512)
    if name == "scenario_002":
        return ArecCfg(enable=True, threshold=0x300, window_shift=6, required_windows=2, pretrig_samples=512)
    if name == "scenario_003":
        return ArecCfg(enable=True, threshold=0x300, window_shift=6, required_windows=2, pretrig_samples=512)
    if name == "scenario_004":
        return ArecCfg(enable=True, threshold=0x300, window_shift=6, required_windows=2, pretrig_samples=512)
    if name == "scenario_005":
        return ArecCfg(enable=True, threshold=0x7FFF, window_shift=6, required_windows=2, pretrig_samples=512)
    raise ValueError(f"unknown scenario: {name}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate expected output CSV for AREC scenario.")
    parser.add_argument("--scenario", required=True, help="scenario_001 ... scenario_005")
    parser.add_argument("--input-csv", type=Path, default=None, help="Input mono CSV (optional)")
    parser.add_argument("--output-csv", type=Path, default=None, help="Expected output CSV (optional)")
    parser.add_argument("--input-dir", type=Path, default=DEFAULT_INPUT_DIR, help="Input directory for auto naming")
    parser.add_argument("--golden-dir", type=Path, default=DEFAULT_GOLDEN_DIR, help="Golden output directory for auto naming")
    parser.add_argument("--pretrig", type=parse_int_auto_base, default=None, help="Override pretrigger samples")
    parser.add_argument("--threshold", type=parse_int_auto_base, default=None, help="Override threshold")
    parser.add_argument("--window-shift", type=parse_int_auto_base, default=None, help="Override window shift")
    parser.add_argument("--required-windows", type=parse_int_auto_base, default=None, help="Override required windows")
    args = parser.parse_args()

    cfg = cfg_for_scenario(args.scenario)
    if args.pretrig is not None:
        cfg.pretrig_samples = args.pretrig
    if args.threshold is not None:
        cfg.threshold = args.threshold
    if args.window_shift is not None:
        cfg.window_shift = args.window_shift
    if args.required_windows is not None:
        cfg.required_windows = args.required_windows

    if args.input_csv is None:
        input_csv = args.input_dir / f"{args.scenario}_input.csv"
    else:
        input_csv = args.input_csv

    if args.output_csv is None:
        output_csv = args.golden_dir / f"{args.scenario}_golden.csv"
    else:
        output_csv = args.output_csv

    mono = read_input_csv(input_csv)
    beats = expand_to_beats(mono)
    out_beats = simulate_arec(beats, cfg)
    out_left = select_left_channel(out_beats)
    write_output_csv(output_csv, out_left)

    print(f"scenario={args.scenario}")
    print(f"input_csv={input_csv}")
    print(f"input_samples={len(mono)} output_samples={len(out_left)}")
    print(f"written: {output_csv}")


if __name__ == "__main__":
    main()
