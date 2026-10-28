-- Frozen title CSS in raw NanoVG. No UI widget tree or Yoga layout.
-- Mode A: 2560 x 1152 contain; physical input uses the same transform.
local P=require('game.TitlePresentation')
local Metrics=require('game.data.TitleVectorMetrics')
local Vectors=require('render.TitleVectors')
local Sets=require('game.data.Levels')
local Catalog=require('game.LevelCatalog')
local Compact=require('render.TitleCompact')
local Levels=Sets.prologue
local Overlay={}
Overlay.__index=Overlay
local INK={10,60,184,255};local BLUE={1,64,196,255}
local WHITE={255,255,255,255};local PAPER={248,250,253,255}
local ALT_INK={242,246,255,255}
local function mixColor(a,b,t)
    return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t,255}
end
local NAMES={{'开始游戏','START'},{'继续','CONTINUE'},{'关卡模式','LEVEL MODE'},{'选择关卡','CHAPTERS'},{'设置','OPTIONS'}}
local function color(c,alpha) return nvgRGBA(math.floor(c[1]+.5),math.floor(c[2]+.5),math.floor(c[3]+.5),math.floor(c[4]*(alpha or 1)+.5)) end
local function rect(vg,x,y,w,h,c,alpha)
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h);nvgFillColor(vg,color(c,alpha));nvgFill(vg)
end
local function text(vg,s,x,y,size,c,align,spacing,font,alpha)
    nvgFontFace(vg,font or 'title-sans');nvgFontSize(vg,size)
    nvgTextLetterSpacing(vg,spacing or 0)
    nvgTextAlign(vg,(align or NVG_ALIGN_LEFT)+NVG_ALIGN_TOP)
    nvgFillColor(vg,color(c or INK,alpha));nvgText(vg,x,y,s)
end
local function inside(x,y,l,t,w,h) return x>=l and x<l+w and y>=t and y<t+h end
function Overlay.new(title)
    local self=setmetatable({},Overlay);self:init(title);return self
end
function Overlay:init(title)
    self.title=title
    self.vg=nvgCreate(1);assert(self.vg,'TITLE_NVG_CONTEXT_FAILED')
    assert(nvgCreateFont(self.vg,'title-sans','Fonts/NotoSansSC-Regular.ttf')~=-1,'TITLE_FONT_FAILED')
    assert(nvgCreateFont(self.vg,'title-bold','Fonts/NotoSansSC-Bold.ttf')~=-1,'TITLE_BOLD_FONT_FAILED')
    self.pig=nvgCreateImage(self.vg,'title/pig.png',0);assert(self.pig>0,'TITLE_CURSOR_IMAGE_FAILED')
    local iw,ih=nvgImageSize(self.vg,self.pig);self.pigHeight=62*ih/iw
    self.uiAt=math.huge;self.blueprintAt=math.huge
    self.altTrack=P.channel(0);self.altAmount=0;self.ink=INK;self.pointerHolding=false
    self.panelKind=false;self.panelTrack=P.channel(798);self.panelX=798
    self.mirrorTrack=P.channel(1);self.cursorTrack=P.channel(4)
    self.mirror=1
    self.cursorY=4;self.cursorSpinAt=-10;self.lastMenuSel=0
    self.rowTracks={};self.rowAmounts={};self.marginTrack=P.channel(0);self.menuMargin=0
    for i=1,5 do self.rowTracks[i]=P.channel(i==1 and 1 or 0);self.rowAmounts[i]=i==1 and 1 or 0 end
    self.logoX=2560-84-(Metrics.width-10)
    self.logoY=1152-46-31.2-12-26.4-6-146.88
    self.pointerId=false;self.pressTarget=false
    self.compactScroll=0;self.compactScrollMax=0;self.compactSelection=false;self.dragging=false
    self.lastX=false;self.lastY=false;self.glitchAt=false
    self.disposed=false
    self:resize(graphics:GetWidth(),graphics:GetHeight(),graphics:GetDPR())
