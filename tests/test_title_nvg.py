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
NVG_ALIGN_LEFT=1;NVG_ALIGN_CENTER=2;NVG_ALIGN_RIGHT=4;NVG_ALIGN_TOP=8;NVG_ALIGN_BASELINE=64;NVG_BUTT=0;NVG_ROUND=1;NVG_CW=2
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
function nvgBeginFrame(vg,w,h,dpr)assert(not draw.active);draw.calls={};draw.active=true;record('begin',w,h,dpr) end
function nvgEndFrame()assert(draw.active and draw.depth==0);draw.active=false;record('end') end
function nvgSave()assert(draw.active);draw.depth=draw.depth+1 end
function nvgRestore()draw.depth=draw.depth-1;assert(draw.depth>=0) end
for _,name in ipairs({'nvgScale','nvgTranslate','nvgRotate','nvgSkewX','nvgIntersectScissor','nvgGlobalAlpha',
 'nvgBeginPath','nvgRect','nvgRoundedRect','nvgFillColor','nvgFill','nvgFillPaint','nvgStrokeWidth',
 'nvgStrokeColor','nvgStroke','nvgTransform','nvgLineCap','nvgMoveTo','nvgLineTo','nvgArc','nvgCircle','nvgBezierTo','nvgQuadTo','nvgClosePath','nvgPathWinding','nvgFontFace','nvgFontSize','nvgTextLetterSpacing','nvgTextAlign','nvgText'}) do
 _G[name]=function(vg,...)assert(draw.active);record(name,...) end
end
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
assert screen.mirror<-.999
title.keyUp(title,'K');tick(45,True)
assert screen.mirror>.999
calls=list(lua.globals().draw.calls.values())
plane=[c for c in calls if c.name=='nvgTransform'][-1].args
assert math.isclose(plane[1],title.st.zoom)
assert math.isclose(plane[5],1280-(title.st.cam.x-title.st.par.x*.004)*2560*title.st.zoom)
# Increment 01: background hold, blocked button/panel hits and cancellation.
for w,h in viewports:
    for dpr in [1,1.25,2,3]:
        screen.resize(screen,w,h,dpr)
        title.st.holding=False
        down(1200,600,7);assert title.st.holding
        up(1200,600,8);assert title.st.holding # unrelated finger cannot release
        up(1200,600,7);assert not title.st.holding
        down(1200,600,7);screen.cancelPointer(screen);assert not title.st.holding
        down(1200,600,7);screen.resize(screen,w,h,dpr);assert not title.st.holding
        down(2400,650,7);assert not title.st.holding # locked continue button
        up(2400,650,7)
        title.openPanel(title,'options');tick(40)
        down(2000,900,7);assert not title.st.holding # blank panel interior
        up(2000,900,7);title.closePanel(title);tick(40)
# Finished inversion colors settle after the CSS 0.3-second transition.
title.st.auto.stage='draft';title.st.auto.t=0;title.st.inv=1;title.st.prog=0
tick(25,True)
assert title.view.alt and abs(screen.altAmount-1)<1e-8
calls=list(lua.globals().draw.calls.values())
fill_colors=[tuple(c.args[1][i] for i in range(1,5)) for c in calls if c.name=='nvgFillColor']
assert (242,246,255,255) in fill_colors and (248,250,253,255) in fill_colors
assert (1,64,196,255) in fill_colors # selected menu text remains cobalt
# White panel keeps blue heading, even while the background is inverted.
title.openPanel(title,'options');tick(40,True)
calls=list(lua.globals().draw.calls.values())
last_color=None
for c in calls:
    if c.name=='nvgFillColor':last_color=tuple(c.args[1][i] for i in range(1,5))
    if c.name=='nvgText' and c.args[3]=='设置' and c.args[1]==80:
        assert last_color==(10,60,184,255)
title.closePanel(title);tick(40)
# Reached save enables continue, adds margin, and selects the correct 0-based floor.
title.reached=3;move(2400,650);tick(40)
assert title.menuSel==1 and abs(screen.menuMargin-26)<1e-7
assert screen.hitTest(screen,2400,700) is False # expansion gap, not chapters
click(2400,650);tick(150,True)
assert title.st.started and not title.active and title.st.choice.level==2
events=list(title.drainEvents(title).values());assert sum(e.kind=='start' for e in events)==1
assert screen.hitTest(screen,2400,580) is False
# A delayed native scene keeps the same paper cover, including letterboxes.
# Once ready, the original title-root easing drives the fade without UI widgets.
for w,h in viewports:
    for dpr in [1,1.25,2,3]:
        screen.resize(screen,w,h,dpr)
        for elapsed in [1.1,1.55,2.0]:
            title.st.leaveT=elapsed;screen.renderBridge(screen)
            calls=list(lua.globals().draw.calls.values())
            frame=[c for c in calls if c.name=='begin'][0].args
            assert frame[1]==w/dpr and frame[2]==h/dpr and frame[3]==dpr
            alpha=[c for c in calls if c.name=='nvgGlobalAlpha'][0].args[1]
            assert abs(alpha-(1-P.ease((elapsed-1.1)/.9)))<1e-9
            rects=[c.args for c in calls if c.name=='nvgRect']
            assert list(rects[0].values())==[0,0,w/dpr,h/dpr]
            assert list(rects[1].values())==[0,0,2560,1152]
            assert any(c.name=='nvgText' and c.args[3].startswith('第 3 层') for c in calls)
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
 'continue expansion gap and saved floor','single start event','NVG frame/save lifecycle and resources','paper loading cover and fade across 24 layouts',
 'background hold and cancellation across 24 layouts','inverted menu/label colors and blue panel interior','CSS curve reversal continuity','120 ticks / 6 paths / 4 blueprint labels','no Yoga or UI widget dependencies'],
 'notCovered':['native engine API execution','NVG rendered pixels','font parity and blur/glow','mobile ergonomics','story callback integration']}
(ROOT/'docs/migration/title-nvg-test-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+chr(10))
print(json.dumps(report,ensure_ascii=False,indent=2))
