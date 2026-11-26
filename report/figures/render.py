#!/usr/bin/env python3
"""Render the FSM/ASMD sources to PNG, SVG, and PDF (requires Graphviz)."""
from pathlib import Path
import shutil
import subprocess


def main():
    dot = shutil.which('dot')
    if dot is None:
        raise SystemExit('Graphviz is required: install it and ensure dot is on PATH.')
    for source in sorted(Path(__file__).resolve().parent.glob('*.dot')):
        for fmt in ('png', 'svg', 'pdf'):
            subprocess.run([dot, '-Gdpi=180', f'-T{fmt}', str(source),
                            '-o', str(source.with_suffix('.' + fmt))], check=True)
        print(f'Rendered {source.stem}: PNG, SVG, PDF')


if __name__ == '__main__':
    main()
