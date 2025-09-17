import os, re
from pathlib import Path

ROOT = Path('docs/lore')

def rel(target: Path, base: Path) -> str:
    return os.path.relpath(target, base)

def build_link(text, href):
    return f'[{text}]({href})'

def normalize_related(md_path: Path):
    lines = md_path.read_text(encoding='utf-8', errors='ignore').splitlines(keepends=False)
    changed = False
    for i, line in enumerate(lines):
        if line.strip().startswith('*Related: '):
            base = md_path.parent
            # extract links
            parts = [p.strip() for p in line.split(':',1)[1].split('|')]
            existing = []
            link_re = re.compile(r'\[([^\]]+)\]\(([^)]+)\)')
            for p in parts:
                m = link_re.search(p)
                if m:
                    existing.append((m.group(1), m.group(2)))
            # desired core
            core = []
            rm = rel(ROOT / 'reality_mechanics' / 'README.md', base)
            tb = rel(ROOT / 'factions' / 'the_bureau.md', base)
            cp = rel(ROOT / 'entities' / 'continuum.md', base)
            core.append(('Reality Mechanics', rm))
            core.append(('The Bureau', tb))
            core.append(('Continuum Program', cp))
            # merge preserving others
            # remove duplicates by href
            seen = set()
            new_links = []
            for text, href in core:
                key = (text.strip(), os.path.normpath(href))
                seen.add(key)
                new_links.append((text, href))
            for text, href in existing:
                key = (text.strip(), os.path.normpath(href))
                if key in seen:
                    continue
                seen.add(key)
                new_links.append((text, href))
            # rebuild line
            new_line = '*Related: ' + ' | '.join(build_link(t,h) for t,h in new_links)
            if new_line != line:
                lines[i] = new_line
                changed = True
            break
    if changed:
        md_path.write_text('\n'.join(lines) + ('\n' if lines and not lines[-1].endswith('\n') else ''), encoding='utf-8')
    return changed

def main():
    count = 0
    for p in ROOT.rglob('*.md'):
        if normalize_related(p):
            count += 1
            print('Normalized:', p)
    print('Total normalized:', count)

if __name__ == '__main__':
    main()

