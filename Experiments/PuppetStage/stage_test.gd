@tool
extends Node2D
@export_group("Stage frame")
## Reference composition size. Scenery fills the window; performers retain their proportions.
@export var design_size := Vector2(1280,720)
@export_range(0,240,1) var controls_height := 110.0
@export var show_editor_frame := true
## Preview sizes are checks of the SAME composition, not separate layouts.
@export_enum("16:9", "16:10", "Ultrawide", "Custom") var editor_screen := 0
@export var custom_preview_size := Vector2(1280,800)
@export var backdrop_color := Color(0.56,0.52,0.76,1)
var stage_rect := Rect2()
var screen_size := Vector2(1280,720)
@export_group("Artwork")
@export_enum("Sprite sheet", "Individual files") var artwork_source := 1
@export_group("Depth")
@export_range(0,2,0.05) var depth_strength := 1.0
@export_range(1,20,0.5) var smoothing := 6.0
@export_enum("Mouse", "Slow automatic", "Flat / off") var movement_mode := 0
var aim := Vector2.ZERO
var clock := 0.0
var actors: Array
func _ready():
	if Engine.is_editor_hint():return
	actors=[$World/Performers/Player,$World/Performers/Actor1,$World/Performers/StageManager]
	$Controls/Panel/Rows/Buttons/Source.select(artwork_source)
	change_source(artwork_source)
	$Controls/Panel/Rows/Buttons/Depth.value=depth_strength
	$Controls/Panel/Rows/Buttons/Mode.select(movement_mode)
	$Controls/Panel/Rows/Buttons/Talk.toggled.connect(func(value):
		for actor in actors:actor.set_talking(value))
	$Controls/Panel/Rows/Buttons/Flip.pressed.connect(flip_all)
	$Controls/Panel/Rows/Buttons/Mode.item_selected.connect(func(index):movement_mode=index)
	$Controls/Panel/Rows/Buttons/Source.item_selected.connect(change_source)
	$Controls/Panel/Rows/Buttons/Depth.value_changed.connect(func(value):depth_strength=value)
	$Controls/Panel/Rows/Buttons/Back.pressed.connect(func():get_tree().change_scene_to_file("res://Scene/00_main_menu.tscn"))
func _unhandled_key_input(event):
	if event.pressed and not event.echo and event.keycode==KEY_SPACE:
		flip_all()
		get_viewport().set_input_as_handled()
func flip_all():
	for actor in actors:actor.flip()
func change_source(index: int):
	if actors.any(func(actor):return actor.flipping):
		$Controls/Panel/Rows/Buttons/Source.select(0 if actors[0].use_sheet else 1)
		return
	for actor in actors:actor.set_source(index==0)
	$Controls/Panel/Rows/Note.text="Sheet: two different poses per character." if index==0 else "Individual files: updated poses, two per character."
func _process(delta):
	if not has_node("World"):return
	screen_size=get_viewport_rect().size
	if Engine.is_editor_hint():
		screen_size=[Vector2(1280,720),Vector2(1280,800),Vector2(1680,720),custom_preview_size][editor_screen]
	apply_layout(screen_size)
	if Engine.is_editor_hint():return
	clock+=delta
	var target=Vector2.ZERO
	if movement_mode==0:
		target=(get_viewport().get_mouse_position()-stage_rect.get_center())/(stage_rect.size*0.5)
		target=target.clamp(Vector2(-1,-1),Vector2(1,1))
	elif movement_mode==1:target=Vector2(sin(clock*0.45),cos(clock*0.31)*0.45)
	aim=aim.lerp(target*depth_strength,1.0-exp(-smoothing*delta))
	for layer in $World.get_children():
		if layer.has_method("aim"):layer.aim(aim)

func apply_layout(size: Vector2):
	var panel=$Controls/Panel
	var toolbar=maxf(controls_height,panel.get_combined_minimum_size().y)
	var available=Vector2(maxf(size.x,1),maxf(size.y,1))
	var fit=minf(available.x/maxf(design_size.x,1),available.y/maxf(design_size.y,1))
	stage_rect=Rect2(Vector2.ZERO,available)
	$World.scale=Vector2.ONE
	$World.position=available*0.5
	# Characters and floor share a uniform scale. Surrounding scenery follows
	# both screen edges independently, like left/right + top/bottom constraints.
	var edge_scale=available/design_size
	for layer in $World.get_children():
		if layer.name in ["Performers", "Floor"]:
			layer.scale=Vector2.ONE*fit
		elif layer.name not in ["Backdrop", "Lighting"]:
			layer.scale=edge_scale
	$World/Backdrop.visible=false
	queue_redraw()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position=Vector2(0,maxf(size.y-toolbar,0))
	panel.size=Vector2(size.x,toolbar)

func _draw():
	# Continuous backing prevents transparent scenery/parallax from exposing black.
	var tint=Color.WHITE
	if has_node("World/Lighting"):tint=$World/Lighting.current_scenery_tint
	draw_rect(stage_rect,backdrop_color*tint)
