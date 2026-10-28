"""Typed Twine production script. Only narration/dialogue are displayable.
Original draft remains untouched. No prose is executed as arbitrary code.
"""
import re, html
FIELDS={'CONTEXT':'context','NARRATOR':'narration','STAGE':'stage','SOUND':'sound','CUE / PHONE':'phone','PLAYER TASK':'task','AUTHOR NOTE':'note','MC BEHAVIOUR':'mc','NPC BEHAVIOUR':'npc','HUD':'hud','ASSETS REQUIRED':'assets','STATE CHANGES':'state','NARRATIVE PURPOSE':'purpose'}
HOOKS=['ON ENTER','ON LISTEN','ON ACCEPT','ON UNCLEAR','ON SILENCE','ON QUESTION','ON OFFSCRIPT']
HEADER=re.compile(r'^(CONTEXT|NARRATOR|STAGE|SOUND|CUE\s*/\s*PHONE|PLAYER TASK|AUTHOR NOTE|MC BEHAVIOUR|NPC BEHAVIOUR|HUD|ASSETS REQUIRED|STATE CHANGES|NARRATIVE PURPOSE|ON ENTER|ON LISTEN|ON ACCEPT|ON UNCLEAR|ON SILENCE|ON QUESTION|ON OFFSCRIPT|ACTOR\s*\d+|ACTOR|STAGE MANAGER|THE MAIN ACTOR|MC|YOU)(?:\s*,[^:]+)?\s*:+\s*(.*)$',re.I)
SPEAKERS={'ACTOR':'Actor 1','ACTOR 1':'Actor 1','ACTOR 2':'Actor 2','STAGE MANAGER':'Stage Manager','THE MAIN ACTOR':'MC','MC':'MC','YOU':'MC'}
SAFE={'tranditional':'traditional','stagae':'stage','lookes':'looks','waitng':'waiting','nuging':'nudging','becase':'because','grumpling':'grumbling','marchs':'marches','atire':'attire','befused':'bemused','squeesh':'squeeze','hand written':'handwritten','pops on on':'pops up','eys':'eyes','If your keep':'If you keep','unseries':'unserious','He stand in':'He stands in','He take a moment':'He takes a moment','He quickly fix':'He quickly fixes','She quietly signal':'She quietly signals','She swiftly leave':'She swiftly leaves','before she continue':'before she continues','She stands there':'She stands there','The stage are':'The stage is','The Actor and the audience is':'The Actor and the audience are','All the eyes of the audience is':'All the eyes of the audience are','The one who keep':'The one who keeps','suppose to be':'supposed to be','acrossed':'across','packed the theater':'packed theater','gets stiff up':'stiffens','she back down':'she backs down','atire':'attire','ligh stripes':'light stripes','sometime before':'some time before'}
def clean_words(text):
 for a,b in SAFE.items():text=re.sub(r'\b'+re.escape(a)+r'\b',b,text)
 return text

