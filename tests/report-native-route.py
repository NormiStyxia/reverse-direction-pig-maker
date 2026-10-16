"""Check observed full native route logs and preserve compact acceptance evidence."""
import json,re,shutil,subprocess
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'validation/full-route'
observed=json.loads((out/'observed-route.json').read_text())
log=Path(observed['log']);rows=[json.loads(line) for line in log.read_text().splitlines()]
rows=rows[next(i for i,row in enumerate(rows) if 'FULL_ROUTE: begin;' in row.get('m','')):]
messages=[row.get('m','') for row in rows]
stages=[m.split('FULL_ROUTE_STAGE: ')[1].strip() for m in messages if 'FULL_ROUTE_STAGE:' in m]
assert stages==['store','echo-store','meeting','echo-meeting','morning'],stages
exits=[int(re.search(r'level=(\d+)',m)[1]) for m in messages if 'ECHO_FLOW: exitReached' in m]
assert exits==[1,2,3,4,5,6,1,2,3,4,5],exits
assert any('FULL_ROUTE: PASS;' in m and 'answer=done' in m for m in messages)
assert any('ECHO_NATIVE_ROUTE: PASS; theme=store; 6452 frames' in m for m in messages)
assert any('ECHO_NATIVE_ROUTE: PASS; theme=meeting; 5692 frames' in m for m in messages)
assert any('CHAPTER1_NATIVE_FINISH: meeting answer=done' in m for m in messages)
assert any('CHAPTER1_NATIVE_FINISH: morning answer=done' in m for m in messages)
assert not any('stack traceback' in m for m in messages)
shutil.copyfile(log,out/'runtime-lua-31.log')
game=max((log.parent.parent/'game').glob('*'),key=lambda p:p.stat().st_mtime)
shutil.copyfile(game,out/'runtime-game-31.log')
errors=[line.strip() for line in game.read_text().splitlines() if 'ERROR:' in line]
official=json.loads((out/'check-after-route-31.json').read_text())
errors=list(dict.fromkeys(errors+official.get('errors',[])))
report={'date':'2026-10-16','sessionId':observed['sessionId'],'reloadId':observed['reloadId'],'runtimePid':observed['runtimePid'],
'principalInputRoute':'PASS','answer':'done','stageOrder':stages,'exitLevels':exits,'echoInputFrames':[6452,5692],
'start':'title UI new game','end':'09:58 then NVG end card','storyInput':'normal movement/interaction/panel APIs at real time; no story phase/time/position edits',
'echoInput':'source-verified fixed-step controls, natural chapter entry, no run reset between story and echo',
'save':'isolated test file reread at end: reached=6,done=true,answer=done; player save untouched',
'storySourceChecks':json.loads((ROOT/'docs/migration/story-input-route-report.json').read_text()),
'completeGameAcceptance':False,'nativeOtherAnswers':'not yet full native routes','mouseTouchAndResolutionAcceptance':False,
'nativeCrossRefreshSave':'FAIL: local preview cache cleanup','runtimeErrors':errors,'officialCheck':'FAIL','visualAcceptance':False,'similarityPercentage':None}
(ROOT/'docs/migration/local-full-route-runtime-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
shots=sorted(p for p in out.glob('*.png') if '-window' not in p.name and p.name!='route-contact-sheet.png')
cols=3;w,h=480,300;sheet=Image.new('RGB',(cols*w,((len(shots)+cols-1)//cols)*h),(20,20,20));draw=ImageDraw.Draw(sheet)
for i,p in enumerate(shots):
 im=Image.open(p).convert('RGB');assert im.size==(1920,1080);im.thumbnail((w,270))
 x=(i%cols)*w;y=(i//cols)*h;sheet.paste(im,(x,y+22));draw.text((x+6,y+5),p.stem,fill=(240,240,240))
sheet.save(out/'route-contact-sheet.png')
print(json.dumps({'principalInputRoute':'PASS','answer':'done','exits':len(exits),'echoInputFrames':[6452,5692],'screenshots':len(shots),'runtimeErrors':errors,'visualAcceptance':False},ensure_ascii=False,indent=2))
