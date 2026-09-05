#!/bin/bash
# Rebuild the site and put it live.
#   ./publish.sh "what changed"
# Rebuilds all four pages from build/site.py, commits, pushes, and waits
# for GitHub Pages to finish deploying before telling you it is live.
set -e
export PATH="/opt/homebrew/bin:$PATH"
cd "$(dirname "$0")"

MSG="${1:-Update site}"

echo "==> building"
python3 build/site.py

if [ -z "$(git status --porcelain)" ]; then
  echo "==> nothing changed; already published"
  exit 0
fi

echo "==> committing"
git add -A
git -c user.name="Igor Kolesnikov" -c user.email="igor_kolesnikov@berkeley.edu" \
    commit -q -m "$MSG"

echo "==> pushing"
git push -q origin main
TARGET=$(git rev-parse --short=8 HEAD)
echo "    commit $TARGET"

echo "==> waiting for GitHub Pages"
for i in $(seq 1 30); do
  OUT=$(gh api repos/IgorUCB/IgorUCB.github.io/pages/builds/latest 2>/dev/null \
        | python3 -c "import json,sys;d=json.load(sys.stdin);print((d.get('commit') or '')[:8]+','+str(d.get('status')))" 2>/dev/null || echo ",")
  C="${OUT%%,*}"; S="${OUT##*,}"
  if [ "$C" = "$TARGET" ] && [ "$S" = "built" ]; then
    echo ""
    echo "    LIVE  https://igorucb.github.io/?v=$(date +%s)"
    echo "    (plain URL is cached for 10 min: hard-refresh with Cmd+Shift+R)"
    exit 0
  fi
  [ "$S" = "errored" ] && { echo "    BUILD FAILED"; exit 1; }
  curl -s -o /dev/null --max-time 12 "https://igorucb.github.io/?w=$i" || true
done
echo "    still building; check https://github.com/IgorUCB/IgorUCB.github.io/actions"
