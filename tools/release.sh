#!/bin/bash
# Publish a new A.T.L.A.S OS version.
#
#   tools/release.sh <major|minor|patch> "<title>" <notes.md>
#
#   minor → new features      patch → fixes only      major → big rework
#
# Bumps VERSION (repo + this machine's ~/.local/share/atlas/VERSION), adds the
# notes to the top of CHANGELOG.md, runs tools/snapshot.sh (which stops on any
# secret-looking match), commits, tags vX.Y.Z, pushes, and creates the GitHub
# release with the same notes.
set -euo pipefail
KIT=$(cd "$(dirname "$0")/.." && pwd)
LEVEL=${1:?usage: tools/release.sh <major|minor|patch> "<title>" <notes.md>}
TITLE=${2:?missing title}
NOTES=${3:?missing notes file}
[[ -s $NOTES ]] || { echo "notes file is empty: $NOTES" >&2; exit 1; }
cd "$KIT"
[[ -z $(git status --porcelain -- VERSION CHANGELOG.md) ]] || { echo "VERSION/CHANGELOG.md have uncommitted edits" >&2; exit 1; }

IFS=. read -r MA MI PA < VERSION
case $LEVEL in
  major) MA=$((MA + 1)); MI=0; PA=0 ;;
  minor) MI=$((MI + 1)); PA=0 ;;
  patch) PA=$((PA + 1)) ;;
  *) echo "level must be major, minor or patch" >&2; exit 1 ;;
esac
NEW="$MA.$MI.$PA"
git rev-parse -q --verify "refs/tags/v$NEW" >/dev/null && { echo "tag v$NEW already exists" >&2; exit 1; }

echo "$NEW" > VERSION
mkdir -p "$HOME/.local/share/atlas" && echo "$NEW" > "$HOME/.local/share/atlas/VERSION"
{ head -n 2 CHANGELOG.md
  printf '## v%s: %s (%s)\n\n' "$NEW" "$TITLE" "$(date +%Y-%m-%d)"
  sed -E 's/^## /### /' "$NOTES"; echo
  tail -n +3 CHANGELOG.md; } > CHANGELOG.md.new && mv CHANGELOG.md.new CHANGELOG.md

tools/snapshot.sh
git add -A
git commit -q -m "v$NEW: $TITLE"
git tag -a "v$NEW" -m "A.T.L.A.S OS v$NEW"
git push -q && git push -q origin "v$NEW"
gh release create "v$NEW" --title "v$NEW: $TITLE" --notes-file "$NOTES" --latest
echo "Released A.T.L.A.S OS v$NEW"
