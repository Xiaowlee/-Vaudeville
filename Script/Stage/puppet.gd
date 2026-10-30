@tool
extends Node2D
@export_group("Motion style")
## Hold movement poses at the chosen frame rate. Does not limit the game frame rate.
@export var hand_drawn_motion := false
@export_range(2,24,1) var motion_fps := 8.0
@export_group("Dialogue pose pacing")
@export_range(2,12,1) var minimum_dialogues_per_pose := 2
@export var automatic_pose_variation := true
@export var allowed_variation_poses: PackedStringArray
var dialogues_since_change := 2
var pending_pose := -1
var pending_hold := 2
var variation_cursor := 0
@export_group("Flip")
## Duration of one turn. Smaller values spin faster.
@export_range(0.2,3,0.05) var flip_seconds := 0.65
@export_group("Size and feet pivot")
@export_range(0.1,3,0.05) var character_size := 1.0
## Drawing offset from the feet pivot, in stage pixels. Adjust until the feet meet the cross.
@export var drawing_offset := Vector2(0,-190):
    set(value):
        drawing_offset=value
        if has_node("Swing/Card/Art"):$Swing/Card/Art.position=value
@export_group("Talking bounce")
@export var talking := false
@export_range(0,30,0.5) var bounce_height := 7.0
@export_range(0.2,8,0.1) var bounce_speed := 2.5
@export_group("Idle sway")
@export_range(0,10,0.1) var sway_degrees := 1.5
@export_range(0.05,2,0.05) var sway_speed := 0.35
@export var preview_motion_in_editor := false
@export_group("Light anchor")
## Optional Marker2D path. Empty automatically finds the feet in the first pose.
@export var lighting_anchor: NodePath
@export var lighting_anchor_offset := Vector2.ZERO
@export_group("Artwork")
@export var pose_names: PackedStringArray
@export var pose_frames: SpriteFrames
@export_range(0,30,1) var starting_pose := 0
var target_pose := -1
var queued_pose := -1
var flipping := false
var flip_elapsed := 0.0
var flip_swapped := false
var flip_length := 0.65
signal flip_started
signal flipped
func _ready():
    var art=$Swing/Card/Art
    if pose_frames!=null:art.sprite_frames=pose_frames
    art.frame=clampi(starting_pose,0,maxi(art.sprite_frames.get_frame_count("poses")-1,0))
func flip():
    if flipping:return
    target_pose=($Swing/Card/Art.frame+1)%$Swing/Card/Art.sprite_frames.get_frame_count("poses")
    flipping=true
    flip_started.emit()
    flip_elapsed=0.0
    flip_swapped=false
    flip_length=maxf(flip_seconds,0.01)

func advance_flip(delta: float):
    flip_elapsed+=delta
    var sample= floorf(flip_elapsed*motion_fps)/motion_fps if hand_drawn_motion else flip_elapsed
    var progress=clampf(sample/flip_length,0.0,1.0)
    var width=maxf(0.015,absf(cos(progress*PI)))
    if progress>=0.5 and not flip_swapped:
        var art=$Swing/Card/Art
        art.frame=target_pose
        flip_swapped=true
    $Swing/Card.scale.x=width
    if flip_elapsed>=flip_length:
        if not flip_swapped:
            var art=$Swing/Card/Art
            art.frame=target_pose
        $Swing/Card.scale.x=1.0
        flipping=false
        flipped.emit()
        # A pending request waits for a NEW dialogue, never a chained flip.

var elapsed := 0.0
var lift := 0.0
func set_talking(value: bool) -> void:
    talking=value
    if not value:lift=0.0
func _process(delta):
    if not has_node("Swing/Card/Art"):return
    $Swing.scale=Vector2.ONE*character_size
    var animate=not Engine.is_editor_hint() or preview_motion_in_editor
    if animate:elapsed+=delta
    if flipping:advance_flip(delta)
    var sample_time=floorf(elapsed*motion_fps)/motion_fps if hand_drawn_motion else elapsed
    lift=-absf(sin(sample_time*TAU*bounce_speed))*bounce_height if talking and animate else 0.0
    $Swing.position.y=lift
    $Swing.rotation=deg_to_rad(sway_degrees)*sin(sample_time*TAU*sway_speed) if animate else 0.0
    if Engine.is_editor_hint():queue_redraw()
func _draw():
    if not Engine.is_editor_hint():return
    draw_line(Vector2(-12,0),Vector2(12,0),Color(0.2,1,0.6),2)
    draw_line(Vector2(0,-12),Vector2(0,12),Color(0.2,1,0.6),2)

var feet_cache: Dictionary={}
func get_lighting_anchor() -> Vector2:
    if not lighting_anchor.is_empty():
        var marker=get_node_or_null(lighting_anchor)
        if marker is Node2D:return marker.global_position+global_transform.basis_xform(lighting_anchor_offset)
    var art=$Swing/Card/Art
    var texture=art.sprite_frames.get_frame_texture(art.animation,0)
    var id=texture.get_instance_id()
    if not feet_cache.has(id):
        var img=texture.get_image()
        var used=Rect2(img.get_used_rect())
        img.resize(64,64,Image.INTERPOLATE_NEAREST)
        var left=64
        var right=-1
        var first_row=int(maxf(used.end.y-used.size.y*0.1,0)*64.0/texture.get_height())
        for y in range(first_row,64):
            for x in range(64):
                if img.get_pixel(x,y).a>0.1:
                    left=mini(left,x)
                    right=maxi(right,x)
        var foot_x=(left+right+1)*0.5/64.0*texture.get_width() if right>=left else used.get_center().x
        feet_cache[id]=Vector2(foot_x,used.end.y)
    var point=feet_cache[id]+art.offset-(texture.get_size()*0.5 if art.centered else Vector2.ZERO)
    var card=$Swing/Card
    var card_transform=Transform2D(card.rotation,card.position)
    var local=card_transform*art.transform*point
    local*=character_size
    return global_transform*(local+lighting_anchor_offset)

func flip_to_pose(pose: String):
    request_pose(pose)
func request_pose(pose: String, hold_dialogues: int=2):
    var index=pose_names.find(pose)
    if index>=0:
        pending_pose=index
        pending_hold=maxi(hold_dialogues,2)
func flip_to_index(index: int):
    if index>=0 and index<pose_names.size():pending_pose=index
func begin_dialogue():
    if not visible:return
    dialogues_since_change+=1
    if flipping or dialogues_since_change<maxi(minimum_dialogues_per_pose,pending_hold):return
    var art=$Swing/Card/Art
    var next=pending_pose
    pending_pose=-1
    if (next<0 or next==art.frame) and automatic_pose_variation and allowed_variation_poses.size()>1:
        for i in allowed_variation_poses.size():
            variation_cursor=(variation_cursor+1)%allowed_variation_poses.size()
            var candidate=pose_names.find(allowed_variation_poses[variation_cursor])
            if candidate>=0 and candidate!=art.frame:next=candidate;break
    if next<0 or next==art.frame:return
    flip()
    target_pose=next
    dialogues_since_change=0
    pending_hold=2
