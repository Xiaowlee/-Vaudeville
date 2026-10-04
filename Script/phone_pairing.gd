extends Control
func _ready() -> void:
	PhoneSession.changed.connect(_refresh)
	$ConnectPhone.pressed.connect(func(): $Card.show(); PhoneSession.ensure_session(); $Card/Lines/Close.grab_focus())
	$Card/Lines/Close.pressed.connect(func(): $Card.hide(); $ConnectPhone.grab_focus())
	_refresh()
func _refresh() -> void:
	$Card/Lines/QR.texture = PhoneSession.qr
	$Card/Lines/QR.visible = PhoneSession.qr != null
	$Card/Lines/Address.text = PhoneSession.phone_url.get_slice("#",0)
	$Card/Lines/Wifi.text = PhoneSession.message
