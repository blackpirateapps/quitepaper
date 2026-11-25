#!/usr/bin/env bash
# Headless, relocatable packaged-CLI smoke using a disposable notebook only.
set -euo pipefail
cli=$(realpath "${1:?Path to packaged Rust qp}")
workspace=$(mktemp -d)
trap 'rm -rf "$workspace"' EXIT
mkdir -p "$workspace/home" "$workspace/data" "$workspace/relocated/bin"
export HOME="$workspace/home"
export XDG_DATA_HOME="$workspace/data"
unset QP_DB QP_API_URL LD_LIBRARY_PATH
cp "$cli" "$workspace/relocated/bin/qp"
cli="$workspace/relocated/bin/qp"
"$cli" --version | grep -F '(Rust)'
"$cli" --help >/dev/null
if ldd "$cli" | grep -E 'not found|libflutter|libdart'; then
  echo 'Rust CLI has missing dependencies or an unexpected UI runtime dependency' >&2
  exit 1
fi
database="$workspace/notebook.sqlite"
printf '# Packaged Rust CLI\n\nOffline #smoke\n' | "$cli" --db "$database" new
"$cli" --db "$database" list --json > "$workspace/notes.json"
note_id=$(python3 - "$workspace/notes.json" <<'PY'
import json, sys
notes=json.load(open(sys.argv[1]))
assert len(notes)==1 and notes[0]['title']=='Packaged Rust CLI'
assert notes[0]['tags']==['smoke']
print(notes[0]['id'])
PY
)
"$cli" --db "$database" show "$note_id" --raw | grep -F 'Offline #smoke'
"$cli" --db "$database" tags --json | python3 -c 'import json,sys; assert json.load(sys.stdin)[0]["noteCount"]==1'
"$cli" --db "$database" attachments "$note_id" --json | python3 -c 'import json,sys; assert json.load(sys.stdin)==[]'
"$cli" --db "$database" delete "$note_id"
"$cli" --db "$database" delete --restore "$note_id"
"$cli" --db "$database" delete --permanent "$note_id"
python3 - "$database" <<'PY'
import sqlite3, sys
db=sqlite3.connect(sys.argv[1])
assert db.execute('PRAGMA user_version').fetchone()[0]==25
assert db.execute('SELECT COUNT(*) FROM notes').fetchone()[0]==0
assert db.execute("SELECT COUNT(*) FROM sync_queue WHERE operation='delete'").fetchone()[0]==1
PY
echo 'PASS: relocated Rust CLI reads and writes a disposable notebook without Flutter/Dart'
