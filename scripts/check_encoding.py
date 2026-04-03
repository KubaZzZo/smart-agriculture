#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
EXTS = {'.ets', '.ts', '.py', '.md', '.json5'}
SUSPICIOUS = (chr(0xFFFD), chr(0x9227), chr(0x951F))

errors = []
for path in ROOT.rglob('*'):
    if not path.is_file() or path.suffix.lower() not in EXTS:
        continue
    if any(part in {'oh_modules', '.git', '__pycache__', '.idea'} for part in path.parts):
        continue
    try:
        text = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        errors.append(f'{path}: not utf-8 decodable')
        continue
    for token in SUSPICIOUS:
        if token in text:
            errors.append(f'{path}: contains suspicious mojibake character U+{ord(token):04X}')
            break

if errors:
    print('Encoding check failed:')
    for item in errors:
        safe = item.encode('ascii', errors='backslashreplace').decode('ascii')
        print(f' - {safe}')
    sys.exit(1)

print('Encoding check passed.')
