"""
knj — KNJ font format parser and renderer (3-column 8×24 layout)

Reference: HANDOVER.md §8.1 — 3-column 8×24 confirmed layout
- Each glyph = 72 bytes = 3 columns × 24 rows
- Column block: 24 bytes, bit 7 = leftmost pixel
- Order: column 0 (bits 7-0 of each row), then column 1, then column 2
"""

from typing import List, Tuple, Optional

# Glyph size
GLYPH_SIZE = 72  # 24 rows × 3 columns
COLUMNS = 3
ROWS = 24

# High-frequency glyphs (slots 0-50) — custom layout
HIGH_FREQ_CHARS = [
    '何', '时', '将', '军', '这', '于', '西', '也', '刀', '力',
    '户', '心', '到', '电', '得', '独', '家', '当', '现', '你',
    '没', '把', '要', '哦', '出', '就', '会', '能', '过', '人',
    '在', '有', '我', '他', '她', '们', '的', '了', '是', '不',
    '和', '与', '也', '之', '为', '在', '上', '下', '中', '大',
]

def get_glyph_bytes(data: bytes, slot: int) -> Optional[bytes]:
    """Get raw 72-byte glyph data for given slot."""
    offset = slot * GLYPH_SIZE
    if offset + GLYPH_SIZE > len(data):
        return None
    return data[offset:offset + GLYPH_SIZE]


def render_ascii(glyph: bytes, width: int = 24) -> str:
    """
    Render glyph to ASCII art.

    Args:
        glyph: 72 bytes of 3-column 8×24 layout
        width: output width in characters (default 24 for full width)

    Returns:
        ASCII art string with '#' for pixels, ' ' for background
    """
    lines = []
    chars = ' .:#@'  # dark to light

    for row in range(ROWS):
        line = ''
        for col in range(COLUMNS):
            byte = glyph[col * ROWS + row]
            # bit 7 = leftmost pixel
            for bit in range(7, -1, -1):
                if byte & (1 << bit):
                    line += '#'
                else:
                    line += ' '
        lines.append(line)

    return '\n'.join(lines)


def render_html(glyph: bytes, pixel_size: int = 3) -> str:
    """Render glyph to HTML table (black on white)."""
    rows = []
    for row in range(ROWS):
        cells = []
        for col in range(COLUMNS):
            byte = glyph[col * ROWS + row]
            for bit in range(7, -1, -1):
                color = '#000' if byte & (1 << bit) else '#fff'
                cells.append(f'<td bgcolor="{color}" width="{pixel_size}" height="{pixel_size}"></td>')
        rows.append(f'<tr>{"".join(cells)}</tr>')

    return f'<table cellpadding="0" cellspacing="0" border="0"><tbody>{"".join(rows)}</tbody></table>'


def render_svg(glyph: bytes, scale: int = 1) -> str:
    """Render glyph to SVG."""
    pixels = []
    width = COLUMNS * 8 * scale
    height = ROWS * scale

    for row in range(ROWS):
        for col in range(COLUMNS):
            byte = glyph[col * ROWS + row]
            for bit in range(7, -1, -1):
                if byte & (1 << bit):
                    x = (col * 8 + (7 - bit)) * scale
                    y = row * scale
                    pixels.append(f'<rect x="{x}" y="{y}" width="{scale}" height="{scale}"/>')

    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}"><g fill="#000">{chr(10).join(pixels)}</g></svg>'


def load_font(path: str) -> bytes:
    """Load KNJ font file."""
    with open(path, 'rb') as f:
        return f.read()


def get_glyph_count(font_data: bytes) -> int:
    """Get number of glyphs in font."""
    return len(font_data) // GLYPH_SIZE


def slot_to_char(slot: int) -> str:
    """Get character for slot (if known)."""
    if 0 <= slot < len(HIGH_FREQ_CHARS):
        return HIGH_FREQ_CHARS[slot]
    # Unicode range: slot 51+ = U+5452 + (slot - 51)
    if slot >= 51:
        unicode_codepoint = 0x5452 + (slot - 51)
        try:
            return chr(unicode_codepoint)
        except ValueError:
            return f'U+{unicode_codepoint:04X}'
    return f'?{slot}'
