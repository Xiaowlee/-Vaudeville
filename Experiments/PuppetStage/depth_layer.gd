extends Node2D
## Add parallax around the current authored/animated position, without restoring a fixed starting point.
@export var travel := Vector2(20,10)
var applied_offset := Vector2.ZERO
func aim(value: Vector2):
	var base=position+applied_offset
	applied_offset=value*travel
	position=base-applied_offset
