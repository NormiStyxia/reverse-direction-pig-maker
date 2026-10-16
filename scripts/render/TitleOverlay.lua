-- Frozen title CSS in raw NanoVG. No UI widget tree or Yoga layout.
-- Mode A: 2560 x 1152 contain; physical input uses the same transform.
local P=require('game.TitlePresentation')
local Metrics=require('game.data.TitleVectorMetrics')
local Vectors=require('render.TitleVectors')
local Levels=require('game.data.Levels').prologue
local Overlay={}
Overlay.__index=Overlay
local INK={10,60,184,255};local BLUE={1,64,196,255}
local WHITE={255,255,255,255};local PAPER={248,250,253,255}
local NAMES={{'开始游戏','START'},{'继续','CONTINUE'},{'选择关卡','CHAPTERS'},{'设置','OPTIONS'}}
local function color(c,alpha) return nvgRGBA(c[1],c[2],c[3],math.floor(c[4]*(alpha or 1)+.5)) end
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
    self.panelKind=false;self.panelTrack=P.channel(798);self.panelX=798
    self.mirrorTrack=P.channel(1);self.cursorTrack=P.channel(4)
    self.mirror=1
    self.cursorY=4;self.cursorSpinAt=-10;self.lastMenuSel=0
    self.rowTracks={};self.rowAmounts={};self.marginTrack=P.channel(0);self.menuMargin=0
    for i=1,4 do self.rowTracks[i]=P.channel(i==1 and 1 or 0);self.rowAmounts[i]=i==1 and 1 or 0 end
    self.logoX=2560-84-(Metrics.width-10)
    self.logoY=1152-66-31.2-12-26.4-6-146.88
    self.pointerId=false;self.pressTarget=false
    self.lastX=false;self.lastY=false;self.glitchAt=false
    self.disposed=false
    self:resize(graphics:GetWidth(),graphics:GetHeight(),graphics:GetDPR())
end
function Overlay:resize(width,height,dpr)
    -- A minimized window may report zero dimensions.
    self.dpr=math.max(.01,dpr or 1)
    self.logicalW=math.max(1,width)/self.dpr;self.logicalH=math.max(1,height)/self.dpr
    self.scale=math.min(self.logicalW/2560,self.logicalH/1152)
    self.offsetX=(self.logicalW/self.scale-2560)/2
    self.offsetY=(self.logicalH/self.scale-1152)/2
    self:cancelPointer()
end
function Overlay:designPoint(x,y) return x/self.dpr/self.scale-self.offsetX,y/self.dpr/self.scale-self.offsetY end
function Overlay:cancelPointer() self.pointerId=false;self.pressTarget=false;self.lastX=false;self.lastY=false end
function Overlay:menuY(index) return 560+index*66+(index>1 and self.menuMargin or 0) end
function Overlay:hitTest(x,y)
    local title=self.title
    if title.st.phase~='idle' or not inside(x,y,0,0,2560,1152) then return false end
    if title.panel then
        local left=1800+self.panelX
        if inside(x,y,left+80,1068,590,30) then return title.panel..':back' end
        for i=0,title:count()-1 do
            if not title:disabled(i) and inside(x,y,left+80,265+i*69,590,69) then return title.panel..':'..i,i end
        end
    else
        local shift=14*(1-P.slide((title.st.t-self.uiAt)/.9))
        for i=0,3 do
            if not title:disabled(i) and inside(x,y,2328,self:menuY(i)+shift,232,66) then return 'menu:'..i,i end
        end
    end
    return false
end
function Overlay:pointerMove(x,y,id)
    -- A stationary mouse must not override keyboard selection.
    if self.pointerId~=false and self.pointerId~=(id or 'mouse') then return end
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
    if self.title.st.phase=='intro' then self.title:skipIntro();return end
    x,y=self:designPoint(x,y);self.pressTarget=self:hitTest(x,y)
end
function Overlay:pointerUp(x,y,id)
    if self.pointerId~=(id or 'mouse') then return end
    local pressed=self.pressTarget;self.pointerId=false;self.pressTarget=false
    x,y=self:designPoint(x,y)
    local target,index=self:hitTest(x,y)
    if pressed and pressed==target then
        if index then self.title:select(index);self.title:activate(index)
        else self.title:closePanel() end
    end
