"""Raw NVG adapter tests: actual story fixtures, responsive input and resource lifetime."""
import json,math
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
lua.execute('''
graphics={GetWidth=function()return 1280 end,GetHeight=function()return 720 end,GetDPR=function()return 1 end}
NVG_ALIGN_LEFT=1;NVG_ALIGN_TOP=8;NVG_IMAGE_GENERATE_MIPMAPS=1;FILTER_TRILINEAR=2
cache={GetResourceAsync=function(self,kind,path,fn)fn({SetFilterMode=function()end})end}
draw={active=false,depth=0,size=16,images={},text={},created=0,deleted=0}
function nvgCreate()return {}end
function nvgDelete()draw.deleted=draw.deleted+1 end
function nvgCreateFont(vg,name,path)assert(path=='fonts/LXGWWenKai-subset.ttf');return 1 end
function nvgCreateImage(vg,path)draw.created=draw.created+1;draw.images[draw.created]=path;return draw.created end
function nvgDeleteImage(vg,id)assert(draw.images[id]);draw.images[id]=nil end
function nvgImageSize()return 256,256 end
function nvgRGBA(...)return {...}end
function nvgImagePattern(...)return {...}end
function nvgBeginFrame(vg,w,h,dpr)assert(not draw.active);draw.active=true;draw.text={};draw.w=w;draw.h=h;draw.dpr=dpr end
function nvgEndFrame()assert(draw.active and draw.depth==0);draw.active=false end
function nvgSave()assert(draw.active);draw.depth=draw.depth+1 end
function nvgRestore()draw.depth=draw.depth-1;assert(draw.depth>=0)end
function nvgFontSize(vg,size)draw.size=size end
function nvgTextBounds(vg,x,y,text)local w=0;for _,cp in utf8.codes(text)do w=w+draw.size*(cp<128 and .55 or 1) end;return w end
function nvgText(vg,x,y,text)assert(draw.active);draw.text[#draw.text+1]=text end
for _,name in ipairs({'nvgFontFace','nvgTextLetterSpacing','nvgTextAlign','nvgFillColor','nvgBeginPath','nvgRoundedRect','nvgFill',
 'nvgIntersectScissor','nvgFillPaint','nvgTranslate','nvgScale','nvgRotate','nvgGlobalAlpha'})do
 _G[name]=function(vg,...)if not name:match('^nvgFont') and not name:match('^nvgText') then assert(draw.active,name) end;for _,v in ipairs({...})do if type(v)=='number'then assert(v==v and math.abs(v)<math.huge,name)end end end
end
''')
def require(name):
    r=lua.eval('require')(name);return r[0] if isinstance(r,tuple) else r
Fixtures=require('preview.PanelFixtures');Canvas=require('render.StoryOverlay');Layout=require('game.StoryPanelLayout')
viewports=[(1280,720,1),(1920,1080,1),(2560,1440,2),(1170,2532,3),(800,600,1),(640,360,1),(3840,2160,2)]
renders=0;assets=set()
for fixture in range(1,7):
    p=Fixtures.make(fixture);c=Canvas.new(p)
    c.update(c,1)
    for w,h,dpr in viewports:
        c.resize(c,w,h,dpr);c.render(c);renders+=1
        assert math.isclose(c.w,w/dpr) and lua.globals().draw.dpr==dpr
        for hit in c.hits.values():
            assert hit.w>0 and hit.h>0 and hit.x>=0 and hit.x+hit.w<=c.w+.01,(fixture,w,h,dict(hit))
        if c.thread:assert c.thread.h>=0
        assets.update(lua.globals().draw.images.values())
    c.dispose(c);c.dispose(c)
    assert len(lua.globals().draw.images)==0
for path in assets:assert (ROOT/'assets'/path).exists(),path
def fresh():
    p=Fixtures.make(2);c=Canvas.new(p);c.update(c,1);c.render(c);return p,c
