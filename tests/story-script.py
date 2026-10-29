from pathlib import Path
import sys,re,json
p=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(p/'tools'))
from story_script import parse_script,clean_working_copy
fixture='''CONTEXT:
Hidden context.
NARRATOR:
Before speech.
ACTOR 1:
"Hello."
STAGE:
Lights fade.

Curtain closes.
SOUND:
Audience murmurs.
CUE / PHONE:
LEFT / RIGHT
NARRATOR:
After speech.
PLAYER TASK:
Choose an entrance.
PLAYER RESPONSE:
[[Left->Next]]
AUTHOR NOTE:
Hidden note.
'''
r=parse_script(fixture)
assert [e['kind'] for e in r['events']]==['narration','dialogue','stage','stage','sound','phone','narration']
assert r['events'][1]['speaker']=='Actor 1'
assert r['events'][-1]['speaker']==''
assert 'Curtain closes' in r['events'][3]['text']
assert r['context']=='Hidden context.' and r['player_task']=='Choose an entrance.'
assert r['author_notes']==['Hidden note.']
assert parse_script('ACTOR 3:\n"Hello."')['events'][0]['speaker']=='Actor 3'
assert parse_script('AUTHOR NOTE:\nCONTEXT: Secret meaning.')['context']=='Secret meaning.'
source=p.parent/'Week 11/2.4 StoryLine_Preproduct_W12.twee'
original=source.read_text(encoding='utf-8-sig');clean=clean_working_copy(original)
links=lambda s:re.findall(r'\[\[[^\n]+',s)
assert links(original)==links(clean),'Story links changed during cleanup'
m=json.loads((p/'Story/StageActs/Graph/acts_0_3_manifest.json').read_text(encoding='utf-8'))
sync=json.loads((p/'Story/StageActs/Graph/source_sync.json').read_text(encoding='utf-8'))
assert len(m)==sync['passages']+sync['takeovers']
assert m['Music_NotYet']['links']==[['Continue','A2_4_CallSomeone']]
for n,row in m.items():
 for _,dest in row['links']:assert dest in m,(n,dest)
 if row['frame'].get('conversation'):
  assert all(k in row['frame']['response_overrides'] for k in ['SILENCE','OFFSCRIPT','UNCLEAR','TECHNICAL_FAILURE'])
  assert row['frame']['takeover_start'] in m
for name,row in m.items():
 for e in row['frame']['events']:
  assert e['kind']!='dialogue' or e['speaker'],name
print('PASS semantic grammar, multiline production fields, metadata, actor labels and unchanged source links')
