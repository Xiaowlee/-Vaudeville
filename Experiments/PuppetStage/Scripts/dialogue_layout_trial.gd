@tool
extends CanvasLayer
## Visual rehearsal using existing Act 1 events. Next advances a display page, not a story route.
@export_enum("Beside character", "Lower panel") var layout_style := 0
@export_enum("Act 1", "Act 3") var excerpt := 0
@export var visual_story: DialogueData = preload("res://Experiments/PuppetStage/visual_story.tres")
@export_group("Placement editing")
@export_enum("Scene zones - drag in editor", "Inspector percentages") var placement_source := 0
@export_group("Alignment")
## Text Alignment centres each line. Block Alignment centres the whole reading block in its zone.
@export_enum("Left", "Center", "Right") var character_text_alignment := 0
@export_enum("Left", "Center", "Right") var narrator_text_alignment := 1
@export_enum("Top", "Center", "Bottom") var character_block_alignment := 0
@export_enum("Top", "Center", "Bottom") var narrator_block_alignment := 0
@export_range(0.3,1,0.05) var text_block_width := 1.0
@export_enum("Left", "Center", "Right") var block_horizontal_alignment := 1
@export_group("Smart placement")
## Chooses a stable position for each page, trying the sides, above and below the speaker.
@export var smart_placement := true
@export_enum("Automatic", "Left", "Right", "Above", "Below") var preferred_placement := 0
@export_storage var smart_box_size := Vector2(0.30,0.25)
@export_range(0,100,1) var character_gap := 12.0
## Uses the existing grey puppet as a third occupancy stand-in, not new Actor 2 artwork.
@export var show_third_character := false
@export_group("Readability")
## Protect the actual name and paragraph even with manually positioned decorative panels.
@export var protect_reading_area := true
@export var text_outline_enabled := true
@export_range(1,8,1) var text_outline_size := 2
@export var text_outline_color := Color(0.04,0.03,0.12,1)
## Appears above the character but below text only when overlap cannot be avoided.
@export_storage var overlap_soft_backing := false
@export_storage var overlap_backing_color := Color(0.04,0.03,0.12,0.72)
@export var text_backing_enabled := true
@export var text_backing_color := Color(0.08,0.05,0.20,0.70)
@export var text_backing_padding := Vector2(10,6)
@export_group("Speaker style")
@export var mc_color := Color(0.72,0.03,0.72,1)
@export var npc_color := Color(0.09,0.12,0.72,1)
@export var manager_color := Color(0.035,0.055,0.28,1)
@export var name_tag_enabled := true
@export var speaker_font: Font = preload("res://Font/LavishlyYours-Regular.ttf")
@export_enum("Down", "Left to right", "Right to left") var backing_gradient_direction := 0
@export_range(0,1,0.05) var backing_start_opacity := 0.85
@export_range(0,1,0.05) var backing_end_opacity := 0.0
@export_group("Dialogue motion")
@export_enum("Off", "Pop and settle", "Gentle wave", "Jitter") var dialogue_motion := 1
@export_range(5,100,1) var characters_per_second := 38.0
@export_range(0.1,1,0.05) var letter_pop_seconds := 0.35
@export_range(0,20,0.5) var letter_pop_height := 5.0
@export_range(0,5,0.1) var text_motion_amount := 0.4
@export_range(0.1,4,0.1) var text_motion_speed := 0.6
@export var preview_dialogue_motion := false
@export_range(0,60,1) var motion_safety_margin := 6.0
@export_group("Character sizing")
## Both modes are previewed in the editor and game. Authored size is preserved by default.
@export_enum("Preserve authored size", "Reserve dialogue space") var character_fit_mode := 0
@export_range(0,0.35,0.01) var dialogue_space_reserve := 0.15
@export_group("Editor preview")
@export_range(0,100,1) var preview_page := 0
@export_group("Typography")
@export var body_font: Font = preload("res://Font/InstrumentSerif-Regular.ttf")
@export_range(0.18,0.32,0.01) var dialogue_width := 0.26
@export_range(18,40,1) var text_size := 24
@export_range(0,40,1) var name_extra_size := 8
@export var text_color := Color.WHITE
@export_range(0,24,1) var line_spacing := 3
@export_range(0,50,1) var paragraph_spacing := 14
@export_range(0,40,1) var speaker_text_gap := 10
@export_group("Backdrop act title")
@export var act_title_enabled := true
@export var act_one_name := ""
@export var act_three_name := ""
@export_range(0.1,3,0.05) var title_slide_seconds := 0.8
@export_range(0,8,0.25) var title_hold_seconds := 2.0
@export var title_color := Color(0.90,0.84,0.96,0.65)
@export var title_position := Vector2(0.5,0.25)
@export_range(40,160,1) var title_font_size := 92
@export var preview_title_in_editor := false
@export_multiline var backdrop_text_override := ""
@export_range(0,1,0.05) var title_scene_brightness := 0.25
@export var intro_camera_enabled := true
@export_range(1,2.5,0.05) var intro_zoom := 1.55
@export var intro_camera_focus := Vector2(0.5,0.28)
@export_range(0.2,5,0.1) var camera_pull_back_seconds := 2.0
@export_group("Beside character placement")
## Fractions of the window: 0.10 is 10%. Position is the upper-left corner.
@export var beside_left := Rect2(0.035,0.24,0.24,0.43)
@export var beside_right := Rect2(0.725,0.24,0.24,0.43)
@export var narrator_bottom := Rect2(0.24,0.70,0.52,0.21)
@export_group("Lower panel placement")
@export var lower_left := Rect2(0.035,0.64,0.30,0.27)
@export var lower_right := Rect2(0.665,0.64,0.30,0.27)
@export_group("Panel appearance")
@export var text_padding := Vector2(16,12)
@export var show_panel := true
@export var panel_color := Color(0.07,0.06,0.18,0.88)
var pages: Array[Dictionary]=[]
var page_index := 0
var last_side := 1
var backing: ColorRect
var placement_key := ""
var cached_smart_box := Rect2()
var last_preview_page := -1
var soft_backing: ColorRect
var last_reading_rect := Rect2()
var used_readability_fallback := false
var alpha_bounds_cache: Dictionary={}
var movement_envelopes: Array[Rect2]=[]
var resolved_box := Rect2()
var band_cache: Dictionary={}
var backing_patches: Array[ColorRect]=[]
var last_excerpt := -1
var layout_padding := Vector2.ZERO
var layout_font_scale := 1.0
var layout_name_extra := 8
var title_label: Label
var title_tween: Tween
var title_slide := -1.0
var title_running := false
var paragraph_labels: Array[RichTextLabel]=[]
var name_tag: ColorRect
var text_effect: RichTextEffect
var dialogue_elapsed := 0.0
var animation_key := ""
var trial_camera: Camera2D
var camera_zoom := 1.0
var camera_focus := Vector2(0.5,0.5)
var title_blocks_dialogue := false
var active_backdrop_text := ""
var active_text_settings: Dictionary = {}
@onready var stage=get_parent()
@onready var root=$Layout
func _ready():
    root.set_anchors_preset(Control.PRESET_TOP_LEFT)
    root.get_node("Text/Words").custom_minimum_size=Vector2.ZERO
    root.get_node("Text/Name").custom_minimum_size=Vector2.ZERO
    stage.get_node("Controls").hide()
    stage.get_node("World/Lighting").preview_cycle=false
    stage.get_node("World/Lighting").enabled=true
    backing=stage.get_node("World").get_node_or_null("DialogueBacking")
    if backing==null:
        backing=ColorRect.new()
        backing.name="DialogueBacking"
        backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
        stage.get_node("World").add_child(backing)
        stage.get_node("World").move_child(backing,stage.get_node("World/Performers").get_index())
    soft_backing=ColorRect.new()
    soft_backing.name="TextBacking"
    soft_backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
    root.add_child(soft_backing)
    root.move_child(soft_backing,root.get_node("Text").get_index())
    text_effect=preload("res://Experiments/PuppetStage/Scripts/puppet_text_effect.gd").new()
    text_effect.controller=weakref(self)
    paragraph_labels.append(root.get_node("Text/Words"))
    name_tag=ColorRect.new()
    name_tag.name="SpeakerNameTag"
    name_tag.mouse_filter=Control.MOUSE_FILTER_IGNORE
    root.add_child(name_tag)
    root.move_child(name_tag,root.get_node("Text").get_index())
    var gradient=Shader.new()
    gradient.code="""shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color;
uniform float start_alpha;
uniform float end_alpha;
uniform int direction;
void fragment(){
 float t=direction==0?UV.y:(direction==1?UV.x:1.0-UV.x);
 COLOR=vec4(tint.rgb,mix(start_alpha,end_alpha,t));
}"""
    var gradient_material=ShaderMaterial.new()
    gradient_material.shader=gradient
    soft_backing.material=gradient_material
    if not Engine.is_editor_hint():
        trial_camera=Camera2D.new()
        trial_camera.name="IntroCamera"
        trial_camera.position_smoothing_enabled=false
        stage.add_child.call_deferred(trial_camera)
    title_label=stage.get_node("World").get_node_or_null("ActTitle")
    if title_label==null:
        title_label=Label.new()
        title_label.name="ActTitle"
        title_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
        title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        title_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
        title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        title_label.add_theme_font_override("font",get_body_font())
        stage.get_node("World").add_child(title_label)
        stage.get_node("World").move_child(title_label,stage.get_node("World/Performers").get_index())
    load_excerpt()
    root.get_node("Toolbar/Excerpt").item_selected.connect(func(i):excerpt=i;load_excerpt();present();play_act_title())
    root.get_node("Toolbar/Style").select(layout_style)
    root.get_node("Toolbar/Style").item_selected.connect(func(i):layout_style=i;arrange())
    root.get_node("Toolbar/Previous").pressed.connect(func():page_index=maxi(0,page_index-1);present())
    root.get_node("Toolbar/Next").pressed.connect(func():page_index=mini(pages.size()-1,page_index+1);present())
    root.get_node("Toolbar/Pose").pressed.connect(func():
        for actor in stage.get_node("World/Performers").get_children():actor.flip())
    root.get_node("Toolbar/Restart").pressed.connect(func():page_index=0;present();play_act_title())
    present()
    play_act_title()
