"""Export successful input routes for real-time native replay; never changes levels."""
import json
from pathlib import Path
root=Path('validation/increment03/routes')
def lit(x):
    if isinstance(x,bool):return 'true' if x else 'false'
    if isinstance(x,str):return json.dumps(x,ensure_ascii=False)
    if isinstance(x,dict):return '{'+','.join('['+lit(k)+']='+lit(v) for k,v in x.items())+'}'
    if isinstance(x,list):return '{'+','.join(lit(v) for v in x)+'}'
    return repr(x)
for theme in ['store','meeting','office','dorm']:
    inputs=json.loads((root/f'{theme}-inputs.json').read_text())
    states=json.loads((root/f'{theme}-states.json').read_text())
    assert len(inputs)==len(states) and states[-1]['phase']=='done'
    runs=[]
    for c in inputs:
        if runs and runs[-1][1]==c:runs[-1][0]+=1
        else:runs.append([1,c])
    code='-- Frozen increment03; controls only, checked every simulation frame.\nlocal inputs={}\n'
    code+='local runs='+lit(runs)+'\nfor _,r in ipairs(runs)do for _=1,r[1]do inputs[#inputs+1]=r[2]end end\n'
    code+='local raw={\n'+',\n'.join(lit([s[k] for k in ['level','phase','x','z','door','timeline']]) for s in states)+'\n}\n'
    code+='local states={}\nfor i,s in ipairs(raw)do states[i]={level=s[1],phase=s[2],x=s[3],z=s[4],door=s[5],timeline=s[6]}end\nreturn {inputs=inputs,states=states}\n'
    target=Path('scripts/preview')/f'Increment03{theme}Route.lua';target.write_text(code)
    print(theme,len(inputs),'frames',len(runs),'control segments')