def hit(c,id):return next(h for h in c.hits.values() if h.id==id)
def point(c,h):return (h.x+h.w/2)*c.dpr,(h.y+h.h/2)*c.dpr
def click(c,id):
    h=hit(c,id);x,y=point(c,h);c.pointerDown(c,x,y,'mouse');c.pointerUp(c,x,y,'mouse')
# Real generated state has sent its first reply. Wait for the next leader request.
p,c=fresh()
for _ in range(1000):p.update(p,.05,lua.table());p.drainEvents(p)
c.update(c,0);c.render(c)
assert any(h.id=='pick:0' for h in c.hits.values())
click(c,'pick:0');c.render(c);assert p.draft and not c.ready
click(c,'send');assert p.draft # premature send ignored
for _ in range(60):p.update(p,.05,lua.table());c.update(c,.05)
c.render(c);assert c.ready and c.typed==p.phone.draft
count=len(p.msgs);click(c,'send');assert len(p.msgs)==count+1 and not p.draft
# Drag across buttons and mismatched touch releases cannot activate close.
c.render(c);h=hit(c,'close');x,y=point(c,h)
c.pointerDown(c,x,y,3);c.pointerUp(c,x,y,4);assert p.phone.open
c.pointerMove(c,x+20,y,3);c.pointerUp(c,x,y,3);assert p.phone.open
# Resize and focus cancellation remove captured touches.
c.pointerDown(c,x,y,3);c.resize(c,2560,1440,2);c.render(c);c.pointerUp(c,x*2,y*2,3);assert p.phone.open
# Thread wheel/drag remain clamped, with the physical->logical DPR conversion.
r=c.thread;tx=(r.x+8)*c.dpr;ty=(r.y+8)*c.dpr
c.wheel(c,100,tx,ty);assert c.scroll.phone==0
c.wheel(c,-100,tx,ty);assert c.scroll.phone==c.maxScroll
c.pointerDown(c,tx,ty,1);c.pointerMove(c,tx,ty+80,1);c.pointerUp(c,tx,ty+80,1)
assert 0<=c.scroll.phone<=c.maxScroll
click(c,'close');assert not p.phone.open
c.dispose(c)
# Browse cannot select a delayed choice until all entries and their hold times finish.
p=Fixtures.make(4);p.closeBrowse(p);p.startBrowse(p,'shelf');c=Canvas.new(p);c.update(c,0);c.render(c)
assert not any(h.id.startswith('choice:') for h in c.hits.values())
for _ in range(80):p.update(p,.05,lua.table());c.update(c,.05)
c.render(c);click(c,'choice:0')
for _ in range(80):p.update(p,.05,lua.table());c.update(c,.05)
c.render(c);assert any(h.text=='再看看别的' for h in c.hits.values())
click(c,'choice:0');assert p.browse.sub=='冷藏饭团'
c.dispose(c)
# Hysteresis and Unicode code-point typing (Chinese + supplementary plane).
place=lua.table();Layout.place(place,.2,.4);assert place.layoutSide=='right'
Layout.place(place,.5,.6);assert place.layoutSide=='right'
Layout.place(place,.6,.7);assert place.layoutSide=='left'
Layout.place(place,.4,.5);assert place.layoutSide=='left'
Layout.place(place,.2,.4);assert place.layoutSide=='right'
assert Layout.utf8Prefix('好😀的',2)=='好😀'
assert lua.globals().draw.deleted==8
# A cold DWP load must not create an NVG font or cache placeholder widths.
lua.execute('pendingLoads={};cache.GetResourceAsync=function(self,kind,path,fn)pendingLoads[#pendingLoads+1]={kind=kind,path=path,done=fn}end')
p=Fixtures.make(2);c=Canvas.new(p);c.update(c,1);c.render(c)
assert not c.fontReady and len(c.metrics)==0 and len(c.hits)==0
resource=lua.eval('{SetFilterMode=function()end}')
lua.globals().pendingLoads[1].done(resource);assert c.fontReady
c.render(c);assert len(c.hits)>0
# Dispose while images are loading: late callbacks may not recreate NVG resources.
created=lua.globals().draw.created;c.dispose(c)
for pending in list(lua.globals().pendingLoads.values())[1:]:pending.done(resource)
assert lua.globals().draw.created==created and len(lua.globals().draw.images)==0
lua.execute('pendingLoads={}')
p=Fixtures.make(2);c=Canvas.new(p);c.dispose(c);lua.globals().pendingLoads[1].done(resource)
assert not c.fontReady and lua.globals().draw.deleted==10
Motion=require('game.StoryPanelMotion')
for age,want in [(0,(0,42,.82)),(.325,(1,-3,1.025)),(.5,(1,0,1))]:
    m=Motion.send(age)
    for name,value in zip(['alpha','y','scale'],want):assert abs(m[name]-value)<1e-6
