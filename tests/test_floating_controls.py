"""Pointer ownership and modal transitions for the real raw-NVG control module."""
from lupa.lua54 import LuaRuntime

l = LuaRuntime(unpack_returned_tuples=True)
l.execute("package.path='scripts/?.lua;'..package.path")
l.execute('''
local Controls=require('render.PlayerControls')
local checks=0
for _,dpr in ipairs({1,2,3})do
 for _,size in ipairs({{800,360},{667,375},{915,412}})do
  local s={movable=true,echo=true,hasCard=true}
  local actions={}
  local c={w=size[1],h=size[2],dpr=dpr,touchUI=true,measure=function(_,t,n)return utf8.len(t)*n end}
  local ctl=Controls.new(function()return s end,function(id)actions[#actions+1]=id end)
  local function down(x,y,id)return ctl:down(c,x*dpr,y*dpr,id or 1)end
  local function move(x,y,id)return ctl:move(c,x*dpr,y*dpr,id or 1)end
  local function up(x,y,id)return ctl:up(c,x*dpr,y*dpr,id or 1)end
  local function find(id)for _,r in ipairs(ctl:layout(c))do if r.id==id then return r end end end
  assert(not find('stick'))
  assert(down(100,280));assert(ctl.stick and ctl.x==0 and ctl.y==0)
  move(105,282);assert(ctl.x==0 and ctl.y==0) -- dead zone
  move(140,280);assert(ctl.x==1 and ctl.y==0)
  down(210,280,2);move(230,300,2);up(230,300,2)
  assert(ctl.stick and ctl.stick.x==100 and ctl.x==1) -- second finger cannot steal
  local rewind=find('rewind');local rx,ry=rewind.x+rewind.w/2,rewind.y+rewind.h/2
  down(rx,ry,3);assert(ctl.spin and ctl.x==1)
  up(140,280);assert(not ctl.stick and ctl.x==0 and ctl.spin)
  up(rx,ry,3);assert(not ctl.spin)
  down(1,c.h-1);assert(ctl.x==0 and ctl.y==0) -- clamped visual, actual press origin
  assert(ctl.stick.hit.x>=0 and ctl.stick.hit.y+ctl.stick.hit.h<=c.h)
  move(31,c.h-1);assert(ctl.x>0);up(31,c.h-1);assert(not find('stick'))
  -- Reserved scene actions, even while disabled, and thread/panel chrome.
  c.sceneActions={layout=function()return {{x=80,y=240,w=100,h=80,enabled=false}} end}
  assert(not down(100,280));c.sceneActions=nil
  c.hitTest=function(_,x,y)return x==100 and y==280 end
  assert(not down(100,280));c.hitTest=nil
  for _,field in ipairs({'thread','composer','panel'})do
   c[field]={x=80,y=240,w=100,h=80};assert(not down(100,280));c[field]=nil
  end
  for _,gate in ipairs({'paused','covered','ending','card','phone','movement'})do
   down(100,280);move(140,280);assert(ctl.x==1)
   if gate=='phone'then c.channel='phone' elseif gate=='movement'then s.movable=false else s[gate]=true end
   ctl:layout(c);assert(not ctl.stick and ctl.x==0 and not ctl.spin)
   if gate=='phone'then c.channel=false elseif gate=='movement'then s.movable=true else s[gate]=false end
   move(150,280);assert(ctl.x==0 and not ctl.stick);up(150,280)
  end
  -- Real wrapper delegates UI touches, and cancellation covers resize/focus.
  local delegated=0
  c.pointerDown=function()delegated=delegated+1;return true end
  c.pointerMove=function()end;c.pointerUp=function()end;c.cancelPointer=function()end
  ctl:attach(c);c.sceneActions={layout=function()return {{x=80,y=240,w=100,h=80}} end}
  c:pointerDown(100*dpr,280*dpr,9);assert(delegated==1 and not ctl.stick)
  c.sceneActions=nil;c:pointerDown(100*dpr,280*dpr,9);c:pointerMove(140*dpr,280*dpr,9)
  assert(ctl.x==1);c:cancelPointer();c:pointerMove(160*dpr,280*dpr,9)
  assert(ctl.x==0 and not ctl.stick)
  ctl.mobile=false;c.touchUI=false;assert(not ctl:down(c,100*dpr,280*dpr,'mouse'))
  checks=checks+1
 end
end
print('PASS: '..checks..' floating-stick viewport/DPR combinations; dead zone, edge origin, multi-touch, six gates, UI delegation and cancellation')
''')
