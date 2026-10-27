-- Raw NVG mode B; shares the active scene's frame/font and physical-to-logical input.
-- Independent pointer ownership lets movement and held rewind coexist on touch.
local Controls={};Controls.__index=Controls
local function inside(x,y,r) return x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end
function Controls.new(context,action)
    local self=setmetatable({},Controls);self:init(context,action);return self
end
function Controls:init(context,action)
    self.context=context;self.action=action;self.mobile=false;self.pointers={};self.x=0;self.y=0;self.spin=false
end
function Controls:cancel() self.pointers={};self.x=0;self.y=0;self.spin=false;self.hover=false end
local Layout=require('game.StoryPanelLayout')
local INK={16,32,63,255}
local function width(c,text,size,spacing)
    return c:measure(text,size)+(utf8.len(text)or 0)*(spacing or 0)
end
local function ink(c,text,x,y,size,color,spacing)
    for _,cp in utf8.codes(text)do local ch=utf8.char(cp);c:text(ch,x,y,size,color);x=x+c:measure(ch,size)+(spacing or 0)end
end
local function paper(c,r,hover)
    local vg=c.vg;nvgBeginPath(vg);nvgRect(vg,r.x,r.y,r.w,r.h)
    nvgFillColor(vg,hover and nvgRGBA(255,243,219,255)or nvgRGBA(245,247,251,224));nvgFill(vg)
    -- CSS background-origin:border-box: eight 9x1 strips, no rounded outline.
    for _,p in ipairs({{r.x,r.y,1,1},{r.x+r.w,r.y,-1,1},{r.x,r.y+r.h,1,-1},{r.x+r.w,r.y+r.h,-1,-1}})do
        nvgBeginPath(vg);nvgRect(vg,p[1]+(p[3]<0 and -9 or 0),p[2]+(p[4]<0 and -1 or 0),9,1)
        nvgRect(vg,p[1]+(p[3]<0 and -1 or 0),p[2]+(p[4]<0 and -9 or 0),1,9)
        nvgFillColor(vg,nvgRGBA(16,32,63,255));nvgFill(vg)
    end
