"""Convert the eight authored SVG diagrams to native NVG primitives, not screenshots."""
import xml.etree.ElementTree as ET,json
from pathlib import Path
from lupa.lua54 import LuaRuntime
l=LuaRuntime(unpack_returned_tuples=True);l.execute("package.path='scripts/?.lua;'..package.path")
cards=l.eval("require('game.data.MechanismCards')")[0]
def convert(e):
 tag=e.tag.split('}')[-1]
 if tag=='defs':return None
 return dict(tag=tag,attrs=dict(e.attrib),text=e.text or '',children=[v for c in e if (v:=convert(c))])
def lua(v):
 if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
 if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
 if isinstance(v,dict):return '{'+','.join('['+lua(k)+']='+lua(x)for k,x in v.items())+'}'
 return str(v).lower()
data={k:convert(ET.fromstring(v['svg']))for k,v in cards.items()}
Path('scripts/game/data/MechanismDiagrams.lua').write_text('-- Authored frozen SVG geometry, converted to NVG commands at build time.\nreturn '+lua(data)+'\n')
print('Imported',len(data),'native vector diagrams')
