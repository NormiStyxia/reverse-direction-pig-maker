"""Real overlay resize/input boundaries, including native phones with missing DPR."""
import json, math
from pathlib import Path
from lupa.lua54 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
l=LuaRuntime(unpack_returned_tuples=True)
l.execute("package.path='scripts/?.lua;'..package.path")
l.execute('''
platform='Mac';function GetPlatform()return platform end
graphics={GetWidth=function()return 1918 end,GetHeight=function()return 865 end,GetDPR=function()return 1 end}
cache={GetResourceAsync=function()end}
function nvgCreate()return {}end
function nvgCreateFont()return 1 end
function nvgCreateImage()return 1 end
function nvgImageSize()return 700,500 end
''')
def req(name):
    r=l.eval('require')(name)
    return r[0] if isinstance(r,tuple) else r
Viewport=req('render.UIViewport');Title=req('game.TitleState')
TitleCanvas=req('render.TitleOverlay');Story=req('render.StoryOverlay');Echo=req('render.EchoOverlay')
Controls=req('render.PlayerControls');Compact=req('render.TitleCompact')
cases=0
for platform in ['Mac','Windows','Linux','Web','Android','iOS','HarmonyOS','OHOS']:
    l.globals().platform=platform
    mobile=platform in ['Android','iOS','HarmonyOS','OHOS']
    for w,h in [(1918,865),(1920,1080),(2400,1080),(1080,2400),(1280,720),(800,360)]:
        for raw in [1,2,3]:
            ratio=min(4,min(w,h)/360) if mobile and raw==1 and min(w,h)>=700 else raw
            vw,vh,dpr=Viewport.resolve(w,h,raw)
            assert math.isclose(dpr,ratio)
            assert math.isclose(vw*dpr,w) and math.isclose(vh*dpr,h)
            t=Title.new(6,lambda:.5);t.skipIntro(t);t.update(t,.1)
            title=TitleCanvas.new(t);title.resize(title,w,h,raw);title.update(title)
            story=Story.new(l.table());echo=Echo.new(l.table())
            story.resize(story,w,h,raw);echo.resize(echo,w,h,raw)
            for c in [story,echo]:
                assert c.w==vw and c.h==vh and c.dpr==dpr
                assert bool(c.touchUI)==mobile
            assert title.logicalW==vw and title.logicalH==vh and title.dpr==dpr
            # H5 title design geometry is identical for mouse and touch.
            assert math.isclose(title.scale*title.dpr,min(w/2560,h/1152))
            for touch in [False,True]:
                title.touchMode=touch
                for i in [0,2,4]:
                    if Compact.active(title):
                        r=Compact.layout(title)[0][i+1]
                        px,py=(r.x+r.w/2)*title.dpr,(r.y+r.h/2)*title.dpr
                    else:
                        x,y=2440,title.menuY(title,i)+28
                        px=(x+title.offsetX)*title.scale*title.dpr
                        py=(y+title.offsetY)*title.scale*title.dpr
                    point=title.designPoint(title,px,py)
                    hit=title.hitTest(title,*point)
                    assert hit[0]=='menu:'+str(i),(platform,w,h,raw,touch,hit)
                # Actual two-finger ownership and activation at a physical point.
                if Compact.active(title):
                    r=Compact.layout(title)[0][5]
                    px,py=(r.x+r.w/2)*title.dpr,(r.y+r.h/2)*title.dpr
                else:
                    x,y=2440,title.menuY(title,4)+28
                    px=(x+title.offsetX)*title.scale*title.dpr
                    py=(y+title.offsetY)*title.scale*title.dpr
                title.pointerDown(title,px,py,7);title.pointerUp(title,px,py,8)
                assert not t.panel
                title.pointerUp(title,px,py,7);assert t.panel=='options'
                t.closePanel(t)
            state=l.table_from(dict(echo=True,movable=True,hasCard=True))
            actions=[]
            story.measure=lambda _,text,size:len(text)*size
            ctl=Controls.new(l.eval('function(s)return function()return s end end')(state),actions.append)
            rows,_=ctl.layout(ctl,story)
            for r in rows.values():
                if r.id=='pause':
                    px,py=(r.x+r.w/2)*dpr,(r.y+r.h/2)*dpr
                    pointer=9 if mobile else 'mouse'
                    ctl.down(ctl,story,px,py,pointer);ctl.up(ctl,story,px,py,pointer)
                    assert actions[-1]=='pause'
            cases+=1

l.globals().platform='Mac'
assert Viewport.resolve(1918,865,0)[2]==1 # desktop invalid DPR
for name in ['TitleOverlay','StoryOverlay','EchoOverlay']:
    source=(ROOT/'scripts/render'/f'{name}.lua').read_text()
    assert 'viewport.resolve' in source or 'Viewport.resolve' in source
assert 'drawTouch' not in (ROOT/'scripts/render/TitleOverlay.lua').read_text()
# Independent Chrome measurements of frozen style.css, when supplied.
metrics=ROOT/'validation/ui-viewport/h5-metrics.json'
if metrics.exists():
    for m in json.loads(metrics.read_text()):
        w,h=m['viewport'];raw=m['dpr']
        t=Title.new(6,lambda:.5);t.skipIntro(t);t.update(t,.1)
        c=TitleCanvas.new(t);c.resize(c,w*raw,h*raw,raw);c.touchMode=m['coarse'];c.update(c)
        for i,r in enumerate(m['title']):
            if Compact.active(c):
                n=Compact.layout(c)[0][i+1];actual=[n.x,n.y,n.w,n.h]
            else:
                actual=[(2328+c.offsetX)*c.scale,(c.menuY(c,i)+c.offsetY)*c.scale,232*c.scale,56*c.scale]
            assert all(abs(a-r[k])<.1 for a,k in zip(actual,['x','y','w','h'])),(m['viewport'],actual,r)
        if Compact.active(c):
            t.openPanel(t,'levelmode')
            for i in range(t.count(t)):
                t.select(t,i);rows,sections,panel=Compact.layout(c);r=rows[i+1]
                assert r.y>=panel.y+65-.1 and r.y+r.h<=panel.y+panel.h-12+.1
                px,py=r.x+r.w/2,r.y+r.h/2
                assert Compact.hit(c,px,py)[0]=='levelmode:'+str(i)
            t.closePanel(t)
