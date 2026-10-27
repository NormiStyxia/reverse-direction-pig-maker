"""Source chapter merges, menu resume boundary, and storage fault checks."""
import json
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1];lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
Save=lua.eval("require('game.SaveState')")[0];Title=lua.eval("require('game.TitleState')")[0]
def py(t):
    if not hasattr(t,'items'):return t
    keys=list(t.keys())
    if keys and all(isinstance(k,int) for k in keys):return [py(t[i]) for i in range(1,len(t)+1)]
    return {k:py(v) for k,v in t.items()}
codec=lua.table_from({'encode':lambda x:json.dumps(py(x),ensure_ascii=False),'decode':lambda x:lua.table_from(json.loads(x),recursive=True)})
checks=0
for fixture in json.loads((ROOT/'validation/save/source.json').read_text()):
    disk={}
    def read():
        if fixture['unavailable']:raise RuntimeError('unavailable')
        return disk.get('data')
    def write(data):
        if fixture['unavailable']:raise RuntimeError('unavailable')
        disk['data']=data;return True
    state=Save.new(lua.table_from({'read':read,'write':write}),codec)
    for op in fixture['steps']:
        state.saveChapter(state,op['id'],lua.table_from(op['fields'],recursive=True));assert py(state.data)==op['expected'];checks+=1
    assert state.persisted== (not fixture['unavailable'])
    if not fixture['unavailable']:
        fresh=Save.new(lua.table_from({'read':read,'write':write}),codec);assert py(fresh.data)==py(state.data)
# Progress is monotonic. Increment03 Continue/Chapters opens the 3D timeline.
disk={};storage=lua.table_from({'read':lambda:disk.get('data'),'write':lambda s:disk.update(data=s) or True})
s=Save.new(storage,codec)
for n in [1,3,2,6,1]:s.echoLoaded(s,n)
assert s.reached(s)==6;s.echoFinished(s);s.meetingFinished(s,'done')
for reached in range(7):
    title=Title.new(reached);title.st.phase='idle'
    title.latest='echo1' if reached else False
    assert title.disabled(title,1)==(reached==0)
    if reached:
        title.activate(title,1);assert title.st.choice.kind=='timeline'
    title.st.phase='idle';title.activate(title,3)
    assert title.st.choice.kind==('timeline' if reached else 'new')
    # Legacy direct panel is retained internally, not the increment03 menu target.
    title.st.phase='idle';title.openPanel(title,'chapters')
    for level in range(7):assert title.disabled(title,level)==(level>reached)
    title.activate(title,reached);assert title.st.choice.kind==('new' if reached==0 else 'echo')
# Corrupt/malformed input recovers without a startup write; write failure keeps session progress.
faults=0
for raw in ['{bad','null','[]','{"chapters":null}','{"chapters":{"echo":{"reached":"bad"},"ch1":{"answer":"old"}}}']:
    wrote=[];s=Save.new(lua.table_from({'read':lambda:raw,'write':lambda v:wrote.append(v) or False}),codec)
    assert s.reached(s)==0 and s.answer(s)=='same' and not wrote
    s.echoLoaded(s,3);s.meetingFinished(s,'late');assert s.reached(s)==3 and s.answer(s)=='late' and not s.persisted;faults+=1
result={'result':'PASS','sourceMergeComparisons':checks,'resumeProgressCases':7,'lockedLevelComparisons':49,'faultCases':faults,'diskReload':'PASS','notCovered':['native file API','Web persistence','visual parity']}
(ROOT/'docs/migration/save-test-report.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
