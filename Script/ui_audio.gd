extends AudioStreamPlayer
## Lives across screen changes so navigation clicks are not cut off.
func _ready() -> void:
    get_tree().node_added.connect(_watch)
    _watch_tree(get_tree().root)
func _watch_tree(node: Node) -> void:
    _watch(node)
    for child in node.get_children(): _watch_tree(child)
func _watch(node: Node) -> void:
    if node is BaseButton and not node.button_down.is_connected(_click):
        node.button_down.connect(_click)
func _click() -> void:
    play()

# One persistent music player survives gameplay -> menu after a failed show.
@export_group("Background music")
@export var act0_music: AudioStream=preload("res://Sound/Act0_InAPlaceHeAppear.wav")
@export var act12_music: AudioStream=preload("res://Sound/Act1_2_InAFinePlace.wav")
@export var act3_music: AudioStream=preload("res://Sound/Act3_InAPlaceSomeoneEnter.wav")
@export var failure_music: AudioStream=preload("res://Sound/00_InASpaceHeGotMe.wav")
@export_range(-60,0,1) var music_volume_db := -22.0
@export_range(0,15,.25) var intruder_silence_seconds := 5.0
@export_group("Stage effects")
@export var flip_sound: AudioStream=preload("res://Sound/Flip.mp3")
@export_range(-60,0,1) var flip_volume_db := -29.0
@export var boing_sound: AudioStream=preload("res://Sound/Boing.mp3")
@export_range(-60,0,1) var boing_volume_db := -21.0
@export var opening_texture: AudioStream=preload("res://Sound/8bitsound.mp3")
@export_range(-60,0,1) var opening_volume_db := -27.0
@export var light_sound: AudioStream=preload("res://Sound/Lightsound.mp3")
@export_range(-60,0,1) var light_volume_db := -24.0
@export var cutin_sound: AudioStream=preload("res://Sound/metalclink.mp3")
@export_range(-60,0,1) var cutin_volume_db := -23.0
@export_group("Phone effects")
## Phone assets use these names in mobile-companion/public/sound, never a desktop file URL.
@export_enum("tea") var phone_waiting_sound := "tea"
@export_enum("suspense") var phone_menacing_sound := "suspense"
@export_range(-60,0,1) var tea_volume_db := -22.0
@export_range(-60,0,1) var suspense_volume_db := -17.0
var failed_show := false
var music_generation := 0
var current_music: AudioStream
var music_group := ""
func start_playthrough():
    music_generation+=1
    failed_show=false;music_group="";current_music=null
    $Music.stop()
    for player in get_children():
        if player is AudioStreamPlayer and player!=$Music:player.stop();player.queue_free()
func leave_game():
    if failed_show:return
    music_generation+=1;current_music=null;music_group="";$Music.stop()
func enter_group(group: String):
    if group=="Endgame":
        if failed_show:return
        failed_show=true;music_generation+=1;music_group=group
        _play_music(failure_music)
        return
    if failed_show or music_group==group:return
    music_group=group;music_generation+=1
    var generation=music_generation
    if group=="Act 3":
        $Music.stop();current_music=null
        await get_tree().create_timer(intruder_silence_seconds).timeout
        if generation!=music_generation or failed_show:return
        _play_music(act3_music)
    elif group in ["Act 1","Act 2"]:_play_music(act12_music)
    elif group=="Act 0 · Pre-show":_play_music(act0_music)
func _play_music(stream: AudioStream):
    if stream==null:$Music.stop();current_music=null;return
    if current_music==stream and $Music.playing:return
    current_music=stream
    $Music.stream=stream.duplicate()
    if $Music.stream is AudioStreamWAV:
        $Music.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
        if $Music.stream.loop_end<=$Music.stream.loop_begin:$Music.stream.loop_end=int($Music.stream.get_length()*$Music.stream.mix_rate)
    elif $Music.stream is AudioStreamMP3 or $Music.stream is AudioStreamOggVorbis:$Music.stream.loop=true
    $Music.volume_db=music_volume_db
    $Music.play()
func stage_effect(stream: AudioStream, level: float):
    if stream==null:return
    var player=AudioStreamPlayer.new()
    player.stream=stream.duplicate();player.volume_db=level
    if player.stream is AudioStreamMP3 or player.stream is AudioStreamOggVorbis:player.stream.loop=false
    elif player.stream is AudioStreamWAV:player.stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
    add_child(player);player.finished.connect(player.queue_free);player.play()
