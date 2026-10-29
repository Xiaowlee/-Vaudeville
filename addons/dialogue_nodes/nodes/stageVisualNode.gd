@tool
extends GraphNode
## A visual, arrow-connected production cue. No command syntax is required.
signal modified
var undo_redo: EditorUndoRedoManager
var payload: Dictionary = {"kind":"cut_in","action":"show","placement":0,"character":0,"picture_source":0,"crop":[0.05,0.0,0.9,0.48],"aspect":1.9,"fill":1.0,"hold":0.0}
var form: VBoxContainer
var loading := false
func _ready():build_form()
func add_label(text: String):
    var label=Label.new();label.text=text;form.add_child(label)
func choice(label: String, key: String, items: Array, current: int):
    add_label(label)
    var field=OptionButton.new()
    for item in items:field.add_item(str(item))
    field.select(clampi(current,0,items.size()-1))
    field.item_selected.connect(func(i):change(key,i))
    form.add_child(field)
func number(label: String,key: String,current: float,minimum: float,maximum: float,step: float):
    add_label(label)
    var field=SpinBox.new();field.min_value=minimum;field.max_value=maximum;field.step=step;field.value=current
    field.value_changed.connect(func(value):change(key,value))
    form.add_child(field)
func colour(label: String,key: String,current: String):
    add_label(label)
    var field=ColorPickerButton.new();field.color=Color(current);field.custom_minimum_size.y=28
    field.color_changed.connect(func(value):change(key,value.to_html()))
    form.add_child(field)
func picture_field(label: String,key: String):
    add_label(label)
    if Engine.is_editor_hint():
        var field=EditorResourcePicker.new();field.base_type="Texture2D"
        var path=str(payload.get(key,""))
        if not path.is_empty() and ResourceLoader.exists(path):field.edited_resource=load(path)
        field.resource_changed.connect(func(value):change(key,value.resource_path if value!=null else ""))
        form.add_child(field)
    else:
        var field=LineEdit.new();field.text=str(payload.get(key,""));field.placeholder_text="res:// image path"
        field.text_submitted.connect(func(value):change(key,value));form.add_child(field)
func build_form():
    loading=true
    if is_instance_valid(form):remove_child(form);form.queue_free()
    form=VBoxContainer.new();form.custom_minimum_size.x=290;add_child(form)
    var kinds=["cut_in","text","atmosphere"]
    var selector=OptionButton.new()
    for item in ["Cut-in illustration","Text effect","Stage atmosphere"]:selector.add_item(item)
    selector.select(maxi(kinds.find(payload.get("kind","cut_in")),0))
    selector.item_selected.connect(func(i):change("kind",kinds[i],true))
    form.add_child(selector)
    match str(payload.get("kind","cut_in")):
        "cut_in":
            choice("Panel", "action_index",["Show","Hide"],0 if payload.get("action","show")=="show" else 1)
            if payload.get("action","show")=="show":
                choice("Position area","placement",["NPC — right","MC — left","Custom area"],int(payload.get("placement",0)))
                choice("Picture","picture_source",["Character close-up","Separate illustration"],int(payload.get("picture_source",0)))
                if int(payload.get("picture_source",0))==0:
                    choice("Character","character",["Actor 1","Player","Actor 2"],int(payload.get("character",0)))
                else:picture_field("Illustration","texture")
                number("Width / height (0 = picture)","aspect",float(payload.get("aspect",1.9)),0,4,0.05)
                number("Size within placement area","fill",float(payload.get("fill",1.0)),0.3,1,0.05)
                number("Seconds (0 = until Hide node)","hold",float(payload.get("hold",0)),0,30,0.25)
                var crop=payload.get("crop",[0.05,0,0.9,0.48])
                for i in 4:number(["Crop left","Crop top","Crop width","Crop height"][i],"crop_"+str(i),float(crop[i]),0,1,0.01)
        "text":
            choice("Text movement","mode",["Normal / still","Pop and settle","Gentle wave","Jitter"],int(payload.get("mode",1)))
            number("Motion strength","amount",float(payload.get("amount",0.7)),0,5,0.1)
            number("Motion speed","rate",float(payload.get("rate",0.6)),0.1,4,0.1)
            number("Letters per second","reveal",float(payload.get("reveal",38)),5,100,1)
        "atmosphere":
            choice("Surrounding pattern","enabled_index",["On","Off"],0 if payload.get("enabled",true) else 1)
            picture_field("Pattern image (empty = stage default)","texture")
            colour("Pattern colour","ink",str(payload.get("ink","5740edff")))
            colour("Background colour","paper",str(payload.get("paper","b88fdbff")))
            var speed=payload.get("speed",[0.012,0.004])
            number("Scroll horizontally","speed_x",float(speed[0]),-0.1,0.1,0.001)
            number("Scroll vertically","speed_y",float(speed[1]),-0.1,0.1,0.001)
            number("Pattern tile size","tile_size",float(payload.get("tile_size",420)),80,1200,10)
    var note=Label.new();note.text="Connect before the affected line.
