#!/usr/bin/env python3
import argparse
from pathlib import Path

def main() -> int:
    p = argparse.ArgumentParser(
        description="Rewrite a file as valid UTF-8, replacing invalid byte sequences."
    )
    p.add_argument("input", help="Input file path")
    p.add_argument("output", help="Output file path")
    args = p.parse_args()

    inp = Path(args.input)
    out = Path(args.output)

    b = inp.read_bytes()
    out.write_text(b.decode("utf-8", "replace"), encoding="utf-8", newline="")
    print(f"wrote {out}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
