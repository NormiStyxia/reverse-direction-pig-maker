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
function Controls:cancel() self.pointers={};self.x=0;self.y=0;self.spin=false end
function Controls:layout(c)
    local s=self.context();local out={}
    local function add(id,text,x,y,w,h) out[#out+1]={id=id,text=text,x=x,y=y,w=w,h=h} end
    if s.paused then
        local w=math.min(190,(c.w-46)/2);local y=c.h/2+12
        add('resume',self.mobile and '继续' or '继续  Esc',c.w/2-w-7,y,w,48)
        add('home',self.mobile and '返回主界面' or '返回主界面  Enter',c.w/2+7,y,w,48)
        return out,s
    end
    if s.ending or s.covered then return out,s end
    add('home','‹',16,16,44,44)
    if s.canSkip then add('skip',self.mobile and '跳过' or '跳过  Esc',c.w-126,16,108,44) end
    if s.echo then
        add('pause',self.mobile and '暂停' or '暂停  Esc',c.w-126,16,108,44)
        if self.mobile then
            add('restart','重来',c.w-214,16,80,44)
            add('charge','冲撞',c.w-100,c.h-92,80,64)
            add('rewind','按住倒带',c.w-200,c.h-92,92,64)
        end
    end
    if self.mobile and s.movable then add('stick','移动',math.min(24,math.max(4,(c.w-312)/2)),c.h-150,112,112) end
    return out,s
end
function Controls:hit(c,x,y)
    local rows=self:layout(c)
    for _,r in ipairs(rows) do if inside(x,y,r) then return r end end
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
    local p=self.pointers[id];if not p then return false end
    if p.hit.id=='stick' then
        local dx=(x/c.dpr-p.hit.x-p.hit.w/2)/44;local dy=(y/c.dpr-p.hit.y-p.hit.h/2)/44
        local len=math.sqrt(dx*dx+dy*dy);local scale=math.max(1,len)
        self.x=len<.12 and 0 or dx/scale;self.y=len<.12 and 0 or dy/scale
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
    if s.paused then
        nvgBeginPath(vg);nvgRect(vg,0,0,c.w,c.h);nvgFillColor(vg,nvgRGBA(12,16,14,158));nvgFill(vg)
        c:text('暂停',(c.w-c:measure('暂停',36))/2,c.h/2-58,36,{240,237,223,255})
    end
    for _,r in ipairs(rows) do
        local stick=r.id=='stick'
        nvgBeginPath(vg);nvgRoundedRect(vg,r.x,r.y,r.w,r.h,stick and 56 or 10)
        nvgFillColor(vg,nvgRGBA(239,228,207,stick and 95 or 235));nvgFill(vg)
        nvgStrokeColor(vg,nvgRGBA(43,33,29,180));nvgStrokeWidth(vg,2);nvgStroke(vg)
        if stick then
            nvgBeginPath(vg);nvgCircle(vg,r.x+56+self.x*36,r.y+56+self.y*36,23)
            nvgFillColor(vg,nvgRGBA(239,228,207,200));nvgFill(vg)
        else c:text(r.text,r.x+(r.w-c:measure(r.text,16))/2,r.y+(r.h-19)/2,16,{43,33,29,255}) end
    end
end
return Controls
