@tool
extends CanvasLayer
## Visual rehearsal using existing Act 1 events. Next advances a display page, not a story route.
@export_enum("Beside character", "Lower panel") var layout_style := 0
@export_group("Alignment")
## Text Alignment centres each line. Block Alignment centres the whole reading block in its zone.
@export_enum("Left", "Center", "Right") var character_text_alignment := 0
@export_enum("Left", "Center", "Right") var narrator_text_alignment := 1
@export_enum("Top", "Center", "Bottom") var character_block_alignment := 0
@export_enum("Top", "Center", "Bottom") var narrator_block_alignment := 1
@export_range(0.3,1,0.05) var text_block_width := 1.0
@export_enum("Left", "Center", "Right") var block_horizontal_alignment := 1
@export_group("Smart placement")
## Chooses a stable position for each page, trying the sides, above and below the speaker.
@export var smart_placement := true
@export_enum("Automatic", "Left", "Right", "Above", "Below") var preferred_placement := 0
@export var smart_box_size := Vector2(0.30,0.25)
@export_range(0,100,1) var character_gap := 20.0
## Uses the existing grey puppet as a third occupancy stand-in, not new Actor 2 artwork.
@export var show_third_character := false
@export_group("Readability")
## Protect the actual name and paragraph even with manually positioned decorative panels.
@export var protect_reading_area := true
@export var text_outline_enabled := false
@export_range(1,8,1) var text_outline_size := 2
@export var text_outline_color := Color(0.04,0.03,0.12,1)
## Appears above the character but below text only when overlap cannot be avoided.
@export var overlap_soft_backing := true
@export var overlap_backing_color := Color(0.04,0.03,0.12,0.96)
@export_range(0,60,1) var motion_safety_margin := 12.0
@export_group("Character sizing")
## Both modes are previewed in the editor and game. Authored size is preserved by default.
@export_enum("Preserve authored size", "Reserve dialogue space") var character_fit_mode := 0
@export_range(0,0.35,0.01) var dialogue_space_reserve := 0.15
@export_group("Editor preview")
@export_range(0,100,1) var preview_page := 0
@export_group("Typography")
@export_range(18,40,1) var text_size := 24
@export_range(0,40,1) var name_extra_size := 8
@export var text_color := Color.WHITE
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
@onready var stage=get_parent()
@onready var root=$Layout
func _ready():
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
    soft_backing.name="OverlapReadabilityBacking"
    soft_backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
    root.add_child(soft_backing)
    root.move_child(soft_backing,root.get_node("Text").get_index())
    var shader=Shader.new()
    shader.code="""shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color;
uniform vec2 rect_size;
void fragment(){
    vec2 d=min(UV,vec2(1.0)-UV)*rect_size;
    float edge=smoothstep(0.0,20.0,min(d.x,d.y));
    COLOR=vec4(tint.rgb,tint.a*edge);
}"""
    var mat=ShaderMaterial.new()
    mat.shader=shader
    soft_backing.material=mat
    var data=JSON.parse_string(FileAccess.get_file_as_string("res://Story/StageActs/Graph/acts_0_3_manifest.json"))
    var event_index=0
    for key in ["A1_1_Once upon a time","A1_1_ACTOR 1'sQuestion","A1_3_FirstCue","A1_4_SecondCue"]:
        for event in data[key]["frame"]["events"]:
            if event["kind"] not in ["dialogue","narration"]:continue
            var words=event["text"].split(" ",false)
            var part=""
            for word in words:
                if part.length()+word.length()>105:
                    pages.append({"text":part,"speaker":event["speaker"],"kind":event["kind"],"event":event_index})
                    part=""
                part+=(" " if not part.is_empty() else "")+word
            if not part.is_empty():pages.append({"text":part,"speaker":event["speaker"],"kind":event["kind"],"event":event_index})
            event_index+=1
    root.get_node("Toolbar/Style").select(layout_style)
    root.get_node("Toolbar/Style").item_selected.connect(func(i):layout_style=i;arrange())
    root.get_node("Toolbar/Previous").pressed.connect(func():page_index=maxi(0,page_index-1);present())
    root.get_node("Toolbar/Next").pressed.connect(func():page_index=mini(pages.size()-1,page_index+1);present())
    root.get_node("Toolbar/Pose").pressed.connect(func():
        for actor in stage.get_node("World/Performers").get_children():actor.flip())
    root.get_node("Toolbar/Restart").pressed.connect(func():page_index=0;present())
    present()
