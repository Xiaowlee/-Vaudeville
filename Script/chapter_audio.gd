extends Node
## Players belong to the chapter, not to an individual beat.
const CHANNELS = ["Ambience", "Music", "Weather", "Movement", "OneShot"]
var fades: Dictionary = {}
var sources: Dictionary = {}
var last_beat := -1
func enter_beat(index: int, cues: Array) -> void:
	if index == last_beat: return
	last_beat = index
	for cue in cues:
		if cue != null: apply_cue(cue)
func apply_cue(cue: BeatAudioCue) -> void:
	if cue == null or cue.action == 0: return
	if cue.channel < 0 or cue.channel >= CHANNELS.size():
		push_warning("[Audio] Invalid cue channel; skipping sound")
		return
	var player := get_node_or_null(NodePath(CHANNELS[cue.channel])) as AudioStreamPlayer
	if player == null:
		push_warning("[Audio] Missing AudioStreamPlayer: " + str(get_path()) + "/" + CHANNELS[cue.channel] + "; skipping sound")
		return
	if cue.action in [1, 3] and cue.stream == null:
		push_warning("[Audio] Start needs a stream: " + CHANNELS[cue.channel])
		return
	if fades.has(player):
		fades[player].kill()
		fades.erase(player)
	if cue.action == 2:
		_fade_stop(player, cue.fade_out_seconds if cue.fade_out_seconds >= 0 else cue.fade_seconds)
		return
	# Change fades out the old track, then uses the existing Start behavior.
	if cue.action == 3 and player.playing and sources.get(player, player.stream) != cue.stream:
		var duration := cue.fade_out_seconds if cue.fade_out_seconds >= 0 else cue.fade_seconds
		var next: BeatAudioCue = cue.duplicate()
		next.action = 1
		if duration > 0:
			var tween := create_tween()
			fades[player] = tween
			tween.tween_property(player, "volume_db", -60.0, duration)
			tween.tween_callback(func():
				fades.erase(player)
				apply_cue(next))
			return
	# Do not restart an already playing loop, even when a later beat repeats Start.
	if cue.channel != 4 and player.playing and sources.get(player, player.stream) == cue.stream:
		
		
		_volume(player, cue.volume_db, cue.fade_in_seconds if cue.fade_in_seconds >= 0 else cue.fade_seconds)
		return
	sources[player] = cue.stream
	var sound: AudioStream = cue.stream.duplicate()
	if sound is AudioStreamWAV:
		sound.loop_mode = AudioStreamWAV.LOOP_DISABLED if cue.channel == 4 else AudioStreamWAV.LOOP_FORWARD
		if cue.channel != 4 and sound.loop_end <= sound.loop_begin: sound.loop_end = int(sound.get_length() * sound.mix_rate)
	elif sound is AudioStreamMP3 or sound is AudioStreamOggVorbis: sound.loop = cue.channel != 4
	player.stream = sound
	player.volume_db = -60.0 if (cue.fade_in_seconds if cue.fade_in_seconds >= 0 else cue.fade_seconds) > 0 else cue.volume_db
	player.play()
	_volume(player, cue.volume_db, cue.fade_in_seconds if cue.fade_in_seconds >= 0 else cue.fade_seconds)
	print("[Audio] Start ", CHANNELS[cue.channel], " ", cue.stream.resource_path)
func _volume(player: AudioStreamPlayer, target: float, seconds: float) -> void:
	if seconds <= 0: player.volume_db = target
	else:
		var tween := create_tween()
		fades[player] = tween
		tween.tween_property(player, "volume_db", target, seconds)
func _fade_stop(player: AudioStreamPlayer, seconds: float) -> void:
	if seconds <= 0 or not player.playing:
		player.stop()
		return
	var tween := create_tween()
	fades[player] = tween
	tween.tween_property(player, "volume_db", -60.0, seconds)
	tween.tween_callback(player.stop)
func stop_all(seconds: float = 0.5) -> void:
	for player in sfx_players: player.stop(); player.queue_free()
	sfx_players.clear()
	for channel in CHANNELS:
		var player := get_node_or_null(NodePath(channel)) as AudioStreamPlayer
		if player == null: continue
		if fades.has(player): fades[player].kill()
		_fade_stop(player, seconds)

@export_range(1, 32, 1) var maximum_sfx_voices := 12
var sfx_players: Array[AudioStreamPlayer] = []
func play_sfx(streams: Array, volume_db := -18.0) -> void:
	for stream in streams:
		if stream == null: continue
		if sfx_players.size() >= maximum_sfx_voices:
			var oldest = sfx_players.pop_front()
			oldest.stop()
			oldest.queue_free()
		var player := AudioStreamPlayer.new()
		player.stream = stream.duplicate()
		if player.stream is AudioStreamWAV: player.stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		elif player.stream is AudioStreamMP3 or player.stream is AudioStreamOggVorbis: player.stream.loop = false
		player.volume_db = volume_db
		add_child(player)
		sfx_players.append(player)
		player.finished.connect(func():
			sfx_players.erase(player)
			player.queue_free())
		player.play()
