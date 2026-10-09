#!/bin/bash
# atlas-protocol: names, spoken-phrase parsing (no side effects), state checks and the bar widget JSON.
# Engaging a protocol changes the live desktop, so that part lives in live-check.sh, not here.
cd "$(dirname "$0")" && source ./lib.sh
PROTO=${ATLAS_PROTOCOL:-$HOME/.local/bin/atlas-protocol}
H=$(sandbox_home); trap 'rm -rf "$H"' EXIT
cp -r "$HOME/.config/atlas-protocol" "$H/.config/"
p() { HOME=$H "$PROTO" "$@"; }
setcur() { mkdir -p "$H/.local/state/atlas-protocol"; echo "$1" > "$H/.local/state/atlas-protocol/current"; }

echo "atlas-protocol"
eq "list order" $'standard\ndeadlock\nfocus\nvibe' "$(p list)"
eq "show defaults to standard" standard "$(p show)"

# Spoken commands resolve without engaging anything.
r() { p resolve "$1" 2>/dev/null; }
eq "Atlas, initiate Deadlock Protocol" deadlock "$(r 'Atlas, initiate Deadlock Protocol')"
eq "Atlas ignitiate standard protocol" standard "$(r 'Atlas ignitiate standard protocol')"
eq "engage focus protocol please" focus "$(r 'engage focus protocol please')"
eq "Vibe" vibe "$(r 'Vibe')"
eq "Hey Atlas, activate house party protocol" vibe "$(r 'Hey Atlas, activate house party protocol')"
eq "code red" deadlock "$(r 'code red')"
eq "violet" vibe "$(r 'violet')"
eq "lets go into vibe code mode" vibe "$(r "let's go into vibe code mode")"
eq "vibe coding" vibe "$(r 'vibe coding')"
fails "self destruct is rejected" p resolve "self destruct"
fails "empty phrase is rejected" p resolve ""
ok "resolve engages nothing" test ! -e "$H/.local/state/atlas-protocol/current"

for n in standard deadlock focus vibe; do
  setcur "$n"
  ok "is $n" p is "$n"
  json=$(p status)
  ok "status JSON valid ($n)" python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert set(d)=={"text","tooltip","class"}' "$json"
  eq "status class ($n)" "$n" "$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["class"])' "$json")"
done
setcur vibe; fails "is standard while vibe" p is standard

# list --json feeds the bar panel's tiles: every profile with its own colors, the active one marked.
lj=$(p list --json)
ok "list --json is valid JSON" python3 -c 'import json,sys; json.loads(sys.argv[1])' "$lj"
eq "list --json order" "standard deadlock focus vibe" \
  "$(python3 -c 'import json,sys; print(" ".join(x["name"] for x in json.loads(sys.argv[1])))' "$lj" 2>/dev/null)"
eq "list --json fields" "accent active desc icon label name" \
  "$(python3 -c 'import json,sys; print(" ".join(sorted(set().union(*[x.keys() for x in json.loads(sys.argv[1])]))))' "$lj" 2>/dev/null)"
eq "list --json marks only the active one" "vibe" \
  "$(python3 -c 'import json,sys; print(" ".join(x["name"] for x in json.loads(sys.argv[1]) if x["active"] is True))' "$lj" 2>/dev/null)"
ok "list --json accents are #rrggbb" python3 -c 'import json,re,sys; assert all(re.fullmatch(r"#[0-9a-fA-F]{6}", x["accent"]) for x in json.loads(sys.argv[1]))' "$lj"
eq "list --json carries each profile's own accent (deadlock)" "#ff3b3b" \
  "$(python3 -c 'import json,sys; print(next(x["accent"] for x in json.loads(sys.argv[1]) if x["name"]=="deadlock"))' "$lj" 2>/dev/null)"
eq "list --json label is title case" "Deadlock" \
  "$(python3 -c 'import json,sys; print(next(x["label"] for x in json.loads(sys.argv[1]) if x["name"]=="deadlock"))' "$lj" 2>/dev/null)"
eq "list --json changes nothing" vibe "$(p show)"
setcur bogus
ok "status survives a corrupt state file" python3 -c 'import json,sys; json.loads(sys.argv[1])' "$(p status 2>/dev/null)"
eq "show falls back to standard on a corrupt state file" standard "$(p show)"
fails "unknown command is an error" p sparkles
finish
