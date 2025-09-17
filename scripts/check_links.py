import os, re, sys
root = sys.argv[1] if len(sys.argv)>1 else 'docs'
link_re = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
missing = []
for dirpath,_,files in os.walk(root):
    for f in files:
        if not f.endswith(('.md','.MD','.markdown')): continue
        p = os.path.join(dirpath,f)
        with open(p,'r',encoding='utf-8',errors='ignore') as fh:
            for i,line in enumerate(fh,1):
                for m in link_re.finditer(line):
                    href = m.group(1)
                    if href.startswith(('http://','https://','#')): continue
                    if href.startswith('mailto:'): continue
                    # strip anchors
                    path = href.split('#',1)[0]
                    # ignore absolute from root (none expected)
                    if path.strip()=='' or path.startswith('data:'): continue
                    # normalize
                    target = os.path.normpath(os.path.join(dirpath, path))
                    if not os.path.exists(target):
                        missing.append((p,i,href,target))

if missing:
    for p,i,href,target in missing:
        print(f"{p}:{i}: missing -> {href} (resolved: {os.path.relpath(target)})")
    sys.exit(1)
else:
    print('No missing relative links found under', root)