func present():
    var page=pages[page_index]
    apply_graph_visuals(page.get("visual_state",{}))
    var speaker=page["speaker"]
    if speaker=="Actor 1":last_side=1
    elif speaker=="Actor 2":last_side=2
    elif speaker=="MC":last_side=0
    root.get_node("Text/Name").text="" if speaker.is_empty() else ("Player" if speaker=="MC" else speaker)
    var key=str([excerpt,page_index,page["text"]])
    if key!=animation_key:
        dialogue_elapsed=0.0
        animation_key=key
    root.get_node("Toolbar/Count").text="%s / %s" % [page_index+1,pages.size()]
    root.get_node("Toolbar/Previous").disabled=page_index==0
    root.get_node("Toolbar/Next").disabled=page_index==pages.size()-1
    var light=stage.get_node("World/Lighting")
    light.lighting_mode=0 if speaker.is_empty() or speaker=="Stage Manager" else 1
    light.focus_character=0 if speaker=="MC" else (2 if speaker=="Actor 2" else 1)
    for actor in stage.get_node("World/Performers").get_children():
        actor.set_talking(actor.name==("Player" if speaker=="MC" else ("StageManager" if speaker=="Actor 2" else "Actor1")) and speaker in ["MC","Actor 1","Actor 2"])
    arrange()
