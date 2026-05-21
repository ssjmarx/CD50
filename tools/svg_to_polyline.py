#!/usr/bin/env python3
"""Convert SVG path data to Godot PackedVector2Array constants.
Parses the Godot monochrome logo SVG and outputs GDScript-ready polyline arrays.
"""
import re
import math
import sys

# ── SVG Path Parser ──────────────────────────────────────────────

def tokenize_path(d: str) -> list:
    """Split SVG path string into commands and numbers."""
    # Split on command letters, keeping them
    tokens = re.findall(r'[MmCcLlHhVvSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', d)
    return tokens

def parse_numbers(tokens: list, pos: int, count: int) -> tuple:
    """Parse `count` numbers from token list starting at pos."""
    nums = []
    i = pos
    while len(nums) < count and i < len(tokens):
        try:
            nums.append(float(tokens[i]))
            i += 1
        except ValueError:
            break
    return nums, i

def parse_path(d: str) -> list:
    """Parse SVG path into list of subpaths, each a list of (x,y) points.
    Returns list of subpaths (list of (float, float))."""
    tokens = tokenize_path(d)
    subpaths = []
    current_path = []
    cx, cy = 0.0, 0.0  # current position
    sx, sy = 0.0, 0.0  # subpath start
    i = 0
    
    BEZIER_SEGMENTS = 12  # segments per cubic bezier
    
    while i < len(tokens):
        cmd = tokens[i]
        i += 1
        
        if cmd == 'M':  # absolute moveTo
            nums, i = parse_numbers(tokens, i, 2)
            if nums:
                cx, cy = nums[0], nums[1]
                sx, sy = cx, cy
                current_path = [(cx, cy)]
                # Remaining pairs are implicit lineTo
                while i < len(tokens):
                    nums, i = parse_numbers(tokens, i, 2)
                    if len(nums) == 2:
                        cx, cy = nums[0], nums[1]
                        current_path.append((cx, cy))
                    else:
                        break
        elif cmd == 'm':  # relative moveTo
            nums, i = parse_numbers(tokens, i, 2)
            if nums:
                cx += nums[0]
                cy += nums[1]
                sx, sy = cx, cy
                current_path = [(cx, cy)]
                # Remaining pairs are implicit relative lineTo
                while i < len(tokens):
                    nums, i = parse_numbers(tokens, i, 2)
                    if len(nums) == 2:
                        cx += nums[0]
                        cy += nums[1]
                        current_path.append((cx, cy))
                    else:
                        break
        elif cmd == 'L':  # absolute lineTo
            while i < len(tokens):
                nums, i = parse_numbers(tokens, i, 2)
                if len(nums) == 2:
                    cx, cy = nums[0], nums[1]
                    current_path.append((cx, cy))
                else:
                    break
        elif cmd == 'l':  # relative lineTo
            while i < len(tokens):
                nums, i = parse_numbers(tokens, i, 2)
                if len(nums) == 2:
                    cx += nums[0]
                    cy += nums[1]
                    current_path.append((cx, cy))
                else:
                    break
        elif cmd == 'H':  # absolute horizontal
            while i < len(tokens):
                nums, i = parse_numbers(tokens, i, 1)
                if nums:
                    cx = nums[0]
                    current_path.append((cx, cy))
                else:
                    break
        elif cmd == 'h':  # relative horizontal
            while i < len(tokens):
                nums, i = parse_numbers(tokens, i, 1)
                if nums:
                    cx += nums[0]
                    current_path.append((cx, cy))
                else:
                    break
        elif cmd == 'V':  # absolute vertical
            while i < len(tokens):
                nums, i = parse_numbers(tokens, i, 1)
                if nums:
                    cy = nums[0]
                    current_path.append((cx, cy))
                else:
                    break
        elif cmd == 'v':  # relative vertical
            while i < len(tokens):
                nums, i = parse_numbers(tokens, i, 1)
                if nums:
                    cy += nums[0]
                    current_path.append((cx, cy))
                else:
                    break
        elif cmd == 'C':  # absolute cubic bezier
            while i < len(tokens):
                nums, i = parse_numbers(tokens, i, 6)
                if len(nums) == 6:
                    x1, y1, x2, y2, x3, y3 = nums
                    for t_idx in range(1, BEZIER_SEGMENTS + 1):
                        t = t_idx / BEZIER_SEGMENTS
                        px = cubic_bezier(cx, x1, x2, x3, t)
                        py = cubic_bezier(cy, y1, y2, y3, t)
                        current_path.append((px, py))
                    cx, cy = x3, y3
                else:
                    break
        elif cmd == 'c':  # relative cubic bezier
            while i < len(tokens):
                nums, i = parse_numbers(tokens, i, 6)
                if len(nums) == 6:
                    dx1, dy1, dx2, dy2, dx3, dy3 = nums
                    x1, y1 = cx + dx1, cy + dy1
                    x2, y2 = cx + dx2, cy + dy2
                    x3, y3 = cx + dx3, cy + dy3
                    for t_idx in range(1, BEZIER_SEGMENTS + 1):
                        t = t_idx / BEZIER_SEGMENTS
                        px = cubic_bezier(cx, x1, x2, x3, t)
                        py = cubic_bezier(cy, y1, y2, y3, t)
                        current_path.append((px, py))
                    cx, cy = x3, y3
                else:
                    break
        elif cmd == 'S':  # smooth cubic (absolute)
            while i < len(tokens):
                nums, i = parse_numbers(tokens, i, 4)
                if len(nums) == 4:
                    # reflect previous control point
                    x2, y2, x3, y3 = nums
                    x1 = 2 * cx - prev_cx2 if hasattr(parse_path, '_pcx2') else cx
                    y1 = 2 * cy - prev_cy2 if hasattr(parse_path, '_pcy2') else cy
                    for t_idx in range(1, BEZIER_SEGMENTS + 1):
                        t = t_idx / BEZIER_SEGMENTS
                        px = cubic_bezier(cx, x1, x2, x3, t)
                        py = cubic_bezier(cy, y1, y2, y3, t)
                        current_path.append((px, py))
                    prev_cx2, prev_cy2 = x2, y2
                    cx, cy = x3, y3
                else:
                    break
        elif cmd == 's':  # smooth cubic (relative)
            while i < len(tokens):
                nums, i = parse_numbers(tokens, i, 4)
                if len(nums) == 4:
                    dx2, dy2, dx3, dy3 = nums
                    x2, y2 = cx + dx2, cy + dy2
                    x3, y3 = cx + dx3, cy + dy3
                    x1 = 2 * cx - prev_cx2 if 'prev_cx2' in dir() else cx
                    y1 = 2 * cy - prev_cy2 if 'prev_cy2' in dir() else cy
                    for t_idx in range(1, BEZIER_SEGMENTS + 1):
                        t = t_idx / BEZIER_SEGMENTS
                        px = cubic_bezier(cx, x1, x2, x3, t)
                        py = cubic_bezier(cy, y1, y2, y3, t)
                        current_path.append((px, py))
                    prev_cx2, prev_cy2 = x2, y2
                    cx, cy = x3, y3
                else:
                    break
        elif cmd in ('Z', 'z'):  # close path
            if current_path:
                current_path.append((sx, sy))
                subpaths.append(current_path)
                current_path = []
                cx, cy = sx, sy
        else:
            # Unknown command, skip
            pass
    
    if current_path:
        subpaths.append(current_path)
    
    return subpaths

