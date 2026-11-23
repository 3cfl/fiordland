#!/usr/bin/env bash
set -euo pipefail
umask 077
tmp=
trap '[ -n "$tmp" ] && rm -rf "$tmp"' EXIT

KEY=11DC7CDCCFD3CB71196EBEF1FD69DE77164F4200
SRC=${FIORDLAND_GNUPGHOME:-$HOME/.local/share/fiordland/signing}

usage() {
  echo "usage: $0 backup DEST_DIR | check BACKUP_DIR" >&2
  exit 2
}

pass_args=()
if [ -n "${FL_BACKUP_PASSFILE:-}" ]; then
  pass_args=(--pinentry-mode loopback --passphrase-file "$FL_BACKUP_PASSFILE")
fi

check() {
  local dir=$1
  tmp=$(mktemp -d)
  (cd "$dir" && sha256sum -c --quiet SHA256SUMS)
  gpg --batch --quiet "${pass_args[@]}" -o "$tmp/secret.asc" -d "$dir/secret.asc.gpg"
  gpg --batch --quiet "${pass_args[@]}" -o "$tmp/revoke.asc" -d "$dir/revoke.asc.gpg"
  GNUPGHOME=$tmp/home
  export GNUPGHOME
  mkdir -m 700 "$GNUPGHOME"
  gpg --batch --quiet --import "$tmp/secret.asc" 2>/dev/null
  gpg --batch --list-secret-keys --with-colons | grep -q "^fpr:::::::::$KEY:" || { echo "FAIL: key $KEY not in backup" >&2; return 1; }
  grep -q "BEGIN PGP PUBLIC KEY BLOCK" "$tmp/revoke.asc" || { echo "FAIL: revocation certificate unreadable" >&2; return 1; }
  echo test > "$tmp/t"
  gpg --batch --quiet -u "$KEY" --detach-sign "$tmp/t"
  mkdir -m 700 "$tmp/pub"
  GNUPGHOME=$tmp/pub gpg --batch --quiet --import "$dir/public.asc" 2>/dev/null
  GNUPGHOME=$tmp/pub gpg --batch --quiet --verify "$tmp/t.sig" "$tmp/t" 2>/dev/null || { echo "FAIL: restored key cannot make valid signatures" >&2; return 1; }
  gpgconf --kill gpg-agent
  GNUPGHOME=$tmp/pub gpgconf --kill gpg-agent
  unset GNUPGHOME
  echo "OK: $dir restores and signs as $KEY"
}

backup() {
  local dest out
  dest=$1
  [ -d "$dest" ] || { echo "no such directory: $dest" >&2; exit 1; }
  out=$dest/fiordland-signing-key-$(date +%F)
  [ -e "$out" ] && { echo "already exists: $out" >&2; exit 1; }
  mkdir -m 700 "$out"
  echo "Choose a strong passphrase and store it in a password manager, not on this drive."
  GNUPGHOME=$SRC gpg --armor --export-secret-keys "$KEY" |
    gpg --batch "${pass_args[@]}" --symmetric --cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-count 65011712 -o "$out/secret.asc.gpg"
  gpg --batch "${pass_args[@]}" --symmetric --cipher-algo AES256 -o "$out/revoke.asc.gpg" "$SRC/openpgp-revocs.d/$KEY.rev"
  GNUPGHOME=$SRC gpg --armor --export "$KEY" > "$out/public.asc"
  cat > "$out/RESTORE.txt" <<EOF
Fiordland Build Key $KEY
Backup made $(date +%F) on $(uname -n)

Restore onto a new build machine:
  mkdir -m 700 -p ~/.local/share/fiordland/signing
  gpg -d secret.asc.gpg | GNUPGHOME=~/.local/share/fiordland/signing gpg --import
  GNUPGHOME=~/.local/share/fiordland/signing gpg --edit-key $KEY trust
  (choose 5 = ultimate)

Check a backup without restoring:
  tools/key-backup.sh check <this directory>

Key stolen or leaked:
  gpg -d revoke.asc.gpg > revoke.asc
  remove the ':' at the start of the "-----BEGIN PGP PUBLIC KEY BLOCK-----" line
  GNUPGHOME=~/.local/share/fiordland/signing gpg --import revoke.asc
  then follow "Key compromise" in docs/signing-key.md
EOF
  (cd "$out" && sha256sum secret.asc.gpg revoke.asc.gpg public.asc RESTORE.txt > SHA256SUMS)
  sync
  echo "Checking the backup (enter the passphrase again)..."
  check "$out"
}

[ $# -eq 2 ] || usage
case $1 in
  backup) backup "$2" ;;
  check) check "$2" ;;
  *) usage ;;
esac
