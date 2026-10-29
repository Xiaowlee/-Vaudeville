@tool
extends "res://Experiments/PuppetStage/Scripts/depth_layer.gd"
## Gentle movement of the supplied single audience strip. Parallax remains smooth.
@export var audience_motion := true
@export_range(0,12,0.25) var audience_bob_height := 2.5
@export_range(0.05,2,0.05) var audience_bob_speed := 0.3
@export var preview_audience_motion := false
var elapsed := 0.0
var last_bob := Vector2.ZERO
func _process(delta):
    var art=get_node_or_null("Art")
    if art==null:return
    var base=art.position-last_bob
    var active=audience_motion and (not Engine.is_editor_hint() or preview_audience_motion)
    if active:elapsed+=delta
    last_bob=Vector2(0,sin(elapsed*TAU*audience_bob_speed)*audience_bob_height) if active else Vector2.ZERO
    art.position=base+last_bob
func _exit_tree():
    var art=get_node_or_null("Art")
    if art!=null:art.position-=last_bob
