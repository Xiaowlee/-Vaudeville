extends CheckButton

## Type this sequence while this Settings panel is open.
@export var reveal_code := "awooo"

var typed := ""

func _ready() -> void:
	reset_access()
	toggled.connect(func(value: bool): PhoneSession.set_meta("developer_mode", value))

func reset_access() -> void:
	typed = ""
	visible = bool(PhoneSession.get_meta("developer_unlocked", false))
	set_pressed_no_signal(bool(PhoneSession.get_meta("developer_mode", false)))

func accept_code(event: InputEvent) -> void:
	if visible or reveal_code.is_empty():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		typed = ""
		return
	if event.unicode == 0:
		return
	var code := reveal_code.to_lower()
	typed = (typed + String.chr(event.unicode).to_lower()).right(code.length())
	if typed == code:
		PhoneSession.set_meta("developer_unlocked", true)
		show()
