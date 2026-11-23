import os, re, sys
src = "/usr/share/icons/Papirus"
dark = "/usr/share/icons/Papirus-Dark/index.theme"
out = sys.argv[1]
BLUE = re.compile(r"^(folder|user)-blue(?=[-.])")
n = 0
for size in sorted(os.listdir(src)):
    places = os.path.join(src, size, "places")
    if not os.path.isdir(places):
        continue
    for name in os.listdir(places):
        path = os.path.join(places, name)
        if not name.startswith(("folder", "user-")) or not os.path.islink(path):
            continue
        target = os.readlink(path)
        hops = 0
        while not BLUE.match(target) and os.path.islink(os.path.join(places, target)) and hops < 8:
            target = os.readlink(os.path.join(places, target))
            hops += 1
        if not BLUE.match(target):
            continue
        tint = BLUE.sub(r"\1-breeze", target, count=1)
        if not os.path.exists(os.path.join(places, tint)):
            continue
        dest = os.path.join(out, size, "places")
        os.makedirs(dest, exist_ok=True)
        os.symlink(f"../../../Papirus/{size}/places/{tint}", os.path.join(dest, name))
        n += 1
theme = open(dark).read()
theme = re.sub(r"(?m)^Name=.*$", "Name=Fiordland", theme, count=1)
theme = re.sub(r"(?m)^Comment=.*$", "Comment=Papirus with Fiordland blue folders", theme, count=1)
theme = re.sub(r"(?m)^Inherits=.*$", "Inherits=Papirus-Dark,Papirus,breeze-dark,hicolor", theme, count=1)
open(os.path.join(out, "index.theme"), "w").write(theme)
print(n, "folder icons")
