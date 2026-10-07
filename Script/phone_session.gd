extends Node
## Runtime-only pairing credentials. Never saved into story resources or preferences.
signal changed
var settings = preload("res://Story/phone_connection.tres")
var game_relay := ""
var phone_url := ""
var speech_url := ""
var qr: Texture2D
var busy := false
var expires_at := 0.0
var message := ""
func ensure_session() -> void:
 if busy: return
 if not game_relay.is_empty() and Time.get_unix_time_from_system() * 1000 < expires_at: changed.emit(); return
 game_relay = ""
 phone_url = ""
 speech_url = ""
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
  request.queue_free(); busy = false; message = "Connection could not start (error %d)." % error; changed.emit(); return
 var result = await request.request_completed
 request.queue_free()
 busy = false
 if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 201:
  message = connection_error(int(result[0]), int(result[1])); changed.emit(); return
 var data = JSON.parse_string(result[3].get_string_from_utf8())
 if not data is Dictionary or not data.has_all(["game_relay", "phone_url", "qr_svg", "expires_at"]):
  message = "Pairing response unavailable."; changed.emit(); return
 var img := Image.new()
 if img.load_svg_from_string(data.qr_svg, 2.0) != OK:
  message = "QR could not load."; changed.emit(); return
 game_relay = data.game_relay
 speech_url = str(data.get("speech_url", ""))
 phone_url = data.phone_url
 expires_at = float(data.expires_at)
 qr = ImageTexture.create_from_image(img)
 message = "Scan to connect to this game."
 changed.emit()

func connection_error(result: int, http_status: int) -> String:
 if result == HTTPRequest.RESULT_SUCCESS:
  return "QR server returned HTTP %d. Try again shortly." % http_status
 match result:
  HTTPRequest.RESULT_CANT_RESOLVE:
   return "Cannot find the QR server. Check internet or try another network. (DNS)"
  HTTPRequest.RESULT_CANT_CONNECT:
   return "Cannot reach the QR server. Try Wi-Fi or mobile data. (CONNECT)"
  HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
   return "Secure connection failed. Check the device date and time. (TLS)"
  HTTPRequest.RESULT_TIMEOUT:
   return "QR server took too long to respond. Please retry. (TIMEOUT)"
  HTTPRequest.RESULT_CONNECTION_ERROR:
   return "Connection interrupted. Please retry. (NETWORK)"
 return "QR connection failed (network %d, HTTP %d)." % [result, http_status]
