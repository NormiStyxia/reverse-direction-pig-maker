"""Raw NVG adapter/input tests. These do not claim native rendering or pixel parity."""
import json, math, re, xml.etree.ElementTree as ET
from pathlib import Path
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path='+json.dumps(str(ROOT/'scripts/?.lua'),ensure_ascii=False)+'..";"..package.path')
# Mock only documented native boundaries. Unknown API calls remain errors.
lua.execute('''
graphics={GetWidth=function()return 1280 end,GetHeight=function()return 720 end,GetDPR=function()return 2 end}
NVG_ALIGN_LEFT=1;NVG_ALIGN_CENTER=2;NVG_ALIGN_RIGHT=4;NVG_ALIGN_TOP=8
draw={calls={},depth=0,fonts=0,images=0,deleted=0,svgCount=0,active=false}
local function record(name,...)
 draw.calls[#draw.calls+1]={name=name,args={...}}
 for _,arg in ipairs({...}) do if type(arg)=='number' then assert(arg==arg and math.abs(arg)<math.huge,name..' nonfinite') end end
end
function nvgCreate()return {} end
function nvgDelete() draw.deleted=draw.deleted+1 end
function nvgCreateFont()draw.fonts=draw.fonts+1;return draw.fonts end
function nvgCreateImage()draw.images=draw.images+1;return draw.images end
function nvgImageSize()return 700,500 end
function nvgDeleteImage()draw.images=draw.images-1 end
function nvgRGBA(...)return {...} end
function nvgImagePattern(...)return {...} end
function nvgBeginFrame(vg,w,h,dpr)assert(not draw.active);draw.active=true;record('begin',w,h,dpr) end
function nvgEndFrame()assert(draw.active and draw.depth==0);draw.active=false;record('end') end
function nvgSave()assert(draw.active);draw.depth=draw.depth+1 end
function nvgRestore()draw.depth=draw.depth-1;assert(draw.depth>=0) end
for _,name in ipairs({'nvgScale','nvgTranslate','nvgRotate','nvgSkewX','nvgIntersectScissor','nvgGlobalAlpha',
 'nvgBeginPath','nvgRect','nvgRoundedRect','nvgFillColor','nvgFill','nvgFillPaint','nvgStrokeWidth',
 'nvgStrokeColor','nvgStroke','nvgFontFace','nvgFontSize','nvgTextLetterSpacing','nvgTextAlign','nvgText'}) do
 _G[name]=function(vg,...)assert(draw.active);record(name,...) end
end
function nvgSvgCreate()
 local svg={elements={}}
 function svg:Load(path)self.path=path;return true end
 function svg:GetError()return '' end
 function svg:Unload()self.unloaded=true end
 function svg:GetElementById(id)
  if not self.elements[id] then
   self.elements[id]={SetTransformOrigin=function(s,x,y)s.origin={x,y} end,
    SetScale=function(s,x,y)s.scale={x,y} end,
    SetTransformOverride=function(s,...)s.transform={...} end}
  end
  return self.elements[id]
 end
 return svg
end
function nvgSvgRender(vg,svg)assert(draw.active and not svg.unloaded);draw.svgCount=draw.svgCount+1;return true end
''')
Title=lua.eval('require("game.TitleState")')[0]
Canvas=lua.eval('require("render.TitleOverlay")')[0]
P=lua.eval('require("game.TitlePresentation")')
title=Title.new(0,lambda:.5);screen=Canvas.new(title)
def tick(n=1,render=False):
    for _ in range(n):
        title.update(title,1/60);screen.update(screen)
        if render: screen.render(screen)
def physical(x,y):
    return (x+screen.offsetX)*screen.scale*screen.dpr,(y+screen.offsetY)*screen.scale*screen.dpr
def move(x,y,id='mouse'): screen.pointerMove(screen,*physical(x,y),id)
def down(x,y,id='mouse'): screen.pointerDown(screen,*physical(x,y),id)
def up(x,y,id='mouse'): screen.pointerUp(screen,*physical(x,y),id)
def click(x,y,id='mouse'): down(x,y,id);up(x,y,id)
tick(1,True)
# Press during intro is consumed even if release arrives after idle begins.
down(2400,580);tick();up(2400,580)
assert title.st.phase=='idle' and title.st.choice is False
tick(100,True)
click(2400,650);assert title.st.phase=='idle' and title.menuSel==0
click(2400,715);tick(40,True);assert title.panel=='chapters'
assert screen.hitTest(screen,2400,700) is False # locked floor 6
click(2400,700);assert title.st.phase=='idle'
assert screen.hitTest(screen,2500,580) is False # no underlying menu hit
click(2000,1080);tick(40);assert not title.panel
# Moving out, dragging to another row, and unrelated releases do not activate.
down(2400,580);up(200,580);assert title.st.phase=='idle'
down(2400,580);move(2400,770);up(2400,770);assert not title.panel
up(2400,580);assert title.st.phase=='idle'
click(2400,780);tick(40,True);assert title.panel=='options'
for i,key in enumerate(['motion','parallax','muted']):
    before=title.opts[key];click(2000,290+i*69);tick();assert title.opts[key]!=before
