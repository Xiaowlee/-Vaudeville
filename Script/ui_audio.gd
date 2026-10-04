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
