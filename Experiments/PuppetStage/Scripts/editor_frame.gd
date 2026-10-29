@tool
extends Node2D
func _process(_delta):queue_redraw()
func _draw():
    var stage=get_parent()
    if not Engine.is_editor_hint() or not stage.show_editor_frame:return
    var box=stage.stage_rect
    if box.size.x<=0:return
    draw_rect(box,Color(0.2,1,0.6),false,2)
    draw_line(Vector2(box.get_center().x,0),Vector2(box.get_center().x,box.end.y),Color(0.2,1,0.6,0.3),1)