click(2000,1080);tick(40)
# Hover changes only on movement; keyboard selection persists with stationary pointer.
move(2400,580);title.keyDown(title,'ArrowDown',False)
assert title.menuSel==2
move(2400,580);assert title.menuSel==2
# Physical/display round trips, letterbox rejection, render DPR and keyboard parity.
viewports=[(1280,720),(2560,1152),(3440,1440),(720,1280),(640,360),(3840,2160)]
for w,h in viewports:
    for dpr in [1,1.25,2,3]:
        screen.resize(screen,w,h,dpr)
        x,y=screen.designPoint(screen,w/2,h/2)
        assert math.isclose(x,1280,abs_tol=1e-8) and math.isclose(y,576,abs_tol=1e-8)
        for px,py in [(0,0),(2560,1152),(2400,780),(56,1063)]:
            dx,dy=screen.designPoint(screen,*physical(px,py))
            assert abs(dx-px)<1e-8 and abs(dy-py)<1e-8
        assert screen.hitTest(screen,-1,580) is False
        assert screen.hitTest(screen,2560,580) is False
        click(2400,780,7);tick(40);assert title.panel=='options'
        # Second finger may neither release nor redirect the first finger.
        before=title.opts.motion
        down(2000,290,7);down(2000,360,8);up(2000,290,8)
        assert title.opts.motion==before
        up(2000,290,7);assert title.opts.motion!=before
        screen.render(screen)
        calls=list(lua.globals().draw.calls.values())
        frame=[c for c in calls if c.name=='begin'][-1].args
        assert frame[1]==w/dpr and frame[2]==h/dpr and frame[3]==dpr
        title.keyDown(title,'Escape',False);tick(40)
# Resize and focus cancellation invalidate a captured tap.
down(2400,580,7);screen.resize(screen,1280,720,2);up(2400,580,7)
assert title.st.phase=='idle'
down(2400,580);screen.cancelPointer(screen);up(2400,580);assert title.st.phase=='idle'
title.keyDown(title,'K',False);tick(45,True)
assert screen.logo.elements['fan-ink'].scale[1]<-.999
title.keyUp(title,'K');tick(45,True)
assert screen.logo.elements['fan-ink'].scale[1]>.999
plane=screen.dial.elements['plane'].transform
assert math.isclose(plane[1],title.st.zoom)
assert math.isclose(plane[5],1280-(title.st.cam.x-title.st.par.x*.004)*2560*title.st.zoom)
# Reached save enables continue, adds margin, and selects the correct 0-based floor.
title.reached=3;move(2400,650);tick(40)
assert title.menuSel==1 and abs(screen.menuMargin-26)<1e-7
assert screen.hitTest(screen,2400,700) is False # expansion gap, not chapters
click(2400,650);tick(150,True)
assert title.st.started and not title.active and title.st.choice.level==2
events=list(title.drainEvents(title).values());assert sum(e.kind=='start' for e in events)==1
assert screen.hitTest(screen,2400,580) is False
screen.dispose(screen);screen.dispose(screen)
assert lua.globals().draw.deleted==1 and lua.globals().draw.images==0
assert lua.globals().draw.fonts==2 # allocated once, not every render
for name in ['ease','slide','reveal','mirror','blueprint']:
    samples=[P[name](i/100) for i in range(101)]
    assert samples[0]<1e-8 and samples[-1]>1-1e-8
    assert all(a<=b for a,b in zip(samples,samples[1:]))
channel=P.channel(0);P.track(channel,1,0,.5,P.slide)
a=P.track(channel,1,.2,.5,P.slide);b=P.track(channel,0,.2,.5,P.slide);assert a==b
ns={'s':'http://www.w3.org/2000/svg'}
dial=ET.parse(ROOT/'assets/title/ui/dial.svg')
assert len(dial.findall('.//s:g[@id="ticks"]/s:line',ns))==120
assert len(dial.findall('.//s:g[@id="blueprint"]/s:text',ns))==4
for path in (ROOT/'scripts').rglob('*.lua'):
    assert not re.search(r'''require\s*\(?[\s'"]*urhox-libs/UI|UI\.(Init|SetRoot)|Yoga\.''',path.read_text()),path
report={'result':'PASS','viewportDprCombinations':24,
 'checks':['intro press consumed across idle transition','locked continue/floors','panel blocks underlying menu',
 'drag/release cancellation','settings','stationary hover vs keyboard','touch capture and multi-finger isolation',
 'resize/focus cancellation','physical input round trips and frame DPR','fan flip and plane transform',
 'continue expansion gap and saved floor','single start event','NVG frame/save lifecycle and resources',
 'CSS curve reversal continuity','120 ticks / 6 paths / 4 blueprint labels','no Yoga or UI widget dependencies'],
 'notCovered':['native engine API execution','SVG rendered pixels','font parity and blur/glow','mobile ergonomics','story callback integration']}
(ROOT/'docs/migration/title-nvg-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
