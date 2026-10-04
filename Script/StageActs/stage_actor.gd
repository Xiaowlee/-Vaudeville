@tool
extends Control
@export var identity: ActorDefinition
@export_node_path("Sprite2D") var static_visual_path := NodePath("Folio2Character"):
	set(value):
		static_visual_path = value
		refresh_visual()
@export var face_left := false:
	set(value):
		face_left = value
		refresh_visual()
@export var visual_texture: Texture2D:
	set(value):
		visual_texture = value
		refresh_visual()
func _ready() -> void:
	refresh_visual()
func refresh_visual() -> void:
	if not is_inside_tree(): return
	for child in get_children():
		if child is Sprite2D:
			child.visible = child == get_node_or_null(static_visual_path)
			if child.visible:
				child.flip_h = face_left
				if visual_texture != null: child.texture = visual_texture
	var sprite = get_node_or_null("Sprite")
	if sprite != null: sprite.flip_h = face_left
func play_voice(stream: AudioStream) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = $Voice
	player.stop()
	player.stream = stream
	if stream != null: player.play()
	return player

@export_node_path("AnimatedSprite2D") var sprite_path := NodePath("Sprite")
@export_node_path("AnimationPlayer") var animation_player_path := NodePath("AnimationPlayer")
func apply_action(action: StageActorAction) -> void:
	if action.visibility == 1: show()
	elif action.visibility == 2: hide()
	if action.animation.is_empty(): return
	var player: AnimationPlayer = get_node(animation_player_path)
	var sprite: AnimatedSprite2D = get_node(sprite_path)
	if player.has_animation(action.animation): player.play(action.animation)
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation(action.animation):
		for child in get_children():
			if child is Sprite2D: child.hide()
		sprite.show()
		sprite.play(action.animation)
	else: push_warning("[Stage animation] Missing animation: " + str(action.animation))