end
function Overlay:resize(width,height,dpr)
    -- A minimized window may report zero dimensions.
    local viewport=require('render.UIViewport')
    self.logicalW,self.logicalH,self.dpr=viewport.resolve(width,height,dpr)
    self.touchMode=self.touchMode or viewport.isMobile()
    self.scale=math.min(self.logicalW/2560,self.logicalH/1152)
    self.offsetX=(self.logicalW/self.scale-2560)/2
    self.offsetY=(self.logicalH/self.scale-1152)/2
    self:cancelPointer()
end
function Overlay:designPoint(x,y) return x/self.dpr/self.scale-self.offsetX,y/self.dpr/self.scale-self.offsetY end
function Overlay:cancelPointer()
    if self.pointerHolding then self.title:keyUp('K') end
    self.pointerHolding=false;self.pointerId=false;self.pressTarget=false;self.lastX=false;self.lastY=false
    self.dragging=false
end
function Overlay:menuY(index) return 552+index*56 end
function Overlay:panelRow(index)
    if (self.title.panel or self.panelKind)=='levelmode' then
        local set=Catalog.at(index);local _,group=Catalog.find(set.id)
        return 220+index*38+(group-1)*28,38
    end
    return 265+index*69,69
end
function Overlay:choiceLabel(choice)
    if choice.kind=='new' or choice.kind=='timeline' then return '' end
    local set=Catalog.find(choice.set or 'prologue');local levels=set.levels
    return (choice.kind=='levels' and (set.name..' · ') or '')..'第 '..(choice.level+1)..' 层 · '..levels[choice.level+1].name
end
function Overlay:hitTest(x,y)
    local title=self.title
    if Compact.active(self)then
        if title.st.phase~='idle'then return false end
        return Compact.hit(self,(x+self.offsetX)*self.scale,(y+self.offsetY)*self.scale)
    end
    if title.st.phase~='idle' or not inside(x,y,0,0,2560,1152) then return false end
    if title.panel then
        local left=1800+self.panelX
        if title.panel~='levelmode' and inside(x,y,left+80,1068,590,30) then return title.panel..':back' end
        for i=0,title:count()-1 do
            local rowY,rowH=self:panelRow(i)
            if not title:disabled(i) and inside(x,y,left+80,rowY,590,rowH) then return title.panel..':'..i,i end
        end
    else
        local shift=14*(1-P.slide((title.st.t-self.uiAt)/.9))
        for i=0,4 do
            if not title:disabled(i) and inside(x,y,2328,self:menuY(i)+shift,232,56) then return 'menu:'..i,i end
        end
    end
    return false
end
function Overlay:pointerMove(x,y,id)
    -- A stationary mouse must not override keyboard selection.
    if self.pointerId~=false and self.pointerId~=(id or 'mouse') then return end
    if Compact.active(self)and self.title.panel and self.pointerId~=false then
        local yy=y/self.dpr
        if math.abs(yy-self.dragStart)>6 then self.dragging=true;self.pressTarget=false end
        if self.dragging then self.compactScroll=math.max(0,math.min(self.compactScrollMax,self.compactScroll+self.dragLast-yy))end
        self.dragLast=yy;return
    end
    if self.lastX==x and self.lastY==y then return end
    self.lastX=x;self.lastY=y
    x,y=self:designPoint(x,y)
    self.title:pointer(x/1280-1,y/576-1)
    local target,index=self:hitTest(x,y)
    if target and index then self.title:select(index) end
