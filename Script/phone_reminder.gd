@tool
extends ColorRect

@export_group("Phone Text")
@export_multiline var reminder_text := "Keep this screen\non while playing\nthe game":
	set(value):
		reminder_text = value
		_update_preview()
@export var text_color := Color("#f3e6f8"):
	set(value):
		text_color = value
		_update_preview()
## Fractions of the phone frame. (0, 0) is top left and (1, 1) bottom right.
@export var text_center := Vector2(0.5, 0.52):
	set(value):
		text_center = value.clamp(Vector2.ZERO, Vector2.ONE)
		_update_preview()
@export_range(25.0, 96.0, 1.0) var text_width_percent := 83.0:
	set(value):
		text_width_percent = value
		_update_preview()
@export_range(3.0, 18.0, 0.1) var font_width_percent := 12.0:
	set(value):
		font_width_percent = value
		_update_preview()
@export_range(0.9, 2.0, 0.05) var text_line_height := 1.3:
	set(value):
		text_line_height = value
		_update_preview()

func _ready() -> void:
	resized.connect(_update_preview)
	_update_preview()

func _update_preview() -> void:
	if not is_node_ready():
		return
	var label: Label = $Reminder
	var font_size := roundi(size.x * font_width_percent / 100.0)
	label.text = reminder_text
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_font_size_override("font_size", font_size)
	var font := label.get_theme_font("font")
	label.add_theme_constant_override("line_spacing", roundi(font_size * text_line_height - font.get_height(font_size)))
	label.size = Vector2(size.x * text_width_percent / 100.0, 0.0)
	label.position = text_center * size - label.size * 0.5

func browser_style() -> Dictionary:
	var frame_size := Vector2(offset_right - offset_left, offset_bottom - offset_top).max(Vector2.ONE)
	var layers := []
	for art: TextureRect in [$Curtain, $Rails, $Bottom, $Top]:
		var left := art.anchor_left + art.offset_left / frame_size.x
		var top := art.anchor_top + art.offset_top / frame_size.y
		var right := art.anchor_right + art.offset_right / frame_size.x
		var bottom := art.anchor_bottom + art.offset_bottom / frame_size.y
		layers.append([left, top, right - left, bottom - top, art.modulate.a * art.self_modulate.a if art.visible else 0.0])
	return {
		"layers": layers,
		"text": reminder_text.left(500),
		"background": "#" + color.to_html(),
		"color": "#" + text_color.to_html(),
		"x": text_center.x,
		"y": text_center.y,
		"width": text_width_percent,
		"fontSize": font_width_percent,
		"lineHeight": text_line_height,
	}
