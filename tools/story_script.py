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


def import_response_template(project, source):
 from html.parser import HTMLParser
 import json, hashlib, datetime, shutil
 class Export(HTMLParser):
  def __init__(self):super().__init__();self.rows={};self.attrs={};self.current=None
  def handle_starttag(self, tag, attrs):
   if tag=='tw-passagedata':
    a=dict(attrs);self.current=a['name'];self.rows[self.current]='';self.attrs[self.current]=a
  def handle_endtag(self, tag):
   if tag=='tw-passagedata':self.current=None
  def handle_data(self, text):
   if self.current is not None:self.rows[self.current]+=text
 data=Export();data.feed(source.read_text(encoding='utf-8-sig'))
 assert data.rows and 'Universal responses' in data.rows, 'Expected full response-template Twine HTML'
 def sections(body):
  matches=list(re.finditer(r'^(CONVERSATION|ANSWER \d+(?: NEXT| STATE)?|SILENCE|OFFSCRIPT|TECHNICAL RETRY|MIC CHECK|TAKEOVER(?: NEXT| STATE)?|AUTHOR NOTE):\s*$',body,re.M))
  return {m[1]:body[m.end():matches[i+1].start() if i+1<len(matches) else len(body)].strip() for i,m in enumerate(matches)}
 def links(body):
  result=[]
  for text in re.findall(r'\[\[([^\]\n]+)\]\]',body):
   if '->' in text:label,dest=text.split('->',1)
   elif '<-' in text:dest,label=text.split('<-',1)
   elif '|' in text:label,dest=text.split('|',1)
   else:label=dest=text
   result.append([label.strip(),dest.strip()])
  return result
 def state(text):return dict(re.findall(r'^([\w]+):\s*(.+)$',text,re.M))
 shared=sections(data.rows['Universal responses'])
 rows={n:b for n,b in data.rows.items() if n not in ['Universal responses'] and not any(t in data.attrs[n].get('tags','').split() for t in ['script','stylesheet','widget']) and n not in ['StoryInit','PassageHeader','PassageFooter','StoryTitle','StoryData','AUTHOR_TEMPLATE','AUTHOR_GUIDE','StoryScript','StoryStylesheet','OffScriptSystem']}
 # Only story passages reachable through explicit links, plus retained authored start sections.
 manifest={}; original_positions={}; overrides={}
 for n,body in rows.items():
  sec=sections(body);conversation=sec.get('CONVERSATION','');interactive=bool(conversation)
  scene_body=body
  if body.lstrip().startswith('AUTHOR NOTE:'):
   first=re.search(r'^(?:NARRATOR|STAGE MANAGER|ACTOR \d+|MC|STAGE|SOUND|CUE / PHONE):',body,re.M)
   if first:scene_body=body[first.start():]
  semantic=parse_script(scene_body)
  cue=next((e['text'] for e in reversed(semantic['events']) if e['kind']=='phone'),'')
  group='Act 0 · Pre-show' if n=='Start' or n.startswith('A1_0_') or n.startswith('A1_1_0 ') else ('Act 2' if n.startswith('A2_') or n in ['Music_NotYet','Hall_AfterForced'] else ('Act 3' if n.startswith('A3_') else ('Endgame' if n=='A0_Endgame' else 'Act 1')))
  dests=[];kinds=[];effects=[];allowed={};bounds={}
  if interactive:
   for field,meaning in sec.items():
    if not re.fullmatch(r'ANSWER \d+',field):continue
    targets=links(sec.get(field+' NEXT',''));assert len(targets)==1,(n,field,targets)
    low=meaning.lower()
    if low in ['yes','ready / yes','agree / let music begin']:kind='yes'
    elif low in ['no','not ready / no','no / not yet']:kind='no'
    elif low.startswith('read '):kind='cue'
    elif 'ambition' in low or 'relevant second attempt' in low:kind='ambition'
    else:kind='choice_'+str(len(kinds))
    assert kind not in kinds,(n,kind)
    dest=targets[0][1];dests.append([meaning,dest]);kinds.append(kind);effects.append({'set':state(sec.get(field+' STATE',''))})
    allowed[kind]={'meaning':meaning,'destination':dest}
    if low.startswith('left /'):bounds[kind]=['left','west','western']
    elif low.startswith('right /'):bounds[kind]=['right','east','eastern']
  else:
   dests=links(body);kinds=['next']*len(dests);effects=[{'set':{}} for _ in dests]
  frame={'id':n,'group':group,'cue':cue,'routes':kinds,'effects':effects,'endgame':'A0_Endgame','reset':n=='Start','coverage':.8,'yes':['yes','yeah','sure','okay','ok','ready','lets begin'],'no':['no','not yet','not ready','wait'],'ambition':['writer','write','become','want','dream','aspire','career','astronaut','doctor','artist'],**semantic,'allowed_authored_intents':allowed,'bounded_evidence':bounds,'input_mode':'speech' if interactive else 'continue','response_overrides':{},'template_version':2}
  if interactive:
   resolved={key:(shared.get(key,'') if sec.get(key,'')=='USE UNIVERSAL' else sec.get(key,'')) for key in ['SILENCE','OFFSCRIPT','TECHNICAL RETRY','MIC CHECK','TAKEOVER']}
   frame.update({'conversation':conversation,'intro_exempt':'intro-exempt' in data.attrs[n].get('tags','').split(),'takeover_start':'TAKEOVER::'+n,'mic_check_reply':resolved['MIC CHECK']})
   for category,field in [('SILENCE','SILENCE'),('OFFSCRIPT','OFFSCRIPT'),('UNCLEAR','TECHNICAL RETRY'),('TECHNICAL_FAILURE','TECHNICAL RETRY')]:frame['response_overrides'][category]={'action':'stay','reply':resolved[field]}
   if not frame['player_task']:frame['player_task']='Respond in context: '+ '; '.join(x[0] for x in dests)
   targets=links(sec.get('TAKEOVER NEXT',''));assert len(targets)==1,(n,'takeover')
   takeover_body=re.sub(r'\[\[.*?\]\]','',resolved['TAKEOVER'],flags=re.S)
   # Response template permits inline Speaker: words without quotation marks.
   takeover_events=[]
   for block in re.split(r'\n\s*\n',takeover_body.strip()):
    match=re.match(r'(Stage Manager|Actor \d+|MC):\s*(.*)',block,re.I|re.S)
    if match:
     who=match[1];who='MC' if who.lower()=='mc' else ('Stage Manager' if who.lower()=='stage manager' else who.title())
     takeover_events.append({'kind':'dialogue','speaker':who,'text':match[2].strip().strip('"')})
    elif block.strip():takeover_events.append({'kind':'narration','speaker':'','text':block.strip()})
   tid=frame['takeover_start'];tf={**frame,'id':tid,'reset':False,'routes':['next'],'effects':[{'set':state(sec.get('TAKEOVER STATE',''))}],'events':takeover_events,'allowed_authored_intents':{},'input_mode':'continue','response_overrides':{},'cue':'','conversation':'','is_takeover':True}
   overrides[tid]={'start_id':tid,'frame':tf,'links':[['Continue performance',targets[0][1]]],'source_passage':n}
   dests.append(['Takeover after retries',tid]);kinds.append('takeover');effects.append({'set':{}})
  manifest[n]={'start_id':n,'frame':frame,'links':dests,'source_passage':n}
  pos=data.attrs[n].get('position','0,0').split(',');original_positions[n]=(float(pos[0])*4,float(pos[1])*5)
 # Place generated authored takeover nodes directly below their conversation, not at random.
 for n,d in overrides.items():
  manifest[n]=d;x,y=original_positions[d['source_passage']];original_positions[n]=(x,y+950)
 for n,d in manifest.items():
  for _,dest in d['links']:assert dest in manifest,(n,dest)
 nodes={};starts={};ids={n:i+1 for i,n in enumerate(manifest)}
 def value(a):
  if isinstance(a,tuple):return 'Vector2('+','.join(map(str,a))+')'
  if isinstance(a,str):return json.dumps(a,ensure_ascii=False)
  if isinstance(a,list):return 'Array[Dictionary]([])'
  if isinstance(a,dict):return '{'+',\n'.join((str(k) if isinstance(k,int) else json.dumps(k))+': '+value(v) for k,v in a.items())+'}'
  if isinstance(a,bool):return str(a).lower()
  return str(a)
 for n,d in manifest.items():
  i=ids[n];x,y=original_positions[n];start='0_'+str(i);signal='3_'+str(i);dialogue='1_'+str(i);starts[n]=start;d['node']=dialogue
  nodes[start]={'start_id':n,'link':signal,'offset':(x,y),'size':(190,100)}
  nodes[signal]={'signalValue':'frame:'+json.dumps(d['frame'],ensure_ascii=False),'link':dialogue,'offset':(x+210,y),'size':(230,150)}
  nodes[dialogue]={'speaker':'','dialogue':'\n\n'.join(e['text'] for e in d['frame']['events'] if e['kind'] in ['dialogue','narration']),'options':{j:{'text':label,'link':'3_'+str(ids[dest]),'condition':[]} for j,(label,dest) in enumerate(d['links'])},'offset':(x+470,y),'size':(310,420)}
 root=project/'Story/StageActs/Graph';backup=project.parent/'Week 11/trial_recovery/story-imports'/datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f');backup.mkdir(parents=True)
 for name in ['acts_0_3_cleaned.tres','acts_0_3_manifest.json','source_sync.json']:
  if (root/name).exists():shutil.copy2(root/name,backup/name)
 (root/'acts_0_3_cleaned.tres').write_text('[gd_resource type="Resource" script_class="DialogueData" load_steps=2 format=3]\n[ext_resource type="Script" path="res://addons/dialogue_nodes/objects/DialogueData.gd" id="1"]\n[resource]\nscript=ExtResource("1")\nstarts='+value(starts)+'\nnodes='+value(nodes)+'\n',encoding='utf-8')
 (root/'acts_0_3_manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf-8')
 (root/'source_sync.json').write_text(json.dumps({'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'passages':len(rows),'takeovers':len(overrides),'template_version':2,'note':'Imported full Twine HTML directly; response sections and Twine map positions retained. Generated takeover starts contain authored words, not AI-written dialogue.'},indent=2),encoding='utf-8')
 print('Imported',len(rows),'story passages,',len(overrides),'authored takeovers,',sum(len(d['links']) for d in manifest.values()),'links')
