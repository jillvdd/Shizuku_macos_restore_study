#!/usr/bin/env python3
"""
shizuku-cli — 《雫～しずく～》资源解析命令行工具

Usage:
    python3 -m shizuku_cli inspect <MAX_DATA.PAK>
    python3 -m shizuku_cli extract <MAX_DATA.PAK> <output_dir>
    python3 -m shizuku_cli disassemble <SCN*.DAT>...
    python3 -m shizuku_cli image <LFG_FILE> [output.png]
    python3 -m shizuku_cli font <KNJ_FILE> [--preview] [--slot N]
    python3 -m shizuku_cli text <SCN*.DAT>...
"""

import sys
import os

# Get the package directory
pkg_dir = os.path.dirname(os.path.abspath(__file__))
if pkg_dir not in sys.path:
    sys.path.insert(0, pkg_dir)

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == 'inspect':
        import cmd_inspect
        cmd_inspect.main(sys.argv[2:])
    elif cmd == 'extract':
        import cmd_extract
        cmd_extract.main(sys.argv[2:])
    elif cmd == 'disassemble':
        import cmd_disasm
        cmd_disasm.main(sys.argv[2:])
    elif cmd == 'image':
        import cmd_image
        cmd_image.main(sys.argv[2:])
    elif cmd == 'font':
        import cmd_font
        cmd_font.main(sys.argv[2:])
    elif cmd == 'text':
        import cmd_text
        cmd_text.main(sys.argv[2:])
    elif cmd == 'cntext':
        import cmd_cntext
        cmd_cntext.main(sys.argv[2:])
    else:
        print(f"Unknown command: {cmd}")
        print(__doc__)
        sys.exit(1)

if __name__ == '__main__':
    main()
