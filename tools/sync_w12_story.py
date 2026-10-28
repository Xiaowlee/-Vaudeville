from pathlib import Path
import re,json,shutil,datetime
from story_script import parse_script, clean_working_copy, route_metadata
p=Path(__file__).resolve().parents[1]
import sys
if '--overwrite' not in sys.argv: raise SystemExit('Reimport replaces graph edits. Supply --overwrite deliberately. Run tests/story-script.py first.')
source=p.parent/'Week 11/2.4 StoryLine_Preproduct_W12_working.twee'
original=p.parent/'Week 11/2.4 StoryLine_Preproduct_W12.twee'
if '--clean-source' in sys.argv:
 source.write_text(clean_working_copy(original.read_text(encoding='utf-8-sig')),encoding='utf-8')
s=source.read_text(encoding='utf-8-sig')
allrows={}
for m in re.finditer(r'^:: (.+?)\r?\n(.*?)(?=^:: |\Z)',s,re.M|re.S):
 name=re.split(r' \[| \{',m[1])[0].strip();allrows[name]=m[2]
rows={n:b for n,b in allrows.items() if n=='Start' or n.startswith(('A1_','A2_','A3_')) or n=='A0_Endgame' or n.startswith('\\ A1_')}
ids={n:i+1 for i,n in enumerate(rows)}
thresholds={k:int(re.search(r'setup.offScript'+k+r'At = (\d+)',s)[1]) for k in ['Correction','Disruption','KickOut']}
widget=allrows['OffScriptSystem']
notices={}
for k in ['correction','disruption']:
 text=re.search(r'<div class="system-response '+k+r'">(.*?)</div>',widget,re.S)[1]
 notices[k]=re.sub(r'\s+',' ',re.sub('<[^>]+>',' ',text)).strip()
previous_manifest_path=p/'Story/StageActs/Graph/acts_0_3_manifest.json'
previous_graph_path=p/'Story/StageActs/Graph/acts_0_3_cleaned.tres'
previous_manifest=json.loads(previous_manifest_path.read_text(encoding='utf-8-sig')) if previous_manifest_path.exists() else {}
previous_text=previous_graph_path.read_text(encoding='utf-8-sig') if previous_graph_path.exists() else ''
nodes={};starts={};manifest={}
for n,body in rows.items():
 i=ids[n];x=(i-1)*950;y=0
 boundary=False
 links=[];effects=[];types=[]
 for m in re.finditer(r'\[\[([^\]\n]+)\](?:\[([^\]]*)\])?\]',body):
  if boundary:break
  label,target=m[1].split('->',1);label=label.strip();target=target.strip();assert target in rows,(n,target)
  setter=m[2] or '';reason=re.search(r'\$offScriptLastReason\s*=\s*"([^"]*)"',setter)
  effects.append({'increment':1 if '$offScriptCount += 1' in setter else 0,'reason':reason[1] if reason else '', 'set':dict(re.findall(r'\$(\w+)\s*=\s*"([^"]*)"',setter))})
  links.append([label,target]);low=label.lower()
  if low.rstrip('.')=='yes':kind='yes'
  elif low.rstrip('.') in ['no','not yet']:kind='no'
  elif 'nothing' in low or 'silent' in low:kind='silence'
  elif 'read ' in low:kind='cue'
  elif 'dream' in low:kind='ambition'
  elif 'watch' in low:kind='watch'
  elif 'something' in low or 'response' in low:kind='other'
  else:kind='next'
  if n.startswith(('A2_','A3_')):
   navigation=low.startswith(('continue','enter the ceremony','listen.','restart'))
   kind='next' if navigation else 'choice_'+str(len(types))
  types.append(kind)
 semantic=parse_script(body)
 text="\n\n".join(e['text'] for e in semantic['events'] if e['kind'] in ['dialogue','narration'])
 cue=next((e['text'] for e in reversed(semantic['events']) if e['kind']=='phone'),'')
 frame={'id':n,'cue':cue, 'routes':types,'effects':effects,'thresholds':thresholds,'notices':notices,'endgame':'A0_Endgame','reset':n=='Start','boundary':boundary,'yes':['yes','yeah','sure','okay','ok','ready','lets begin'],'no':['no','not yet','not ready','wait'],'ambition':['writer','write','become','want','dream','aspire','career','astronaut','doctor','artist'],'coverage':0.8}
 group='Act 0 · Pre-show' if n=='Start' or n.startswith('A1_0_') or n.startswith('A1_1_0 ') else ('Act 2' if n.startswith('A2_') else ('Act 3' if n.startswith('A3_') else ('Endgame' if n=='A0_Endgame' else 'Act 1')))
 frame['group']=group
 frame.update(semantic)
 frame.update(route_metadata(links,types,cue))
 if semantic['player_task']:frame['player_task']=semantic['player_task']
 starts[n]='0_'+str(i)
 nodes['0_'+str(i)]={'start_id':n,'link':'3_'+str(i),'offset':(x,y),'size':(190,100)}
 nodes['3_'+str(i)]={'signalValue':'frame:'+json.dumps(frame,ensure_ascii=False),'link':'1_'+str(i),'offset':(x+210,y),'size':(230,150)}
 nodes['1_'+str(i)]={'speaker':'','dialogue':text,'options':{j:{'text':label,'link':'3_'+str(ids[dest]),'condition':[]} for j,(label,dest) in enumerate(links)},'offset':(x+470,y),'size':(310,420)}
 manifest[n]={'start_id':n,'node':'1_'+str(i),'frame':frame,'links':links}
