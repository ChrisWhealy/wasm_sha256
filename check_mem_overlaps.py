#!/usr/bin/env python3
import re
import subprocess
import sys
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

SEG_RX_WITH_MEM = re.compile(
    r"segment\[(\d+)\][^\n]*?memory=(\d+)[^\n]*?size=(\d+)[^\n]*?init\s+([^\n]+)"
)
SEG_RX_NO_MEM = re.compile(
    r"segment\[(\d+)\][^\n]*?size=(\d+)[^\n]*?init\s+([^\n]+)"
)
GLOB_RX = re.compile(r"global\[(\d+)\][^\n]*?i32[^\n]*?init\s+i32=(\d+)")

@dataclass
class Segment:
    index: int
    memory: int
    size: int
    init_expr: str
    offset: Optional[int]
    start: Optional[int]
    end: Optional[int]

def run_objdump(path: str) -> str:
    try:
        return subprocess.check_output(
            ["wasm-objdump", "-x", path], stderr=subprocess.STDOUT
        ).decode("utf-8", errors="replace")
    except FileNotFoundError:
        sys.exit("Error: wasm-objdump not found in PATH. Install WABT (wabt.dev).")
    except subprocess.CalledProcessError as e:
        sys.exit(f"wasm-objdump failed:\n{e.output.decode('utf-8', errors='replace')}")

def parse_globals(text: str) -> Dict[int, int]:
    g: Dict[int, int] = {}
    for m in GLOB_RX.finditer(text):
        g[int(m.group(1))] = int(m.group(2))
    return g

def resolve_init(expr: str, globals_map: Dict[int, int]) -> Optional[int]:
    s = expr.strip().replace(" ", "")
    m = re.search(r"i32=(\d+)$", s)
    if m: return int(m.group(1))
    m = re.fullmatch(r"global\[(\d+)\]\+(\d+)", s)
    if m: return globals_map.get(int(m.group(1)), None) + int(m.group(2)) if int(m.group(1)) in globals_map else None
    m = re.fullmatch(r"(\d+)\+global\[(\d+)\]", s)
    if m: return globals_map.get(int(m.group(2)), None) + int(m.group(1)) if int(m.group(2)) in globals_map else None
    m = re.fullmatch(r"global\[(\d+)\]", s)
    if m: return globals_map.get(int(m.group(1)))
    m = re.fullmatch(r"i32=(\d+)\+global\[(\d+)\]", s)
    if m: return int(m.group(1)) + globals_map.get(int(m.group(2)), 0)
    return None

def parse_segments(text: str, globals_map: Dict[int, int]) -> List[Segment]:
    segs: List[Segment] = []

    # First, capture segments that explicitly show "memory="
    seen_idx = set()
    for m in SEG_RX_WITH_MEM.finditer(text):
        idx = int(m.group(1))
        mem = int(m.group(2))
        size = int(m.group(3))
        init_expr = m.group(4).strip()
        off = resolve_init(init_expr, globals_map)
        segs.append(
            Segment(idx, mem, size, init_expr, off, off, off + size - 1 if off is not None else None)
        )
        seen_idx.add(idx)

    # Then capture segments without "memory=", but SKIP any index we already saw.
    for m in SEG_RX_NO_MEM.finditer(text):
        idx = int(m.group(1))
        if idx in seen_idx:
            continue  # avoid duplicate (same segment matched both regexes)
        size = int(m.group(2))
        init_expr = m.group(3).strip()
        off = resolve_init(init_expr, globals_map)
        segs.append(
            Segment(idx, 0, size, init_expr, off, off, off + size - 1 if off is not None else None)
        )

    # Sort for stable output: by memory, then start (unknowns last), then index
    segs.sort(key=lambda s: (s.memory, float('inf') if s.start is None else s.start, s.index))
    return segs

def find_overlaps(segs: List[Segment]) -> List[Tuple[Segment, Segment]]:
    overlaps = []
    by_mem: Dict[int, List[Segment]] = {}
    for s in segs:
        if s.offset is not None:
            by_mem.setdefault(s.memory, []).append(s)
    for mem, lst in by_mem.items():
        lst.sort(key=lambda s: (s.start, s.end))
        for i in range(len(lst)):
            for j in range(i+1, len(lst)):
                a, b = lst[i], lst[j]
                if a.end < b.start: break
                if not (a.end < b.start or b.end < a.start):
                    overlaps.append((a, b))
    return overlaps

def ascii_range_chart(segments: List[Segment], width: int = 80):
    segs = [s for s in segments if s.offset is not None]
    if not segs:
        print("(no resolved segments to draw)")
        return
    min_addr = min(s.start for s in segs)
    max_addr = max(s.end for s in segs)
    span = max_addr - min_addr + 1
    scale = span / width if span > width else 1
    print(f"\n== ASCII memory map (addresses {min_addr}..{max_addr}) ==")
    for s in segs:
        rel_start = int((s.start - min_addr) / scale)
        rel_end   = int((s.end   - min_addr) / scale)
        bar = " " * rel_start + "#" * max(1, rel_end - rel_start + 1)
        print(f"segment[{s.index}] mem={s.memory} [{s.start}..{s.end}]".ljust(50) + "|" + bar)

def main():
    if len(sys.argv) != 2:
        print("Usage: python check_wasm_overlaps.py <module.wasm>")
        sys.exit(1)
    path = sys.argv[1]
    text = run_objdump(path)
    globals_map = parse_globals(text)
    segs = parse_segments(text, globals_map)

    print("== Globals ==")
    for g, v in globals_map.items():
        print(f"  global[{g}] = {v}")
    if not globals_map:
        print("  (none)")

    print("\n== Segments ==")
    for s in segs:
        if s.offset is not None:
            print(f"  segment[{s.index}] mem={s.memory} size={s.size} offset={s.offset} range=[{s.start}..{s.end}] init='{s.init_expr}'")
        else:
            print(f"  segment[{s.index}] mem={s.memory} size={s.size} offset=? init='{s.init_expr}' (unresolved)")

    overlaps = find_overlaps(segs)
    if overlaps:
        print("\n== OVERLAPS ==")
        for a, b in overlaps:
            print(f"  mem={a.memory}: segment[{a.index}] [{a.start}..{a.end}] overlaps segment[{b.index}] [{b.start}..{b.end}]")
    else:
        print("\nNo overlaps among resolved segments.")

    ascii_range_chart(segs)

if __name__ == "__main__":
    main()