end
function Overlay:pointerDown(x,y,id)
    if self.pointerId~=false then return end
    self:pointerMove(x,y,id)
    self.pointerId=id or 'mouse';self.pressTarget=false
    self.dragging=false;self.dragStart=y/self.dpr;self.dragLast=self.dragStart
    if self.title.st.phase=='intro' then self.title:skipIntro();return end
    x,y=self:designPoint(x,y);self.pressTarget=self:hitTest(x,y)
    -- The whole panel (and disabled menu buttons) consumes a press, not just active rows.
    local panelHit=self.panelKind and inside(x,y,1800+self.panelX,0,760,1152)
    local buttonHit=Compact.active(self)and self.pressTarget
    if Compact.active(self)and not self.title.panel then
        local fx,fy,fw,fh=Compact.frame(self)
        buttonHit=inside((x+self.offsetX)*self.scale,(y+self.offsetY)*self.scale,fx+fw-132,fy+fh/2-110,132,220)
    end
    if not self.title.panel then
        local shift=14*(1-P.slide((self.title.st.t-self.uiAt)/.9))
        for i=0,4 do buttonHit=buttonHit or inside(x,y,2328,self:menuY(i)+shift,232,56) end
    end
    if self.title.st.phase=='idle' and not self.pressTarget and not (self.touchMode and self.title.panel) and not panelHit and not buttonHit and inside(x,y,0,0,2560,1152) then
        self.pointerHolding=true;self.title:keyDown('K',false)
    end
end
function Overlay:wheel(delta)
    if Compact.active(self)and self.title.panel then self.compactScroll=math.max(0,math.min(self.compactScrollMax,self.compactScroll-delta*44))end
end
function Overlay:pointerUp(x,y,id)
    if self.pointerId~=(id or 'mouse') then return end
    local pressed=self.pressTarget
    if self.pointerHolding then self.title:keyUp('K') end
    self.pointerHolding=false;self.pointerId=false;self.pressTarget=false
    x,y=self:designPoint(x,y)
    local target,index=self:hitTest(x,y)
    if pressed and pressed==target then
        if index then self.title:select(index);self.title:activate(index)
        else self.title:closePanel() end
    end
end
function Overlay:update()
    local title=self.title;local st,v=title.st,title.view;local t=st.t
    self.altAmount=P.track(self.altTrack,v.alt and 1 or 0,t,.3,P.ease)
    self.ink=mixColor(INK,ALT_INK,self.altAmount)
    if v.uiIn and self.uiAt==math.huge then self.uiAt=t end
    if v.blueprintDrawn and self.blueprintAt==math.huge then self.blueprintAt=t end
    if v.glitch then self.glitchAt=self.glitchAt or t else self.glitchAt=false end
    self.mirror=P.track(self.mirrorTrack,v.held and -1 or 1,t,.45,P.mirror)
    if title.menuSel~=self.lastMenuSel then self.lastMenuSel=title.menuSel;self.cursorSpinAt=t end
    self.menuMargin=P.track(self.marginTrack,0,t,.3,P.ease)
    self.cursorY=P.track(self.cursorTrack,title.menuSel*56+4,t,.35,P.slide)
    for i=1,5 do self.rowAmounts[i]=P.track(self.rowTracks[i],title.menuSel==i-1 and 1 or 0,t,.35,P.slide) end
    if title.panel then
        if self.panelKind~=title.panel then self.compactScroll=0;self.compactSelection=false end
        self.panelKind=title.panel
    end
    self.panelX=P.track(self.panelTrack,title.panel and 0 or 798,t,.5,P.slide)
