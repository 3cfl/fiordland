import sys, pathlib, html

WEB = pathlib.Path(sys.argv[1])
V = sys.argv[2]

NAV = [("/#features", "Features"), ("/compare/", "Compare"), ("/docs/", "Docs"), ("/wiki/", "Wiki"), ("https://github.com/Fiordland-Linux/fiordland", "GitHub"), ("https://donate.stripe.com/8x25kFfe96fn0WL6X12wU00", "Donate"), ("https://discord.gg/gy4ANH2Q9V", "Discord")]

def nav(cur):
    out = []
    for href, label in NAV:
        a = ' aria-current="page"' if href == cur else ""
        out.append(f'      <a href="{href}"{a}>{label}</a>')
    return "\n".join(out)

FOOT = """<footer class="foot">
  <div class="wrap foot-in">
    <span class="mark">Fiordland</span>
    <span class="credit">Created by <a href="https://apollo44.lat" rel="author">Apollo</a> (<a href="https://github.com/3cfl">3cfl</a>)</span>
    <a href="/docs/">Docs</a>
    <a href="/why/">Why Fiordland</a>
    <a href="/low-end/">Low-end PCs</a>
    <a href="/wiki/">Wiki</a>
    <a href="/mirrors/">Mirrors</a>
    <a href="/repo/x86_64/">Repo</a>
    <a href="https://github.com/Fiordland-Linux/fiordland">GitHub</a>
      <a href="https://donate.stripe.com/8x25kFfe96fn0WL6X12wU00">Donate</a>
    <a href="https://apollo44.lat">apollo44.lat</a>
    <a href="https://ivy.rest">ivy.rest</a>
    <span class="credit">Tux by <a href="https://isc.tamu.edu/~lewing/linux/">Larry Ewing</a>, Simon Budig and Garrett LeSage, made with The GIMP.</span>
  </div>
</footer>"""

def head_extra(path):
    if path is None:
        return '<meta name="robots" content="noindex">'
    return f'<link rel="canonical" href="https://fiordlandlinux.org{path}">\n<meta property="og:url" content="https://fiordlandlinux.org{path}">'

def page(title, desc, cur, body, eyebrow, path="/docs/"):
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} &middot; Fiordland Linux</title>
<meta name="description" content="{html.escape(desc)}">
<meta name="theme-color" content="#131313">
{head_extra(path)}
<meta property="og:title" content="{title}">
<meta property="og:description" content="{html.escape(desc)}">
<meta property="og:image" content="https://fiordlandlinux.org/assets/og.png?v=5">
<meta property="og:site_name" content="Fiordland Linux">
<meta property="og:type" content="website">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="https://fiordlandlinux.org/assets/og.png?v=5">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<link rel="preload" href="/assets/fonts/inter.woff2" as="font" type="font/woff2" crossorigin>
<link rel="icon" href="data:,">
<link rel="stylesheet" href="/assets/site.css?v={V}">
</head>
<body>
<header class="nav">
  <div class="nav-in">
    <a class="mark" href="/"><img src="/assets/logos/tux.svg" alt="" width="18" height="21">Fiordland</a>
    <nav>
{nav(cur)}
    </nav>
    <a class="btn sm" data-iso href="/iso/fiordland-latest.iso">Download</a>
  </div>
</header>

<main class="wrap main-pad">
  <p class="eyebrow">{eyebrow}</p>
{body}
</main>