end
function Controls:layout(c)
    local s=self.context();local out={};local wide=c.w/c.h>=2
    local mobile=self.mobile or c.touchUI
    local compact=c.w>c.h and c.h<=600
    local function add(id,text,x,y,w,h,kind,size)
        local r={id=id,text=text,x=x,y=y,w=w,h=h,kind=kind,size=size};out[#out+1]=r;return r
    end
    local function button(id,label,key,size,spacing,px,py)
        key=not mobile and key or nil
        local text=label..(key and ' 'or '')
        local labelW=width(c,text,size,spacing)
        local kw=key and width(c,key,12,.96)+14 or 0
        local gap=key and(id=='skip'and 6 or 8)or 0
        local w=labelW+gap+kw+px*2+2
        local h=Layout.normalHeight(size)+py*2+2
        if key and size<12 then h=h+1 end -- 12px inline key raises the 11px line box.
        if wide and id~='skip'then h=math.max(44,h)end
        local r=add(id,text,0,0,w,h,'paper',size)
        r.spacing=spacing;r.labelW=labelW;r.key=key;r.keyW=kw;r.keyGap=gap;r.px=px
        return r
    end
    if s.card then add('cardClose','关闭手记',0,0,c.w,c.h,'invisible',12);return out,s end
    if s.paused then
        local size=wide and 12 or 16
        local a=button('resume','继续','Esc',size,size*.14,20,9)
        local b=button('home','返回主界面','Enter',size,size*.14,20,9)
        local titleH=Layout.normalHeight(wide and 24 or 36)
        local top=(c.h-titleH-22-a.h)/2
        a.x=(c.w-a.w-14-b.w)/2;b.x=a.x+a.w+14;a.y=top+titleH+22;b.y=a.y
        return out,s
    end
    if s.ending or s.covered then return out,s end
    -- Retain the required native home shortcut, in the frozen straight-line style.
    add('home','‹',mobile and 12 or 16,wide and 8 or 16,44,44,'home',30)
    if s.canSkip then
        local size=wide and 11 or 13;local r=button('skip','跳过','Esc',size,size*.2,wide and 10 or 12,6)
        r.x=c.w-(wide and 16 or compact and 12 or 18)-r.w;r.y=(wide or compact)and 8 or 16
        if c.channel=='phone' and c.placement and c.placement.layoutSide=='right'then
            r.x=compact and 12 or 18
            -- Left phone-safe corner is also occupied by the native home arrow.
            out[1].x=c.w-16-out[1].w
        end
    end
    if s.echo and not mobile then
        local r=button('pause','暂停','Esc',wide and 11 or 13,(wide and 11 or 13)*.2,wide and 10 or 12,6)
        r.x=c.w-18-r.w;r.y=wide and 8 or 16
        local edge=r.x-10
        for _,item in ipairs({{'topview','俯瞰','V'},{'mechanism','机制手记','H'}})do
            if item[1]~='mechanism'or s.hasCard then local b=button(item[1],item[2],item[3],wide and 11 or 13,1,10,6);b.x=edge-b.w;b.y=r.y;edge=b.x-10 end
        end
    end
    if mobile and c.w>c.h and (s.echo or s.movable) then
        local size=wide and 12 or 15;local min=wide and 44 or 56;local pad=wide and 6 or 8
        local actions={}
        if s.cycle then actions[#actions+1]={'cycle','换一个'}end
        if s.echo then actions[#actions+1]={'rewind','倒带'};actions[#actions+1]={'charge','冲撞'}
        elseif not s.moveOnly then actions[#actions+1]={'interact','交互'}end
        local x=c.w-16;local bottom=wide and 12 or 16;local gap=wide and 8 or 12
        for i=#actions,1,-1 do
            local a=actions[i];local w=math.max(min,width(c,a[2],size,size*.06)+pad*2+2)
            x=x-w;local r=add(a[1],a[2],x,c.h-bottom-min,w,min,'touch',size)
            r.disabled=not s.movable;r.spacing=size*.06;x=x-gap
        end
        if s.echo then
            for i,a in ipairs({{'pause','暂停'},{'restart','重来'},{'topview','俯瞰'},{'mechanism','手记'}})do
                local r=add(a[1],a[2],c.w-12-44-(i-1)*52,8,44,44,'tool',wide and 11 or 13)
                r.disabled=(a[1]=='restart'and not s.movable)or (a[1]=='mechanism'and not s.hasCard)
            end
        end
        if s.movable then
            local diameter=wide and 72 or math.max(84,math.min(112,c.h*.25))
            local r=add('stick','走动',18,c.h-bottom-diameter,diameter,diameter,'stick',wide and 11 or 14)
            r.knob=wide and 40 or 52
        end
    end
    return out,s
end
function Controls:hit(c,x,y)
    local rows=self:layout(c)
    for _,r in ipairs(rows) do if not r.disabled and inside(x,y,r) then return r end end
end
function Controls:down(c,x,y,id)
    if type(id)=='number' then self.mobile=true;c.touchUI=true end
    x=x/c.dpr;y=y/c.dpr
    local hit=self:hit(c,x,y);local s=self.context()
    if not hit then return s.paused or s.covered end
    for _,p in pairs(self.pointers) do if p.hit.id==hit.id then return true end end
    self.pointers[id]={hit=hit,x=x,y=y}
    if hit.id=='stick' then self:move(c,x*c.dpr,y*c.dpr,id)
    elseif hit.id=='rewind' then self.spin=true end
    return true
end
function Controls:move(c,x,y,id)
    if id=='mouse'then local h=self:hit(c,x/c.dpr,y/c.dpr);self.hover=h and h.id or false end
    local p=self.pointers[id];if not p then return false end
    if p.hit.id=='stick' then
        local radius=p.hit.w*.32
        local dx=(x/c.dpr-p.hit.x-p.hit.w/2)/radius;local dy=(y/c.dpr-p.hit.y-p.hit.h/2)/radius
        local len=math.sqrt(dx*dx+dy*dy);local scale=math.max(1,len)
        self.x=len*radius<8 and 0 or dx/scale;self.y=len*radius<8 and 0 or dy/scale
    end
    return true
end
function Controls:up(c,x,y,id)
    local p=self.pointers[id];self.pointers[id]=nil
    if not p then return self.context().paused or self.context().covered end
    if p.hit.id=='stick' then self.x=0;self.y=0
    elseif p.hit.id=='rewind' then self.spin=false
    else
        local hit=self:hit(c,x/c.dpr,y/c.dpr)
        if hit and hit.id==p.hit.id and math.abs(x/c.dpr-p.x)+math.abs(y/c.dpr-p.y)<=12 then self.action(hit.id) end
    end
    return true
end
function Controls:attach(c)
    local down,move,up,cancel=c.pointerDown,c.pointerMove,c.pointerUp,c.cancelPointer
    c.pointerDown=function(canvas,x,y,id) if self:down(canvas,x,y,id or 'mouse') then return true end;return down(canvas,x,y,id) end
    c.pointerMove=function(canvas,x,y,id) if self:move(canvas,x,y,id or 'mouse') then return true end;return move(canvas,x,y,id) end
    c.pointerUp=function(canvas,x,y,id) if self:up(canvas,x,y,id or 'mouse') then return true end;return up(canvas,x,y,id) end
    c.cancelPointer=function(canvas) self:cancel();cancel(canvas) end
    c.externalHUD=function(canvas) self:render(canvas) end
    c.touchUI=self.mobile
end
function Controls:render(c)
    local rows,s=self:layout(c);local vg=c.vg
    if not s.movable then self.x=0;self.y=0;self.spin=false end
    if s.paused then
        nvgBeginPath(vg);nvgRect(vg,0,0,c.w,c.h);nvgFillColor(vg,nvgRGBA(12,16,14,158));nvgFill(vg)
        local size=c.w/c.h>=2 and 24 or 36;local w=width(c,'暂停',size,size*.3)
        ink(c,'暂停',(c.w-w)/2+size*.15,rows[1].y-22-Layout.normalHeight(size),size,{240,237,223,255},size*.3)
    end
    for _,r in ipairs(rows) do
        nvgSave(vg)
        if r.disabled then nvgGlobalAlpha(vg,.35)end
        if r.kind=='paper'then
            paper(c,r,self.hover==r.id)
            local y=r.y+(r.h-Layout.normalHeight(r.size))/2
            ink(c,r.text,r.x+r.px+1,y,r.size,INK,r.spacing)
            if r.key then
                local x=r.x+r.px+1+r.labelW+r.keyGap
                local ky=y+math.floor(r.size*.928+.5)-math.floor(12*.928+.5)-2
                nvgBeginPath(vg);nvgRect(vg,x+.5,ky+.5,r.keyW-1,17);nvgStrokeColor(vg,nvgRGBA(16,32,63,255));nvgStrokeWidth(vg,1);nvgStroke(vg)
                ink(c,r.key,x+7,ky+2,12,INK,.96)
            end
        elseif r.kind=='home'then
            c:text(r.text,r.x+(r.w-c:measure(r.text,r.size))/2,r.y+(r.h-Layout.normalHeight(r.size))/2,r.size,INK)
        elseif r.kind=='stick'then
            nvgBeginPath(vg);nvgCircle(vg,r.x+r.w/2,r.y+r.h/2,r.w/2-.5)
            nvgFillColor(vg,nvgRGBA(7,11,22,77));nvgFill(vg);nvgStrokeColor(vg,nvgRGBA(243,241,234,128));nvgStrokeWidth(vg,1);nvgStroke(vg)
            local x=r.x+r.w/2+self.x*r.w*.32;local y=r.y+r.h/2+self.y*r.w*.32
            nvgBeginPath(vg);nvgCircle(vg,x,y,r.knob/2);nvgFillColor(vg,nvgRGBA(243,241,234,204));nvgFill(vg)
            c:text(r.text,x-c:measure(r.text,r.size)/2,y-Layout.normalHeight(r.size)/2,r.size,{23,35,59,255})
        else
            local pressed=false;for _,p in pairs(self.pointers)do if p.hit.id==r.id then pressed=true end end
            nvgBeginPath(vg)
            if r.kind=='tool'then nvgRoundedRect(vg,r.x+.5,r.y+.5,r.w-1,r.h-1,4)
            else nvgEllipse(vg,r.x+r.w/2,r.y+r.h/2,(r.w-1)/2,(r.h-1)/2)end
            nvgFillColor(vg,pressed and nvgRGBA(53,121,241,166)or nvgRGBA(7,11,22,163));nvgFill(vg)
            nvgStrokeColor(vg,nvgRGBA(243,241,234,153));nvgStrokeWidth(vg,1);nvgStroke(vg)
            local small=c.w/c.h>=2 and 9 or 10;local h=Layout.normalHeight(r.size)+(r.id=='rewind'and Layout.normalHeight(small)or 0)
            local y=r.y+(r.h-h)/2
            ink(c,r.text,r.x+(r.w-width(c,r.text,r.size,r.spacing))/2,y,r.size,{243,241,234,255},r.spacing)
            if r.id=='rewind'then ink(c,'按住',r.x+(r.w-width(c,'按住',small,r.spacing))/2,y+Layout.normalHeight(r.size),small,{243,241,234,179},r.spacing)end
        end
        nvgRestore(vg)
    end
end
return Controls