func _process(delta):
    if not (title_running and title_blocks_dialogue):dialogue_elapsed+=delta
    if last_excerpt!=excerpt and is_node_ready():
        load_excerpt()
        present()
        play_act_title()
    if Engine.is_editor_hint() and not pages.is_empty() and preview_page!=last_preview_page:
        last_preview_page=preview_page
        page_index=clampi(preview_page,0,pages.size()-1)
        present()
    arrange()
func arrange():
    if pages.is_empty() or backing==null or soft_backing==null:return
    var size=stage.screen_size if Engine.is_editor_hint() else get_viewport().get_visible_rect().size
    root.size=size
    var performers=stage.get_node("World/Performers")
    performers.get_node("StageManager").visible=show_third_character or excerpt==1
    stage.performer_scale_multiplier=(1.0-dialogue_space_reserve if character_fit_mode==1 else 1.0)
    stage.apply_layout(size)
    layout_font_scale=minf(size.x/1280.0,size.y/720.0)
    layout_padding=text_padding*layout_font_scale
    layout_name_extra=int(round(name_extra_size*layout_font_scale))
    var page=pages[page_index]
    var narration=page["speaker"].is_empty() or page["speaker"]=="Stage Manager"
    var side=0 if last_side==0 else 1
    var placement=narrator_bottom if narration else ((beside_left if side==0 else beside_right) if layout_style==0 else (lower_left if side==0 else lower_right))
    var box=Rect2(size*placement.position,size*placement.size)
    if placement_source==0 and root.has_node("PlacementZones"):
        var zone_name="Narration" if page["speaker"].is_empty() else ("StageManager" if page["speaker"]=="Stage Manager" else (("BesideLeft" if side==0 else "BesideRight") if layout_style==0 else ("LowerLeft" if side==0 else "LowerRight")))
        var zone=root.get_node("PlacementZones").get_node(zone_name)
        box=zone.get_rect()
    elif not narration:box.size.x=size.x*dialogue_width
    var px=maxi(10,int(round(text_size*layout_font_scale)))
    var name_label=root.get_node("Text/Name")
    var words=root.get_node("Text/Words")
    name_label.add_theme_font_size_override("font_size",px+layout_name_extra)
    words.add_theme_font_size_override("normal_font_size",px)
    words.add_theme_constant_override("line_spacing",int(round(line_spacing*layout_font_scale)))
    name_label.add_theme_color_override("font_color",text_color)
    words.add_theme_color_override("default_color",text_color)
    if speaker_font!=null:name_label.add_theme_font_override("font",speaker_font)
    name_label.visible=not page["speaker"].is_empty()
    for label in [name_label,words]:
        label.add_theme_color_override("font_outline_color",text_outline_color)
        label.add_theme_constant_override("outline_size",text_outline_size if text_outline_enabled else 0)
    movement_envelopes.clear()
    for actor in performers.get_children():
        if actor.visible:movement_envelopes.append_array(character_bands(actor))
    var cut_in=stage.get_node_or_null("FrameCutInLayer/FrameCutIn")
    if cut_in!=null:
        var obstacle=cut_in.get_obstacle()
        if obstacle.has_area():movement_envelopes.append(obstacle)
    var key=str([page_index,size,layout_style,preferred_placement,dialogue_width,character_gap,show_third_character,character_fit_mode,dialogue_space_reserve,smart_placement,protect_reading_area,placement_source,box,px,text_padding,text_block_width,character_block_alignment,block_horizontal_alignment,line_spacing,paragraph_spacing,speaker_text_gap,get_body_font().get_instance_id(),speaker_font.get_instance_id() if speaker_font!=null else 0,actor_layout_signature()])
    if not narration:
        var current_safe=not overlaps_characters(reading_rect(cached_smart_box,px,false))
        if key!=placement_key or (protect_reading_area and not current_safe and not used_readability_fallback):
            if layout_style==0 and smart_placement:
                cached_smart_box=choose_smart_box(size,"Player" if page["speaker"]=="MC" else ("StageManager" if page["speaker"]=="Actor 2" else "Actor1"),box,px)
            else:cached_smart_box=box
            placement_key=key
        box=cached_smart_box
    var needed=measure_text(maxf((box.size.x-layout_padding.x*2)*text_block_width,40),px)
    box.size.y=needed.x+needed.y+current_speaker_gap()+layout_padding.y*2
    if not narration and layout_style==0:
        box.position.y=clampf(box.position.y,size.y*0.10,maxf(size.y*0.91-box.size.y,size.y*0.10))
    resolved_box=box
    var inner=(box.size-layout_padding*2).max(Vector2(40,40))
    var block_width=maxf(inner.x*text_block_width,40)
    var heights=measure_text(block_width,px)
    var total_height=heights.x+current_speaker_gap()+heights.y
    var vertical=narrator_block_alignment if narration else character_block_alignment
    var content_position=box.position+layout_padding+Vector2((inner.x-block_width)*block_horizontal_alignment*0.5,maxf(inner.y-total_height,0)*vertical*0.5)
    var text=root.get_node("Text")
    text.position=content_position
    text.size=Vector2(block_width,total_height)
    name_label.position=Vector2.ZERO
    name_label.size=Vector2(block_width,heights.x)
    words.position=Vector2(0,heights.x+current_speaker_gap())
    words.size=Vector2(block_width,heights.y)
    arrange_paragraphs(block_width,px,words.position)
    var alignment=narrator_text_alignment if narration else character_text_alignment
    name_label.horizontal_alignment=alignment

    last_reading_rect=Rect2(content_position,Vector2(block_width,total_height))
    var overlap=overlaps_characters(last_reading_rect)
    used_readability_fallback=overlap
    # Decorative backing remains below the puppets; only the safety backing is above them.
    backing.scale=Vector2.ONE
    backing.position=box.position-stage.get_node("World").position
    backing.size=box.size
    backing.color=panel_color
    backing.visible=show_panel and layout_style==1
    var colour=manager_color if page["speaker"]=="Stage Manager" else (mc_color if page["speaker"]=="MC" else npc_color)
    var header_width=minf(name_label.get_theme_font("font").get_string_size(name_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,px+layout_name_extra).x,block_width)
    name_tag.position=content_position+Vector2((block_width-header_width)*alignment*0.5-8*layout_font_scale,heights.x*0.22)
    name_tag.size=Vector2(header_width+16*layout_font_scale,heights.x*0.72)
    name_tag.color=colour
    name_tag.visible=name_tag_enabled and name_label.visible
    var body_start=content_position+words.position
    soft_backing.position=body_start-text_backing_padding*layout_font_scale
    soft_backing.size=Vector2(block_width,heights.y)+text_backing_padding*2*layout_font_scale
    soft_backing.color=Color.WHITE
    soft_backing.material.set_shader_parameter("tint",colour)
    soft_backing.material.set_shader_parameter("start_alpha",backing_start_opacity)
    soft_backing.material.set_shader_parameter("end_alpha",backing_end_opacity)
    soft_backing.material.set_shader_parameter("direction",backing_gradient_direction)
    soft_backing.visible=text_backing_enabled and not page["speaker"].is_empty()
    update_act_title(size)
    var blocked=title_running and title_blocks_dialogue
    root.get_node("Text").visible=not blocked
    backing.visible=backing.visible and not blocked and not page["speaker"].is_empty()
    soft_backing.visible=soft_backing.visible and not blocked
    name_tag.visible=name_tag.visible and not blocked
    if trial_camera!=null and is_instance_valid(trial_camera) and trial_camera.is_inside_tree():
        trial_camera.position=camera_focus*size
        trial_camera.zoom=Vector2.ONE*camera_zoom
    var bar=root.get_node("Toolbar")
    bar.position=Vector2(16,size.y-42)

