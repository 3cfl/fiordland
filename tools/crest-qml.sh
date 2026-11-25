#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
root="$PWD"

qtbin() {
  local name="$1" p
  for p in "/usr/lib/qt6/bin/$name" "$(command -v "$name" 2>/dev/null || true)"; do
    if [ -n "$p" ] && [ -x "$p" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  echo "missing $name" >&2
  return 1
}

assemble() {
  local which="$1" dest="$2"
  mkdir -p "$dest"
  if [ "$which" = crest ]; then
    cp -r "$root/crest/." "$dest/"
  else
    cp -r "$root/crest-greeter/." "$dest/"
    cp -r "$root/crest/theme" "$root/crest/components" "$dest/"
    mkdir -p "$dest/assets"
    cp "$root/crest/assets/wallpaper.webp" "$dest/assets/wallpaper.webp"
  fi
}

write_qmldirs() {
  local base="$1" dir rel module f name
  while IFS= read -r -d '' dir; do
    rel="${dir#"$base"}"
    rel="${rel#/}"
    module="qs"
    [ -n "$rel" ] && module="qs.${rel//\//.}"
    {
      printf 'module %s\n' "$module"
      for f in "$dir"/*.qml; do
        [ -e "$f" ] || continue
        name="$(basename "$f" .qml)"
        [[ $name =~ ^[A-Z] ]] || continue
        if grep -q '^pragma Singleton' "$f"; then
          printf 'singleton %s 1.0 %s.qml\n' "$name" "$name"
        else
          printf '%s 1.0 %s.qml\n' "$name" "$name"
        fi
      done
    } > "$dir/qmldir"
  done < <(find "$base" -type d -not -path '*/tests*' -not -path '*/assets*' -print0)
}

overlay() {
  local dest="$1" src=/usr/lib/qt6/qml/Quickshell f
  mkdir -p "$dest"
  [ -d "$src" ] || return 0
  cp -r "$src" "$dest/"
  while IFS= read -r -d '' f; do
    sed -i '/^prefer /d' "$f"
  done < <(find "$dest/Quickshell" -name qmldir -print0)
}

lint() {
  local work rc=0 which qmllint
  qmllint="$(qtbin qmllint)"
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN
  overlay "$work/overlay"
  for which in crest crest-greeter; do
    [ -d "$root/$which" ] || continue
    assemble "$which" "$work/$which/qs"
    write_qmldirs "$work/$which/qs"
    mapfile -d '' files < <(find "$work/$which/qs" -name '*.qml' -not -path '*/tests/*' -print0)
    echo ":: qmllint $which (${#files[@]} files)"
    "$qmllint" -I "$work/$which" -I "$work/overlay" -I /usr/lib/qt6/qml --max-warnings 0 \
      --uncreatable-type disable --unused-imports info --import info --unresolved-type info \
      "${files[@]}" || rc=1
  done
  return "$rc"
}

unit() {
  local runner
  runner="$(qtbin qmltestrunner)"
  QT_QPA_PLATFORM=offscreen "$runner" -input "$root/crest/tests/unit"
}

render() {
  local out="$1" work which rc=0
  mkdir -p "$out"
  out="$(readlink -f "$out")"
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN
  for which in crest crest-greeter; do
    [ -f "$root/$which/tests/render/Harness.qml" ] || continue
    assemble "$which" "$work/$which"
    cp "$root/$which/tests/render/Harness.qml" "$work/$which/shell.qml"
    mkdir -p "$work/run-$which"
    chmod 700 "$work/run-$which"
    echo ":: render $which"
    env XDG_RUNTIME_DIR="$work/run-$which" HOME="$work/run-$which" \
      CREST_DEMO=1 CREST_RENDER_OUT="$out" CREST_RENDER_SCHEME="${CREST_RENDER_SCHEME:-}" \
      QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
      timeout -k 5 240 qs -p "$work/$which/shell.qml" --no-color || rc=1
  done
  ls -l "$out"
  return "$rc"
}

case "${1:-}" in
  lint) lint ;;
  unit) unit ;;
  render) render "${2:-render-out}" ;;
  *) echo "usage: $0 lint|unit|render [dir]" >&2; exit 2 ;;
esac