def parse_script(body):
 body=re.sub(r'<<.*?>>','',body,flags=re.S)
 body=html.unescape(re.sub(r'<img\b[^>]*>','',body,flags=re.I))
 body=re.sub(r'<[^>]+>','',body)
 events=[];notes=[];context=[];task=[];warnings=[];hooks={k:[] for k in HOOKS}
 area='scene';kind='auto';speaker='';buffer=[];quoted=False;quote_lines=[];quote_speaker='';board_quote=False
 def emit(k,text,who=''):
  text=text.strip()
  if not text:return
  if k=='context':context.append(text)
  elif k=='task':task.append(text)
  elif k=='note':notes.append(text)
  elif k in HOOKS:hooks[k].append({'kind':'stage','text':text})
  else:
   if k=='phone':text=re.sub(r'^(?:CUE CARD:|SCRIPT UPDATE)\s*[—:-]*\s*','',text,flags=re.I)
   events.append({'kind':k,'speaker':who if k=='dialogue' else '', 'text':text})
 def flush():
  nonlocal buffer
  if buffer:emit('narration' if kind in ['auto','dialogue'] else kind,'\n'.join(buffer))
  buffer=[]
 for raw in body.splitlines():
  line=raw.strip()
  if line.upper() in ['PLAYER RESPONSE:', 'PLAYER RESPONSE / CONTINUE:']:
   flush();area='routes';continue
  if line.upper()=='AUTHOR NOTE:':
   flush();area='note';kind='note';continue
  if line.startswith('!! '):
   flush(); title=line[3:].lower()
   if 'scene script' in title:area='scene';kind='auto'
   elif 'player response' in title:area='routes'
   elif 'author note' in title:area='note';kind='note'
   elif 'context' in title:area='context';kind='context'
   continue
  if area=='routes' or line.startswith('[['):continue
  if area in ['note','context']:
   if area=='note' and line.startswith('CONTEXT:'):
    area='context';line=line.removeprefix('CONTEXT:').strip()
   if line:emit(area if area=='note' else 'context',line)
   continue
  if line=='NARRATOR':line='NARRATOR:'
  if line in ['---','**END OF ACTS 1–3 PROTOTYPE**']:emit('note',line);continue
  if line.startswith('[what '):emit('task',line.strip('[]'));continue
  match=HEADER.match(line) if not quoted else None
  if match:
   flush();label=re.sub(r'\s+',' ',match[1].upper());line=match[2]
   if label in SPEAKERS or re.fullmatch(r'ACTOR \d+',label):
    speaker=SPEAKERS.get(label,label.title());kind='dialogue'
   else:kind=FIELDS.get(label,label)
   if not line:continue
  if not line:
   if quoted:quote_lines.append('')
   else:flush()
   continue
  # Explicit production fields stay production until the next field, even across paragraphs.
  if kind not in ['auto','dialogue','narration']:
   buffer.append(line);continue
  if quoted:
   end=line.find('"')
   if end<0:quote_lines.append(line);continue
   quote_lines.append(line[:end]);emit('dialogue' if quote_speaker else 'narration','\n'.join(quote_lines),quote_speaker)
   tail=line[end+1:].strip(' .');quoted=False;quote_lines=[]
   if tail:emit('narration',tail)
   continue
  if line.startswith(('"','“')):
   flush(); end=max(line.rfind('"'),line.rfind('”'))
   who=speaker if kind!='narration' else ''
   if board_quote:who='';board_quote=False
   if end>0:
    emit('dialogue' if who else 'narration',line[1:end],who)
    tail=line[end+1:].strip(' .')
    if tail:emit('narration',tail)
   else:quoted=True;quote_speaker=who;quote_lines=[line[1:]]
  else:
   buffer.append(line)
 if quoted:
  emit('dialogue' if quote_speaker else 'narration','\n'.join(quote_lines),quote_speaker)
  warnings.append('Unclosed quotation: confirm speaker and final line.')
 flush()
 return {'events':events,'context':'\n'.join(context),'player_task':'\n'.join(task),'author_notes':notes,'grammar_warnings':warnings,'production_hooks':hooks}

