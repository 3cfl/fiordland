# Signing key

Every package and the `[fiordland]` database are signed by:

```
Fiordland Build Key <build@fiordland.apollo44.lat>
11DC 7CDC CFD3 CB71 196E  BEF1 FD69 DE77 164F 4200
```

It lives in `~/.local/share/fiordland/signing` on the build machine, without a passphrase so builds can sign unattended. Losing it means every installed system stops trusting new updates. A leak means anyone can push packages that installs accept.

## Backup checklist

- [ ] Two USB drives, ideally different brands.
- [ ] A passphrase of 6+ random words, saved in a password manager. Never on the drives.
- [ ] `tools/key-backup.sh backup /run/media/$USER/<drive1>`
- [ ] `tools/key-backup.sh backup /run/media/$USER/<drive2>`
- [ ] Both runs end with `OK: ... restores and signs`.
- [ ] One drive stays at home, the other somewhere else (family, a safe, a locker).
- [ ] Every 6 months: plug each drive in and run `tools/key-backup.sh check <dir>`. USB flash fades.
- [ ] After any key change (new subkey, new key), make fresh backups and wipe the old ones.

Each backup folder holds:

| File | What it is |
| --- | --- |
| `secret.asc.gpg` | the private key, encrypted with the passphrase |
| `revoke.asc.gpg` | the revocation certificate, encrypted |
| `public.asc` | the public key |
| `RESTORE.txt` | restore and revoke steps |
| `SHA256SUMS` | checksums for all of the above |

## Build machine hygiene

- Full-disk encryption on the build machine.
- Do not copy the signing directory to the VPS, CI, cloud storage or Syncthing folders.
- CI never signs. Release builds and signing happen on the build machine only.

## Restoring

Follow `RESTORE.txt` in the backup, then run `./build.sh` and confirm `repo-add` signs without errors.

## Key compromise

1. Import the revocation certificate (see `RESTORE.txt`) and check that `gpg --list-keys` shows the key as revoked.
2. Generate a new key, put it in `fiordland-keyring` (new key in `fiordland.gpg`, its fingerprint in `fiordland-trusted`, the old fingerprint in `fiordland-revoked`), bump pkgrel and sign the keyring with the new key.
3. Post a notice on the site and the wiki Help desk with both fingerprints. Existing installs trust the old key only, so they cannot pull the new keyring automatically. Users must run:

   ```
   sudo pacman-key --recv-keys <NEW_FINGERPRINT> --keyserver keys.openpgp.org
   sudo pacman-key --lsign-key <NEW_FINGERPRINT>
   sudo pacman -Syu fiordland-keyring
   ```

4. Rebuild and re-sign every package and the database with the new key, and rebuild the ISO.
5. Publish a GitHub security advisory on `3cfl/fiordland`.
