#!/usr/bin/env python3
"""Time the commands an interactive session waits on.

Three scenarios, each chosen because a person or an agent notices it:

  version       nothing but process start. Every tab completion pays it.
  capabilities  what an agent asks first, every session.
  plan          parse, validate and build the whole file plan — the work the
                interactive preview redoes after every edit.

Reports p50 and p95 over N runs, after discarding warm-up runs: the first
execution of a freshly built binary pays for page-faulting it in, which is a
real cost exactly once and not the one being measured here.

Run against a release build; a debug binary measures the compiler's choices
rather than the program's.

    Scripts/benchmark.py                    # builds release, then measures
    Scripts/benchmark.py --runs 100
    Scripts/benchmark.py --binary path/to/xscaffold
"""

import argparse
import pathlib
import statistics
import subprocess
import sys
import tempfile
import time

WARMUP = 3


def build_release() -> str:
    subprocess.run(["swift", "build", "-c", "release"], check=True)
    path = subprocess.run(
        ["swift", "build", "-c", "release", "--show-bin-path"],
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    return str(pathlib.Path(path) / "xscaffold")


def time_once(command: list[str]) -> float:
    """Wall-clock milliseconds for one run, including process start.

    Wall clock rather than CPU time: what a user waits for includes the dynamic
    linker and everything else between the shell's fork and the first byte of
    output.
    """
    start = time.perf_counter()
    result = subprocess.run(command, capture_output=True)
    elapsed = (time.perf_counter() - start) * 1000

    if result.returncode != 0:
        sys.exit(
            f"{' '.join(command)} exited {result.returncode}:\n"
            f"{result.stderr.decode(errors='replace')}"
        )
    return elapsed


def measure(name: str, command: list[str], runs: int) -> tuple[str, float, float]:
    for _ in range(WARMUP):
        time_once(command)

    samples = sorted(time_once(command) for _ in range(runs))
    p50 = statistics.median(samples)
    # Nearest-rank, so the reported number is a run that actually happened.
    p95 = samples[min(len(samples) - 1, int(len(samples) * 0.95))]
    return name, p50, p95


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=int, default=50)
    parser.add_argument("--binary", help="Skip the release build and measure this binary.")
    arguments = parser.parse_args()

    binary = arguments.binary or build_release()

    with tempfile.TemporaryDirectory() as directory:
        # The heaviest configuration this version can describe, so `plan` is
        # measured against the most files it would ever have to work out.
        manifest = pathlib.Path(directory) / "scaffold.yml"
        manifest.write_text(subprocess.run(
            [binary, "config", "example", "--preset", "production"],
            check=True, capture_output=True, text=True,
        ).stdout)

        scenarios = [
            ("version", [binary, "--version"]),
            ("capabilities", [binary, "capabilities", "--output", "json"]),
            ("plan (production)", [
                binary, "plan", "--config", str(manifest), "--output", "json",
            ]),
        ]
        results = [measure(name, command, arguments.runs) for name, command in scenarios]

    print(f"{binary}, {arguments.runs} runs each, {WARMUP} discarded\n")
    print(f"{'scenario':<20} {'p50 (ms)':>10} {'p95 (ms)':>10}")
    for name, p50, p95 in results:
        print(f"{name:<20} {p50:>10.1f} {p95:>10.1f}")


if __name__ == "__main__":
    main()
