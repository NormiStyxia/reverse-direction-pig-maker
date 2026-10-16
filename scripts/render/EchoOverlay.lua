-- Raw NVG mode B: logical pixels = physical pixels / DPR, one BeginFrame.
-- Source HUD/title/hint content; font glow and exact title typography still pending.
local StoryCanvas=require('render.StoryOverlay')
local Canvas={}
Canvas.__index=Canvas
Canvas.fontSize=StoryCanvas.fontSize;Canvas.measure=StoryCanvas.measure;Canvas.text=StoryCanvas.text
function Canvas.new(run)
    local self=setmetatable({},Canvas);self:init(run);return self
end
function Canvas:init(run)
    self.run=run;self.vg=nvgCreate(1);self.metrics={};self.fontReady=false;self.disposed=false
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
function Canvas:cancelPointer() end
function Canvas:pointerDown() end
function Canvas:pointerMove() end
function Canvas:pointerUp() end
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
function Canvas:render()
    if self.disposed or not self.fontReady then return end
    local vg=self.vg;nvgBeginFrame(vg,self.w,self.h,self.dpr)
    local light={242,232,214,255}
    self:text('WASD 移动 · J / 空格 冲撞 · 按住 K / Shift 反方向转(倒带) · R 重来这一层',16,self.h-36,self.w<600 and 12 or 15,light,true)
    local age=self.elapsed-self.titleAt
    if age>=0 and age<3.2 then
        local opacity=math.min(1,age/.64,(3.2-age)/.96);local size=math.min(46,self.w/13)
        nvgGlobalAlpha(vg,opacity);local width=self:measure(self.title,size)
        self:text(self.title,(self.w-width)/2,self.h*.38-size/2,size,{246,238,223,255},true);nvgGlobalAlpha(vg,1)
    end
    local t=self.elapsed-self.hintAt
    if t>=0 and t<(self.hintDuration or 0) and self.hint~='' then
        local size=self.w<600 and 14 or 16;local width=self:measure(self.hint,size);local x=(self.w-width-28)/2;local y=self.w<600 and 46 or 18
        nvgBeginPath(vg);nvgRoundedRect(vg,x,y,width+28,size+16,12);nvgFillColor(vg,nvgRGBA(239,228,207,235));nvgFill(vg)
        nvgStrokeColor(vg,nvgRGBA(43,33,29,255));nvgStrokeWidth(vg,2);nvgStroke(vg)
        self:text(self.hint,x+14,y+7,size,{43,33,29,255})
    end
    if self.loading then self:text('正在加载回响…',16,16,16,light,true) end
    if self.run.phase=='done' then self:text('回响结束',16,16,18,light,true) end
    nvgEndFrame(vg)
end
function Canvas:dispose() if self.disposed then return end;self.disposed=true;nvgDelete(self.vg) end
return Canvas