func body_paragraphs() -> PackedStringArray:
    return str(pages[page_index]["text"]).split("\n\n",false)

func measure_paragraph(text: String, width: float, px: int) -> float:
    var font=get_body_font()
    var line_count=font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,maxf(width-8*layout_font_scale,20),px).y/maxf(font.get_height(px),1)
    return font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,maxf(width-8*layout_font_scale,20),px).y+maxf(ceilf(line_count)-1,0)*line_spacing*layout_font_scale+(6+letter_pop_height)*layout_font_scale

func measure_text(width: float, px: int) -> Vector2:
    var name_label=root.get_node("Text/Name")
    var name_height=0.0 if str(pages[page_index]["speaker"]).is_empty() else name_label.get_theme_font("font").get_multiline_string_size(name_label.text,HORIZONTAL_ALIGNMENT_LEFT,maxf(width-8*layout_font_scale,20),px+layout_name_extra).y+6*layout_font_scale
    var body_height=0.0
    var paragraphs=body_paragraphs()
    for paragraph in paragraphs:body_height+=measure_paragraph(paragraph,width,px)
    body_height+=maxi(paragraphs.size()-1,0)*paragraph_spacing*layout_font_scale
    return Vector2(name_height,body_height)

func get_body_font() -> Font:
    return body_font if body_font!=null else root.get_theme_default_font()

