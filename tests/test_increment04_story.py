from lupa.lua54 import LuaRuntime
l=LuaRuntime();l.execute("package.path='scripts/?.lua;'..package.path")
l.execute('''
local S=require('game.Chapter1State');local D=require('game.DayStoreState');local Data=require('game.data.Story03Data')
assert(Data.DREAM_LINES.swapBack=='……？'and not Data.DREAM_LINES.follow)
local function tick(s,t)for i=1,math.ceil(t/.05)do s:update(.05,{})end end
local s=S.new({});tick(s,4);assert(s.phase=='play');s:onInteract('box');tick(s,8);assert(s.phase=='play')
s:togglePhone();s:closePanel();tick(s,3);assert(s.phase=='ask')
for _,answer in ipairs({'same','late','done'})do
 local s=S.new({});s.phase='walk';s.answer=answer;s.carrying=true;s:putDown();tick(s,8);assert(s.parked and not s.carrying and s:triedCount()==1)
 s:goRewind();tick(s,1);assert(s.result.toTimeline and s.phase=='walk')
 s.result=false;s:goDown(true);tick(s,1);assert(s.result.toStore)
 local d=D.new({answer=answer});tick(d,4);assert(d.phase=='play')
 for _,id in ipairs({'window','shelf'})do d:startBrowse(id);d:closeBrowse()end
 tick(d,6);assert(d.msgOpen and d:hm()=='17:45');assert(d.browse.open)
 d:onBrowse('choice:0');tick(d,3);assert(d.phase=='done')
 local back=S.new({fromStore=true,answer=answer,tried={answer}});tick(back,2);assert(back.phase=='walk'and back:hm()=='17:58'and back.parked)
 back:onInteract('put');tick(back,16);assert(back.phase=='desk');back:startFold();tick(back,5);assert(back.result.answer==answer)
end
local all=S.new({tried={'same','late'},rewound=true});all.answer='done';all.phase='walk';all:putDown();tick(all,8)
assert(all:triedCount()==3);for _,z in ipairs(all:zones())do assert(z.id~='rewind')end
local re=S.new({tried={'same'},rewound=true});tick(re,9);assert(re.phase=='ask');re:openAsk();re.phone:flush();assert(re.phone.choices[1]:find('试过了'))
local Save=require('game.SaveState');local save=Save.new({read=function()end,write=function()return true end},{encode=function()return '{}'end})
for _,a in ipairs({'same','late','done','same'})do save:noteTried(a)end;assert(#save:tried()==3)
''')
print('PASS: proof gate, 3 day-store branches, return at 17:58, active rewind, tried dedup/removal and latest dream text')