assert abs(Motion.arrive(.32).y)<1e-6
dom_path=ROOT/'validation/panels/h5-metrics.json'
dom_checks=0
if dom_path.exists():
    # Independent browser geometry oracle, with advances from the actual frozen font.
    # No screenshots or DOM enter the game; all hooks below exist only in this test.
    from fontTools.ttLib import TTFont
    font=TTFont(ROOT/'assets/fonts/LXGWWenKai-subset.ttf');cmap=font.getBestCmap()
    def text_bounds(vg,x,y,text):
        return sum(font['hmtx'].metrics[cmap[ord(ch)]][0] for ch in text)*lua.globals().draw.size/1000
    lua.globals().nvgTextBounds=text_bounds
    lua.execute('cache.GetResourceAsync=function(self,kind,path,fn)fn({SetFilterMode=function()end})end')
    lua.globals().TestCanvas=Canvas;lua.globals().TestLayout=Layout
    lua.execute('''
    originalMessage=TestCanvas.drawMessage;originalBrowse=TestCanvas.browseEntry
    function TestCanvas:drawMessage(m,x,y,width,p,...)
      local l=TestLayout.message(m,width,p,function(t,s)return self:measure(t,s)end)
      self.observed[#self.observed+1]={text=m.text,x=m.me and x+width-p.avatar-p.messageGap-l.w or x+p.avatar+p.messageGap,y=y+l.stampH+l.nameH,w=l.w,h=l.bubbleH}
      return originalMessage(self,m,x,y,width,p,...)
    end
    function TestCanvas:browseEntry(e,x,y,width,p,render)
      local h=originalBrowse(self,e,x,y,width,p,render)
      if render and e.kind=='card' then self.observedCards[#self.observedCards+1]={x=x,y=y,h=h}end
      return h
    end
    ''')
    for ref in json.loads(dom_path.read_text()):
        p=Fixtures.make(ref['fixture']);c=Canvas.new(p);c.resize(c,1920,1080,1)
        c.observed=lua.table();c.observedCards=lua.table();c.update(c,0);c.update(c,1);c.render(c)
        header=next(m['rect'] for m in ref['metrics'] if m['class']=='ph-header')
        for actual,expected in [(c.panel.x,header['x']),(c.panel.y,header['y']),(c.panel.w,header['width']),(c.panel.headerH,header['height'])]:
            assert abs(actual-expected)<.02,(ref['name'],'header',actual,expected);dom_checks+=1
        for actual in c.observed.values():
            want=next(m['rect'] for m in ref['metrics'] if m['class']=='ph-bubble' and m['text']==actual.text)
            for key,dim in [('x','x'),('y','y'),('w','width'),('h','height')]:
                assert abs(actual[key]-want[dim])<1,(ref['name'],actual.text,key,actual[key],want[dim]);dom_checks+=1
        cards=[m['rect'] for m in ref['metrics'] if m['class'].startswith('br-card')]
        for actual,want in zip(c.observedCards.values(),cards):
            for key,dim in [('x','x'),('y','y'),('h','height')]:
                assert abs(actual[key]-want[dim])<1,(ref['name'],'card',key,actual[key],want[dim]);dom_checks+=1
        for actual in c.hits.values():
            if actual.id.startswith('choice:') or actual.id=='chat':
                want=next(m['rect'] for m in ref['metrics'] if m['text']==actual.text and ('reply' in m['class'] or 'ph-open-chat' in m['class']))
                for key,dim in [('x','x'),('y','y'),('w','width'),('h','height')]:
                    assert abs(actual[key]-want[dim])<1,(ref['name'],'choice',key,actual[key],want[dim]);dom_checks+=1
        c.dispose(c)
    lua.execute('TestCanvas.drawMessage=originalMessage;TestCanvas.browseEntry=originalBrowse')
