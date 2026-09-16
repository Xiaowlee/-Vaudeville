extends Button
## The card itself moves; its Button styles remain editable in WordCard.tscn.
signal released(card: Control)
signal drag_moved(card: Control)
@export_range(1.0, 60.0) var follow_speed := 28.0
@export_range(0.05, 1.0) var snap_back_seconds := 0.25
var dragging := false
var locked := false
var origin := Vector2.ZERO
var click_offset := Vector2.ZERO
var return_tween: Tween

func _ready() -> void:
	gui_input.connect(_card_input)
	origin = position

func _card_input(event: InputEvent) -> void:
	if locked: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if return_tween != null: return_tween.kill()
		click_offset = get_global_mouse_position() - global_position
		dragging = true
		z_index = 20
		accept_event()

func _process(delta: float) -> void:
	if not dragging: return
	global_position = global_position.lerp(get_global_mouse_position() - click_offset, 1.0 - exp(-follow_speed * delta))
	drag_moved.emit(self)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		dragging = false
		released.emit(self)

func return_home() -> void:
	dragging = false
	z_index = 0
	return_tween = create_tween()
	return_tween.tween_property(self, "position", origin, snap_back_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func snap_to(point: Vector2) -> void:
	dragging = false
	locked = true
	disabled = true
	z_index = 0
	global_position = point
	mouse_filter = Control.MOUSE_FILTER_IGNORE
