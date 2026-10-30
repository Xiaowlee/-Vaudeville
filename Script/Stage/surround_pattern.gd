@tool
extends Node2D
## The texture scrolls under a stationary aperture. Artwork is not baked or edited.
@export var enabled := false
@export var pattern: Texture2D
@export var ink_color := Color(0.34,0.22,0.93,1)
@export var background_color := Color(0.72,0.56,0.86,1)
@export var scroll_speed := Vector2(0.012,0.004)
@export_range(80,1200,10) var tile_size := 420.0
@export var preview_motion := false
@export_group("Stationary mask")
## Optional white-outside / black-stage image, registered to the entire design canvas.
@export var outside_mask: Texture2D
## Normalized stage opening. Points follow the fixed border; they never scroll.
@export var opening := PackedVector2Array([Vector2(0.055,0.06),Vector2(0.945,0.06),Vector2(0.98,0.30),Vector2(0.965,0.73),Vector2(0.94,0.82),Vector2(0.85,0.88),Vector2(0.74,0.918),Vector2(0.62,0.943),Vector2(0.5,0.95),Vector2(0.38,0.943),Vector2(0.26,0.918),Vector2(0.15,0.88),Vector2(0.06,0.82),Vector2(0.035,0.73),Vector2(0.02,0.30),Vector2(0.035,0.12)])
var phase := Vector2.ZERO
var story_settings: Dictionary = {}
var story_image: Texture2D
var fill: ColorRect
func _ready():
    fill=ColorRect.new()
    fill.name="MaskedPattern"
    fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var mat=ShaderMaterial.new()
    mat.shader=preload("res://Script/Stage/Shaders/surround_pattern.gdshader")
    fill.material=mat
    add_child(fill)
func _process(delta):
    if not is_instance_valid(fill):return
    var stage=get_parent().get_parent()
    var design=stage.design_size
    fill.position=-design*0.5
    fill.size=design
    fill.visible=bool(story_settings.get("enabled",enabled)) and (pattern!=null or story_image!=null)
    var speed=scroll_speed
    if story_settings.has("speed"):speed=Vector2(story_settings.speed[0],story_settings.speed[1])
    if not Engine.is_editor_hint() or preview_motion:phase+=speed*delta
    phase=Vector2(fposmod(phase.x,1.0),fposmod(phase.y,1.0))
    var mat=fill.material
    var image=pattern
    if story_image!=null:image=story_image
    mat.set_shader_parameter("pattern_image",image)
    mat.set_shader_parameter("outside_mask",outside_mask)
    mat.set_shader_parameter("use_image_mask",outside_mask!=null)
    var points=PackedVector2Array(opening)
    if points.size()<3 and outside_mask==null:
        fill.hide()
        return
    var count=clampi(points.size(),3,16)
    points.resize(16)
    mat.set_shader_parameter("opening",points)
    mat.set_shader_parameter("opening_count",count)
    mat.set_shader_parameter("phase",phase)
    mat.set_shader_parameter("design_size",design)
    mat.set_shader_parameter("tile_size",float(story_settings.get("tile_size",tile_size)))
    mat.set_shader_parameter("ink",Color(str(story_settings.ink)) if story_settings.has("ink") else ink_color)
    mat.set_shader_parameter("paper",Color(str(story_settings.paper)) if story_settings.has("paper") else background_color)
    mat.set_shader_parameter("stage_tint",stage.get_node("World/Lighting").current_scenery_tint)
func apply_settings(settings: Dictionary):
    story_settings=settings.duplicate(true)
    story_image=null
    var path=str(settings.get("texture",""))
    if not path.is_empty() and ResourceLoader.exists(path):story_image=load(path)
func reset():
    story_settings.clear()
    story_image=null
    phase=Vector2.ZERO
