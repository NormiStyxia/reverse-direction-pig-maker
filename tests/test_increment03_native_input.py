"""Targeted macOS input test; requires an already-running dedicated maker_validate window."""
import subprocess,time,json,sys
from pathlib import Path
FRAMES=10006
key='afa0dcff485e9b3b31d610f753bbb7791551aab4723b4b2494f88cc3d9dceabb'
exe='/tmp/reverse-pig-native-input03';out=Path('validation/increment03/native/physical-input');out.mkdir(exist_ok=True)
resume='--resume-home' in sys.argv
receipt=json.loads((out/'report.json').read_text()).get('checks',[]) if resume else [];held=set();pid=None;log=None
start=time.monotonic()
while time.monotonic()-start<90:
 rows=subprocess.check_output(['ps','-axo','pid=,command='],text=True).splitlines()
 found=[r for r in rows if '/UrhoXRuntime -game_url=' in r and key in r and f'-validate-frames={FRAMES} ' in r]
 if len(found)==1:
  pid=int(found[0].strip().split()[0]);break
 time.sleep(.25)
assert pid,'Dedicated input validation process not found'
logs=Path('/Users/xd/.taptap-maker/runtime/runtime-0562af91-3ee7-439a-acf7-87c701ae890e/logs/lua')
def state():
 global log
 log=max(logs.glob('*.log'),key=lambda p:p.stat().st_mtime)
 for line in reversed(log.read_text().splitlines()):
  d=json.loads(line);m=d.get('m','')
  if 'OS_INPUT_STATE: ' in m:return json.loads(m.split('OS_INPUT_STATE: ',1)[1])
 return {}
def wait(label,fn,timeout=30):
 until=time.monotonic()+timeout
 while time.monotonic()<until:
  s=state()
  if fn(s):receipt.append({'check':label,'state':s});print(label,s,flush=True);return s
  time.sleep(.15)
 raise AssertionError((label,'timeout',state()))
def command(*args):
 r=subprocess.run([exe,str(pid),*map(str,args)],capture_output=True,text=True,check=True)
 receipt.append({'event':r.stdout.strip()})
def down(k):command('key',k,'down');held.add(k)
def up(k):command('key',k,'up');held.discard(k)
def tap(k):down(k);time.sleep(.08);up(k);time.sleep(.15)
def capture(label):
 w=json.loads(subprocess.check_output(['/tmp/reverse-pig-native-window03',str(pid)],text=True).splitlines()[0]);subprocess.run(['screencapture','-x','-o','-l',str(w['window']),str(out/(label+'.png'))],check=True);return w
try:
 deadline=time.monotonic()+20
 while time.monotonic()<deadline:
  ready=subprocess.run(['/tmp/reverse-pig-native-window03',str(pid)],capture_output=True,text=True)
  if ready.returncode==0 and ready.stdout.strip():break
  time.sleep(.2)
 command('focus','now')
 if not resume:
  wait('title silent',lambda s:s.get('scene')=='title' and s.get('phase')=='idle' and s.get('sounds')==0 and s.get('loops')==0)
  tap(1);wait('keyboard selects level mode',lambda s:s.get('sel')==2)
  tap(36);wait('level mode list',lambda s:s.get('panel')=='levelmode')
  tap(36);s=wait('native level ready',lambda s:s.get('scene')=='echo' and s.get('phase')=='play' and s.get('t',0)>6,45)
  before=(s['x'],s['z']);down(2);time.sleep(.7);up(2)
  wait('D moves player',lambda s:s.get('scene')=='echo' and abs(s['x']-before[0])+abs(s['z']-before[1])>.3)
  down(40);wait('K starts rewind',lambda s:s.get('rewind')is True,5);capture('held-rewind')
  up(40);wait('K release ends rewind',lambda s:s.get('rewind')is False,5)
  down(38);wait('J charge',lambda s:s.get('charge',0)>0,3);up(38)
  tap(15);wait('R restarts level',lambda s:s.get('load')==2,5)
  wait('restarted level playable',lambda s:s.get('phase')=='play',8)
  tap(53);s=wait('Esc pauses',lambda s:s.get('paused')is True);t=s['t'];time.sleep(.7);assert state()['t']==t;capture('paused')
  tap(53);wait('Esc resumes',lambda s:s.get('paused')is False and s.get('t',0)>t)
  down(40);wait('held before focus loss',lambda s:s.get('rewind')is True,5)
  command('hide','now');wait('focus loss observed',lambda s:s.get('focused')is False,5);up(40)
  command('focus','now');wait('focus restored without stuck rewind',lambda s:s.get('focused')is True and s.get('rewind')is False,5)
 w=capture('before-home');b=w['bounds'];command('click',b['X']+38,b['Y']+32+38)
 wait('mouse home',lambda s:s.get('scene')=='title' and s.get('phase')=='idle',12)
 tap(36);wait('keyboard starts dream',lambda s:s.get('scene')=='dream',10)
 wait('dream phone appears',lambda s:s.get('phone')is True,24)
 time.sleep(.8);capture('dream-phone')
 tap(38);wait('J closes dream phone',lambda s:s.get('scene')=='dream' and s.get('phone')is False,4)
 wait('dream walking available',lambda s:s.get('phase')=='walk',8)
 down(2);wait('dream switches to pig',lambda s:s.get('phase')=='pigwalk',16);capture('dream-pig')
 wait('dream switches back',lambda s:s.get('phase')=='unswap',12);up(2)
 tap(46);wait('M mutes in play',lambda s:s.get('muted')is True)
 w=capture('dream-return');b=w['bounds'];command('click',b['X']+38,b['Y']+32+38)
 wait('home preserves mute and stops audio',lambda s:s.get('scene')=='title' and s.get('phase')=='idle' and s.get('muted')is True and s.get('loops')==0 and s.get('sounds')==0,12)
 report={'result':'PASS','pid':pid,'scope':'macOS CGEvent delivered to actual isolated Runtime: keyboard, mouse, focus. No hardware touchscreen proof.','checks':receipt}
except Exception as e:
 report={'result':'FAIL','pid':pid,'error':str(e),'checks':receipt};raise
finally:
 for k in list(held):
  try:up(k)
  except Exception:pass
 if 'report'in globals():(out/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
