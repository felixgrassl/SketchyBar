#!/bin/bash
# Rebase the `custom` branch onto the newest upstream release, build it and
# install it over the Homebrew binary.
#
#   ./install-custom.sh           # newest upstream release tag
#   ./install-custom.sh v2.25.0   # a specific tag or ref
#
# Homebrew's sketchybar is pinned, so `brew upgrade` does not overwrite this
# build. Run this script to get a new upstream version instead.
set -euo pipefail
cd "$(dirname "$0")"

# Sign with a real certificate, not ad hoc. An ad hoc signature changes on
# every build, so macOS forgets the Accessibility permission each time.
SIGN_IDENTITY="${SIGN_IDENTITY:-2BEAB39BACC99D672B01C65DDDC3C4DA71A11A23}"  # Apple Development: Felix Grassl

git fetch -q upstream --tags
target="${1:-$(git tag --sort=-v:refname | grep -E '^v[0-9.]+$' | head -1)}"

git checkout -q custom
echo "Rebasing custom onto $target ..."
if ! git rebase "$target"; then
  echo "Rebase conflict. Fix it, run 'git rebase --continue', then run this script again." >&2
  exit 1
fi
git log --oneline "$target"..custom

make clean >/dev/null
make arm64 >/dev/null

bin="$(realpath "$(brew --prefix sketchybar)/bin/sketchybar")"
chmod u+w "$bin"
cp bin/sketchybar "$bin"
codesign -f -s "$SIGN_IDENTITY" -i com.felixkratz.sketchybar "$bin"
chmod a-w "$bin"
brew services restart sketchybar

git push -q --force-with-lease origin custom
echo "Installed custom sketchybar on $target."
