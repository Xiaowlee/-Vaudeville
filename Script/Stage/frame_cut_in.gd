@tool
extends Control
signal cutin_shown
var sounded_command := ""
## Floating story illustrations. Placement areas are draggable children in the 2D editor.
class Cue:
    extends RefCounted
    var placement := 0
    var character := 0
    var picture_source := 0
    var illustration: Texture2D
    var crop := Rect2(0.05,0,0.9,0.48)
    var aspect_override := 0.0
    var area_fill := 1.0
    var hold_seconds := 0.0
    var offset := Vector2.ZERO
@export var enabled := true
@export_group("Editor preview")
## Editor only. Runtime visibility is still controlled by the story graph.
@export var preview_in_editor := true
@export_enum("NPC / right", "MC / left", "Custom") var preview_placement := 0
@export_enum("Actor 1", "Player", "Actor 2", "Stage Manager") var preview_character := 0
@export var preview_illustration: Texture2D
@export var preview_crop := Rect2(0.05,0,0.9,0.48)
@export_range(0,4,.05) var preview_aspect := 1.9
@export_range(.3,1,.05) var preview_fill := 1.0
@export_group("Motion")
@export_range(0,2,0.05) var enter_seconds := 0.3
@export_range(0,80,1) var entrance_distance := 24.0
@export_group("Frame")
@export var backing_art: Texture2D = preload("res://Visual Asset/Stage/CutIn/FramecutinBorder_1.png")
@export var decoration_art: Texture2D = preload("res://Visual Asset/Stage/CutIn/FramecutinBorder_2.png")
## Disable to position and size Panel/Backing and Panel/Decoration directly in the 2D editor.
@export var auto_place_ornaments := true
@export var decoration_anchor := Vector2(0,0)
## Point ON THE ARTWORK attached to Decoration Anchor: 0,0 top-left; .5,.5 centre; 1,1 bottom-right.
@export var decoration_pivot := Vector2(0,0)
@export var decoration_offset := Vector2.ZERO
@export var decoration_fraction := Vector2(0.42,0.42)
@export var backing_anchor := Vector2(1,1)
@export var backing_pivot := Vector2(1,1)
@export var backing_offset := Vector2.ZERO
@export var backing_fraction := Vector2(0.42,0.42)
@export var backing_flip_h := false
@export var backing_flip_v := false
@export var inner_color := Color(0.81,0.79,0.90)
var panel_rect := Rect2()
var active_cue := -1
var active_settings: RefCounted
var command_id := ""
var cue_elapsed := 0.0
var entrance := 1.0
var signature := ""
var motion: Tween
var crop_cache: Dictionary = {}
@onready var panel: Control = $Panel
@onready var picture: TextureRect = $Panel/Clip/Picture
@onready var trial = get_parent().get_parent().get_node("DialogueView")
func _ready():
    if not Engine.is_editor_hint():panel.hide()
