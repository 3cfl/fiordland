# Security policy

## Reporting a vulnerability

Report security problems privately through GitHub:
**Security → Report a vulnerability** on the affected repository
([fiordland](https://github.com/Fiordland-Linux/fiordland/security/advisories/new),
[tawaki](https://github.com/Fiordland-Linux/tawaki/security/advisories/new),
[rawaru](https://github.com/Fiordland-Linux/rawaru/security/advisories/new)).

Do not open a public issue, wiki page or talk page for a vulnerability. If GitHub is not an option, email fiordlandlinux@gmail.com or message `u5sk` on Discord and ask for a private channel; do not send details in the first message.

A useful report includes:

- what is affected (package, version, ISO date, URL)
- steps to reproduce, or a proof of concept
- what an attacker gains
- any suggested fix

## What to expect

- Acknowledgement within 7 days.
- An assessment and a planned fix date within 14 days.
- Fixes ship as package updates in the `[fiordland]` repo; ISO-level issues also get a rebuilt ISO.
- Reporters are credited in the advisory unless they ask not to be.

Please allow 90 days, or until a fix is released, before public disclosure.

## Scope

In scope:

- `rawaru` (installer), `tawaki` (package and app manager), `crest` (desktop shell)
- `fiordland-desktop`, `fiordland-keyring` and the other packages in this repository
- The live ISO and the defaults it installs (services, firewall, sudo, polkit, sysctl)
- Package signing, the repository database and the mirror sync script
- `fiordlandlinux.org`: the site, docs, wiki, `/repo` and `/iso`

Out of scope:

- Bugs in upstream Arch Linux or CachyOS packages; report those upstream
- Social engineering, physical attacks, or attacks that need root on the victim's machine already
- Volumetric denial of service, spam, and automated scanning that degrades the service
- Missing headers or best-practice notes with no demonstrated impact

## Testing rules

- Test against your own install or VM. Do not touch other users' machines or accounts.
- On the website and wiki: no denial of service, no mass account creation, no data destruction, and stop and report as soon as you reach data that is not yours.
- Do not publish working exploits for unfixed issues.

Good-faith research that follows these rules will not be pursued legally.

## Supported versions

Fiordland is rolling. Only the current packages in `[fiordland]` and the latest ISO at
[fiordlandlinux.org/iso](https://fiordlandlinux.org/iso/) are supported.

## Package signing

Packages and the repository database are signed with:

```
Fiordland Build Key <build@fiordlandlinux.org>
11DC 7CDC CFD3 CB71 196E  BEF1 FD69 DE77 164F 4200
```

The key is shipped in `fiordland-keyring`. A package or database signed by any other key should be treated as compromised and reported.
