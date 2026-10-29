@tool
extends Control
## Editor-only guide. Drag/resize this Control to author the dialogue area.
@export var guide_label := "Dialogue zone"
@export var guide_color := Color(0.3,0.85,1.0,0.7)
@export var show_guide := true
func _process(_delta):
    if Engine.is_editor_hint():queue_redraw()
func _draw():
    if not Engine.is_editor_hint() or not show_guide:return
    draw_rect(Rect2(Vector2.ZERO,size),Color(guide_color,0.04))
    draw_rect(Rect2(Vector2.ZERO,size),guide_color,false,1.5)
    draw_string(get_theme_default_font(),Vector2(6,18),guide_label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,guide_color)
