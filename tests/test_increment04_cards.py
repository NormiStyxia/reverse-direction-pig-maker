"""All mechanism cards keep their prose above the close action on short screens."""
from lupa.lua54 import LuaRuntime
from fontTools.ttLib import TTFont
l=LuaRuntime(unpack_returned_tuples=True)
l.execute("package.path='scripts/?.lua;'..package.path")
f=TTFont('assets/fonts/LXGWWenKai-subset.ttf'); cm=f.getBestCmap()
def measure(_,text,size):
 return sum(f['hmtx'].metrics[cm.get(ord(c),'.notdef')][0] for c in text)*size/f['head'].unitsPerEm
l.execute("""
scaled=false;local stack={}
setmetatable(_G,{__index=function(_,k)if k:match('^nvg')then return function()end end end})
function nvgSave()stack[#stack+1]=scaled end
function nvgRestore()scaled=table.remove(stack)end
function nvgScale()scaled=true end
""")
Card=l.eval("require('render.MechanismCard')")[0]
Cards=l.eval("require('game.data.MechanismCards')")
if isinstance(Cards,tuple):Cards=Cards[0]
checks=0
for w,h in [(800,360),(780,360),(844,390),(915,412),(667,375),(640,360),(1280,720),(1920,1080)]:
 for key,data in Cards.items():
  texts=[]
  def text(_,s,x,y,size,col):
   if not l.globals().scaled:texts.append((s,x,y,size))
  c=l.table_from(dict(w=w,h=h,measure=measure,text=text))
  card=Card.new();card.open=True;card.key=key;card.card=data;card.render(card,c)
  close=texts[-1];assert close[0].startswith('知道了')
  for s,x,y,size in texts[:-1]:
   assert y+size<=close[2]-4,(w,h,key,s,y,size,close)
   assert x>=0 and x+measure(None,s,size)<=w,(w,h,key,s)
  checks+=1
print('PASS:',checks,'card layouts; readable prose, reserved close action; real font metrics (not native GPU evidence)')
