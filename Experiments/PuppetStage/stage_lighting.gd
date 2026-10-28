@tool
extends Node2D
## Painted theatre-light comparison. Does not affect the main game.
@export var enabled := true
@export_enum("World", "Character focus") var lighting_mode := 1
@export_range(0,5,0.05) var transition_seconds := 1.0
## Automatically demonstrate World > Player > Actor1 > StageManager > World.
@export var preview_cycle := false
@export_range(1,10,0.25) var preview_hold_seconds := 3.0
@export_range(0.01,0.9,0.01) var top_softness := 0.05
## Edge Softness below controls the soft bottom end of the beam.
@export_enum("Player", "Actor1", "StageManager") var focus_character := 1
@export var scenery_tint := Color(0.48,0.42,0.72,1)
@export var inactive_tint := Color(0.64,0.59,0.85,1)
@export var light_color := Color(0.95,0.49,0.92,1)
@export_range(0,1,0.01) var beam_opacity := 0.22
@export_range(0,1,0.01) var pool_opacity := 0.32
@export_range(40,500,1) var beam_width := 300.0
@export_range(0.01,0.9,0.01) var edge_softness := 0.35
@export var light_offset := Vector2.ZERO
@export var pool_size := Vector2(340,90)
@export var feet_shadow := false
@export_range(0,1,0.01) var shadow_opacity := 0.25
var area := Rect2()
var weights := Vector3.ZERO
var start_weights := Vector3.ZERO
var target_weights := Vector3.ZERO
var transition_time := 0.0
var cycle_time := 0.0
var cycle_step := 0
var current_scenery_tint := Color.WHITE
func _process(delta):
    var stage=get_parent().get_parent()
    var world=get_parent()
    if not world.has_node("Performers"):return
    area=Rect2(-stage.stage_rect.size*0.5,stage.stage_rect.size)
    if preview_cycle:
        cycle_time+=delta
        if cycle_time>=preview_hold_seconds:
            cycle_time=0.0
            cycle_step=(cycle_step+1)%4
        lighting_mode=0 if cycle_step==0 else 1
        if cycle_step>0:focus_character=cycle_step-1
    else:
        cycle_time=0.0
        cycle_step=0
    var desired=Vector3.ZERO
    if enabled and lighting_mode==1:desired[focus_character]=1.0
    if desired!=target_weights:
        start_weights=weights
        target_weights=desired
        transition_time=0.0
    transition_time+=delta
    var progress=1.0 if transition_seconds<=0.0 else clampf(transition_time/transition_seconds,0.0,1.0)
    weights=start_weights.lerp(target_weights,smoothstep(0.0,1.0,progress))
    var strength=weights.x+weights.y+weights.z
    current_scenery_tint=Color.WHITE.lerp(scenery_tint,strength)
    for layer in world.get_children():
        if layer==self or layer.name=="Performers":continue
        if layer.has_node("Art"):layer.get_node("Art").self_modulate=current_scenery_tint
    var names=["Player","Actor1","StageManager"]
    var fit=world.get_node("Performers").scale.x
    var feet=Vector2.ZERO
    for i in range(3):
        var actor=world.get_node("Performers").get_node(names[i])
        actor.modulate=Color.WHITE.lerp(inactive_tint,clampf(strength-weights[i],0.0,1.0))
        feet+=(to_local(actor.global_position)+light_offset*fit)*weights[i]
    if strength>0.0001:feet/=strength
    else:feet=to_local(world.get_node("Performers").get_node(names[focus_character]).global_position)+light_offset*fit
    material.set_shader_parameter("feet",feet)
    material.set_shader_parameter("top_y",area.position.y)
    material.set_shader_parameter("beam_width",beam_width*fit)
    material.set_shader_parameter("pool_size",pool_size*fit)
    material.set_shader_parameter("softness",edge_softness)
    material.set_shader_parameter("top_softness",top_softness)
    material.set_shader_parameter("light_color",light_color)
    material.set_shader_parameter("beam_opacity",beam_opacity*strength)
    material.set_shader_parameter("pool_opacity",pool_opacity*strength)
    material.set_shader_parameter("shadow_opacity",shadow_opacity*strength if feet_shadow else 0.0)
    visible=strength>0.0001
    queue_redraw()
func _draw():draw_rect(area,Color.WHITE)