print(f'PASS: {cases} viewport cases; native DPR fallback, valid desktop/Web DPR unchanged, H5 title geometry and physical taps')

# Dialog typography and portrait diameter against the same independent CSS data.
if metrics.exists():
    from fontTools.ttLib import TTFont
    font=TTFont(ROOT/'assets/fonts/LXGWWenKai-subset.ttf');cmap=font.getBestCmap()
    def measure(_,text,size):
        return sum(font['hmtx'].metrics[cmap.get(ord(ch),'.notdef')][0]for ch in text)*size/font['head'].unitsPerEm
    l.execute("setmetatable(_G,{__index=function(_,name)if name:match('^nvg')then return function()return {}end end end})")
    Dialog=req('render.DialogOverlay')
    for m in json.loads(metrics.read_text()):
        image=[];texts=[];w,h=m['viewport']
        c=l.table_from(dict(w=w,h=h,dpr=m['dpr'],vg=l.table(),touchUI=m['coarse'],measure=measure))
        c.image=lambda _,path,x,y,w,h,shape:image.append([x,y,w,h])
        c.text=lambda _,text,x,y,size,*args:texts.append([text,x,y,size])
        story=l.table_from(dict(t=2,dialogTheme='dream',dialog=l.table_from(dict(at=0,hold=1000,text='刚才还在……现在看清了。',face='puzzled',stamp='23:38'))))
        story.controlEnabled=l.eval('function()return false end')
        Dialog.draw(c,story)
        assert abs(image[0][2]/.768-m['medal']['w'])<.02,(m['viewport'],image,m['medal'])
        native=next(t for t in texts if t[0]=='刚')
        assert abs(native[3]-m['say']['fontSize'])<.01,(m['viewport'],native,m['say'])
    print('PASS: frozen H5 dialog font size and portrait diameter; 5 Google Chrome viewports')

# Execute the actual compact NVG drawing path, including every scrolled floor.
l.execute('NVG_ALIGN_LEFT=1;NVG_ALIGN_CENTER=2;NVG_ALIGN_RIGHT=4;NVG_ALIGN_TOP=8;NVG_ALIGN_BASELINE=64;NVG_BUTT=0;NVG_ROUND=1;NVG_CW=2')
for mobile in [False,True]:
    l.globals().platform='Mac'
    t=Title.new(6,lambda:.5);t.skipIntro(t);t.update(t,.1)
    c=TitleCanvas.new(t);c.touchMode=mobile;c.resize(c,2400,1080,3);c.update(c);c.render(c)
    t.openPanel(t,'levelmode');c.update(c)
    for i in range(t.count(t)):
        t.select(t,i);c.update(c);c.render(c)
    t.closePanel(t);c.update(c);c.render(c)
print('PASS: compact NVG menu/panel rendering, mouse and touch, all 19 floors')

# End-page geometry against independently captured final H5 CSS, not the old
# rounded 33px native button. Includes coarse 16:9 and mouse desktop cases.
end_metrics=ROOT/'validation/ui-review/h5-end-metrics.json'
if end_metrics.exists():
    End=req('render.ChapterEnd')
    l.execute('''
    endTexts={};endSize=0;endSpacing=0
    function nvgTextLetterSpacing(_,value)endSpacing=value end
    function nvgText(_,x,y,value)
        endTexts[#endTexts+1]={text=value,x=x,y=y,size=endSize,spacing=endSpacing}
    end
    ''')
    for m in json.loads(end_metrics.read_text()):
        w,h=m['viewport'];l.execute('endTexts={}')
        c=l.table_from(dict(w=w,h=h,dpr=m['dpr'],vg=l.table(),touchUI=m['coarse'],measure=measure))
        c.fontSize=lambda _,size:setattr(l.globals(),'endSize',size)
        end=End.new();end.show(end,'关卡模式 · 完','全部 4 章 19 层');end.update(end,3);end.render(end,c)
        for i,(actual,expected) in enumerate(zip(l.globals().endTexts.values(),m['end'])):
            expected_y=expected['y']
            if i==2:
                expected_y+=(expected['h']-req('game.StoryPanelLayout').normalHeight(expected['fontSize']))/2
            for a,b in [(actual.y,expected_y),(actual.size,expected['fontSize']),(actual.spacing,expected['spacing'])]:
                assert abs(a-b)<.1,(m['viewport'],a,b)
        button=m['end'][2]
        for k in ['x','y','w','h']:
            assert abs(end.button[k]-button[k])<.1,(m['viewport'],k,end.button[k],button[k])
        px,py=(end.button.x+end.button.w/2)*c.dpr,(end.button.y+end.button.h/2)*c.dpr
        end.down(end,c,px,py,7);end.up(end,c,px,py,8);assert not end.replay
        end.down(end,c,px,py,7);end.up(end,c,px,py,7);assert end.replay
    print('PASS: end-page typography, button rectangles and physical-pointer ownership; 5 Google Chrome viewports')
