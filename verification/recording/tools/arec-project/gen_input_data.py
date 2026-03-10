#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def emit_csv(path: Path, samples: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(str(v) for v in samples) + "\n", encoding="utf-8")


def repeat(value: int, n: int) -> list[int]:
    return [value] * n


def build_scenario_001() -> list[int]:
    # PASS only: always under threshold (0x300=768)
    return repeat(120, 3000)


def build_scenario_002() -> list[int]:
    # DUMP+IRQ: quiet -> loud section -> quiet
    return repeat(80, 1200) + repeat(1200, 600) + repeat(100, 1200)


def build_scenario_003() -> list[int]:
    # Boundary around threshold: below / near / above
    # Default threshold is 768 in current register setup.
    return (
        repeat(760, 256)
        + repeat(767, 128)
        + repeat(768, 128)
        + repeat(769, 256)
        + repeat(760, 512)
    )


def build_scenario_004() -> list[int]:
    # Re-arm: two loud blocks separated by a quiet gap
    return repeat(100, 900) + repeat(1200, 500) + repeat(100, 900) + repeat(1200, 500) + repeat(100, 600)


def build_scenario_005() -> list[int]:
    # No trigger: low-level pseudo-noise under threshold
    out: list[int] = []
    seq = [120, 160, 220, 180, 140, 200, 240, 190]
    for i in range(3000):
        out.append(seq[i % len(seq)])
    return out


def build_scenario_006(window_size: int) -> list[int]:
    # Window-edge check: only last sample of each window goes high.
    out: list[int] = []
    cycles = 40
    for _ in range(cycles):
        out.extend(repeat(100, window_size - 1))
        out.append(1200)
    out.extend(repeat(100, 400))
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate AREC input CSVs.")
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path("input"),
        help="Output directory for generated CSV files.",
    )
    parser.add_argument(
        "--window-size",
        type=int,
        default=64,
        help="Window size for scenario_006 (default: 64).",
    )
    args = parser.parse_args()

    scenarios = {
        "scenario_001_input.csv": build_scenario_001(),
        "scenario_002_input.csv": build_scenario_002(),
        "scenario_003_input.csv": build_scenario_003(),
        "scenario_004_input.csv": build_scenario_004(),
        "scenario_005_input.csv": build_scenario_005(),
        "scenario_006_input.csv": build_scenario_006(args.window_size),
    }

    for name, data in scenarios.items():
        path = args.out_dir / name
        emit_csv(path, data)
        print(f"generated: {path} ({len(data)} samples)")


if __name__ == "__main__":
    main()