func _process(delta):
    if not is_node_ready() or not is_instance_valid(trial):return
    var editing=Engine.is_editor_hint()
    size=trial.stage.screen_size if editing else trial.root.size
    var cue=active_settings
    if editing:
        if not preview_in_editor:
            panel.hide();panel_rect=Rect2();return
        cue=Cue.new()
        cue.placement=preview_placement;cue.character=preview_character
        cue.illustration=preview_illustration
        cue.picture_source=1 if preview_illustration!=null else 0
        cue.crop=preview_crop;cue.aspect_override=preview_aspect;cue.area_fill=preview_fill
        entrance=1.0
    elif trial.pages.is_empty():return
    if not editing and not (trial.title_running and trial.title_blocks_dialogue):cue_elapsed+=delta
    panel_rect=Rect2()
    panel.visible=enabled and cue!=null and (editing or not (trial.title_running and trial.title_blocks_dialogue))
    if not panel.visible:return
    if cue==null:
        panel.hide()
        return
    if cue.hold_seconds>0 and cue_elapsed>cue.hold_seconds:panel.visible=false
    if not panel.visible:return
    var texture=cue.illustration
    if cue.picture_source==0:
        var actor=trial.stage.get_node("World/Performers/"+["Actor1","Player","Actor2","StageManager"][cue.character])
        var sprite=actor.get_node("Swing/Card/Art") as AnimatedSprite2D
        texture=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
    if texture==null:
        panel.hide()
        return
    var cache_key=str([texture.get_instance_id(),cue.crop])
    if not crop_cache.has(cache_key):
        var bounds=Rect2(texture.get_image().get_used_rect())
        var crop_rect=Rect2(bounds.position+bounds.size*cue.crop.position,bounds.size*cue.crop.size).intersection(bounds)
        if crop_rect.size.x<1 or crop_rect.size.y<1:crop_rect=bounds
        var atlas=AtlasTexture.new()
        atlas.atlas=texture
        atlas.region=crop_rect
        crop_cache[cache_key]=atlas
    picture.texture=crop_cache[cache_key]
    if not Engine.is_editor_hint() and sounded_command!=command_id:
        sounded_command=command_id;cutin_shown.emit()
    var zone=get_node(["RightArea","LeftArea","CustomArea"][cue.placement]).get_rect()
    var ratio=cue.aspect_override if cue.aspect_override>0 else picture.texture.get_width()/float(picture.texture.get_height())
    # Keep the panel inside its authored area without stretching the picture.
    var dims=Vector2(zone.size.x,zone.size.x/maxf(ratio,0.1))
    if dims.y>zone.size.y:dims*=zone.size.y/dims.y
    dims*=cue.area_fill
    panel_rect=Rect2(zone.get_center()-dims*0.5+cue.offset*minf(size.x/1280.0,size.y/720.0),dims)
    panel_rect.position=panel_rect.position.clamp(Vector2.ZERO,(size-dims).max(Vector2.ZERO))
    panel.position=panel_rect.position+Vector2((1.0-entrance)*entrance_distance*(1 if cue.placement==0 else -1),0)
    panel.size=dims
    panel.pivot_offset=dims*0.5
    panel.scale=Vector2.ONE*lerpf(0.96,1.0,entrance)
    panel.modulate.a=entrance
    $Panel/Clip/Fill.color=inner_color
    $Panel/Backing.texture=backing_art
    $Panel/Decoration.texture=decoration_art
    if auto_place_ornaments:
        var unit=minf(dims.x,dims.y)
        var decor=decoration_fraction*unit
        var back=backing_fraction*unit
        $Panel/Decoration.set_anchors_preset(Control.PRESET_TOP_LEFT)
        $Panel/Backing.set_anchors_preset(Control.PRESET_TOP_LEFT)
        $Panel/Decoration.size=decor
        $Panel/Decoration.position=decoration_anchor*dims-decoration_pivot*decor+decoration_offset*minf(size.x/1280.0,size.y/720.0)
        $Panel/Backing.size=back
        $Panel/Backing.position=backing_anchor*dims-backing_pivot*back+backing_offset*minf(size.x/1280.0,size.y/720.0)
        $Panel/Backing.flip_h=backing_flip_h
        $Panel/Backing.flip_v=backing_flip_v

func get_obstacle() -> Rect2:
    return panel_rect if is_instance_valid(panel) and panel.visible else Rect2()

func show_from_graph(settings: Dictionary, id: String):
    if command_id==id:return
    command_id=id
    var cue=Cue.new()
    cue.placement=clampi(int(settings.get("placement",0)),0,2)
    cue.character=clampi(int(settings.get("character",0)),0,3)
    cue.picture_source=int(settings.get("picture_source",0))
    var path=str(settings.get("texture",""))
    if not path.is_empty() and ResourceLoader.exists(path):cue.illustration=load(path)
    var crop=settings.get("crop",[0.05,0.0,0.9,0.48])
    cue.crop=Rect2(float(crop[0]),float(crop[1]),float(crop[2]),float(crop[3]))
    cue.aspect_override=float(settings.get("aspect",0))
    cue.area_fill=clampf(float(settings.get("fill",1)),0.3,1)
    cue.hold_seconds=maxf(float(settings.get("hold",0)),0)
    var offset=settings.get("offset",[0,0])
    cue.offset=Vector2(float(offset[0]),float(offset[1]))
    active_settings=cue
    active_cue=0
    cue_elapsed=0
    if is_instance_valid(motion):motion.kill()
    entrance=1.0
    if not Engine.is_editor_hint() and enter_seconds>0:
        entrance=0.0
        motion=create_tween()
        motion.tween_property(self,"entrance",1.0,enter_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
func hide_from_graph():
    sounded_command=""
    command_id=""
    active_settings=null
    active_cue=-1
    panel_rect=Rect2()
    if is_instance_valid(panel):panel.hide()
