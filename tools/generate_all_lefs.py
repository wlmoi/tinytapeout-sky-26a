#!/usr/bin/env python3
"""
Scan for GDS files in `projects/` and `gds/` and generate LEF files next to each project (and optionally copy to tt_top/lef).

Usage:
  python tools/generate_all_lefs.py [--scale SCALE] [--margin MARGIN] [--layer LAYER] [--copy-to-tt]

This script calls `tools/gds2lef.py` for each found GDS file and writes the corresponding LEF.
"""

import glob
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def ensure_lef_for_gds(gds_path, scale, margin, layer):
    p = Path(gds_path)
    parts = p.parts
    try:
        proj_index = parts.index('projects')
    except ValueError:
        proj_index = None

    if proj_index is not None and len(parts) > proj_index + 1:
        # projects/<project>/... -> place LEF in projects/<project>/lef/
        proj_dir = Path(*parts[:proj_index+2])
        lef_dir = proj_dir / 'lef'
    else:
        # top-level gds -> place lef in tt-multiplexer/ol2/tt_top/lef
        lef_dir = ROOT / 'tt-multiplexer' / 'ol2' / 'tt_top' / 'lef'

    lef_dir.mkdir(parents=True, exist_ok=True)
    lef_file = lef_dir / f"{p.stem}.lef"

    cmd = [
        sys.executable,
        str(ROOT / 'tools' / 'gds2lef.py'),
        str(gds_path),
        str(lef_file),
        '--scale', str(scale),
        '--margin', str(margin),
        '--layer', layer,
    ]

    print('Running:', ' '.join(cmd))
    r = subprocess.run(cmd)
    return r.returncode == 0


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--scale', type=float, default=0.001)
    parser.add_argument('--margin', type=float, default=0.0)
    parser.add_argument('--layer', default='M1')
    parser.add_argument('--copy-to-tt', action='store_true')
    args = parser.parse_args()

    patterns = [
        str(ROOT / 'projects' / '**' / '*.gds'),
        str(ROOT / 'gds' / '*.gds'),
    ]

    found = set()
    for pat in patterns:
        for p in glob.glob(pat, recursive=True):
            found.add(os.path.normpath(p))

    if not found:
        print('No GDS files found')
        return 1

    ok = True
    for g in sorted(found):
        print('Generating LEF for:', g)
        if not ensure_lef_for_gds(g, args.scale, args.margin, args.layer):
            print('Failed for', g)
            ok = False

    if args.copy_to_tt:
        tt_lef_dir = ROOT / 'tt-multiplexer' / 'ol2' / 'tt_top' / 'lef'
        tt_lef_dir.mkdir(parents=True, exist_ok=True)
        for p in (ROOT / 'projects').glob('*/lef/*.lef'):
            shutil.copy2(p, tt_lef_dir / p.name)
            print('Copied', p, '->', tt_lef_dir / p.name)

    return 0 if ok else 2


if __name__ == '__main__':
    raise SystemExit(main())
