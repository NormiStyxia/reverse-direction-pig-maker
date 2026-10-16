"""Frozen browser geometry oracle and native pointer behavior for scene actions."""
import json, math
from pathlib import Path
from fontTools.ttLib import TTFont
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path='scripts/?.lua;'..package.path")
module=lua.eval("require('render.SceneActions')")[0]
font=TTFont(ROOT/'assets/fonts/LXGWWenKai-subset.ttf');cmap=font.getBestCmap()
def measure(canvas,text,size):
    return sum(font['hmtx'].metrics[cmap[ord(ch)]][0] for ch in text)*size/font['head'].unitsPerEm
def table(value):
    if isinstance(value,dict):return lua.table_from({k:table(v) for k,v in value.items()})
    if isinstance(value,list):return lua.table_from([table(v) for v in value])
    return value
lua.execute('''
function fakeStory(options)
 return {options=options,interactionId='seat',t=10,interactionAt=-99,normi={busy=function()return false end},
  phone={open=false,k=0,view='lock'},browse={open=false,k=0},
  nearbyInteractions=function(self)return self.options end,
  interact=function(self,id)self.action=id end,togglePhone=function(self)self.phone.open=not self.phone.open end}
end
function storyGetter(s)return function()return s end end
''')
checks=0
for fixture in json.loads((ROOT/'validation/scene-actions/h5-metrics.json').read_text()):
    canvas=table({'w':fixture['width'],'h':fixture['height'],'dpr':1,'fontReady':True});canvas.measure=measure
    options=[dict(zip(['id','object','text'],o)) for o in fixture['options']]
    story=lua.globals().fakeStory(table(options));actions=module.new(canvas,lua.globals().storyGetter(story),True)
    buttons,hint=actions.layout(actions)
    for actual in buttons.values():
        expected=next(e['rect'] for e in fixture['elements'] if e['action']==actual.id or (actual.id=='phone' and e['id']=='phoneBtn'))
        for k,field in [('x','x'),('y','y'),('width','w'),('height','h')]:
            assert abs(expected[k]-actual[field])<.08,(fixture['width'],fixture['count'],actual.id,k,expected[k],actual[field])
            checks+=1
    if hint:
        expected=next(e['rect'] for e in fixture['elements'] if e['text']==hint.text and e['tag']=='SMALL')
        text_x=expected['x']+(expected['width']-measure(canvas,hint.text,13))/2
        assert abs(text_x-hint.x)<.08 and abs(expected['y']-hint.y)<.08;checks+=2
    for dpr in [1,2,3]:
        canvas.dpr=dpr
        first=buttons[1];x=(first.x+first.w/2)*dpr;y=(first.y+first.h/2)*dpr
        story.action=False
        assert actions.down(actions,x,y,0)
        assert not actions.down(actions,x,y,1)  # A second finger cannot steal a pressed action.
        assert not actions.up(actions,x,y,1) and not story.action
        actions.move(actions,x+9*dpr,y,0);actions.up(actions,x,y,0);assert not story.action
        actions.down(actions,x,y,2);actions.cancel(actions);assert not actions.up(actions,x,y,2)
        actions.down(actions,x,y,3);actions.up(actions,x,y,3);assert story.action=='seat'
        story.interactionAt=story.t;assert not actions.down(actions,x,y,3);story.interactionAt=-99
        phone=buttons[len(buttons)];px=(phone.x+40)*dpr;py=(phone.y+40)*dpr
        story.phone.open=False;actions.down(actions,px,py,4);actions.up(actions,px,py,4);assert story.phone.open
        # Frozen body.phone-open uses progress > .3, also during closing.
        for panel in [story.phone,story.browse]:
            for view in ['lock','chat']:
                story.phone.view=view
                for opened in [True,False]:
                    panel.open=opened
                    for progress in [0,.3,.30001,1]:
                        panel.k=progress
                        current,_=actions.layout(actions)
                        visible=any(b.id=='phone' for b in current.values())
                        assert visible == (progress<=.3)
                        assert bool(actions.down(actions,px,py,4)) == visible
                        actions.cancel(actions);checks+=2
                panel.k=0;panel.open=False
        # If a panel opens while the pointer is held, release must not toggle it.
        story.phone.open=True
        assert actions.down(actions,px,py,4)
        story.phone.k=1;actions.up(actions,px,py,4)
        assert story.phone.open
        story.phone.k=0;story.phone.open=False;checks+=2
        story.phoneButtonHidden=True;assert not actions.down(actions,px,py,4);story.phoneButtonHidden=False
        checks+=10
report={'result':'PASS','sourceLayouts':12,'dprs':[1,2,3],'checks':checks,
        'checksInclude':['frozen CSS button bounds and wrapping','phone icon button bounds',
        'pointer ID ownership, drag cancellation and focus/resize cancellation hook',
        'source cooldown disabling and hidden phone button',
        'lock/chat/browse progress threshold and closing restoration',
        'hidden phone has no hit region; panel opening cancels pending activation'],
        'notCovered':['real-device touch events','complete game visual acceptance']}
(ROOT/'docs/migration/scene-actions-test-report.json').write_text(json.dumps(report,indent=2)+chr(10))
print(json.dumps(report,indent=2))
