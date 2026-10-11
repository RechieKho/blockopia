#!/bin/sh
# Starts the Blockopia server in the container.
#
# /data (a volume) keeps everything that must survive an update:
#   /data/pack/db/, /data/pack/storage.json   the pack's vb.db / vb.storage (accounts, locks, ...)
#   /data/world/                              the saved world
#   /data/world_seed                          the world seed, chosen once (or WORLD_SEED)
#   /data/server.toml                         generated below on every start
# The pack itself is copied from the image on every start, so a new image brings new code.
set -eu

pack=/data/pack
mkdir -p "$pack" /data/world
rsync -a --delete \
	--exclude '/db/' --exclude '/storage.json' \
	--exclude '/.*' --exclude '/ops/' --exclude '/world/' \
	/opt/blockopia/ "$pack/"

if [ "${BLOCKOPIA_NO_AUTH:-0}" = "1" ]; then
	# Sign-in off: anyone may join under any name (accounts are keyed by name). LAN/testing only.
	rm -f "$pack/auth.lua"
	echo "blockopia: *** BLOCKOPIA_NO_AUTH=1: sign-in is OFF, anyone can join as anyone ***" >&2
elif [ -z "${AUTH_ISSUER:-}" ]; then
	echo "blockopia: AUTH_ISSUER is not set (e.g. https://id.example.com/realms/blockopia)" >&2
	exit 1
fi

# The seed must stay the same for a saved world, or new chunks would not match the saved ones.
if [ -n "${WORLD_SEED:-}" ]; then
	seed=$WORLD_SEED
elif [ -s /data/world_seed ]; then
	seed=$(cat /data/world_seed)
else
	seed=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
	seed=$((seed + 1)) # 0 would mean "random on every start"
	echo "$seed" > /data/world_seed
fi

toml_string() {
	# a TOML basic string: escape backslashes and quotes
	printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

{
	echo "bind_address = \"0.0.0.0\""
	echo "port = ${GAME_PORT:-7777}"
	echo "content_pack = \"$pack\""
	echo "world_dir = \"/data/world\""
	echo "persist_world = true"
	echo "world_seed = $seed"
	echo "max_players = ${MAX_PLAYERS:-32}"
	echo "tick_rate = 20"
	echo "view_distance = ${VIEW_DISTANCE:-6}"
	echo "max_connections_per_ip = ${MAX_CONNECTIONS_PER_IP:-4}"
	# 0 = no per-connection message limit. The engine counts every message, and a client sends one
	# input message per rendered frame, so any limit below the players' frame rates silently drops
	# their chat and UI clicks (engine 0.1.5).
	echo "max_messages_per_second = ${MAX_MESSAGES_PER_SECOND:-0}"
	echo "autosave_interval_seconds = 60.0"
	echo "motd = $(toml_string "${MOTD:-Welcome to Blockopia}")"
	if [ "${BLOCKOPIA_NO_AUTH:-0}" != "1" ]; then
		echo
		echo "[auth]"
		echo "issuer = $(toml_string "$AUTH_ISSUER")"
		echo "client_id = $(toml_string "${AUTH_CLIENT_ID:-blockopia-game}")"
	fi
} > /data/server.toml

exec voxel_browser_server --config /data/server.toml "$@"
