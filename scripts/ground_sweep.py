import os
import re

ROOT = 'docs/lore'
TARGET_DIRS = [
    os.path.join(ROOT, 'npcs'),
    os.path.join(ROOT, 'characters'),
    os.path.join(ROOT, 'locations', 'districts'),
    os.path.join(ROOT, 'locations', 'establishments'),
]

NOTE_LINE = 'Note: This page adheres to Grounded Canon v2 (single-premise).\n'

def add_note(path):
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    text = ''.join(lines)
    if 'Grounded Canon v2' in text:
        return False
    # find first H1 header
    for i, line in enumerate(lines):
        if line.strip().startswith('# '):
            insert_at = i + 1
            # skip blank line immediately after header
            if insert_at < len(lines) and lines[insert_at].strip() == '':
                insert_at += 1
            lines.insert(insert_at, NOTE_LINE)
            with open(path, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            return True
    return False

def main():
    changed = []
    for base in TARGET_DIRS:
        if not os.path.isdir(base):
            continue
        for dirpath, _, files in os.walk(base):
            for fn in files:
                if not fn.endswith('.md'):
                    continue
                p = os.path.join(dirpath, fn)
                if add_note(p):
                    changed.append(p)
    print(f'Updated {len(changed)} files with Grounded Canon note.')
    for p in changed:
        print(' -', p)

if __name__ == '__main__':
    main()