func present():
    var page=pages[page_index]
    var speaker=page["speaker"]
    if speaker=="Actor 1":last_side=1
    elif speaker=="MC":last_side=0
    root.get_node("Text/Name").text="Narrator" if speaker.is_empty() else ("Player" if speaker=="MC" else speaker)
    root.get_node("Text/Words").text=page["text"]
    root.get_node("Toolbar/Count").text="%s / %s" % [page_index+1,pages.size()]
    root.get_node("Toolbar/Previous").disabled=page_index==0
    root.get_node("Toolbar/Next").disabled=page_index==pages.size()-1
    var light=stage.get_node("World/Lighting")
    light.lighting_mode=0 if speaker.is_empty() or speaker=="Stage Manager" else 1
    light.focus_character=0 if speaker=="MC" else 1
    for actor in stage.get_node("World/Performers").get_children():
        actor.set_talking(actor.name==("Player" if speaker=="MC" else "Actor1") and speaker in ["MC","Actor 1"])
    arrange()
func _process(_delta):
    if Engine.is_editor_hint() and not pages.is_empty() and preview_page!=last_preview_page:
        last_preview_page=preview_page
        page_index=clampi(preview_page,0,pages.size()-1)
        present()
    arrange()
func arrange():
    if pages.is_empty() or backing==null or soft_backing==null:return
    var size=stage.screen_size if Engine.is_editor_hint() else get_viewport().get_visible_rect().size
    var performers=stage.get_node("World/Performers")
    performers.get_node("StageManager").visible=show_third_character
    var fit=minf(size.x/stage.design_size.x,size.y/stage.design_size.y)
    performers.scale=Vector2.ONE*fit*(1.0-dialogue_space_reserve if character_fit_mode==1 else 1.0)
    var page=pages[page_index]
    var narration=page["speaker"].is_empty() or page["speaker"]=="Stage Manager"
    var side=last_side
    var placement=narrator_bottom if narration else ((beside_left if side==0 else beside_right) if layout_style==0 else (lower_left if side==0 else lower_right))
    var box=Rect2(size*placement.position,size*placement.size)
    if narration:box.position.x=(size.x-box.size.x)*0.5
    var px=int(clampf(text_size*minf(size.x/1280.0,size.y/720.0),18,32))
    var name_label=root.get_node("Text/Name")
    var words=root.get_node("Text/Words")
    name_label.add_theme_font_size_override("font_size",px+name_extra_size)
    words.add_theme_font_size_override("font_size",px)
    name_label.add_theme_color_override("font_color",text_color)
    words.add_theme_color_override("font_color",text_color)
    for label in [name_label,words]:
        label.add_theme_color_override("font_outline_color",text_outline_color)
        label.add_theme_constant_override("outline_size",text_outline_size if text_outline_enabled else 0)
    movement_envelopes.clear()
    for actor in performers.get_children():
        if actor.visible:movement_envelopes.append(character_rect(actor).grow(character_gap))
    var key=str([page_index,size,layout_style,preferred_placement,smart_box_size,character_gap,show_third_character,character_fit_mode,dialogue_space_reserve,smart_placement,protect_reading_area,placement,px,text_padding,text_block_width,character_block_alignment,block_horizontal_alignment])
    if not narration:
        var current_safe=not overlaps_characters(reading_rect(cached_smart_box,px,false))
        if key!=placement_key or (protect_reading_area and not current_safe):
            if smart_placement or (protect_reading_area and overlaps_characters(reading_rect(box,px,false))):
                cached_smart_box=choose_smart_box(size,"Player" if page["speaker"]=="MC" else "Actor1",box,px)
            else:cached_smart_box=box
            placement_key=key
        box=cached_smart_box
    var needed=measure_text(maxf((box.size.x-text_padding.x*2)*text_block_width,40),px)
    box.size.y=maxf(box.size.y,needed.x+needed.y+10+text_padding.y*2)
    box.position.y=clampf(box.position.y,size.y*0.08,maxf(size.y-54-box.size.y,size.y*0.08))
    resolved_box=box
    var inner=(box.size-text_padding*2).max(Vector2(40,40))
    var block_width=maxf(inner.x*text_block_width,40)
    var heights=measure_text(block_width,px)
    var total_height=heights.x+10+heights.y
    var vertical=narrator_block_alignment if narration else character_block_alignment
    var content_position=box.position+text_padding+Vector2((inner.x-block_width)*block_horizontal_alignment*0.5,maxf(inner.y-total_height,0)*vertical*0.5)
    var text=root.get_node("Text")
    text.position=content_position
    text.size=Vector2(block_width,total_height)
    name_label.position=Vector2.ZERO
    name_label.size=Vector2(block_width,heights.x)
    words.position=Vector2(0,heights.x+10)
    words.size=Vector2(block_width,heights.y)
    var alignment=narrator_text_alignment if narration else character_text_alignment
    name_label.horizontal_alignment=alignment
    words.horizontal_alignment=alignment
    last_reading_rect=Rect2(content_position,Vector2(block_width,total_height))
    var overlap=overlaps_characters(last_reading_rect)
    used_readability_fallback=overlap
    # Decorative backing remains below the puppets; only the safety backing is above them.
    backing.scale=Vector2.ONE
    backing.position=box.position-stage.get_node("World").position
    backing.size=box.size
    backing.color=panel_color
    backing.visible=show_panel and layout_style==1
    soft_backing.position=last_reading_rect.position-Vector2(28,24)
    soft_backing.size=last_reading_rect.size+Vector2(56,48)
    soft_backing.material.set_shader_parameter("tint",overlap_backing_color)
    soft_backing.material.set_shader_parameter("rect_size",soft_backing.size)
    soft_backing.visible=overlap and (overlap_soft_backing or protect_reading_area)
    var bar=root.get_node("Toolbar")
    bar.position=Vector2(16,size.y-42)

