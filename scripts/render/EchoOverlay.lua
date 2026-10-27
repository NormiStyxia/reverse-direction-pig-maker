-- Raw NVG mode B: logical pixels = physical pixels / DPR, one BeginFrame.
-- Source HUD/title/hint content; font glow and exact title typography still pending.
local StoryCanvas=require('render.StoryOverlay')
local Canvas={}
Canvas.__index=Canvas
Canvas.fontSize=StoryCanvas.fontSize;Canvas.measure=StoryCanvas.measure;Canvas.text=StoryCanvas.text
Canvas.lines=StoryCanvas.lines
Canvas.image=StoryCanvas.image
function Canvas.new(run)
    local self=setmetatable({},Canvas);self:init(run);return self
end
function Canvas:init(run)
    self.ending=require('render.ChapterEnd').new()
    self.run=run;self.vg=nvgCreate(1);self.metrics={};self.images={};self.fontReady=false;self.disposed=false
    self.titleAt=-99;self.hintAt=math.huge;self.hint='';self.elapsed=0;self.seen={};self.loading=false
    self:resize(graphics:GetWidth(),graphics:GetHeight(),graphics:GetDPR())
    cache:GetResourceAsync('Font','fonts/LXGWWenKai-subset.ttf',function(resource)
        if self.disposed then return end
        assert(resource,'ECHO_FONT_LOAD_FAILED')
        self.font=nvgCreateFont(self.vg,'story-wenkai','fonts/LXGWWenKai-subset.ttf');assert(self.font~=-1,'ECHO_FONT_FAILED');self.fontReady=true
    end)
    return self
end
function Canvas:resize(w,h,dpr) self.dpr=math.max(.01,dpr);self.w=w/self.dpr;self.h=h/self.dpr;self:cancelPointer() end
function Canvas:cancelPointer() self.ending:cancel() end
function Canvas:pointerDown(x,y,id) if self.ending.active then self.ending:down(self,x,y,id);return true end end
function Canvas:pointerMove() end
function Canvas:pointerUp(x,y,id) if self.ending.active then self.ending:up(self,x,y,id);return true end end
function Canvas:wheel() end
function Canvas:event(event)
    if event.kind=='loadLevel' then self.hintAt=math.huge;self.titleAt=-99 end
    if event.kind=='levelPlayable' and not self.seen[event.level] then
        self.seen[event.level]=true;self.titleAt=self.elapsed
        self.title='第 '..event.level..' 层 · '..self.run.levels[event.level].name
        self.hint=self.run.levels[event.level].hint or (event.level==1 and 'WASD 移动 · J / 空格 冲撞' or '')
        self.hintAt=self.elapsed+(self.run.levels[event.level].hint and 2.6 or .4)
        self.hintDuration=self.run.levels[event.level].hint and 8 or 2
    end
end
function Canvas:update(dt) self.elapsed=self.elapsed+dt end
function Canvas:exitPointer()
    local r=self.run
    if not self.exitPoint or r.phase~='play' or r.sim.rewinding or not r.sim:exitOn() then return end
    local x,y,behind=self.exitPoint();if not x then return end
    if behind then x=-x;y=-y end
    if not behind and math.abs(x)<.9 and math.abs(y)<.85 then return end
    local k=1/math.max(math.abs(x)/.9,math.abs(y)/.82,.001);x=x*k;y=y*k
    local px,py=(x+1)*self.w/2,(1-y)*self.h/2;local vg=self.vg;local a=math.atan(-y,x)
    nvgSave(vg);nvgTranslate(vg,px,py)
    local size=13*(1+.08*math.sin(self.elapsed*math.pi*2/1.4))
    nvgBeginPath(vg);nvgMoveTo(vg,0,-size);nvgLineTo(vg,size*.16,-size*.16);nvgLineTo(vg,size,0);nvgLineTo(vg,size*.16,size*.16)
    nvgLineTo(vg,0,size);nvgLineTo(vg,-size*.16,size*.16);nvgLineTo(vg,-size,0);nvgLineTo(vg,-size*.16,-size*.16);nvgClosePath(vg)
    nvgFillColor(vg,nvgRGBA(255,210,122,255));nvgFill(vg)
    nvgRotate(vg,a);nvgBeginPath(vg);nvgMoveTo(vg,20,-6);nvgLineTo(vg,30,0);nvgLineTo(vg,20,6);nvgClosePath(vg);nvgFill(vg);nvgRestore(vg)
end
function Canvas:render()
    if self.disposed or not self.fontReady then return end
    local vg=self.vg;nvgBeginFrame(vg,self.w,self.h,self.dpr)
    local light={242,232,214,255}
    if not self.touchUI then self:text('WASD 移动 · J / 空格 冲撞 · 按住 K / Shift 反方向转(倒带) · R 重来这一层 · Esc 暂停',16,self.h-36,(self.w/self.h>=2 or self.w<600)and 12 or 15,light,true) end
    local age=self.elapsed-self.titleAt
    if age>=0 and age<3.2 then
        local opacity=math.min(1,age/.64,(3.2-age)/.96);local size=math.min(46,self.w/13)
        nvgGlobalAlpha(vg,opacity);local width=self:measure(self.title,size)
        self:text(self.title,(self.w-width)/2,self.h*.38-size/2,size,{246,238,223,255},true);nvgGlobalAlpha(vg,1)
    end
    local t=self.elapsed-self.hintAt
    if t>=0 and t<(self.hintDuration or 0) and self.hint~='' then
        require('render.CaptionOverlay').hint(self,self.hint,self.hintDuration-t)
    end
    if self.loading then self:text('正在加载回响…',16,16,16,light,true) end
    if self.run.phase=='done' then self:text('回响结束',16,16,18,light,true) end
    self:exitPointer()
    if self.ending.active then self.ending:render(self) end
    if self.externalHUD then self.externalHUD(self) end
    require('render.TimelinePortal').draw(self)
    nvgEndFrame(vg)
end
function Canvas:dispose() if self.disposed then return end;self.disposed=true;for _,im in pairs(self.images)do if im.id>0 then nvgDeleteImage(self.vg,im.id)end end;nvgDelete(self.vg) end
return Canvas