{FOOT}
<script src="/assets/js/site.js?v=4" defer></script>
</body>
</html>
"""

DOCS = [
 ("install", "Install Fiordland", "Make a USB stick, boot it and run the installer."),
 ("first-steps", "First steps", "What to do after the first boot."),
 ("apps", "Installing apps", "Find, install, update and remove apps with tawaki."),
 ("updates", "Updates", "Keep the system current and what to do when an update goes wrong."),
 ("snapshots", "Snapshots and rollback", "Undo a bad update with Btrfs snapshots."),
 ("help", "Getting help", "Where to ask, and what to include so people can help."),
]

def pager(slug):
    i = [d[0] for d in DOCS].index(slug)
    prev = DOCS[i - 1] if i > 0 else None
    nxt = DOCS[i + 1] if i + 1 < len(DOCS) else None
    a = f'<a class="dp" href="/docs/{prev[0]}/"><span>Previous</span>{prev[1]}</a>' if prev else "<span></span>"
    b = f'<a class="dp nx" href="/docs/{nxt[0]}/"><span>Next</span>{nxt[1]}</a>' if nxt else "<span></span>"
    return f'  <nav class="dpager" aria-label="Docs pages">{a}{b}</nav>'

def term(t):
    return f'<pre class="term">{html.escape(t)}</pre>'

def sec(h, inner):
    return f'  <section class="msec">\n    <h2 class="h3">{h}</h2>\n{inner}\n  </section>'

def steps(items):
    li = "\n".join(f"      <li><h3>{h}</h3>{b}</li>" for h, b in items)
    return f'    <ol class="msteps">\n{li}\n    </ol>'

def p(t):
    return f"    <p>{t}</p>"

def ul(items):
    return '    <ul class="dlist">' + "".join(f"<li>{x}</li>" for x in items) + "</ul>"

C = {}

C["install"] = "\n".join([
 sec("What you need", ul([
  "A 64-bit PC. UEFI is recommended; older BIOS machines work too.",
  "4 GB of RAM at least, 8 GB or more is better.",
  "30 GB of disk. Either a whole disk, which is erased, or room next to Windows on a UEFI computer. Back up anything you want to keep.",
  "To keep Windows: turn off Fast Startup and BitLocker (Device encryption) in Windows first, then shut down fully.",
  "A USB stick of 4 GB or more, and an internet connection during the install.",
 ])),
 sec("Install", steps([
  ("Download the ISO", '<p>Get it from the <a href="/">home page</a>. The SHA-256 checksum is listed under the download button. On Linux, check it with:</p>' + term("sha256sum fiordland-*.iso")),
  ("Write it to a USB stick", '<p>On Windows use <a href="https://rufus.ie">Rufus</a> and pick <em>DD image mode</em> when it asks. On macOS or Windows, <a href="https://etcher.balena.io">balenaEtcher</a> also works. On Linux:</p>' + term("sudo dd if=fiordland-*.iso of=/dev/sdX bs=4M status=progress oflag=sync") + "<p>Replace <code>sdX</code> with the USB stick. <code>lsblk</code> lists your drives. Picking the wrong one erases it.</p>"),
  ("Boot from the stick", "<p>Restart and press the boot menu key while the logo shows. It is usually F12, F11, F8, Esc or F2. Turn off <strong>Secure Boot</strong> in the firmware settings first; Fiordland's boot files are not signed yet.</p>"),
  ("Run the installer", "<p>The live desktop opens the installer by itself. Pick your language, keyboard, timezone, the disk (the whole disk, alongside Windows with a slider for the size, or partitions you choose, with a partition editor one click away), your account and a desktop. KDE Plasma is the default and the easiest switch from Windows. The review page lets you change the graphics driver and kernel before anything is written.</p>"),
  ("Restart", "<p>Packages download fresh, so the install takes 5 to 20 minutes. Remove the USB stick when the computer restarts.</p>"),
 ])),
 sec("If something goes wrong", ul([
  "The disk does not show up: in the firmware settings, change SATA mode from RAID or Intel RST to AHCI.",
  "Black screen after the boot menu: pick <strong>Fiordland Linux (safe graphics)</strong>.",
  'Anything else: see the <a href="/wiki/Troubleshooting">Troubleshooting</a> page on the wiki.',
 ])),
])

C["first-steps"] = "\n".join([
 sec("Connect to the internet", p("Click the network icon in the panel and pick your Wi-Fi. A cable works without any setup.")),
 sec("Update once", p("The ISO may be a few days old. Open a terminal and run:") + "\n    " + term("tawaki update") + "\n" + p("It asks for your password, then updates the system, Flatpaks and AUR packages together.")),
 sec("Install your apps", p("Use the package manager from the terminal:") + "\n    " + term("tawaki install firefox steam discord") + "\n" + p('<code>i</code> is a shortcut for <code>tawaki install</code>. More in <a href="/docs/apps/">Installing apps</a>.')),
 sec("Already set up for you", ul([
  "Graphics drivers for your GPU, Vulkan and 32-bit libraries for Steam and Wine.",
  "Steam, proton-cachyos, wine-cachyos, umu-launcher, gamemode, MangoHud and gamescope.",
  "Flathub, so Flatpak apps work straight away.",
  "Printing, with network printers found automatically.",
  "A firewall (ufw) that blocks incoming connections.",
  "Bluetooth, power profiles, firmware updates and zram swap.",
  "Snapshots before every update, so a bad update can be undone.",
 ])),
 sec("Terminal basics", ul([
  "<code>sudo</code> runs a command as administrator. It asks for your own password.",
  "Typing a command you do not have tells you which package provides it.",
  "<code>Ctrl+C</code> stops a running command. <code>Ctrl+Shift+V</code> pastes in most terminals.",
 ])),
])

C["apps"] = "\n".join([
 sec("How it works", p("tawaki searches three places at once: the Arch repositories, Flathub and the AUR. It installs from the repos when it can, then Flathub, then the AUR. If a Flatpak would pull in a large runtime you do not have yet, it picks a prebuilt package instead.")),
 sec("Commands", '    <div class="card plain"><table class="cmp dcmd"><tbody>' + "".join(
   f"<tr><th scope=\"row\"><code>{c}</code></th><td>{d}</td></tr>" for c, d in [
    ("tawaki install NAME", "Install an app. Short: <code>i NAME</code>"),
    ("tawaki remove NAME", "Remove it, wherever it came from"),
    ("tawaki update", "Update everything. Short: <code>up</code>"),
    ("tawaki search WORDS", "Search all three sources"),
    ("tawaki list", "List apps installed with tawaki"),
    ("tawaki install NAME --from flatpak", "Force a source: <code>pacman</code>, <code>flatpak</code> or <code>aur</code>"),
   ]) + "</tbody></table></div>"),
 sec("Settings", p("Edit <code>~/.config/tawaki/config.toml</code> to change the order or turn off the light-package check:") + "\n    " + term('priority = ["pacman", "flatpak", "aur"]\nprefer_light = true')),
 sec("About the AUR", p("AUR packages are build scripts uploaded by users. Nobody at Arch or Fiordland reviews them. Prefer repo and Flathub packages, and only install from the AUR when you trust the package.")),
 sec("Other tools still work", p("<code>pacman</code> and <code>flatpak</code> work as usual. tawaki is a front end, not a replacement. No AUR helper is installed: tawaki builds AUR packages with <code>makepkg</code> and shows you the build script first. If you install <code>paru</code> or <code>yay</code> yourself, tawaki uses it.")),
])

C["updates"] = "\n".join([
 sec("Update", term("tawaki update") + "\n" + p("Run it every week or two. Fiordland is a rolling release: packages update in small steps, and new releases arrive the same way.")),
 sec("New releases", p("A new ISO is only for new installs. An installed system gets the same changes through <code>tawaki update</code>: new default packages, settings and fixes are applied once, inside the update, after the pre-update snapshot. When the release number changes, the update prints it with a short list of what's new, for example <code>Fiordland 0.9.0 -&gt; 1.0.0</code>.") + "\n    " + term("cat /etc/os-release") + "\n" + p("shows the current release. <code>fiordland-migrate --list</code> shows which release changes are applied. A change that fails is reported, logged in <code>/var/log/fiordland-migrate.log</code> and tried again on the next update.")),
 sec("Before updating", ul([
  "Close games and apps that are running.",
  "Keep the laptop plugged in.",
  "Read what the update prints. Messages that start with <code>==&gt;</code> or <code>warning:</code> sometimes ask you to do something.",
 ])),
 sec("After a kernel update", p("Restart when it finishes. Until then, new USB devices and some drivers may not load.")),
 sec("When an update goes wrong", p('A snapshot is taken before every update. See <a href="/docs/snapshots/">Snapshots and rollback</a>. If the desktop does not start, pick <strong>Arch kernel</strong> or <strong>safe graphics</strong> in the boot menu first.')),
 sec("Clean up", p("Old package downloads are cleared every week automatically, keeping the last three versions. To remove packages nothing uses any more:") + "\n    " + term("sudo pacman -Rns $(pacman -Qdtq)")),
])

C["snapshots"] = "\n".join([
 sec("What is saved", p("Fiordland uses Btrfs and <a href=\"https://wiki.archlinux.org/title/Snapper\">snapper</a>. A snapshot is a frozen copy of the system, not your home folder. Snapshots are taken before and after every package change, and every hour (5 hourly, 7 daily, 2 weekly and 1 monthly are kept).") + "\n    " + term("snapper -c root list")),
 sec("Undo an update while the system works", p("Find the snapshot pair for the bad update in the list (the <em>pre</em> and <em>post</em> numbers), then:") + "\n    " + term("sudo snapper -c root undochange PRE..POST") + "\n" + p("Restart afterwards.")),
 sec("Roll back when the system does not boot", steps([
  ("Pick a snapshot", "<p>Restart, open <strong>Fiordland snapshots</strong> in the boot menu and pick one from before the problem. Each entry shows its date and what caused it.</p>"),
  ("Check it works", "<p>The system starts from the snapshot. Changes made now are kept in memory and lost at the next restart.</p>"),
  ("Make it permanent", term("sudo fiordland-rollback") + "<p>Restart, and Fiordland starts from the restored system. Your home folder is not touched.</p>"),
  ("Free the space", term("sudo fiordland-rollback --clean") + "<p>Deletes the old system once everything works.</p>"),
 ]) + "\n" + p("Each snapshot carries its own kernel, so this also undoes a bad kernel update. To restore by number without booting it first, use <code>fiordland-rollback --list</code> and then <code>sudo fiordland-rollback N</code>.")),
 sec("Installs from before 23 November 2026", p("Older installs use systemd-boot, so the snapshot menu is not there. Boot the USB stick, open a terminal, and:") + "\n    " + term("lsblk -f\nsudo mount -o subvolid=5 /dev/nvme0n1p2 /mnt\nsudo ls /mnt/@snapshots\nsudo mv /mnt/@ /mnt/@broken\nsudo btrfs subvolume snapshot /mnt/@snapshots/N/snapshot /mnt/@\nsudo umount /mnt") + "\n" + p("Use the <code>btrfs</code> partition from <code>lsblk -f</code>, and <code>info.xml</code> in each snapshot folder for its date. If a kernel update caused the problem, run <code>sudo pacman -S linux-cachyos linux</code> after restarting.")),
])

C["help"] = "\n".join([
 sec("Where to ask", ul([
  '<a href="/wiki/">Wiki</a>: guides and fixes written by users. Search it first.',
  '<a href="/wiki/Help_desk">Help desk</a>: ask a question on the wiki. Every wiki page also has a Discussion tab.',
  '<a href="https://github.com/Fiordland-Linux/fiordland/issues">GitHub issues</a>: bugs in Fiordland, tawaki or the installer.',
  '<a href="https://wiki.archlinux.org">Arch Wiki</a>: Fiordland uses the Arch repos, so most of it applies.',
 ])),
 sec("What to include", ul([
  "What you did, what you expected, and what happened instead.",
  "The exact error text. Copy it, do not retype it.",
  "Your hardware, especially the GPU.",
 ]) + "\n" + p("This prints a hardware summary you can paste:") + "\n    " + term("inxi -Fxz") + "\n" + p("For errors from the current boot:") + "\n    " + term("journalctl -b -p err --no-pager | tail -50")),
 sec("Do not paste", p("Passwords, Wi-Fi keys or anything from <code>/etc/shadow</code>. <code>inxi -z</code> already hides serial numbers and IP addresses.")),
])

def doc(slug, title, desc):
    body = f'  <h1 class="page">{title}</h1>\n  <p class="lede">{desc}</p>\n{C[slug]}\n{pager(slug)}'
    return page(title, desc, "/docs/", body, '<a href="/docs/">Docs</a>', f"/docs/{slug}/")

cards = "\n".join(f'    <a class="card dcard" href="/docs/{s}/"><div class="card-in"><h3>{t}</h3><p>{d}</p></div></a>' for s, t, d in DOCS)
idx = f"""  <h1 class="page">Documentation</h1>
  <p class="lede">Official guides for installing and using Fiordland. Community guides and fixes are on the <a href="/wiki/">wiki</a>.</p>
  <div class="dgrid">
{cards}
  </div>
  <p class="note">Found a mistake? These pages live in <a href="https://github.com/Fiordland-Linux/fiordland/tree/main/web/docs">the repo</a>.</p>"""

(WEB / "docs").mkdir(exist_ok=True)
(WEB / "docs/index.html").write_text(page("Documentation", "Official guides for installing and using Fiordland Linux.", "/docs/", idx, "Docs"))
for s, t, d in DOCS:
    (WEB / "docs" / s).mkdir(exist_ok=True)
    (WEB / "docs" / s / "index.html").write_text(doc(s, t, d))

nf = """  <h1 class="page">Page not found</h1>
  <p class="lede">That page does not exist. It may have moved.</p>
  <p><a href="/">Home</a> &middot; <a href="/docs/">Docs</a> &middot; <a href="/wiki/">Wiki</a></p>"""
(WEB / "404.html").write_text(page("Page not found", "That page does not exist.", "", nf, "Fiordland", None))
