#!/bin/sh
# Fixtures for the git write guard.
#
# Fixtures live in this file, not on a command line: the hook scans the whole Bash command
# string, so a harness that passes a blocked command as an argument is itself a command
# containing it, and the installed hook blocks the test run. The command word is assembled
# at runtime from $G so every fixture is inert on disk.
#
# Both directions matter. A guard that blocks everything is as broken as one that blocks
# nothing, and the must-pass half is what caught the anchoring bug where read-only commands
# were denied.
#
# Run: sh plugins/dev-workflow/tests/test_block_git_writes.sh

set -u
HERE=$(dirname "$0")
RULES=$HERE/../hooks/lib/git-rules.awk
G=$(printf 'g%s' 'it')
H=$(printf 'g%s' 'h')
FAILED=0
BLOCKED=0
ALLOWED=0

must_block() {
cat <<EOF
$G commit -m "add a thing"
$G commit --amend --no-edit
$G push
$G push --force origin main
$G merge main
$G rebase -i main
$G revert HEAD
$G cherry-pick abc1234
$G filter-branch --tree-filter x
$G tag v1.0.0
$G tag -a v1 -m release
$G reset --hard
$G reset --hard HEAD~1
$G checkout -b feature
$G checkout -B feature
$G switch -c feature
$G switch -C feature
$G branch -d old
$G branch -D old
$G stash drop
$G stash clear
$G stash pop
$G clean -f
$G clean -xdf
sudo $G push
$G -C /tmp/repo commit -m x
$G --git-dir=/tmp/x/.git push
cd /tmp && $G push
$G status; $G push
echo hi | $G commit -m x
$H pr create --title x
$H pr merge 12
$H release create v1.0.0
$H repo delete owner/name
$H issue close 12
EOF
}

must_pass() {
cat <<EOF
$G status
$G status --short
$G diff
$G diff --name-only HEAD
$G log --oneline -20
$G log --grep=commit
$G log --grep=push --author=someone
$G show HEAD
$G blame README.md
$G branch
$G branch -l
$G branch --list
$G tag -l
$G tag --list
$G checkout main
$G checkout -- README.md
$G switch main
$G stash
$G stash list
$G reset
$G reset HEAD~1
$G clean -n
$G clean --dry-run
$G fetch
$G remote -v
$G ls-files --others --exclude-standard
$G rev-parse --show-toplevel
echo "$G push"
$H pr view 12
$H pr list
$H repo view
$H issue list
ls -la
sh -n x.sh
EOF
}

judge() {
    printf '%s' "$1" | awk -f "$RULES" 2>/dev/null
}

must_block | while IFS= read -r fixture; do
    [ -n "$fixture" ] || continue
    [ -n "$(judge "$fixture")" ] || printf 'FAIL  should block but did not: %s\n' "$fixture"
done > "$HERE/.block.out"

must_pass | while IFS= read -r fixture; do
    [ -n "$fixture" ] || continue
    [ -z "$(judge "$fixture")" ] || printf 'FAIL  should allow but blocked: %s\n' "$fixture"
done > "$HERE/.pass.out"

BLOCKED=$(must_block | grep -c .)
ALLOWED=$(must_pass | grep -c .)
FAILED=$(cat "$HERE/.block.out" "$HERE/.pass.out" | grep -c . || true)
cat "$HERE/.block.out" "$HERE/.pass.out" >&2
rm -f "$HERE/.block.out" "$HERE/.pass.out"

if [ "$FAILED" -eq 0 ]; then
    printf 'PASSED — %s must-block, %s must-pass, 0 failures\n' "$BLOCKED" "$ALLOWED"
    exit 0
fi
printf 'FAILED — %s must-block, %s must-pass, %s failures\n' "$BLOCKED" "$ALLOWED" "$FAILED"
exit 1
