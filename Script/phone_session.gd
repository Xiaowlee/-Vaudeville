extends Node
## Runtime-only pairing credentials. Never saved into story resources or preferences.
signal changed
var settings = preload("res://Story/phone_connection.tres")
var game_relay := ""
var phone_url := ""
var qr: Texture2D
var busy := false
var expires_at := 0.0
var message := ""
func ensure_session() -> void:
 if busy: return
 if not game_relay.is_empty() and Time.get_unix_time_from_system() * 1000 < expires_at: changed.emit(); return
 game_relay = ""
 phone_url = ""
 qr = null
 var origin: String = settings.relay_server.trim_suffix("/")
 if OS.has_feature("web"):
  # The website passes its configured relay in the page fragment; otherwise the page's own address (single-host setup).
  var from_page := str(JavaScriptBridge.eval("new URLSearchParams(window.location.hash.slice(1)).get('relay_origin') || ''", true))
  if from_page.begins_with("https://") or from_page.begins_with("http://localhost:"): origin = from_page.trim_suffix("/")
  elif origin.is_empty(): origin = str(JavaScriptBridge.eval("window.location.origin", true))
 if origin.is_empty():
  message = "Phone connection is not configured yet."
  changed.emit()
  return
 busy = true
 message = "Connecting..."
 changed.emit()
 var request := HTTPRequest.new()
 add_child(request)
 request.timeout = 90
 var error := request.request(origin + "/api/pair", PackedStringArray(), HTTPClient.METHOD_POST)
 if error != OK:
  request.queue_free(); busy = false; message = "Connection unavailable. Try again."; changed.emit(); return
 var result = await request.request_completed
 request.queue_free()
 busy = false
 if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 201:
  message = "Connection unavailable. Try again."; changed.emit(); return
 var data = JSON.parse_string(result[3].get_string_from_utf8())
 if not data is Dictionary or not data.has_all(["game_relay", "phone_url", "qr_svg", "expires_at"]):
  message = "Pairing response unavailable."; changed.emit(); return
 var img := Image.new()
 if img.load_svg_from_string(data.qr_svg, 2.0) != OK:
  message = "QR could not load."; changed.emit(); return
 game_relay = data.game_relay
 phone_url = data.phone_url
 expires_at = float(data.expires_at)
 qr = ImageTexture.create_from_image(img)
 message = "Scan to connect to this game."
 changed.emit()
