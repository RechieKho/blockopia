-- Keycloak sign-in. A pack with an auth.lua makes sign-in MANDATORY: the engine opens the
-- player's browser on the Keycloak login page, verifies the ID token before sending any world
-- data, and gives the pack player:get_login(). No secret belongs here (public client + PKCE).
--
-- Set up Keycloak with ops/keycloak/ (docker compose up). For another host, override without
-- touching the pack, in server.toml:
--   [auth]
--   issuer    = "https://id.example.com/realms/blockopia"
--   client_id = "blockopia-game"
-- For local development without Keycloak run the server with --insecure-skip-auth.
return {
	provider = "keycloak",
	display_name = "Blockopia",
	issuer = "http://localhost:8080/realms/blockopia",
	client_id = "blockopia-game",
	scopes = { "openid", "profile" },
	name_claim = "preferred_username",
	claims = { "groups" },
}
