#!/bin/sh
# Starts the Blockopia server in the container.
#
# /data (a volume) keeps everything that must survive an update:
#   /data/pack/db/, /data/pack/storage.json   the pack's vb.db / vb.storage (accounts, locks, ...)
#   /data/world/                              the saved world
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
	echo "max_players = ${MAX_PLAYERS:-32}"
	echo "tick_rate = 20"
	echo "view_distance = ${VIEW_DISTANCE:-6}"
	echo "max_connections_per_ip = ${MAX_CONNECTIONS_PER_IP:-4}"
	echo "max_messages_per_second = 60.0"
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
