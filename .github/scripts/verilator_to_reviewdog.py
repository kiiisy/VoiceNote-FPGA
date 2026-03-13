#!/usr/bin/env python3
import re
import sys

# Verilator main diagnostics examples:
# %Error: path/to/file.sv:12:5: message
# %Warning-DECLFILENAME: path/to/file.sv:1:8: message
#
# We convert them into:
# path/to/file.sv:12:5: error: message
# path/to/file.sv:1:8: warning [DECLFILENAME]: message
#
# reviewdog then reads them with:
#   -efm="%f:%l:%c: %m"

pat = re.compile(
    r"^%(Error|Warning)(?:-([A-Z0-9_]+))?:\s+([^:]+):(\d+):(?:(\d+):)?\s*(.*)$"
)

for raw in sys.stdin:
    line = raw.rstrip("\n")
    m = pat.match(line)
    if not m:
        continue

    sev, code, path, lno, col, msg = m.groups()
    sev = sev.lower()
    col = col or "1"

    if code:
        msg = f"{sev} [{code}]: {msg}"
    else:
        msg = f"{sev}: {msg}"

    print(f"{path}:{lno}:{col}: {msg}")
