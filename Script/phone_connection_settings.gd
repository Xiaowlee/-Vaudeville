extends Resource
## Public HTTPS address of the relay/pairing server, without a path (e.g. https://vaudeville-relay.onrender.com).
## Set before exporting the desktop game. Browser builds use the website's NEXT_PUBLIC_RELAY_ORIGIN when provided.
@export var relay_server: String = ""
