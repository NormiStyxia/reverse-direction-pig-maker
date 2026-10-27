"""Frozen increment 03 store rhythm, chat handoff and new browse graph. Model only."""
from pathlib import Path
from lupa.lua54 import LuaRuntime
import json
l=LuaRuntime();l.execute("package.path='scripts/?.lua;'..package.path")
l.execute('''
local Group=require('game.GroupChat')
local Night=require('game.NightOfficeState')
local Store=require('game.PrologueState')
local L=require('game.data.Story03Data').STORE_LINES
local Layout=require('game.StoryPanelLayout')
local Extras=require('render.PhoneExtras')
local n=Night.new();n.phase='play';n:receive();n:onPhone('sticker:pig-shoudao');n:closePhone()
assert(n.sent and #Group.mine==1 and Group.mine[1].text=='[收到]')
n.phone.reacts.w1={'r-zan'};n:saveChat()
local s=Store.new();assert(#s.phone.history==4 and s.phone.history[4].sticker=='pig-shoudao')
assert(s.phone.reacts.h2[1]=='r-zan')
local transcript=Layout.transcript(s.phone);assert(transcript[4].sticker=='pig-shoudao' and transcript[3].reacts[1]=='r-zan')
for i=1,337 do s:update(1/60,{})end;assert(s.phase=='play' and s.t<5.7)
local seen={};local frame=0
while s.phase=='play' and frame<6000 do
    frame=frame+1;s:update(1/60,{})
    if s.unread then s:openPhone('chat')end
    if s.pending then
        local id=s.pendingId;seen[id]=true
        local c={story=s};Extras.action(c,'react:'..id..':r-shoudao')
        assert(not s.pending);Extras.action(c,'react:'..id..':r-shoudao');assert(#s.phone.reacts[id]==0)
        s:closePhone()
    end
end
assert(s.phase=='dark' and s.workI==6 and s.clock==12)
local count=0;for _ in pairs(seen)do count=count+1 end;assert(count==6)
while s.darkT<1.5 do s:update(1/60,{})end;assert(s.power==1)
while s.darkT<1.7 do s:update(1/60,{})end;assert(s.power==0 and s.offline)
while s.phase~='pig' do s:update(1/60,{})end;assert(s.darkT>=9.2 and s.darkT<9.23 and s.tablePig.visible)
local before=s.sentN;s:onPhone('sticker:tw-shoudao');for i=1,100 do s:update(1/60,{})end
assert(s.msgs[#s.msgs].status=='failed' and s.sentN==before)
for zone,acts in pairs(require('game.data.Story03Data').STORE_BROWSE)do
    for _,act in ipairs(acts)do
        s.phase='play';s:startBrowse(zone)
        for id in pairs(act.nodes)do s:goBrowse(id);s.browse:flush()end
        s:closeBrowse()
    end
end
Group.mine=false;Group.reacts={};local direct=Store.new();assert(#direct.phone.history==#L.history)
print('STORE03_MODEL: PASS; six work messages, answer reactions, stickers, office history, blackout 9.2s, all browse nodes')
''')
report={'result':'PASS','scope':'increment03 store model and phone action routing; not native graphics or OS input','sourceTreeSha256':'1e4ec744204da5269a0b9989fab42d91f1bd9703f12f94db4ad95d7603acefdf'}
Path('docs/migration/increment03-store-story-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