func current_speaker_gap() -> float:
    return 0.0 if str(pages[page_index]["speaker"]).is_empty() else speaker_text_gap*layout_font_scale

func arrange_paragraphs(width: float, px: int, start: Vector2):
    var paragraphs=body_paragraphs()
    while paragraph_labels.size()<paragraphs.size():
        var label=RichTextLabel.new()
        label.mouse_filter=Control.MOUSE_FILTER_IGNORE
        root.get_node("Text").add_child(label)
        paragraph_labels.append(label)
    var y=start.y
    var base=0
    var narration=str(pages[page_index]["speaker"]).is_empty() or pages[page_index]["speaker"]=="Stage Manager"
    var alignment=narrator_text_alignment if narration else character_text_alignment
    for i in range(paragraph_labels.size()):
        var label=paragraph_labels[i]
        label.visible=i<paragraphs.size()
        if not label.visible:continue
        label.horizontal_alignment=alignment
        label.scroll_active=false
        label.fit_content=false
        label.bbcode_enabled=true
        # Scene-saved effects have no live controller. Always bind this trial's
        # configured instance, including the first, scene-authored paragraph.
        if label.custom_effects!=[text_effect]:label.custom_effects=[text_effect]
        var value="[stagepop base=%s]%s[/stagepop]" % [base,paragraphs[i].replace("[","[lb]")]
        if alignment==1:value="[center]"+value+"[/center]"
        elif alignment==2:value="[right]"+value+"[/right]"
        if label.text!=value:label.text=value
        label.add_theme_font_override("normal_font",get_body_font())
        label.add_theme_font_size_override("normal_font_size",px)
        label.add_theme_color_override("default_color",text_color)
        label.add_theme_color_override("font_outline_color",text_outline_color)
        label.add_theme_constant_override("outline_size",text_outline_size if text_outline_enabled else 0)
        label.add_theme_constant_override("line_separation",int(round(line_spacing*layout_font_scale)))
        var height=measure_paragraph(paragraphs[i],width,px)
        label.position=Vector2(start.x,y)
        label.size=Vector2(width,height)
        y+=height+paragraph_spacing*layout_font_scale
        base+=paragraphs[i].length()+2

