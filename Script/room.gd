extends Control
## Edit AnimatedSprite2D/SpriteFrames directly: standby loops; action runs once.
@export_node_path("AnimatedSprite2D") var sprite_path := NodePath("AnimatedSprite2D")
@export var debug_logging := true
@export var standby_animation: StringName = &"standby"
@export var action_animation: StringName = &"" # Assign when the light-on sheet is supplied.
@export var return_to_standby := false
## Optional synchronized layers, such as a separate animated headphone object.
@export var action_layers: Array[NodePath] = []
@export_range(0.0, 1.0) var light_amount := 0.0:
	set(value):
		light_amount = value
		if is_node_ready(): get_node(sprite_path).modulate.a = value
var has_played := false

func _ready() -> void:
	var sprite: AnimatedSprite2D = get_node(sprite_path)
	sprite.sprite_frames = sprite.sprite_frames.duplicate(true)
	if sprite.sprite_frames.has_animation(standby_animation):
		sprite.sprite_frames.set_animation_loop(standby_animation, true)
		sprite.play(standby_animation)
		_log("Standby looping: " + str(standby_animation))
	light_amount = 0.0

func play_once() -> void:
	if has_played: return
	has_played = true
	var sprite: AnimatedSprite2D = get_node(sprite_path)
	if not action_animation.is_empty() and sprite.sprite_frames.has_animation(action_animation):
		sprite.sprite_frames.set_animation_loop(action_animation, false)
		for path in action_layers:
			var layer := get_node(path) as AnimatedSprite2D
			layer.sprite_frames = layer.sprite_frames.duplicate(true)
			layer.sprite_frames.set_animation_loop(layer.animation, false)
			layer.play()
		_log("Action playing once: " + str(action_animation))
		sprite.play(action_animation)
		await sprite.animation_finished
		for path in action_layers:
			var layer := get_node(path) as AnimatedSprite2D
			if layer.is_playing(): await layer.animation_finished
		if return_to_standby: sprite.play(standby_animation)
		_log("Returned to standby" if return_to_standby else "Action finished; holding final frame")
	# With no supplied action sheet, the existing light_on AnimationPlayer is the response.

func _log(detail: String) -> void:
	if debug_logging: print("[Animation][", get_path(), "] ", detail)
