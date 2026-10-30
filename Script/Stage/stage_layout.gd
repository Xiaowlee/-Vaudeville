@tool
extends Node2D
@export_group("Stage frame")
## Reference composition size. Scenery fills the window; performers retain their proportions.
@export var design_size := Vector2(1280,720)

@export var show_editor_frame := true
## Preview sizes are checks of the SAME composition, not separate layouts.
@export_enum("16:9", "16:10", "Ultrawide", "Custom") var editor_screen := 0
@export var custom_preview_size := Vector2(1280,800)
@export var backdrop_color := Color(0.56,0.52,0.76,1)
var stage_rect := Rect2()
var screen_size := Vector2(1280,720)
@export_group("Character layout")
@export_range(0.5,1.5,0.01) var performer_scale_multiplier := 1.0
@export_group("Artwork")

@export_group("Depth")
@export_range(0,2,0.05) var depth_strength := 1.0
@export_range(1,20,0.5) var smoothing := 6.0
@export_enum("Mouse", "Slow automatic", "Flat / off") var movement_mode := 0
var aim := Vector2.ZERO
var clock := 0.0
var actors: Array
func _ready():
    actors=$World/Performers.get_children()
func flip_all():
    for actor in actors:
        if actor.visible:actor.flip()
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
    var available=Vector2(maxf(size.x,1),maxf(size.y,1))
    var fit=minf(available.x/maxf(design_size.x,1),available.y/maxf(design_size.y,1))
    stage_rect=Rect2(Vector2.ZERO,available)
    $World.scale=Vector2.ONE
    $World.position=available*0.5
    # Characters and floor share a uniform scale. Surrounding scenery follows
    # both screen edges independently, like left/right + top/bottom constraints.
    var edge_scale=available/design_size
    for layer in $World.get_children():
        if layer.name=="Performers":
            layer.scale=Vector2.ONE*fit*(performer_scale_multiplier if layer.name=="Performers" else 1.0)
        elif layer.name not in ["Backdrop", "Lighting"]:
            layer.scale=edge_scale
    $World/Backdrop.visible=false
    queue_redraw()

func _draw():
    # Continuous backing prevents transparent scenery/parallax from exposing black.
    var tint=Color.WHITE
    if has_node("World/Lighting"):tint=$World/Lighting.current_scenery_tint
    draw_rect(stage_rect,backdrop_color*tint)