func reading_rect(box: Rect2, px: int, narration: bool) -> Rect2:
    var inner=(box.size-layout_padding*2).max(Vector2(40,40))
    var width=maxf(inner.x*text_block_width,40)
    var heights=measure_text(width,px)
    var height=heights.x+current_speaker_gap()+heights.y
    var vertical=narrator_block_alignment if narration else character_block_alignment
    var start=box.position+layout_padding+Vector2((inner.x-width)*block_horizontal_alignment*0.5,maxf(inner.y-height,0)*vertical*0.5)
    return Rect2(start,Vector2(width,height))

func overlaps_characters(rect: Rect2) -> bool:
    if rect.size.x<=0:return true
    for obstacle in movement_envelopes:
        if rect.intersects(obstacle):return true
    return false

func texture_bounds(texture: Texture2D) -> Rect2:
    var id=texture.get_instance_id()
    if not alpha_bounds_cache.has(id):
        var img=texture.get_image()
        alpha_bounds_cache[id]=Rect2(img.get_used_rect()) if img!=null else Rect2(Vector2.ZERO,texture.get_size())
    return alpha_bounds_cache[id]

func character_rect(actor: Node2D) -> Rect2:
    var art=actor.get_node("Swing/Card/Art")
    var card=actor.get_node("Swing/Card")
    var result=Rect2()
    var first=true
    # Reserve both poses and the complete bounce/sway path. A width-collapse flip must not
    # temporarily convince the layout that the puppet has disappeared.
    var frames=art.sprite_frames
    for frame in range(frames.get_frame_count(art.animation)):
        var texture=frames.get_frame_texture(art.animation,frame)
        var local_bounds=texture_bounds(texture)
        local_bounds.position+=art.offset-(texture.get_size()*0.5 if art.centered else Vector2.ZERO)
        for angle in [-actor.sway_degrees,0,actor.sway_degrees]:
            for lift in [0.0,-actor.bounce_height]:
                var swing=Transform2D(deg_to_rad(angle),Vector2(0,lift))
                swing.x*=actor.character_size
                swing.y*=actor.character_size
                var stable_card=Transform2D(card.rotation,card.position)
                stable_card.y*=card.scale.y
                var transform=stage.global_transform.affine_inverse()*actor.global_transform*swing*stable_card*art.transform
                var bounds=transform*local_bounds
                result=bounds if first else result.merge(bounds)
                first=false
    var travel=stage.get_node("World/Performers").travel*stage.depth_strength*stage.get_node("World/Performers").scale
    return result.grow(motion_safety_margin+maxf(absf(travel.x),absf(travel.y))*2)