func measure_text(width: float, px: int) -> Vector2:
    var name_label=root.get_node("Text/Name")
    var words=root.get_node("Text/Words")
    var font=words.get_theme_font("font")
    var name_height=name_label.get_theme_font("font").get_multiline_string_size(name_label.text,HORIZONTAL_ALIGNMENT_LEFT,maxf(width-8,20),px+name_extra_size).y+6
    var body_height=font.get_multiline_string_size(str(pages[page_index]["text"]),HORIZONTAL_ALIGNMENT_LEFT,maxf(width-8,20),px).y+10
    return Vector2(name_height,body_height)

func reading_rect(box: Rect2, px: int, narration: bool) -> Rect2:
    var inner=(box.size-text_padding*2).max(Vector2(40,40))
    var width=maxf(inner.x*text_block_width,40)
    var heights=measure_text(width,px)
    var height=heights.x+10+heights.y
    var vertical=narrator_block_alignment if narration else character_block_alignment
    var start=box.position+text_padding+Vector2((inner.x-width)*block_horizontal_alignment*0.5,maxf(inner.y-height,0)*vertical*0.5)
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
    var safe=Rect2(size*Vector2(0.035,0.10),size*Vector2(0.93,0.80))
    var speaker=stage.get_node("World/Performers").get_node(speaker_name)
    var bounds=character_rect(speaker).grow(character_gap)
    var regions: Array[Rect2]=[safe]
    for obstacle in movement_envelopes:
        var next: Array[Rect2]=[]
        for region in regions:
            if not region.intersects(obstacle):
                next.append(region)
                continue
            var hit=region.intersection(obstacle)
            for rect in [Rect2(region.position,Vector2(region.size.x,hit.position.y-region.position.y)),Rect2(Vector2(region.position.x,hit.end.y),Vector2(region.size.x,region.end.y-hit.end.y)),Rect2(Vector2(region.position.x,hit.position.y),Vector2(hit.position.x-region.position.x,hit.size.y)),Rect2(Vector2(hit.end.x,hit.position.y),Vector2(region.end.x-hit.end.x,hit.size.y))]:
                if rect.size.x>100 and rect.size.y>30:next.append(rect)
        regions=next
    var candidates: Array[Rect2]=[]
    # Reflow into clear regions instead of choosing a smaller amount of overlap.
    for region in regions:
        for width in [minf(size.x*smart_box_size.x,region.size.x),region.size.x]:
            if width<180:continue
            var content=measure_text(maxf((width-text_padding.x*2)*text_block_width,40),px)
            var height=content.x+10+content.y+text_padding.y*2
            if height>region.size.y:continue
            var start=Vector2(clampf(bounds.get_center().x-width*0.5,region.position.x,region.end.x-width),clampf(bounds.get_center().y-height*0.5,region.position.y,region.end.y-height))
            candidates.append(Rect2(start,Vector2(width,height)))
    var authored_read=reading_rect(authored,px,false)
    if safe.encloses(authored_read) and not overlaps_characters(authored_read):candidates.append(authored)
    var best=Rect2()
    var cost=INF
    for candidate in candidates:
        var read=reading_rect(candidate,px,false)
        if overlaps_characters(read) or not safe.encloses(read):continue
        var centre=candidate.get_center()
        var distance=centre.distance_to(bounds.get_center())
        var direction=1 if centre.x<bounds.position.x else (2 if centre.x>bounds.end.x else (3 if centre.y<bounds.get_center().y else 4))
        if preferred_placement>0 and direction!=preferred_placement:distance+=size.x*0.25
        if distance<cost:
            cost=distance
            best=candidate
    if best.size.x>0:return best
    # No free area: show a frontmost readable caption rather than hide words behind art.
    var width=size.x*0.72
    var content=measure_text((width-text_padding.x*2)*text_block_width,px)
    var height=content.x+content.y+10+text_padding.y*2
    return Rect2(Vector2((size.x-width)*0.5,maxf(size.y*0.90-height,size.y*0.12)),Vector2(width,height))