end
function Overlay:drawMenu(alpha)
    if Compact.active(self)then return end
    local vg,title=self.vg,self.title
    for i,n in ipairs(NAMES) do
        local selected=title.menuSel==i-1;local c=selected and mixColor(WHITE,BLUE,self.altAmount) or self.ink
        local y=self:menuY(i-1);local amount=self.rowAmounts[i]
        nvgGlobalAlpha(vg,alpha*(title:disabled(i-1) and .38 or 1))
        rect(vg,2328+232*(1-amount),y+4,232*amount,48,title.view.alt and PAPER or BLUE)
        text(vg,string.format('%02d',i),2346,y+12,17,c,nil,1.36,nil,selected and .8 or .55)
        text(vg,n[1],2530,y+7,28,c,NVG_ALIGN_RIGHT,3.6,'title-bold')
        text(vg,i==2 and not title.latest and title.reached==0 and 'NO SAVE' or n[2],2530,y+40,14,c,NVG_ALIGN_RIGHT,1.12,nil,.65)
    end
    nvgGlobalAlpha(vg,alpha)
    if title.menuSel==1 and (title.latest or title.reached>0) then
        local label=''
        if title.latest then for _,n in ipairs(require('game.data.TimelineNodes'))do if n.id==title.latest then label=n.time..' · '..n.place end end
        elseif title.reached>0 then label='第 '..title.reached..' 层 · '..Levels[title.reached].name end
        nvgFontFace(vg,'title-sans');nvgFontSize(vg,15);nvgTextLetterSpacing(vg,0)
        local w=nvgTextBounds(vg,0,0,label)+20
        rect(vg,2316-w,622,w,26,title.view.alt and PAPER or BLUE)
        text(vg,label,2306,626,15,title.view.alt and BLUE or WHITE,NVG_ALIGN_RIGHT)
    end
    nvgSave(vg)
    nvgTranslate(vg,2328-70+31,552+self.cursorY+self.pigHeight/2)
    nvgRotate(vg,-2*math.pi*P.mirror((title.st.t-self.cursorSpinAt)/.6))
    nvgBeginPath(vg);nvgRect(vg,-31,-self.pigHeight/2,62,self.pigHeight)
    nvgFillPaint(vg,nvgImagePattern(vg,-31,-self.pigHeight/2,62,self.pigHeight,0,self.pig,1));nvgFill(vg)
    nvgRestore(vg)
end
function Overlay:drawPanel(alpha)
    if Compact.active(self)then return end
    if not self.panelKind then return end
    local vg,title=self.vg,self.title;local chapters=self.panelKind=='chapters'
    local mode=self.panelKind=='levelmode'
    nvgSave(vg);nvgTranslate(vg,1800+self.panelX,0);nvgGlobalAlpha(vg,alpha)
    rect(vg,0,0,760,1152,PAPER,.9);rect(vg,0,0,8,1152,BLUE)
    text(vg,mode and '关卡模式' or (chapters and '选择关卡' or '设置'),80,mode and 80 or 110,mode and 56 or 64,INK,nil,6.4,'title-bold')
    text(vg,mode and 'LEVEL MODE · 不走剧情，一路打下去 · ESC 返回' or (chapters and 'CHAPTERS · 序章 + 6 FLOORS' or 'OPTIONS'),80,mode and 153 or 197,16,INK,nil,1.28,nil,.6)
    if mode then
        local index=0
        for _,set in ipairs(Catalog) do
            local y=self:panelRow(index);text(vg,set.name..'回响',98,y-23,15,INK,nil,0,nil,.6);index=index+#set.levels
        end
    end
    for index=0,(mode and Catalog.count()-1 or (chapters and 6 or 3)) do
        local disabled=chapters and index>title.reached
        local selected=title.panel==self.panelKind and title.sel==index
        local c=selected and WHITE or INK;local y,rh=self:panelRow(index)
        nvgGlobalAlpha(vg,alpha*(disabled and .35 or 1))
        if selected then rect(vg,80,y,590,rh,BLUE) end
        rect(vg,80,y+rh-2,590,2,INK,.14)
        local set,floor=Catalog.at(index)
        local name=mode and set.levels[floor+1].name or chapters and (index==0 and '序章 · 23:38' or Levels[index].name) or ({'画面动态','鼠标视差','声音','返回'})[index+1]
        text(vg,name,(chapters or mode) and 164 or 98,y+(mode and 6 or 14),mode and 26 or 32,c,nil,2.56,'title-bold')
        if mode then text(vg,string.format('%02d',floor+1),98,y+10,18,c,nil,0,nil,.6)
        elseif chapters then text(vg,string.format('%02d',index),98,y+26,18,c,nil,1.44,nil,.6) end
        local note=''
        if chapters then note=index==0 and '公司楼下的便利店' or (index==title.reached and '上次停在这里' or (disabled and '未到达' or ''))
        elseif not mode and index<3 then note=({title.opts.motion,title.opts.parallax,not title.opts.muted})[index+1] and '开 ON' or '关 OFF' end
        text(vg,note,652,y+26,15,c,NVG_ALIGN_RIGHT,0,nil,.7)
    end
    nvgGlobalAlpha(vg,alpha);if not mode then text(vg,'ESC 返回',80,1068,16,INK,nil,0,nil,.7) end
    nvgRestore(vg)
