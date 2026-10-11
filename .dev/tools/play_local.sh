#!/bin/sh
# Plays Blockopia locally in singleplayer, without Keycloak.
#
# A pack with an auth.lua always needs Keycloak, even in singleplayer.
# This copies the pack, minus auth.lua, to .dev/local/pack and starts singleplayer on the copy.
# Run it again after editing the pack. The copy's world and storage are kept between runs; delete
# .dev/local/ to start over. Extra arguments go to the client.
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
local_dir="$root/.dev/local"
pack="$local_dir/pack"
mkdir -p "$pack" "$local_dir/world"

if command -v rsync >/dev/null 2>&1; then
	# --delete keeps removed files out of the copy; the excludes also protect the copy's own state.
	rsync -a --delete \
		--exclude '/.*' --exclude '/auth.lua' \
		--exclude '/storage.json' --exclude '/db/' --exclude '/world/' \
		"$root/" "$pack/"
else
	for entry in "$root"/*; do
		name=$(basename "$entry")
		case "$name" in
		auth.lua | storage.json | db | world) continue ;;
		esac
		rm -rf "${pack:?}/$name"
		cp -R "$entry" "$pack/$name"
	done
fi

exec vb launch -- --singleplayer --content-pack "$pack" --world-dir "$local_dir/world" "$@"
