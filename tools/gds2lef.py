#!/usr/bin/env python3
"""
Generate a simple LEF for a macro from its GDS bounding box.

Usage:
  python tools/gds2lef.py <input.gds> <output.lef> [--scale SCALE] [--margin MARGIN] [--layer LAYER] [--name NAME]

Notes:
- SCALE multiplies GDS units to micrometers (default 0.001).
- MARGIN is added (in micrometers) around the bounding box.
- Requires 'gdstk' or 'gdspy' to be installed.
"""

import argparse
import os
import sys
from math import isfinite


def write_lef(path: str, name: str, width: float, height: float, layer_name: str = "M1"):
    lef_lines = [
        "VERSION 5.7 ;",
        "NOWIREEXTENSIONATPIN ON ;",
        'DIVIDERCHAR "/" ;',
        'BUSBITCHARS "[]" ;',
        f"MACRO {name}",
        "  CLASS BLOCK ;",
        f"  FOREIGN {name} ;",
        "  ORIGIN 0.000 0.000 ;",
        f"  SIZE {width:.3f} BY {height:.3f} ;",
        "  OBS",
        f"      LAYER {layer_name} ;",
        f"        RECT 0.000 0.000 {width:.3f} {height:.3f} ;",
        "  END",
        f"END {name}",
        "END LIBRARY",
    ]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(lef_lines) + "\n")


def compute_bbox_gdstk(path):
    import gdstk
    lib = gdstk.read_gds(path)
    minx = float("inf")
    miny = float("inf")
    maxx = float("-inf")
    maxy = float("-inf")
    for cell in lib.cells:
        bbox = cell.bounding_box()
        if not bbox:
            continue
        (xmin, ymin), (xmax, ymax) = bbox
        minx = min(minx, xmin)
        miny = min(miny, ymin)
        maxx = max(maxx, xmax)
        maxy = max(maxy, ymax)
    if minx == float("inf"):
        return None
    return minx, miny, maxx, maxy


def compute_bbox_gdspy(path):
    import gdspy
    lib = gdspy.GdsLibrary(infile=path)
    minx = float("inf")
    miny = float("inf")
    maxx = float("-inf")
    maxy = float("-inf")
    for cell in lib.cells.values():
        bbox = cell.get_bounding_box()
        if bbox is None:
            continue
        (xmin, ymin), (xmax, ymax) = bbox
        minx = min(minx, xmin)
        miny = min(miny, ymin)
        maxx = max(maxx, xmax)
        maxy = max(maxy, ymax)
    if minx == float("inf"):
        return None
    return minx, miny, maxx, maxy


def compute_bbox(path):
    # prefer gdstk, fall back to gdspy
    try:
        return compute_bbox_gdstk(path)
    except Exception:
        try:
            return compute_bbox_gdspy(path)
        except Exception as e:
            raise RuntimeError("No GDS library available (gdstk/gdspy) or failed to read GDS") from e


def main():
    parser = argparse.ArgumentParser(description="Generate LEF from a GDS bounding box")
    parser.add_argument("gds", help="Input GDS file")
    parser.add_argument("lef", help="Output LEF file")
    parser.add_argument("--scale", type=float, default=0.001, help="Scale to convert GDS units to micrometers (default 0.001)")
    parser.add_argument("--margin", type=float, default=0.0, help="Margin (um) to add around bounding box")
    parser.add_argument("--layer", default="M1", help="Layer name to declare in OBS")
    parser.add_argument("--name", default=None, help="Macro name to use (defaults to GDS basename)")
    args = parser.parse_args()

    gds_file = args.gds
    lef_file = args.lef
    name = args.name or os.path.splitext(os.path.basename(gds_file))[0]

    width = 1000.0
    height = 1000.0
    try:
        bbox = compute_bbox(gds_file)
        if bbox:
            xmin, ymin, xmax, ymax = bbox
            # convert to micrometers
            width = (xmax - xmin) * args.scale
            height = (ymax - ymin) * args.scale
            if args.margin:
                width += 2*args.margin
                height += 2*args.margin
            # ensure positive
            if not (isfinite(width) and width > 0 and isfinite(height) and height > 0):
                width = 1000.0
                height = 1000.0
    except Exception as exc:
        print(f"Warning: failed to compute bounding box ({exc}), using defaults 1000x1000 um", file=sys.stderr)
        width = 1000.0
        height = 1000.0

    write_lef(lef_file, name, width, height, layer_name=args.layer)
    print(f"Wrote LEF {lef_file} (width={width:.3f}um, height={height:.3f}um)")


if __name__ == "__main__":
    main()
