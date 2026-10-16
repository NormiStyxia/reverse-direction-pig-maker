"""Observe an explicitly started native input route; never changes game state."""
import argparse,json,re,subprocess,time
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
CLI=Path.home()/'Library/Application Support/Cindy/owners/8666d40ddc404195528a/cindy-brain/taptap-maker/vendor/taptap-maker/dist/maker.js'
parser=argparse.ArgumentParser();parser.add_argument('--meta',default='validation/chapter1/native-full-route-start.json');parser.add_argument('--output',default='validation/full-route')
args=parser.parse_args()
meta=json.loads((ROOT/args.meta).read_text())
out=ROOT/args.output;out.mkdir(parents=True,exist_ok=True)
def status():return json.loads(subprocess.check_output(['node',str(CLI),'preview','status','--target-dir',str(ROOT),'--json'],text=True))
s=status();assert s['process_alive'] and s['runtime_pid']==meta['runtimePid'] and s['reload_id']==meta['reloadId']
log=max((Path(s['executable']).parent/'logs/lua').glob('*'),key=lambda p:p.stat().st_mtime)
events=[];cursor=0;stage='title';counter=0;deadline=time.monotonic()+700

def capture(label):
    global counter
    current=status();assert current['process_alive'] and current['runtime_pid']==meta['runtimePid']
    counter+=1;name=f'{counter:02}-{label}'
    raw=out/(name+'-window.png');subprocess.run(['screencapture','-x','-o','-a','-l',str(meta['window']),str(raw)],check=True)
    im=Image.open(raw);w,h=meta['contentSize'];assert im.width==w and im.height>=h
    im.crop((0,im.height-h,w,im.height)).save(out/(name+'.png'))
    print('captured',name,flush=True)
    return name+'.png'

# Start observing at the current moment; earlier log events stay in the report.
initial=log.read_text().splitlines()
for line in initial:
    row=json.loads(line);m=row.get('m','')
    if 'FULL_ROUTE_STAGE:' in m:stage=m.split('FULL_ROUTE_STAGE: ')[1].strip()
cursor=len(initial);capture(stage+'-observed')
while time.monotonic()<deadline:
    lines=log.read_text().splitlines();new=lines[cursor:];cursor=len(lines)
    for line in new:
        row=json.loads(line);m=row.get('m','')
        if any(k in m for k in ['FULL_ROUTE','ECHO_FLOW','ECHO_NATIVE_ROUTE','CHAPTER1_NATIVE_FINISH','STORE_PROBE_DONE']):
            events.append(row);print(m.strip(),flush=True)
        if 'FULL_ROUTE_STAGE:' in m:
            stage=m.split('FULL_ROUTE_STAGE: ')[1].strip();time.sleep(1);row['capture']=capture(stage)
        elif 'ECHO_FLOW: levelPlayable' in m:
            level=re.search(r'level=(\d+)',m)[1];row['capture']=capture(stage+'-'+level)
        elif 'FULL_ROUTE: PASS' in m:
            time.sleep(3);row['capture']=capture('end')
            (out/'observed-route.json').write_text(json.dumps({'sessionId':s['session_id'],'reloadId':s['reload_id'],'runtimePid':s['runtime_pid'],'result':'PASS','log':str(log),'events':events,'visualAcceptance':False},ensure_ascii=False,indent=2)+'\n')
            raise SystemExit(0)
        elif 'stack traceback' in m or row.get('l')=='ERROR':raise RuntimeError(m)
    time.sleep(1)
raise TimeoutError('Native route did not finish within 700 seconds')
