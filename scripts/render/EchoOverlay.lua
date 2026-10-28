-- Raw NVG mode B: logical pixels = physical pixels / DPR, one BeginFrame.
-- Frozen HUD typography, proximity crate labels and native input overlay.
local StoryCanvas=require('render.StoryOverlay')
local Caption=require('render.CaptionOverlay')
local Layout=require('game.StoryPanelLayout')
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
    self.titleAt=-99;self.hintAt=math.huge;self.hint='';self.elapsed=0;self.seen={};self.loading=true;self.loadingAlpha=1
    self:resize(graphics:GetWidth(),graphics:GetHeight(),graphics:GetDPR())
    cache:GetResourceAsync('Font','fonts/LXGWWenKai-subset.ttf',function(resource)
        if self.disposed then return end
        assert(resource,'ECHO_FONT_LOAD_FAILED')
        self.font=nvgCreateFont(self.vg,'story-wenkai','fonts/LXGWWenKai-subset.ttf');assert(self.font~=-1,'ECHO_FONT_FAILED');self.fontReady=true
    end)
    return self
end
function Canvas:resize(w,h,dpr)
    local viewport=require('render.UIViewport')
    self.w,self.h,self.dpr=viewport.resolve(w,h,dpr)
    self.touchUI=self.touchUI or viewport.isMobile()
    self:cancelPointer()
end
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
function Canvas:update(dt)
    self.elapsed=self.elapsed+dt
    if self.tagLoad~=self.run.loadId then self.tagLoad=self.run.loadId;self.tags={}end
    if self.run.theme=='store'then return end
    local live={};local p=self.run.pig.pos
    for _,crate in ipairs(self.run.sim.room.crates)do
        local k=self.tags[crate]or 0
        local near=self.run.phase=='play'and ((p.x-crate.x)^2+(p.z-crate.z)^2)<2.4^2
        live[crate]=k+((near and 1 or 0)-k)*math.min(1,dt*8)
    end
    self.tags=live
end
function Canvas:crateTags()
    if not self.projectTag or self.run.theme=='store'then return end
    local T=require('game.data.Story03Data').TONIGHT
    local branch=T[self.run.answer]or T.same
    for _,crate in ipairs(self.run.sim.room.crates)do
        local opacity=self.tags and self.tags[crate]or 0
        if opacity>=.01 then
            local labels=crate.origin=='b'and {
                past={'下午 · 关联案','老陈那份关联案 · 下午 14:47'},tonight={'今晚 · 关联案','老陈那份关联案 · 便利贴：今晚一起交'},now={'现在 · 关联案','老陈那份关联案 · 定了'}
            }or {past={'下午','策划案 v6 · 下午 14:47'},tonight={'今晚 · 投影',branch.tag},now={'现在',branch.now},plain={'','一筐别的资料'},bag={'今晚 · 投影','外卖 · 还没拆'},parcel={'','闪送 · 包邮到家'}}
            local label=labels[crate.kind];local px,py=self.projectTag(crate)
            if label and px then
                local size=17;local spacing=size*.06;local badge=label[1]~='';local bw=badge and Caption.width(self,label[1],15,spacing)+12 or 0
                local tw=Caption.width(self,label[2],size,spacing);local w=tw+bw+(badge and 8 or 0)+30;local h=Layout.normalHeight(size)+12
                local x=px*self.w-w/2;local y=py*self.h-h+(1-opacity)*8;local vg=self.vg
                nvgSave(vg);nvgGlobalAlpha(vg,opacity);Caption.band(self,x,y,w,h)
                local tx=x+15
                if badge then
                    local color=crate.kind=='now'and {211,154,36,255}or(crate.kind=='tonight'or crate.kind=='bag')and {35,168,151,255}or {198,156,109,255}
                    local by=y+6+math.floor(size*.928+.5)-math.floor(15*.928+.5)
                    nvgBeginPath(vg);nvgRect(vg,tx,by,bw,Layout.normalHeight(15));nvgFillColor(vg,nvgRGBA(table.unpack(color)));nvgFill(vg)
                    Caption.ink(self,label[1],tx+6,by,15,{255,248,234,255},spacing);tx=tx+bw+8
                end
                Caption.ink(self,label[2],tx,y+6,size,{16,32,63,255},spacing);nvgRestore(vg)
            end
        end
    end
end
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
    if self.disposed then return end
    if not self.fontReady then nvgBeginFrame(self.vg,self.w,self.h,self.dpr);Caption.drawLoading(self);nvgEndFrame(self.vg);return end
    local vg=self.vg;nvgBeginFrame(vg,self.w,self.h,self.dpr)
    if self.finale then Caption.drawLoading(self);nvgEndFrame(vg);return end
    local light={242,232,214,255}
    require('render.DialogOverlay').draw(self,self.run,'background')
    if not self.touchUI then self:text('WASD 移动 · J / 空格 冲撞 · 按住 K / Shift 反方向转(倒带) · R 重来这一层 · Esc 暂停',16,self.h-36,(self.w/self.h>=2 or self.w<600)and 12 or 15,light,true) end
    local age=self.elapsed-self.titleAt
    if age>=0 and age<3.2 then
        local opacity=math.min(1,age/.64,(3.2-age)/.96);local size=math.min(46,self.w/13)
        nvgGlobalAlpha(vg,opacity);local spacing=size*.25;local width=Caption.width(self,self.title,size,spacing)
        Caption.ink(self,self.title,(self.w-width)/2,self.h*.38-Layout.normalHeight(size)/2,size,{246,238,223,255},spacing,'dark');nvgGlobalAlpha(vg,1)
    end
    local t=self.elapsed-self.hintAt
    if self.run.phase=='done' then self:text('回响结束',16,16,18,light,true) end
    if self.top then self.top:render(self)end
    if not self.top or (self.top.view.topK or 0)<.5 then self:crateTags()end
    self:exitPointer()
    if self.ending.active then self.ending:render(self) end
    require('render.DialogOverlay').draw(self,self.run,'foreground')
    if self.externalHUD then self.externalHUD(self) end
    require('render.TimelinePortal').draw(self)
    if self.card then self.card:render(self)end
    Caption.drawLoading(self)
    nvgEndFrame(vg)
end
function Canvas:dispose() if self.disposed then return end;self.disposed=true;for _,im in pairs(self.images)do if im.id>0 then nvgDeleteImage(self.vg,im.id)end end;nvgDelete(self.vg) end
return Canvas