def cubic_bezier(p0, p1, p2, p3, t):
    """Evaluate cubic bezier at parameter t."""
    mt = 1 - t
    return mt*mt*mt*p0 + 3*mt*mt*t*p1 + 3*mt*t*t*p2 + t*t*t*p3

def apply_matrix(points, matrix):
    """Apply SVG matrix(a, b, c, d, e, f) to list of (x,y) points."""
    a, b, c, d, e, f = matrix
    result = []
    for x, y in points:
        nx = a*x + c*y + e
        ny = b*x + d*y + f
        result.append((nx, ny))
    return result

def parse_transform(transform_str):
    """Parse SVG transform='matrix(a b c d e f)'."""
    m = re.search(r'matrix\(([^)]+)\)', transform_str)
    if m:
        nums = [float(x) for x in m.group(1).replace(',', ' ').split()]
        return nums  # [a, b, c, d, e, f]
    return None

def scale_and_center(points, scale, offset_x, offset_y):
    """Scale and translate points."""
    return [(x * scale + offset_x, y * scale + offset_y) for x, y in points]

def points_to_gdscript(points, var_name):
    """Convert list of (x,y) to GDScript PackedVector2Array declaration."""
    lines = []
    lines.append(f"var {var_name}: PackedVector2Array = PackedVector2Array([")
    for x, y in points:
        lines.append(f"\tVector2({x:.1f}, {y:.1f}),")
    lines.append("])")
    return "\n".join(lines)