func choose_smart_box(size: Vector2, speaker_name: String, authored: Rect2, px: int) -> Rect2:
    var safe=Rect2(size*Vector2(0.035,0.12),size*Vector2(0.93,0.78))
    var speaker=stage.get_node("World/Performers").get_node(speaker_name)
    var bounds=character_rect(speaker)
    if not overlaps_characters(reading_rect(authored,px,false)):
        return authored
    var widths=[authored.size.x if placement_source==0 else size.x*dialogue_width]
    var candidates: Array[Rect2]=[]
    for width in widths:
        var body_width=maxf((width-layout_padding.x*2)*text_block_width,40)
        var content=measure_text(body_width,px)
        var height=content.x+speaker_text_gap*layout_font_scale+content.y+layout_padding.y*2
        var dims=Vector2(width,height)
        var gap=character_gap*layout_font_scale
        var centre=bounds.get_center()
        var positions=[Vector2(bounds.position.x-gap-width,centre.y-height*0.5),Vector2(bounds.end.x+gap,centre.y-height*0.5),Vector2(centre.x-width*0.5,bounds.position.y-gap-height),Vector2(centre.x-width*0.5,bounds.end.y+gap)]
        # Try adjacent blank areas without ever expanding into a full-width banner.
        for x in [bounds.position.x-gap-width,bounds.end.x+gap,centre.x-width*0.5]:
            for y in [size.y*0.20,size.y*0.38,size.y*0.56]:positions.append(Vector2(x,y))
        for position in positions:
            var clamped=position.clamp(safe.position,Vector2(maxf(safe.end.x-width,safe.position.x),maxf(safe.end.y-height,safe.position.y)))
            candidates.append(Rect2(clamped,dims))
    var best=candidates[0]
    var best_cost=INF
    for candidate in candidates:
        var read=reading_rect(candidate,px,false)
        var overlap=0.0
        for obstacle in movement_envelopes:
            if read.intersects(obstacle):overlap+=read.intersection(obstacle).get_area()
        var centre=candidate.get_center()
        var cost=centre.distance_to(bounds.get_center())
        cost+=overlap*4.0/maxf(layout_font_scale,0.01)
        var direction=1 if centre.x<bounds.position.x else (2 if centre.x>bounds.end.x else (3 if centre.y<bounds.get_center().y else 4))
        if preferred_placement>0 and direction!=preferred_placement:cost+=size.x*0.18
        if cost<best_cost:
            best_cost=cost
            best=candidate
    return best

func actor_layout_signature() -> Array:
    var result=[]
    var cut_in=stage.get_node_or_null("FrameCutInLayer/FrameCutIn")
    if cut_in!=null:result.append(cut_in.get_obstacle())
    for actor in stage.get_node("World/Performers").get_children():
        result.append([actor.position,actor.scale,actor.character_size,actor.get_node("Swing/Card/Art").position])
    return result

func character_bands(actor: Node2D) -> Array[Rect2]:
    var art=actor.get_node("Swing/Card/Art")
    var result: Array[Rect2]=[]
    var frames=art.sprite_frames
    for i in range(frames.get_frame_count(art.animation)):
        var texture=frames.get_frame_texture(art.animation,i)
        var id=texture.get_instance_id()
        if not band_cache.has(id):
            var img=texture.get_image()
            var bands: Array[Rect2]=[]
            if img!=null:
                img.resize(48,48,Image.INTERPOLATE_NEAREST)
                var cell=texture.get_size()/48.0
                for y in range(0,48,4):
                    var left=48
                    var right=-1
                    for yy in range(y,mini(y+4,48)):
                        for x in range(48):
                            if img.get_pixel(x,yy).a>0.08:
                                left=mini(left,x)
                                right=maxi(right,x)
                    if right>=left:bands.append(Rect2(Vector2(left,y)*cell,Vector2(right-left+1,4)*cell))
            band_cache[id]=bands
        for band in band_cache[id]:
            var rect=band
            rect.position+=art.offset-(texture.get_size()*0.5 if art.centered else Vector2.ZERO)
            for angle in [-actor.sway_degrees,actor.sway_degrees]:
                for lift in [0.0,-actor.bounce_height]:
                    var swing=Transform2D(deg_to_rad(angle),Vector2(0,lift))
                    swing.x*=actor.character_size
                    swing.y*=actor.character_size
                    var stable_card=Transform2D(actor.get_node("Swing/Card").rotation,actor.get_node("Swing/Card").position)
                    var transform=stage.global_transform.affine_inverse()*actor.global_transform*swing*stable_card*art.transform
                    result.append((transform*rect).grow((motion_safety_margin+character_gap*0.5)*layout_font_scale))
    return result

func load_excerpt():
    last_excerpt=excerpt
    pages.clear()
    page_index=0
    placement_key=""
    if visual_story==null:return
    var cursor=str(visual_story.starts.get("ACT1" if excerpt==0 else "ACT3","END"))
    var visited={}
    var state={}
    while cursor!="END" and visual_story.nodes.has(cursor) and not visited.has(cursor):
        visited[cursor]=true
        var data=visual_story.nodes[cursor]
        if data.has("visual"):
            var command=data.visual.duplicate(true)
            command["id"]=cursor
            state[str(command.get("kind",""))]=command
        if data.has("dialogue"):
            var words=str(data.dialogue)
            var speaker=str(data.get("speaker",""))
            pages.append({"text":words,"speaker":speaker,"kind":"narration" if speaker.is_empty() else "dialogue","source":str(data.get("source_passage",cursor)),"event":int(data.get("event",0)),"node":cursor,"visual_state":state.duplicate(true)})
            cursor=str(data.get("options",{}).get(0,{}).get("link","END"))
        else:cursor=str(data.get("link","END"))
    if pages.is_empty():
        pages.append({"text":"No dialogue connected to this excerpt start.","speaker":"","source":"","event":0,"visual_state":{}})
    root.get_node("Toolbar/Excerpt").select(excerpt)