end
function Overlay:renderBridge()
    -- onStart fires while the title is paper-white. Retain that cover during
    -- native resource loading, then fade it with the original root opacity.
    local vg,st=self.vg,self.title.st
    local alpha=1-P.ease((st.leaveT-1.1)/.9)
    nvgBeginFrame(vg,self.logicalW,self.logicalH,self.dpr)
    nvgGlobalAlpha(vg,alpha);rect(vg,0,0,self.logicalW,self.logicalH,BLUE)
    nvgScale(vg,self.scale,self.scale);nvgTranslate(vg,self.offsetX,self.offsetY)
    nvgIntersectScissor(vg,0,0,2560,1152);rect(vg,0,0,2560,1152,PAPER)
    local choice=st.choice
    if choice then
        local label=self:choiceLabel(choice)
        text(vg,label,1280,553,46,INK,NVG_ALIGN_CENTER,13.8)
    end
    nvgEndFrame(vg)
end
function Overlay:render()
    if self.disposed then return end
    local vg,title=self.vg,self.title;local st,v=title.st,title.view
    local rootAlpha=st.started and 1-P.ease((st.leaveT-1.1)/.9) or 1
    local uiT=st.t-self.uiAt;local fade=P.ease(uiT/.7)*rootAlpha
    local compact=Compact.active(self);local titleShift=compact and(84-148/self.scale)or 0
    nvgBeginFrame(vg,self.logicalW,self.logicalH,self.dpr)
    nvgScale(vg,self.scale,self.scale);nvgTranslate(vg,self.offsetX,self.offsetY)
    nvgIntersectScissor(vg,0,0,2560,1152);nvgGlobalAlpha(vg,rootAlpha)
    Vectors.dial(vg,title,P.blueprint((st.t-self.blueprintAt)/1.4),rootAlpha)
    nvgSave(vg);nvgGlobalAlpha(vg,fade);nvgTranslate(vg,0,14*(1-P.slide(uiT/.9)))
    text(vg,'TEMPUS',55,590.8,30,self.ink,nil,2.4)
    text(vg,'REDIT',55,630.4,30,self.ink,nil,2.4)
    rect(vg,55,681.2,44,4,self.ink)
    text(vg,v.clockText or 'LAT. 23:38:00',55,703,24,self.ink,nil,1.92,nil,.85)
    rect(vg,1900+titleShift,self.logoY-43,576,33,BLUE)
    text(vg,'NOMI × PIG · COUNTERCLOCKWISE',2464+titleShift,self.logoY-38,19,WHITE,NVG_ALIGN_RIGHT,1.52)
    for _,line in ipairs({{'THE PIG THAT TURNS BACKWARD',self.logoY+152.88,22,1.76,.9},{'猪不会回到过去，但世界会。',1074.8,26,3.64,.92}}) do
        text(vg,line[1],2481+titleShift,line[2]+5,line[3],BLUE,NVG_ALIGN_RIGHT,line[4],nil,line[5])
        text(vg,line[1],2476+titleShift,line[2],line[3],WHITE,NVG_ALIGN_RIGHT,line[4],nil,line[5])
    end
    self:drawMenu(fade)
    nvgGlobalAlpha(vg,fade*(v.held and 1 or .75))
    if compact then
        nvgSave(vg);nvgResetTransform(vg);nvgResetScissor(vg)
        local fx,fy,_,fh=Compact.frame(self);local bottom=fy+fh-24*self.scale
        text(vg,v.atStart and'……再往前，'or self.touchMode and'长按画面倒带'or'按住 K 倒带',fx+16,bottom-34,10,self.ink)
        text(vg,v.atStart and'就回不去了。'or self.touchMode and'点菜单选择'or'↑↓ 选择 · ENTER 确认',fx+16,bottom-17,10,self.ink)
        nvgRestore(vg)
    elseif v.atStart then
        text(vg,'……再往前，',56,1050,24,self.ink,nil,2.88)
        text(vg,'就回不去了。',56,1090.8,24,self.ink,nil,2.88)
    elseif self.touchMode then
        text(vg,'长按画面倒带',56,1066,19,self.ink)
        text(vg,'点菜单选择',56,1098.3,19,self.ink)
    else
        text(vg,'按住',56,1066,19,self.ink)
        nvgBeginPath(vg);nvgRoundedRect(vg,99,1062,32,32,4);nvgStrokeWidth(vg,2);nvgStrokeColor(vg,color(self.ink));nvgStroke(vg)
        text(vg,'K',115,1066,19,self.ink,NVG_ALIGN_CENTER)
        text(vg,'倒带',140,1066,19,self.ink)
        text(vg,'↑↓ 选择 · ENTER 确认',56,1098.3,19,self.ink)
    end
    nvgRestore(vg)
    nvgSave(vg);nvgGlobalAlpha(vg,rootAlpha)
    local clipped=Metrics.width*(1-P.reveal((uiT-.15)/1.3))
    local jitter,skew=0,0.0
    if self.glitchAt then
        local phase=math.floor(((st.t-self.glitchAt)%.14)/.14*3)+1
        jitter=({-7,5,-2})[phase];skew=phase==2 and -4*math.pi/180 or 0
    end
    nvgTranslate(vg,self.logoX+titleShift+jitter,self.logoY)
    nvgTranslate(vg,Metrics.width/2,Metrics.height/2);nvgSkewX(vg,skew)
    nvgTranslate(vg,-Metrics.width/2,-Metrics.height/2)
    nvgIntersectScissor(vg,clipped,0,Metrics.width-clipped,Metrics.height)
    Vectors.logo(vg,self.mirror);nvgRestore(vg)
    self:drawPanel(rootAlpha)
    if compact then Compact.draw(self,fade,text,rect,NAMES,PAPER,BLUE,INK,WHITE)end
    if title.saveStatus and title.saveStatus~='ready' and st.phase=='idle' then
        local message=title.saveStatus=='loading' and '正在读取进度…' or title.saveStatus=='saving' and '正在保存进度…' or '暂未连上存档，刷新前请等待保存'
        nvgSave(vg);nvgResetTransform(vg);nvgResetScissor(vg);nvgGlobalAlpha(vg,fade)
        rect(vg,12,12,math.min(self.logicalW-24,260),30,PAPER,.95)
        text(vg,message,20,20,12,INK);nvgRestore(vg)
    end
    local wash=st.phase=='leaving' and P.ease((st.leaveT-.5)/.6)*rootAlpha or 0
    nvgGlobalAlpha(vg,wash);rect(vg,0,0,2560,1152,PAPER)
    if st.choice then
        local label=self:choiceLabel(st.choice)
        text(vg,label,1280,553,46,INK,NVG_ALIGN_CENTER,13.8)
    end
    nvgEndFrame(vg)
end
function Overlay:dispose()
    if self.disposed then return end
    self:cancelPointer()
    nvgDeleteImage(self.vg,self.pig);nvgDelete(self.vg);self.disposed=true
end
return Overlay
