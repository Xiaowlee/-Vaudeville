@tool
extends Control
## Content supplies a minimum; Inspector Custom Minimum Size remains your lower bound.
var content_minimum := Vector2.ZERO:
	set(value):
		if content_minimum == value: return
		content_minimum = value
		update_minimum_size()

func _get_minimum_size() -> Vector2:
	return content_minimum
