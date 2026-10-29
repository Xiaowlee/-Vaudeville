@tool
extends Control
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
@export_group("Motion")
@export_range(0,2,0.05) var enter_seconds := 0.3
@export_range(0,80,1) var entrance_distance := 24.0
@export_group("Frame")
@export var backing_art: Texture2D = preload("res://Experiments/PuppetStage/Art/framecut_1.png")
@export var decoration_art: Texture2D = preload("res://Experiments/PuppetStage/Art/framecut_2.png")
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
@onready var trial = get_parent().get_parent().get_node("DialogueTrial")
func _process(delta):
    if not is_node_ready() or not is_instance_valid(trial) or trial.pages.is_empty():return
    size=trial.root.size
    if not (trial.title_running and trial.title_blocks_dialogue):cue_elapsed+=delta
    panel_rect=Rect2()
    panel.visible=enabled and active_settings!=null and not (trial.title_running and trial.title_blocks_dialogue)
    if not panel.visible:return
    var cue=active_settings
    if cue==null:
        panel.hide()
        return
    if cue.hold_seconds>0 and cue_elapsed>cue.hold_seconds:panel.visible=false
    if not panel.visible:return
    var texture=cue.illustration
    if cue.picture_source==0:
        var actor=trial.stage.get_node("World/Performers/"+["Actor1","Player","StageManager"][cue.character])
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
    # The two supplied exports share one canvas. Preserve their registration;
    # the visible inner frame occupies this rectangle inside that canvas.
    var art_scale=dims/Vector2(1434,648)
    $Panel/Decoration.position=-Vector2(107,181)*art_scale
    $Panel/Decoration.size=Vector2(1638,881)*art_scale
func get_obstacle() -> Rect2:
    return panel_rect if is_instance_valid(panel) and panel.visible else Rect2()

func show_from_graph(settings: Dictionary, id: String):
    if command_id==id:return
    command_id=id
    var cue=Cue.new()
    cue.placement=clampi(int(settings.get("placement",0)),0,2)
    cue.character=clampi(int(settings.get("character",0)),0,2)
    cue.picture_source=int(settings.get("picture_source",0))
    var path=str(settings.get("texture",""))
    if not path.is_empty() and ResourceLoader.exists(path):cue.illustration=load(path)
    var crop=settings.get("crop",[0.05,0.0,0.9,0.48])
    cue.crop=Rect2(float(crop[0]),float(crop[1]),float(crop[2]),float(crop[3]))
    cue.aspect_override=float(settings.get("aspect",0))
    cue.area_fill=clampf(float(settings.get("fill",1)),0.3,1)
    cue.hold_seconds=maxf(float(settings.get("hold",0)),0)
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
    command_id=""
    active_settings=null
    active_cue=-1
    panel_rect=Rect2()
    if is_instance_valid(panel):panel.hide()
