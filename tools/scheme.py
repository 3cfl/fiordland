import json, sys, types
sys.path.insert(0, "/usr/lib/python3.14/site-packages")
from caelestia.utils.material.generator import gen_scheme, hex_to_hct

def gen(variant, seed):
    return gen_scheme(types.SimpleNamespace(mode="dark", variant=variant, flavour="default"), hex_to_hct(seed))

blue = gen("fidelity", "8ec5ff")
grey = gen("monochrome", "8ec5ff")
soft = gen("tonalspot", "8ec5ff")
grey_keys = ("background", "onBackground", "surface", "onSurface", "inverseSurface", "inverseOnSurface", "outline", "shadow", "scrim", "neutral")
c = dict(blue)
for k in blue:
    if k.startswith(grey_keys):
        c[k] = grey[k]
    if "tertiary" in k or "Tertiary" in k:
        c[k] = soft[k]
c["surfaceTint"] = blue["surfaceTint"]
json.dump({"name": "fiordland", "flavour": "default", "mode": "dark", "variant": "fidelity", "colours": c},
          open("packages/fiordland-desktop/files/crest/scheme.json", "w"), indent=4)
open("packages/aur/caelestia-cli/fiordland-dark.txt", "w").write("".join(f"{k} {v}\n" for k, v in c.items()))
print({k: c[k] for k in ("background", "surfaceContainer", "onSurface", "primary", "primaryContainer", "secondary", "tertiary", "term4")})
