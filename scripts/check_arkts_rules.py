#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

failed = []
for path in ROOT.rglob('*.ets'):
    if any(part in {'oh_modules', '.git', '__pycache__', '.idea'} for part in path.parts):
        continue
    text = path.read_text(encoding='utf-8', errors='ignore')
    if '[key: string]' in text:
        failed.append(f'{path}: contains indexed signature [key: string] which ArkTS forbids')
    if 'new WebSocket(' in text:
        failed.append(f'{path}: uses WebSocket global which is not available in this project setup')

if failed:
    print('ArkTS rule check failed:')
    for item in failed:
        print(' - ' + item)
    sys.exit(1)

print('ArkTS rule check passed.')