end
function Overlay:update()
    local title=self.title;local st,v=title.st,title.view;local t=st.t
    if v.uiIn and self.uiAt==math.huge then self.uiAt=t end
    if v.blueprintDrawn and self.blueprintAt==math.huge then self.blueprintAt=t end
    if v.glitch then self.glitchAt=self.glitchAt or t else self.glitchAt=false end
    self.mirror=P.track(self.mirrorTrack,v.held and -1 or 1,t,.45,P.mirror)
    if title.menuSel~=self.lastMenuSel then self.lastMenuSel=title.menuSel;self.cursorSpinAt=t end
    self.menuMargin=P.track(self.marginTrack,title.menuSel==1 and 26 or 0,t,.3,P.ease)
    self.cursorY=P.track(self.cursorTrack,title.menuSel*66+4,t,.35,P.slide)
    for i=1,4 do self.rowAmounts[i]=P.track(self.rowTracks[i],title.menuSel==i-1 and 1 or 0,t,.35,P.slide) end
    if title.panel then self.panelKind=title.panel end
    self.panelX=P.track(self.panelTrack,title.panel and 0 or 798,t,.5,P.slide)
end
function Overlay:drawMenu(alpha)
    local vg,title=self.vg,self.title
    for i,n in ipairs(NAMES) do
        local selected=title.menuSel==i-1;local c=selected and WHITE or INK
        local y=self:menuY(i-1);local amount=self.rowAmounts[i]
        nvgGlobalAlpha(vg,alpha*(i==2 and title.reached==0 and .38 or 1))
        rect(vg,2328+232*(1-amount),y+4,232*amount,58,BLUE)
        text(vg,string.format('%02d',i),2346,y+14,17,c,nil,1.36,nil,selected and .8 or .55)
        text(vg,n[1],2530,y+10,30,c,NVG_ALIGN_RIGHT,3.6,'title-bold')
        text(vg,i==2 and title.reached==0 and 'NO SAVE' or n[2],2530,y+47,14,c,NVG_ALIGN_RIGHT,1.12,nil,.65)
    end
    nvgGlobalAlpha(vg,alpha)
    if title.menuSel==1 and title.reached>0 then
        text(vg,'第 '..title.reached..' 层 · '..Levels[title.reached].name,2530,692,15,INK,NVG_ALIGN_RIGHT,0,nil,.9)
    end
    nvgSave(vg)
    nvgTranslate(vg,2328-70+31,560+self.cursorY+self.pigHeight/2)
    nvgRotate(vg,-2*math.pi*P.mirror((title.st.t-self.cursorSpinAt)/.6))
    nvgBeginPath(vg);nvgRect(vg,-31,-self.pigHeight/2,62,self.pigHeight)
    nvgFillPaint(vg,nvgImagePattern(vg,-31,-self.pigHeight/2,62,self.pigHeight,0,self.pig,1));nvgFill(vg)
    nvgRestore(vg)
end
function Overlay:drawPanel(alpha)
    if not self.panelKind then return end
    local vg,title=self.vg,self.title;local chapters=self.panelKind=='chapters'
    nvgSave(vg);nvgTranslate(vg,1800+self.panelX,0);nvgGlobalAlpha(vg,alpha)
    rect(vg,0,0,760,1152,PAPER,.9);rect(vg,0,0,8,1152,BLUE)
    text(vg,chapters and '选择关卡' or '设置',80,110,64,INK,nil,6.4,'title-bold')
    text(vg,chapters and 'CHAPTERS · 序章 + 6 FLOORS' or 'OPTIONS',80,197,16,INK,nil,1.28,nil,.6)
    for index=0,(chapters and 6 or 3) do
        local disabled=chapters and index>title.reached
        local selected=title.panel==self.panelKind and title.sel==index
        local c=selected and WHITE or INK;local y=265+index*69
        nvgGlobalAlpha(vg,alpha*(disabled and .35 or 1))
        if selected then rect(vg,80,y,590,69,BLUE) end
        rect(vg,80,y+67,590,2,INK,.14)
        local name=chapters and (index==0 and '序章 · 23:38' or Levels[index].name) or ({'画面动态','鼠标视差','声音','返回'})[index+1]
        text(vg,name,chapters and 164 or 98,y+14,32,c,nil,2.56,'title-bold')
        if chapters then text(vg,string.format('%02d',index),98,y+26,18,c,nil,1.44,nil,.6) end
        local note=''
        if chapters then note=index==0 and '公司楼下的便利店' or (index==title.reached and '上次停在这里' or (disabled and '未到达' or ''))
        elseif index<3 then note=({title.opts.motion,title.opts.parallax,not title.opts.muted})[index+1] and '开 ON' or '关 OFF' end
        text(vg,note,652,y+26,15,c,NVG_ALIGN_RIGHT,0,nil,.7)
    end
    nvgGlobalAlpha(vg,alpha);text(vg,'ESC 返回',80,1068,16,INK,nil,0,nil,.7)
    nvgRestore(vg)