# Discover saved IDs from the graph itself: the editor may renumber nodes.
blocks=list(re.finditer(r'(?:&?)"([013]_[^"\n]+)":\s*\{',previous_text))
layout={}
for j,block in enumerate(blocks):
 chunk=previous_text[block.end():blocks[j+1].start() if j+1<len(blocks) else len(previous_text)]
 if not block[1].startswith('0_'):continue
 name_match=re.search(r'"start_id":\s*("(?:\\.|[^"\\])*")',chunk)
 if not name_match:continue
 name=json.loads(name_match[1]);layout[name]=block[1].split('_',1)[1]
aliases={"A1_1_ACTOR 1'sQuestion":"A1_1_Mother'sQuestion","A3_3_ACTOR 1Interrupts":"A3_3_MotherInterrupts"}
for name,data in manifest.items():
 previous_id=layout.get(name,layout.get(aliases.get(name,'')))
 if previous_id is None:continue
 for typ in ['0','1','3']:
  oid=typ+'_'+previous_id;nid=typ+'_'+data['node'].split('_')[1]
  at=previous_text.find('"'+oid+'":')
  coords=re.search(r'"offset":\s*Vector2\(([^)]*)\)',previous_text[at:]) if at>=0 else None
  if coords:nodes[nid]['offset']=tuple(float(x.strip()) for x in coords[1].split(','))

def v(a):
 if isinstance(a,tuple):return 'Vector2('+','.join(map(str,a))+')'
 if isinstance(a,str):return json.dumps(a,ensure_ascii=False)
 if isinstance(a,list):return 'Array[Dictionary]([])'
 if isinstance(a,dict):return '{'+',\n'.join((str(k) if isinstance(k,int) else json.dumps(k))+': '+v(w) for k,w in a.items())+'}'
 return str(a)
backup=p.parent/'Week 11/trial_recovery/story-imports'/datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
backup.mkdir(parents=True,exist_ok=True)
for old in [previous_graph_path,previous_manifest_path,p/'Story/StageActs/Graph/source_sync.json']:
 if old.exists():shutil.copy2(old,backup/old.name)
(p/'Story/StageActs/Graph/acts_0_3_cleaned.tres').write_text('[gd_resource type="Resource" script_class="DialogueData" load_steps=2 format=3]\n[ext_resource type="Script" path="res://addons/dialogue_nodes/objects/DialogueData.gd" id="1"]\n[resource]\nscript=ExtResource("1")\nstarts='+v(starts)+'\nnodes='+v(nodes)+'\n',encoding='utf-8')
(p/'Story/StageActs/Graph/acts_0_3_manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False),encoding='utf-8')
(p/'Story/StageActs/Graph/source_sync.json').write_text(json.dumps({'source':str(source),'sha256':__import__('hashlib').sha256(source.read_bytes()).hexdigest(),'passages':len(rows),'note':'Explicit import replaces dialogue/links; matching passage layout, production and policy remain separate.'},indent=2),encoding='utf-8')
print('Imported',len(rows),'semantic passages,',sum(len(x['links']) for x in manifest.values()),'routes.')