# ── Extract paths from SVG ─────────────────────────────────────

def extract_paths(svg_content):
    """Extract path data and transforms from SVG."""
    paths = []
    # Find all <path ... /> or <path ...> elements
    for m in re.finditer(r'<path\s+([^>]+)/?>', svg_content):
        attrs = m.group(1)
        # Extract d attribute
        d_match = re.search(r'd="([^"]*)"', attrs)
        if not d_match:
            continue
        d = d_match.group(1)
        # Extract transform attribute (optional)
        t_match = re.search(r'transform="([^"]*)"', attrs)
        matrix = None
        if t_match:
            matrix = parse_transform(t_match.group(1))
        paths.append((d, matrix))
    return paths

# ── Main ────────────────────────────────────────────────────────

if __name__ == "__main__":
    svg_path = sys.argv[1] if len(sys.argv) > 1 else "/home/ssjmarx/Downloads/icon_monochrome_dark.svg"
    
    with open(svg_path, "r") as f:
        svg = f.read()
    
    raw_paths = extract_paths(svg)
    print(f"Found {len(raw_paths)} paths in SVG\n")
    
    # Target: fit logo into ~180px tall in a 640x360 viewport
    # SVG viewBox is 1024x1024
    # Scale to make it ~180px tall: 180/1024 ≈ 0.176
    SCALE = 0.176
    TARGET_W = 640
    TARGET_H = 360
    # Center horizontally, position in upper portion
    OFFSET_X = (TARGET_W - 1024 * SCALE) / 2
    OFFSET_Y = 40  # some top padding
    
    all_subpaths = []
    names = ["body", "jaw", "left_eye", "right_eye"]
    
    for idx, (d, matrix) in enumerate(raw_paths):
        print(f"--- Path {idx} ({names[idx] if idx < len(names) else 'unknown'}) ---")
        if matrix:
            print(f"  Transform: matrix({', '.join(f'{v:.4f}' for v in matrix)})")
        
        subpaths = parse_path(d)
        print(f"  {len(subpaths)} subpath(s)")
        
        for sp_idx, sp in enumerate(subpaths):
            # Apply SVG transform if present
            if matrix:
                sp = apply_matrix(sp, matrix)
            
            # Scale and center for viewport
            sp = scale_and_center(sp, SCALE, OFFSET_X, OFFSET_Y)
            
            # Reduce point count: remove near-duplicate points
            simplified = [sp[0]]
            for p in sp[1:]:
                dx = p[0] - simplified[-1][0]
                dy = p[1] - simplified[-1][1]
                if dx*dx + dy*dy > 0.5:  # threshold: ~0.7px
                    simplified.append(p)
            
            var_name = f"_logo_{names[idx]}" if len(subpaths) == 1 else f"_logo_{names[idx]}_{sp_idx}"
            all_subpaths.append((var_name, simplified))
            print(f"  Subpath {sp_idx}: {len(sp)} → {len(simplified)} points (var: {var_name})")
    
    print("\n\n# ═══ GDScript Output ═══\n")
    
    for var_name, points in all_subpaths:
        print(points_to_gdscript(points, var_name))
        print()
    
    # Print bounding box info
    all_pts = []
    for _, pts in all_subpaths:
        all_pts.extend(pts)
    if all_pts:
        min_x = min(p[0] for p in all_pts)
        max_x = max(p[0] for p in all_pts)
        min_y = min(p[1] for p in all_pts)
        max_y = max(p[1] for p in all_pts)
        print(f"# Bounding box: ({min_x:.1f}, {min_y:.1f}) to ({max_x:.1f}, {max_y:.1f})")
        print(f"# Size: {max_x - min_x:.1f} x {max_y - min_y:.1f}")
        print(f"# Center: ({(min_x+max_x)/2:.1f}, {(min_y+max_y)/2:.1f})")