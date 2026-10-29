@tool
extends RichTextEffect
var bbcode="stagepop"
var controller: WeakRef
func _process_custom_fx(char_fx: CharFXTransform) -> bool:
    var settings=controller.get_ref() if controller!=null else null
    if settings==null:return true
    if settings.text_motion_mode()==0 or (Engine.is_editor_hint() and not settings.preview_dialogue_motion):return true
    var index=char_fx.relative_index+int(char_fx.env.get("base",0))
    var age=settings.dialogue_elapsed-index/maxf(settings.text_reveal_speed(),1.0)
    if age<0:
        char_fx.visible=false
        return true
    var scale=settings.layout_font_scale
    var t=age/maxf(settings.letter_pop_seconds,0.01)
    var settle=exp(-7.0*t)
    char_fx.offset.y+=settings.letter_pop_height*scale*settle*cos(t*9.0)
    var amount=1.0-0.08*settle*cos(t*9.0)
    char_fx.transform.x*=amount
    char_fx.transform.y*=amount
    if settings.text_motion_mode()==1:
        char_fx.offset.y+=sin(settings.dialogue_elapsed*TAU*settings.text_motion_rate()+index*0.35)*settings.text_motion_strength()*scale*(1.0-settle)
    elif settings.text_motion_mode()==2:
        char_fx.offset.y+=sin(settings.dialogue_elapsed*TAU*settings.text_motion_rate()+index*0.45)*settings.text_motion_strength()*scale
    elif settings.text_motion_mode()==3:
        var tick=floorf(settings.dialogue_elapsed*10.0)
        char_fx.offset+=Vector2(sin(index*31.3+tick*17.7),cos(index*11.9+tick*13.1))*settings.text_motion_strength()*scale
    return true