chapter_renders=0
for fixture in range(7,len(Fixtures.names)+1):
    adapter=Fixtures.make(fixture);c=Canvas.new(adapter);c.update(c,1)
    for w,h,dpr in viewports:
        c.resize(c,w,h,dpr);c.render(c);chapter_renders+=1
        assert c.channel=='browse' and adapter.story.phone.open,(fixture,adapter.story.phase)
        for item in c.hits.values():assert item.x>=0 and item.x+item.w<=c.w+.01,(fixture,w,item.text)
        assets.update(lua.globals().draw.images.values())
    c.dispose(c)
for path in assets:assert (ROOT/'assets'/path).exists(),path
# Click real required chapter choices through physical NVG hit regions.
adapter=Fixtures.make(8);c=Canvas.new(adapter);c.update(c,1);c.render(c)
click(c,'close');assert adapter.story.phone.open and adapter.story.phase=='ask'
click(c,'choice:2');assert adapter.story.answer=='done' and len(adapter.story.phone.queue)==5
assert not any(item.id.startswith('choice:') for item in c.hits.values()) or not adapter.story.phone.choices[1]
c.dispose(c)
# A scene action and a story panel share one pointer owner, including ID zero.
p,c=fresh();c.resize(c,1920,1080,1);c.render(c)
Actions=require('render.SceneActions')
lua.globals().sceneActionStory=p
c.sceneActions=Actions.new(c,lua.eval('function() return sceneActionStory end'),True)
p.phone.k=.3 # entrance is only visible before body.phone-open crosses its threshold
buttons,_=c.sceneActions.layout(c.sceneActions)
phone=next(b for b in buttons.values() if b.id=='phone')
px,py=phone.x+phone.w/2,phone.y+phone.h-1
assert c.pointerDown(c,px,py,0)
assert c.sceneActions.press.id==0
panel_hit=next(h for h in c.hits.values() if h.enabled)
hx,hy=point(c,panel_hit)
assert not c.pointerDown(c,hx,hy,2) and not c.pointerId
assert not c.pointerUp(c,hx,hy,2) and c.sceneActions.press.id==0
assert p.phone.open and c.pointerUp(c,px,py,0) and not p.phone.open
c.dispose(c)
report={'result':'PASS','fixtureRenders':renders,'chapter1FixtureRenders':chapter_renders,'fixtures':len(Fixtures.names),'viewportDprCombinations':len(viewports),'imagesVerified':sorted(assets),
 'frozenBrowserGeometryChecks':dom_checks,'browserOracle':'validation/panels/h5-metrics.json' if dom_checks else 'NOT_RUN: run capture-panels.mjs first',
 'checks':['raw NVG lifecycle','source WenKai font','physical/logical input transforms','portrait controls remain on screen','typing gates send','matching pointer capture','scene action and panel share pointer owner','drag cancellation','resize cancellation','scroll clamp','browse choice reveal delays','layout side hysteresis','Unicode typing','cold font load blocks placeholder metrics','late resource callbacks after disposal','source outgoing animation keyframes'],
 'notCovered':['real GPU output','source screenshot similarity','full scene frost blur','end-to-end story gameplay']}
(ROOT/'docs/migration/story-nvg-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