func play_act_title():
    var name=act_one_name if excerpt==0 else act_three_name
    var text=("Act 1" if excerpt==0 else "Act 3")+(": "+name if not name.strip_edges().is_empty() else "")
    if not backdrop_text_override.strip_edges().is_empty():text=backdrop_text_override
    play_backdrop_text(text,true)

func play_backdrop_text(text: String, cinematic: bool=false):
    if title_tween!=null:title_tween.kill()
    title_running=false
    title_blocks_dialogue=cinematic
    active_backdrop_text=text
    var performers=stage.get_node("World/Performers")
    var light=stage.get_node("World/Lighting")
    camera_zoom=1.0
    camera_focus=Vector2(0.5,0.5)
    light.cinematic_dimming=1.0
    performers.modulate.a=1.0
    if Engine.is_editor_hint() or not act_title_enabled:
        if is_node_ready():arrange()
        return
    title_running=true
    title_slide=-1.0
    if cinematic:
        root.get_node("Toolbar/Next").disabled=true
        root.get_node("Toolbar/Previous").disabled=true
        for actor in performers.get_children():actor.set_talking(false)
        light.lighting_mode=0
        light.cinematic_dimming=title_scene_brightness
        performers.modulate.a=0.0
        if intro_camera_enabled:
            camera_zoom=intro_zoom
            camera_focus=intro_camera_focus
    title_tween=create_tween()
    title_tween.tween_property(self,"title_slide",0.0,title_slide_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    title_tween.tween_interval(title_hold_seconds)
    title_tween.tween_property(self,"title_slide",1.0,title_slide_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    if cinematic:
        title_tween.tween_property(self,"camera_zoom",1.0,camera_pull_back_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        title_tween.parallel().tween_property(self,"camera_focus",Vector2(0.5,0.5),camera_pull_back_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        title_tween.parallel().tween_property(light,"cinematic_dimming",1.0,camera_pull_back_seconds)
        title_tween.parallel().tween_property(performers,"modulate:a",1.0,camera_pull_back_seconds).set_trans(Tween.TRANS_SINE)
    title_tween.tween_callback(func():
        title_running=false
        if cinematic:
            dialogue_elapsed=0.0
            present())
    arrange()

func update_act_title(size: Vector2):
    if title_label==null:return
    var name=act_one_name if excerpt==0 else act_three_name
    title_label.text=active_backdrop_text if not active_backdrop_text.is_empty() else (("Act 1" if excerpt==0 else "Act 3")+(": "+name if not name.strip_edges().is_empty() else ""))
    title_label.add_theme_font_override("font",speaker_font if speaker_font!=null else get_body_font())
    title_label.add_theme_font_size_override("font_size",maxi(24,int(title_font_size*layout_font_scale)))
    title_label.self_modulate=title_color
    title_label.scale=Vector2.ONE
    title_label.size=size*Vector2(0.86,0.25)
    var slide=0.0 if Engine.is_editor_hint() else title_slide
    title_label.position=title_position*size-title_label.size*0.5-stage.get_node("World").position+Vector2(slide*(size.x+title_label.size.x)*0.5,0)
    title_label.visible=(preview_title_in_editor if Engine.is_editor_hint() else title_running)

func apply_graph_visuals(state: Dictionary):
    active_text_settings=state.get("text",{}).duplicate(true)
    var atmosphere=stage.get_node_or_null("World/Atmosphere")
    if atmosphere!=null:atmosphere.apply_settings(state.get("atmosphere",{}))
    var cut_in=stage.get_node_or_null("FrameCutInLayer/FrameCutIn")
    if cut_in!=null:
        var cue=state.get("cut_in",{})
        if cue.get("action","hide")=="show":cut_in.show_from_graph(cue,str(cue.get("id","")))
        else:cut_in.hide_from_graph()
func text_motion_mode() -> int:
    return int(active_text_settings.get("mode",dialogue_motion))
func text_motion_strength() -> float:
    return float(active_text_settings.get("amount",text_motion_amount))
func text_motion_rate() -> float:
    return float(active_text_settings.get("rate",text_motion_speed))
func text_reveal_speed() -> float:
    return float(active_text_settings.get("reveal",characters_per_second))
