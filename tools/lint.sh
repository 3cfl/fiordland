#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
failed=0

need() {
  command -v "$1" >/dev/null || { echo "missing tool: $1" >&2; exit 2; }
}

shell_scripts() {
  local f first
  git ls-files -z | while IFS= read -r -d '' f; do
    [ "$f" = iso/profiledef.sh ] && continue
    [ -f "$f" ] || continue
    first=
    IFS= read -r first < "$f" || true
    if [[ $f == *.sh || $first =~ ^#!.*(ba)?sh([[:space:]]|$) ]]; then
      printf '%s\0' "$f"
    fi
  done
}

lint_shell() {
  shell_scripts | xargs -0 -r shellcheck
}

lint_packages() {
  git ls-files -z -- '*PKGBUILD' '*.install' | xargs -0 -r shellcheck -s bash -e SC2034,SC2154,SC2164
}

lint_yaml() {
  git ls-files -z -- '*.yml' '*.yaml' | xargs -0 -r yamllint --strict -c .yamllint.yml
}

lint_github() {
  local rc=0 forms
  mapfile -t forms < <(git ls-files -- '.github/ISSUE_TEMPLATE/*.yml' ':!:.github/ISSUE_TEMPLATE/config.yml')
  check-jsonschema --builtin-schema vendor.github-workflows .github/workflows/*.yml || rc=1
  check-jsonschema --builtin-schema vendor.github-issue-config .github/ISSUE_TEMPLATE/config.yml || rc=1
  check-jsonschema --builtin-schema vendor.github-issue-forms "${forms[@]}" || rc=1
  return "$rc"
}

lint_python() {
  git ls-files -z -- '*.py' | xargs -0 -r python3 -c 'import ast, sys
for f in sys.argv[1:]:
    ast.parse(open(f).read(), f)'
}

lint_json() {
  git ls-files -z -- '*.json' | xargs -0 -r python3 -c 'import json, sys
for f in sys.argv[1:]:
    json.load(open(f))'
}

need shellcheck
need yamllint
need check-jsonschema
echo ":: shellcheck scripts"
lint_shell || failed=1
echo ":: shellcheck PKGBUILDs and install scripts"
lint_packages || failed=1
echo ":: yamllint"
lint_yaml || failed=1
echo ":: github workflow and issue form schemas"
lint_github || failed=1
echo ":: json"
lint_json || failed=1
echo ":: python syntax"
lint_python || failed=1
exit "$failed"