def clean_working_copy(source):
 out=[]
 for m in re.finditer(r'^:: (.+?)\n(.*?)(?=^:: |\Z)',source.replace('\r\n','\n'),re.M|re.S):
  header,body=m[1],m[2];name=re.split(r' \[| \{',header)[0].strip()
  if name=='AUTHOR_TEMPLATE':
   out.append(':: '+header+'\nCONTEXT:\n\nNARRATOR:\n\nACTOR 1:\n\nSTAGE:\n\nSOUND:\n\nCUE / PHONE:\n\nPLAYER TASK:\n\nPLAYER RESPONSE:\n\nAUTHOR NOTE:\n');continue
  if not(name=='Start' or name.startswith(('A1_','A2_','A3_','\\ A1_')) or name=='A0_Endgame'):
   out.append(':: '+header+'\n'+body.rstrip());continue
  # Legacy STAGE/SOUND inline notes end at the paragraph. Explicit cleaned fields do not.
  scene=body.split('!! Scene script — in order',1)[-1].split('!! Player response')[0].split('!! Author note')[0]
  # Add explicit narration boundaries after legacy production paragraphs.
  scene=re.sub(r'((?:STAGE|SOUND):[^\n]*\n(?:[^\n]+\n)*?)\n',r'\1\nNARRATOR:\n',scene)
  # Preserve speaker across prose but clear the displayed label on every prose event.
  scene=re.sub(r'(<div class="cue">.*?</div>)',r'\1\n\nNARRATOR:',scene)
  scene=scene.replace('NARRATOR\n','NARRATOR:\n')
  # Unlabelled continuation in the opening is unmistakably the manager finishing his sentence.
  scene=scene.replace('Without further ado...\nLet the show begin."','STAGE MANAGER: "Without further ado...\nLet the show begin."')
  prefix=body.split('!! Scene script — in order')[0] if '!! Scene script — in order' in body else ''
  meta=parse_script(prefix+'!! Scene script — in order\n'+scene)
  # A quoted cue-board description is a phone instruction, not the real player speaking as MC.
  if name=='A1_3_FirstCue':
   for e in meta['events']:
    if e['speaker']=='MC' and e['text'].lower()=='i want to become a writer, just like you.':e['kind']='phone';e['speaker']=''
  chunks=[':: '+header]
  if meta['context']:chunks+=['CONTEXT:\n'+meta['context']]
  for e in meta['events']:
   label=e['speaker'].upper() if e['kind']=='dialogue' else next((k for k,v in FIELDS.items() if v==e['kind']),e['kind'].upper())
   text=clean_words(e['text'])
   chunks+=[label+':\n'+('"'+text+'"' if e['kind']=='dialogue' else text)]
  if meta['player_task']:chunks+=['PLAYER TASK:\n'+meta['player_task']]
  route_section=body.split('!! Player response',1)[1].split('!! Author note')[0] if '!! Player response' in body else ''
  links=re.findall(r'\[\[[^\n]+',route_section)
  if links:chunks+=['PLAYER RESPONSE:\n\n'+'\n\n'.join(links)]
  note=body.split('!! Author note',1)[1].strip() if '!! Author note' in body else ''
  if meta['grammar_warnings']:note+='\nREVIEW: '+' '.join(meta['grammar_warnings'])
  if note:chunks+=['AUTHOR NOTE:\n'+note]
  out.append('\n\n'.join(chunks))
 return '\n\n\n'.join(out)+'\n'

def route_metadata(links,kinds,cue):
 allowed={};fallbacks={};bounds={};issues=[]
 for (label,dest),kind in zip(links,kinds):
  low=label.lower().strip(' .')
  if kind=='silence':fallbacks['SILENCE']={'action':'route','route':kind};continue
  if any(x in low for x in ['unrelated','off-topic','off the script','something else']):
   fallbacks['OFFSCRIPT']={'action':'route','route':kind}
   continue
  if kind in ['next','watch']:continue
  allowed[kind]={'meaning':label,'destination':dest}
  if low in ['left','right']:bounds[kind]=[low,'west' if low=='left' else 'east','western' if low=='left' else 'eastern']
 interactive=bool(allowed or fallbacks)
 task='Read the phone cue aloud.' if any('read ' in x[0].lower() for x in links) else ('Choose an entrance verbally.' if bounds else ('Respond to the current scene.' if interactive else ''))
 if cue.upper()=='COMMENT ON THE HALL':task='Comment on the hall or the people gathered there.'
 return {'allowed_authored_intents':allowed,'response_overrides':fallbacks,'bounded_evidence':bounds,'input_mode':'speech' if interactive else 'continue','player_task':task,'narrative_purpose':'','mc_behaviour':[],'npc_behaviour':[],'assets_required':[],'state_changes':{},'missing_logic':issues}