Cut-ins persist until a Hide cue.";note.modulate=Color(0.7,0.75,0.85);form.add_child(note)
    set_slot(0,true,0,Color.WHITE,true,0,Color.WHITE)
    title="Stage Visual — "+["Cut-in","Text","Atmosphere"][selector.selected]
    size=Vector2.ZERO
    loading=false
func change(key: String,value: Variant,rebuild: bool=false):
    if loading:return
    var before=payload.duplicate(true)
    var after=payload.duplicate(true)
    if key=="kind":
        after=defaults(str(value))
    elif key=="action_index":after["action"]="show" if int(value)==0 else "hide";rebuild=true
    elif key=="enabled_index":after["enabled"]=int(value)==0
    elif key.begins_with("crop_"):
        var crop=after.get("crop",[0.05,0.0,0.9,0.48]).duplicate();crop[int(key.trim_prefix("crop_"))]=value;after["crop"]=crop
    elif key in ["speed_x","speed_y"]:
        var speed=after.get("speed",[0.012,0.004]).duplicate();speed[0 if key=="speed_x" else 1]=value;after["speed"]=speed
    else:after[key]=value
    if key=="picture_source":rebuild=true
    if before==after:return
    if undo_redo!=null:
        undo_redo.create_action("Change stage visual")
        undo_redo.add_do_method(self,"set_payload",after,rebuild)
        undo_redo.add_undo_method(self,"set_payload",before,true)
        undo_redo.commit_action()
    else:set_payload(after,rebuild)
func set_payload(value: Dictionary,rebuild: bool=true):
    payload=value.duplicate(true)
    if rebuild and is_node_ready():build_form()
    modified.emit()
func _to_dict(graph: GraphEdit) -> Dictionary:
    var links=graph.get_connections(name)
    var saved=defaults(str(payload.get("kind","cut_in")))
    saved.merge(payload,true)
    return {"visual":saved,"signalValue":"stage_visual:"+JSON.stringify(saved),"link":links[0]["to_node"] if not links.is_empty() else "END"}
func _from_dict(data: Dictionary) -> Array[String]:
    payload=data.get("visual",{}).duplicate(true)
    if payload.is_empty():
        var decoded=JSON.parse_string(str(data.get("signalValue","")).trim_prefix("stage_visual:"))
        if decoded is Dictionary:payload=decoded
    build_form()
    return [str(data.get("link","END"))]

func defaults(kind: String) -> Dictionary:
    match kind:
        "text":return {"kind":"text","mode":1,"amount":0.7,"rate":0.6,"reveal":38}
        "atmosphere":return {"kind":"atmosphere","enabled":true,"texture":"","ink":"5740edff","paper":"b88fdbff","speed":[0.012,0.004],"tile_size":420}
    return {"kind":"cut_in","action":"show","placement":0,"character":0,"picture_source":0,"crop":[0.05,0,0.9,0.48],"aspect":1.9,"fill":1.0,"hold":0}