end
function Overlay:render()
    if self.disposed then return end
    local vg,title=self.vg,self.title;local st,v=title.st,title.view
    local rootAlpha=st.started and 1-P.ease((st.leaveT-1.1)/.9) or 1
    local uiT=st.t-self.uiAt;local fade=P.ease(uiT/.7)*rootAlpha
    nvgBeginFrame(vg,self.logicalW,self.logicalH,self.dpr)
    nvgScale(vg,self.scale,self.scale);nvgTranslate(vg,self.offsetX,self.offsetY)
    nvgIntersectScissor(vg,0,0,2560,1152);nvgGlobalAlpha(vg,rootAlpha)
    Vectors.dial(vg,title,P.blueprint((st.t-self.blueprintAt)/1.4),rootAlpha)
    nvgSave(vg);nvgGlobalAlpha(vg,fade);nvgTranslate(vg,0,14*(1-P.slide(uiT/.9)))
    text(vg,'TEMPUS',55,590.8,30,INK,nil,2.4)
    text(vg,'REDIT',55,630.4,30,INK,nil,2.4)
    rect(vg,55,681.2,44,4,INK)
    text(vg,v.clockText or 'LAT. 23:38:00',55,703,24,INK,nil,1.92,nil,.85)
    rect(vg,1900,self.logoY-43,576,33,BLUE)
    text(vg,'NOMI × PIG · COUNTERCLOCKWISE',2464,self.logoY-38,19,WHITE,NVG_ALIGN_RIGHT,1.52)
    for _,line in ipairs({{'THE PIG THAT TURNS BACKWARD',self.logoY+152.88,22,1.76,.9},{'猪不会回到过去，但世界会。',1054.8,26,3.64,.92}}) do
        text(vg,line[1],2481,line[2]+5,line[3],BLUE,NVG_ALIGN_RIGHT,line[4],nil,line[5])
        text(vg,line[1],2476,line[2],line[3],WHITE,NVG_ALIGN_RIGHT,line[4],nil,line[5])
    end
    self:drawMenu(fade)
    nvgGlobalAlpha(vg,fade*(v.held and 1 or .75))
    if v.atStart then
        text(vg,'……再往前，',56,1050,24,INK,nil,2.88)
        text(vg,'就回不去了。',56,1090.8,24,INK,nil,2.88)
    else
        text(vg,'按住',56,1066,19,INK)
        nvgBeginPath(vg);nvgRoundedRect(vg,99,1062,32,32,4);nvgStrokeWidth(vg,2);nvgStrokeColor(vg,color(INK));nvgStroke(vg)
        text(vg,'K',115,1066,19,INK,NVG_ALIGN_CENTER)
        text(vg,'倒带',140,1066,19,INK)
        text(vg,'↑↓ 选择 · ENTER 确认',56,1098.3,19,INK)
    end
    nvgRestore(vg)
    nvgSave(vg);nvgGlobalAlpha(vg,rootAlpha)
    local clipped=Metrics.width*(1-P.reveal((uiT-.15)/1.3))
    local jitter,skew=0,0.0
    if self.glitchAt then
        local phase=math.floor(((st.t-self.glitchAt)%.14)/.14*3)+1
        jitter=({-7,5,-2})[phase];skew=phase==2 and -4*math.pi/180 or 0
    end
    nvgTranslate(vg,self.logoX+jitter,self.logoY)
    nvgTranslate(vg,Metrics.width/2,Metrics.height/2);nvgSkewX(vg,skew)
    nvgTranslate(vg,-Metrics.width/2,-Metrics.height/2)
    nvgIntersectScissor(vg,clipped,0,Metrics.width-clipped,Metrics.height)
    Vectors.logo(vg,self.mirror);nvgRestore(vg)
    self:drawPanel(rootAlpha)
    local wash=st.phase=='leaving' and P.ease((st.leaveT-.5)/.6)*rootAlpha or 0
    nvgGlobalAlpha(vg,wash);rect(vg,0,0,2560,1152,PAPER)
    if st.choice then
        local label=st.choice.kind=='new' and '23:38' or ('第 '..(st.choice.level+1)..' 层 · '..Levels[st.choice.level+1].name)
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
