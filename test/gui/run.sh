#!/bin/sh
# Run the checks in test/gui and report PASS, FAIL or SKIP for each.
#
#   test/gui/run.sh [CHECK...]
#
# CHECK is a file name such as check-revert.el; all checks run by
# default.  EMACS names the Emacs to run (default: emacs); it must be
# able to open a graphical frame.  Reports go to GUI_CHECK_OUT (default:
# $TMPDIR/pdf-tools-gui-checks).  A check that takes longer than
# GUI_CHECK_TIMEOUT seconds (default: 300) is stopped and fails.

cd "$(dirname "$0")" || exit 2
EMACS=${EMACS:-emacs}
TIMEOUT=${GUI_CHECK_TIMEOUT:-300}
OUT=${GUI_CHECK_OUT:-${TMPDIR:-/tmp}/pdf-tools-gui-checks}
export GUI_CHECK_OUT="$OUT"
mkdir -p "$OUT"

# These need no graphical frame and run in batch.
BATCH="check-page-sizes.el check-long-document.el check-nested-query.el"

[ $# -gt 0 ] || set -- check-*.el
failed=0
for check in "$@"; do
    name=${check%.el}
    rm -f "$OUT/$name.out"
    case " $BATCH " in
        *" $check "*) "$EMACS" -Q -batch -l "$PWD/$check" >/dev/null 2>&1 & ;;
        *) "$EMACS" -Q -l "$PWD/$check" >/dev/null 2>&1 & ;;
    esac
    pid=$!
    waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$TIMEOUT" ]; do
        sleep 1
        waited=$((waited + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        echo "FAIL $name (stopped after $TIMEOUT s)"
        failed=1
    elif [ -f "$OUT/$name.out" ]; then
        head -1 "$OUT/$name.out"
        grep -q '^PASS\|^SKIP' "$OUT/$name.out" || failed=1
    else
        echo "FAIL $name (no report)"
        failed=1
    fi
done
echo "Reports: $OUT"
exit $failed
