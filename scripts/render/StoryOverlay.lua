-- Native NVG phone and browsing panels. Source styling: frozen style.css/phone.js/browse.js.
-- Full-screen logical-pixel layout (mode B), unlike the fixed-size title.
local Layout=require('game.StoryPanelLayout')
local Motion=require('game.StoryPanelMotion')
local Extras=require('render.PhoneExtras')
local Canvas={}
Canvas.__index=Canvas
local INK={41,58,48,255};local LIGHT={240,237,223,255};local GREEN={175,225,135,255}
local WHITE={255,255,248,242};local CHOICE={243,250,234,204};local MUTED={143,154,137,255}
local function rgba(c) return nvgRGBA(c[1],c[2],c[3],c[4] or 255) end
local function inside(x,y,r) return x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end
-- The frozen font lacks these two Unicode vertical bars. Draw their actual
-- shapes instead of platform-dependent missing-glyph boxes; keep all other
-- characters in the frozen face and share advances with wrapping/hit layout.
local function symbolRuns(text,visit)
    local from=1
    for i,code in utf8.codes(text)do
        if code==0x25AF or code==0x25AE then
            if i>from then visit(text:sub(from,i-1),false)end
            local ch=utf8.char(code);visit(ch,true);from=i+#ch
        end
    end
    if from<=#text then visit(text:sub(from),false)end
end
local function hasBars(text)return text:find('▯',1,true) or text:find('▮',1,true)end
local function box(vg,x,y,w,h,c,r)
    nvgBeginPath(vg);nvgRoundedRect(vg,x,y,math.max(0,w),math.max(0,h),r or 0);nvgFillColor(vg,rgba(c));nvgFill(vg)
end
function Canvas.new(story)
    local self=setmetatable({},Canvas);self:init(story);return self
end
function Canvas:init(story)
    self.story=story;self.vg=nvgCreate(1);assert(self.vg,'STORY_NVG_CONTEXT_FAILED')
    self.font=-1;self.fontReady=false
    self.images={};self.metrics={};self.hits={};self.disposed=false
    self.placement={layoutSide=false,frostEdge=.5};self.actorLeft=.2;self.actorRight=.4
    self.channel=false;self.lastView=false;self.wasOpen=false;self.lastDraft='';self.typeFrom=0;self.typed='';self.ready=false
    self.arrivals={};self.browseArrivals={};self.browseFirst=false;self.elapsed=0;self.lastCount=0;self.lastBrowseCount=0
    self.scroll={phone=0,browse=0};self.maxScroll=0;self.scrollBottom=false;self.thread=false
    self.pointerId=false;self.press=false;self.dragged=false;self.pointerY=0;self.startX=0;self.startY=0
    self.probeBackdrop=false
    self.sceneBackdrop=false
    self.sceneHUD=false
    self.sceneActions=false
    self:resize(graphics:GetWidth(),graphics:GetHeight(),graphics:GetDPR())
    -- Never cache metrics from DWP's temporary font. The native NVG handle
    -- must be created only after the frozen face is available.
    cache:GetResourceAsync('Font','fonts/LXGWWenKai-subset.ttf',function(resource)
        if self.disposed then return end
        assert(resource,'STORY_FONT_DOWNLOAD_FAILED')
        self.font=nvgCreateFont(self.vg,'story-wenkai','fonts/LXGWWenKai-subset.ttf')
        assert(self.font~=-1,'STORY_FONT_FAILED');self.fontReady=true;self.metrics={}
        print('STORY_FONT_READY: digit '..self:measure('1',20)..'; first message '..self:measure('第 14 页再顺一下，明早九点前发我就行',20))
    end)
end
function Canvas:resize(w,h,dpr)
    self.dpr=math.max(.01,dpr or 1);self.w=math.max(1,w)/self.dpr;self.h=math.max(1,h)/self.dpr
    self:cancelPointer();self.scrollBottom=true
end
function Canvas:place(left,right) self.actorLeft=left;self.actorRight=right end
function Canvas:cancelPointer()
    self.pointerId=false;self.press=false;self.dragged=false;self.scrollTarget=false
    if self.sceneActions then self.sceneActions:cancel() end
end
function Canvas:fontSize(size)
    nvgFontFace(self.vg,'story-wenkai');nvgFontSize(self.vg,size);nvgTextLetterSpacing(self.vg,0);nvgTextAlign(self.vg,NVG_ALIGN_LEFT+NVG_ALIGN_TOP)
end
function Canvas:measure(text,size)
    assert(self.fontReady,'STORY_FONT_NOT_READY')
    local key=size..':'..text
    if not self.metrics[key] then
        -- Dream chat changes glyphs every 70ms. Bound cached measurements so
        -- reading it for a long time cannot retain every generated string.
        self.metricCount=(self.metricCount or 0)+1
        if self.metricCount>4096 then self.metrics={};self.metricCount=1 end
        self:fontSize(size)
        if hasBars(text)then
            local width=0;symbolRuns(text,function(run,bar)width=width+(bar and size*.6 or nvgTextBounds(self.vg,0,0,run))end);self.metrics[key]=width
        else self.metrics[key]=nvgTextBounds(self.vg,0,0,text)end
    end
    return self.metrics[key]
end
function Canvas:text(text,x,y,size,c,shadow)
    self:fontSize(size)
    if self.story and self.story.mode=='dream' then
        if c==LIGHT then c={1,64,196,255}elseif c==INK then c={11,29,79,255}elseif c==MUTED then c={53,121,241,255}end
    end
    local function draw(yy,color)
        nvgFillColor(self.vg,color)
        if not hasBars(text)then nvgText(self.vg,x,yy,text);return end
        local sx=x
        symbolRuns(text,function(run,bar)
            if bar then
                nvgBeginPath(self.vg);nvgRect(self.vg,sx+size*.13,yy+size*.12,size*.34,size*.8)
                if run=='▮'then nvgFill(self.vg)else nvgStrokeColor(self.vg,color);nvgStrokeWidth(self.vg,math.max(.7,size*.055));nvgStroke(self.vg)end
                sx=sx+size*.6
            else nvgText(self.vg,sx,yy,run);sx=sx+nvgTextBounds(self.vg,0,0,run)end
        end)
    end
    if shadow then draw(y+1,self.story and self.story.mode=='dream' and nvgRGBA(250,252,255,230) or nvgRGBA(15,31,12,220))end
    draw(y,rgba(c or INK))
end
function Canvas:lines(lines,x,y,size,lineH,c,shadow)
    for i,line in ipairs(lines) do self:text(line,x,y+(i-1)*lineH+(lineH-Layout.normalHeight(size))/2,size,c,shadow) end
end
function Canvas:image(path,x,y,w,h,cover)
    path=path:gsub('^%./assets/',''):gsub('^assets/','')
    local im=self.images[path]
    if not im then
        im={id=0,w=1,h=1};self.images[path]=im
        cache:GetResourceAsync('Texture2D',path,function(resource)
            if self.disposed then return end
            assert(resource,'STORY_IMAGE_DOWNLOAD_FAILED: '..path)
            local texture=resource --[[@as Texture2D]]
            texture:SetFilterMode(FILTER_TRILINEAR)
            local handle=nvgCreateImage(self.vg,path,NVG_IMAGE_GENERATE_MIPMAPS);assert(handle>0,'STORY_IMAGE_FAILED: '..path)
            local iw,ih=nvgImageSize(self.vg,handle);im.id=handle;im.w=iw;im.h=ih
        end)
    end
    if im.id==0 then return end
    local k=cover and math.max(w/im.w,h/im.h) or math.min(w/im.w,h/im.h)
    local dw,dh=im.w*k,im.h*k
    nvgSave(self.vg);nvgIntersectScissor(self.vg,x,y,w,h)
    nvgBeginPath(self.vg)
    if cover=='circle' then nvgCircle(self.vg,x+w/2,y+h/2,math.min(w,h)/2)
    else nvgRoundedRect(self.vg,x,y,w,h,cover and 5 or 0) end
    nvgFillPaint(self.vg,nvgImagePattern(self.vg,x+(w-dw)/2,y+(h-dh)/2,dw,dh,0,im.id,1));nvgFill(self.vg);nvgRestore(self.vg)
end
function Canvas:update(dt)
    self.elapsed=self.elapsed+dt
    local p,b=self.story.phone,self.story.browse
    if self.pointerId and self.press and self.press.message and not self.dragged and not self.longPressed and self.elapsed-(self.pressAt or self.elapsed)>=.45 then
        Extras.action(self,self.press.id);self.longPressed=true
    end
    local channel=b.k>=.02 and 'browse' or (p.k>=.02 and 'phone' or false)
    if channel~=self.channel then self:cancelPointer();Extras.reset(self);self.channel=channel;self.scrollBottom=true end
    if not p.open or p.view~='chat' then Extras.reset(self)end
    if p.open and not self.wasOpen then self.placement.layoutSide=false;self.lastView=false end
    self.wasOpen=p.open
    Layout.placePhone(self.placement,self.actorLeft,self.actorRight);b:place(self.actorLeft,self.actorRight)
    if p.draft~=self.lastDraft then self.lastDraft=p.draft;self.typeFrom=p.elapsed end
    local count=math.min(utf8.len(p.draft),math.floor((p.elapsed-self.typeFrom)/.05))
    self.typed=Layout.utf8Prefix(p.draft,math.max(0,count));self.ready=p.draft~='' and count>=utf8.len(p.draft)
    local entering=p.view~=self.lastView
    if entering then self.arrivals={};self.scrollBottom=true;self.lastView=p.view end
    for _,m in ipairs(Layout.transcript(p)) do
        if not self.arrivals[m.id] or self.arrivals[m.id].status~=m.status then
            self.arrivals[m.id]={t=self.elapsed,status=m.status,outgoing=not entering and not m.them and not m.history and m.status=='sending',animate=entering or m.history or m.them or m.status=='sending'}
        end
    end
    if #p.msgs~=self.lastCount then self.scrollBottom=true;self.lastCount=#p.msgs end
    if #b.entries~=self.lastBrowseCount then self.scrollBottom=true;self.lastBrowseCount=#b.entries end
    if self.browseFirst~=b.entries[1] then self.browseArrivals={};self.browseFirst=b.entries[1] end
    for i in ipairs(b.entries) do if not self.browseArrivals[i] then self.browseArrivals[i]=self.elapsed end end
end
function Canvas:addHit(id,text,x,y,w,h,enabled)
    if self.hitClip then
        local r=self.hitClip;local right,bottom=math.min(x+w,r.x+r.w),math.min(y+h,r.y+r.h)
        x=math.max(x,r.x);y=math.max(y,r.y);w=right-x;h=bottom-y
        if w<=0 or h<=0 then return end
    end
    self.hits[#self.hits+1]={id=id,text=text,key=tostring(self.channel)..':'..id..':'..text,x=x,y=y,w=w,h=h,enabled=enabled~=false}
end
function Canvas:hitTest(x,y)
    for i=#self.hits,1,-1 do local r=self.hits[i];if r.enabled and inside(x,y,r) then return r end end
    return false
end
function Canvas:inputEnabled()
    local p=self.channel=='browse' and self.story.browse or self.story.phone
    return self.channel and p.open and p.k>=.6
end
function Canvas:pointerDown(x,y,id)
    if self.pointerId or (self.sceneActions and self.sceneActions.press) then return false end
    if not self:inputEnabled() then return self.sceneActions and self.sceneActions:down(x,y,id or 'mouse') or false end
    local px,py=x,y
    x=x/self.dpr;y=y/self.dpr
    local hit=self:hitTest(x,y);local inThread=self.thread and inside(x,y,self.thread)
    local inComposer=self.composer and inside(x,y,self.composer)
    if not hit and not inThread and not inComposer then return self.sceneActions and self.sceneActions:down(px,py,id or 'mouse') or false end
    self.scrollTarget=inComposer and 'composer' or 'thread'
    self.pointerId=id or 'mouse';self.press=hit;self.dragged=false;self.startX=x;self.startY=y;self.pointerY=y
    self.pressAt=self.elapsed;self.longPressed=false
    return true
end
function Canvas:pointerMove(x,y,id)
    if self.sceneActions then self.sceneActions:move(x,y,id or 'mouse') end
    if self.pointerId~=(id or 'mouse') then return end
    x=x/self.dpr;y=y/self.dpr
    if math.abs(x-self.startX)+math.abs(y-self.startY)>6 then self.dragged=true end
    if self.dragged and self.scrollTarget=='composer' then
        self.composerScroll=math.max(0,math.min(self.composerMaxScroll or 0,(self.composerScroll or 0)+self.pointerY-y))
    elseif self.dragged and (not self.press or self.press.message) and self.channel then
        self.scroll[self.channel]=math.max(0,math.min(self.maxScroll,self.scroll[self.channel]+self.pointerY-y))
        self.scrollBottom=false
    end
    self.pointerY=y
end
function Canvas:pointerUp(x,y,id)
    if self.sceneActions and self.sceneActions:up(x,y,id or 'mouse') then return true end
    if self.pointerId~=(id or 'mouse') then return false end
    local pressed=self.press;local dragged=self.dragged or self.longPressed;self:cancelPointer()
    local hit=self:hitTest(x/self.dpr,y/self.dpr)
    if not dragged and pressed and hit and hit.key==pressed.key and self:inputEnabled() then self:dispatch(hit.id);return true end
    return false
end
function Canvas:contextMenu(x,y)
    if not self:inputEnabled() or self.channel~='phone' then return false end
    local hit=self:hitTest(x/self.dpr,y/self.dpr)
    if hit and hit.message then self:cancelPointer();Extras.action(self,hit.id);return true end
    return false
end
function Canvas:wheel(delta,x,y)
    if self.channel and self.composer and inside(x/self.dpr,y/self.dpr,self.composer)then
        self.composerScroll=math.max(0,math.min(self.composerMaxScroll or 0,(self.composerScroll or 0)-delta*40));return true
    end
    if self.channel and self.thread and inside(x/self.dpr,y/self.dpr,self.thread) then
        self.scroll[self.channel]=math.max(0,math.min(self.maxScroll,self.scroll[self.channel]-delta*40));self.scrollBottom=false;return true
    end
    return false
end
function Canvas:dispatch(id)
    if not self:inputEnabled() then return false end
    if self.channel=='browse' then self.story:onBrowse(id)
    elseif Extras.action(self,id) then
    elseif id~='send' or self.ready then self.story:onPhone(id) end
    self:update(0)
end
function Canvas:drawHeader(p,isBrowse)
    local left=p.wide and math.max(p.x,68)or p.x
    local right=p.wide and math.min(p.x+p.w,self.w-140)or p.x+p.w
    local phone,b=self.story.phone,self.story.browse
    local title=isBrowse and b.title or (phone.view=='chat' and phone.contact or '消息')
    local subtitle=isBrowse and b.sub or phone.subtitle
    local close=isBrowse and (not self.story.story or self.story.story.panelClosable)
    for _,item in ipairs(phone.buttons) do if item.id=='close' then close=true end end
    local offset=close and (self.touchUI and 48 or (p.small and 32.8 or 40.8)) or 0
    if close then self:text('‹',left,p.y,35,LIGHT,true);self:addHit('close','close',left,p.y,self.touchUI and 44 or 26,self.touchUI and 44 or 42) end
    local available=right-left-offset-48
    local lines=Layout.wrap(title,math.max(1,available),p.contactSize,function(t,s)return self:measure(t,s)end)
    -- Source is a single header flex row; reserve enough height when narrow text wraps.
    local titleLine=Layout.normalHeight(p.contactSize)
    self:lines(lines,left+offset,p.y,p.contactSize,titleLine,LIGHT,true)
    self:text(subtitle,left+offset,p.y+#lines*titleLine+3,p.subtitleSize or (p.small and 11 or 13),LIGHT,true)
    local metaLine=Layout.normalHeight(p.metaSize);local titleH=#lines*titleLine+3+Layout.normalHeight(p.subtitleSize or (p.small and 11 or 13))
    local metaH=isBrowse and metaLine or metaLine*2+3;local metaY=p.y+(titleH-metaH)/2
    local clock=isBrowse and b.clock or phone.time
    self:text(clock,right-self:measure(clock,p.metaSize),metaY,p.metaSize,LIGHT,true)
    if not isBrowse then local battery=phone.batteryText or phone.battery..'%';self:text(battery,right-self:measure(battery,p.metaSize),metaY+metaLine+3,p.metaSize,LIGHT,true) end
    p.headerH=p.headerH+(#lines-1)*titleLine
    box(self.vg,p.x,p.y+p.headerH-1,p.w,1,{65,87,63,46})
end
function Canvas:drawChoices(p,list,bottom,hasInput)
    local buttons,height=Layout.choices(list,p.w,p.small,function(t,s)return self:measure(t,s)end,self.touchUI,p.wide)
    local inputH=hasInput and (p.wide and not self.touchUI and 36 or 44)or 0
    local grid=hasInput and Extras.gridLayout(self,p)or nil
    local gap=p.wide and 5 or 10;local pad=p.wide and 6 or 13
    local content=pad+height+(grid and gap+grid.h or 0)+(hasInput and gap+inputH or 0)
    local compact=self.w>self.h and self.h<=600
    local limit=p.wide and (p.bottom-p.y)*.48 or compact and (p.bottom-p.y)*.58 or content
    -- Preserve a readable thread even when long choices and the picker coexist.
    limit=math.min(limit,math.max(44,bottom-(p.y+p.headerH+p.gap)-44))
    local visible=math.min(content,limit);local top=bottom-visible
    self.composer={x=p.x,y=top,w=p.w,h=visible};self.composerMaxScroll=math.max(0,content-visible)
    self.composerScroll=math.max(0,math.min(self.composerMaxScroll,self.composerScroll or 0))
    nvgSave(self.vg);nvgIntersectScissor(self.vg,p.x,top,p.w,visible);self.hitClip=self.composer
    local y0=top+pad-self.composerScroll
    box(self.vg,p.x,top-self.composerScroll,p.w,1,{240,237,223,56})
    for _,b in ipairs(buttons) do
        local y=y0+b.y;local color=b.id=='chat' and {128,182,101,255} or (b.quietReply and {239,228,207,179} or CHOICE)
        if self.story.mode=='dream' then color={250,252,255,235}end
        box(self.vg,p.x+b.x,y,b.w,b.h,color,6)
        if self.story.mode=='dream' then nvgStrokeColor(self.vg,nvgRGBA(1,64,196,153));nvgStrokeWidth(self.vg,1);nvgStroke(self.vg)end
        self:lines(b.lines,p.x+b.x+b.px+1,y+(b.h-#b.lines*Layout.normalHeight(b.size))/2,b.size,Layout.normalHeight(b.size),b.id=='chat' and LIGHT or INK)
        self:addHit(b.id,b.text,p.x+b.x,y,b.w,b.h)
    end
    local nextY=y0+height
    if grid then nextY=nextY+gap;Extras.grid(self,p,nextY,grid);nextY=nextY+grid.h end
    if hasInput then self:drawInput(p,nextY+gap,inputH)end
    self.hitClip=false;nvgRestore(self.vg)
    if self.composerMaxScroll>0 then
        local bar=math.max(16,visible*visible/content)
        box(self.vg,p.x+p.w-2,top+(visible-bar)*self.composerScroll/self.composerMaxScroll,2,bar,{240,237,223,160},1)
    end
    return top
end
function Canvas:drawInput(p,y,h)
    h=h or 44;local offset=Extras.input(self,p,y,h);if offset>0 then local q={};for k,v in pairs(p)do q[k]=v end;q.x=q.x+offset;q.w=q.w-offset;p=q end
    local phone=self.story.phone;local hasDraft=phone.draft~=''
    local dream=self.story.mode=='dream'
    local sendSize=p.wide and 11 or 15;local sendW=dream and 0 or self:measure('发送',sendSize)+(p.wide and 18 or 28);local clearW=hasDraft and 27 or 0
    local draftW=math.max(20,p.w-sendW-8-(hasDraft and clearW+8 or 0))
    box(self.vg,p.x,y,draftW,h,{250,251,244,230},6)
    nvgSave(self.vg);nvgIntersectScissor(self.vg,p.x+13,y,draftW-26,h)
    local text=hasDraft and self.typed or phone.placeholder or '选一句，或者什么都不说';local size=p.wide and (hasDraft and 12 or 10)or (hasDraft and 18 or 15)
    local offset=math.max(0,self:measure(text,size)-(draftW-30))
    self:text(text,p.x+13-offset,y+(h-size)/2,size,hasDraft and INK or MUTED)
    if hasDraft and self.elapsed%1<.5 then box(self.vg,p.x+14+self:measure(text,size)-offset,y+(h-size*1.1)/2,2,size*1.1,{95,174,74,255}) end
    nvgRestore(self.vg)
    if dream then return end
    local sendX=p.x+p.w-sendW
    if hasDraft then self:text('✕',sendX-8-clearW+6,y+(h-sendSize)/2,sendSize,LIGHT,true);self:addHit('clear','clear',sendX-8-clearW,y,clearW,h) end
    box(self.vg,sendX,y,sendW,h,self.ready and {7,193,96,255} or {225,230,218,217},6)
    self:text('发送',sendX+(sendW-self:measure('发送',sendSize))/2,y+(h-sendSize)/2,sendSize,self.ready and {255,255,255,255} or {138,149,133,255})
    self:addHit('send',phone.draft,sendX,y,sendW,h,self.ready)
end
function Canvas:drawMessage(m,x,y,width,p,motion,opacity)
    local layout=Layout.message(m,width,p,function(t,s)return self:measure(t,s)end)
    if m.displayStamp then
        local sw=self:measure(m.displayStamp,13)+16
        box(self.vg,x+(width-sw)/2,y,sw,Layout.normalHeight(13)+4,{20,32,18,56},4);self:text(m.displayStamp,x+(width-sw)/2+8,y+2,13,LIGHT,true)
    end
    y=y+layout.stampH
    nvgSave(self.vg)
    if motion then
        nvgGlobalAlpha(self.vg,(opacity or 1)*motion.alpha)
        nvgTranslate(self.vg,x+width,y+layout.h-layout.stampH+motion.y)
        nvgScale(self.vg,motion.scale,motion.scale)
        nvgTranslate(self.vg,-x-width,-y-layout.h+layout.stampH)
    end
    local avatarX=m.me and x+width-p.avatar or x
    local bx=m.me and avatarX-p.messageGap-layout.w or avatarX+p.avatar+p.messageGap
    local by=y+layout.nameH
    local avatar=m.me and 'store/avatar-me.png' or (m.avatar or 'store/avatar-them.png')
    if self.story.mode=='dream' then avatar='increment03/avatars/'..avatar:match('([^/]+)$'):gsub('%.[^.]+$','.png')end
    self:image(avatar,avatarX,y,p.avatar,p.avatar,true)
    if layout.nameH>0 then self:text(m.name,bx+2,y,p.wide and 10 or 13,LIGHT,true) end
    if m.sticker then self:image('stickers/'..m.sticker..'.png',bx,by,layout.w,layout.bubbleH)else
    box(self.vg,bx,by+2,layout.w,layout.bubbleH,{40,58,31,18},5)
    local dream=self.story.mode=='dream'
    local c=dream and {250,252,255,237} or m.me and GREEN or WHITE;box(self.vg,bx,by,layout.w,layout.bubbleH,c,5)
    local truth=dream and (m.truthUntil or 0)>self.story.t
    if dream then nvgStrokeColor(self.vg,truth and nvgRGBA(1,64,196,255)or nvgRGBA(53,121,241,140));nvgStrokeWidth(self.vg,truth and 2 or 1.5);nvgStroke(self.vg)end
    nvgSave(self.vg);nvgTranslate(self.vg,m.me and bx+layout.w-1 or bx+1,by+20);nvgRotate(self.vg,math.pi/4);box(self.vg,-5,-5,10,10,c,1);nvgRestore(self.vg)
    if dream and m.gl then
        nvgSave(self.vg);nvgIntersectScissor(self.vg,bx+(m.gx or 0),by+layout.bubbleH*(m.gt or 0),layout.w,layout.bubbleH*.4)
        self:lines(layout.lines,bx+layout.px+(m.gx or 0)+3,by+layout.py,layout.size,layout.lineH,{53,121,241,191})
        self:lines(layout.lines,bx+layout.px+(m.gx or 0)-3,by+layout.py,layout.size,layout.lineH,{1,64,196,140})
        self:lines(layout.lines,bx+layout.px+(m.gx or 0),by+layout.py,layout.size,layout.lineH,truth and {1,64,196,255}or INK)
        nvgRestore(self.vg)
    else self:lines(layout.lines,bx+layout.px,by+layout.py,layout.size,layout.lineH,truth and {1,64,196,255}or INK)end
    end
    Extras.message(self,m,bx,by,layout,p)
    if m.status=='failed' then
        box(self.vg,bx-26,by+layout.bubbleH/2-9,18,18,{224,83,61,255},9);self:text('!',bx-20,by+layout.bubbleH/2-7,13,{255,255,255,255})
    end
    if m.showRead then
        local status=m.status=='failed' and self.story.phone.failText or (m.status=='sending' and '◌' or '已送达')
        self:text(status,bx+layout.w-self:measure(status,12),by+layout.bubbleH+6,12,m.status=='failed' and {255,140,122,255} or LIGHT,true)
    end
    nvgRestore(self.vg);return layout.h
end
function Canvas:drawLock(p,top,bottom)
    local phone=self.story.phone;local size=math.max(48,math.min(94,self.w*.07))
    local previewLines=Layout.wrap(phone.preview,math.max(1,p.w-96),18,function(t,s)return self:measure(t,s)end)
    local previewH=math.max(46,21.6+4+#previewLines*21.6)+(p.small and 24 or 40)
    local total=size+18+18+18+28+previewH
    local y=top+(bottom-top-total)/2
    self:text(phone.time,p.x,y,size,LIGHT,true);y=y+size+18
    self:text(phone.lockLabel,p.x,y,15,LIGHT,true);y=y+18+18+28
    box(self.vg,p.x,y,p.w,previewH,{249,251,244,191},8)
    local pad=p.small and 12 or 18;local gap=p.small and 8 or 14
    self:image(phone.previewAvatar,p.x+pad,y+(previewH-46)/2,46,46,true)
    self:text(phone.previewName,p.x+pad+46+gap,y+(p.small and 12 or 20),18,INK)
    self:lines(previewLines,p.x+pad+46+gap,y+(p.small and 12 or 20)+25.6,18,21.6,{101,116,98,255})
end
function Canvas:browseEntry(e,x,y,width,p,draw)
    local measure=function(t,s)return self:measure(t,s)end
    if e.kind=='thought' or e.kind=='msg' or e.kind=='me' then
        local m={text=e.text,me=e.kind~='msg',name=e.name,avatar=e.avatar}
        if draw then return self:drawMessage(m,x,y,width,p) end
        return Layout.message(m,width,p,measure).h
    elseif e.kind=='scene' then
        local h=math.min(self.h*(p.wide and .36 or .42),width*(e.prop and .8 or .6))
        local w=e.prop and math.min(width,h) or width
        if draw then self:image((e.src or ''):gsub('^%./assets/',''):gsub('^assets/',''),x+(width-w)/2,y,w,h) end
        return h
    elseif e.kind=='card' then
        local ns,rs,ss=p.wide and 13 or 20,p.wide and 12 or 16,p.wide and 10 or 13
        local pad=p.wide and 10 or 18;local labelW=p.wide and 48 or 74;local imageSize=p.wide and 56 or 84
        local imageW=e.img and imageSize+12 or 0;local sourceRows=e.rows or {}
        local ideal=measure(e.name,ns)+(p.wide and labelW or 64)
        for _,row in ipairs(sourceRows) do ideal=math.max(ideal,labelW+measure(row[2],rs)) end
        local w=math.min(width*.92,math.max(p.wide and 160 or 220,ideal+pad*2+imageW))
        local contentW=math.max(1,w-pad*2-imageW)
        local lines=Layout.wrap(e.name,math.max(1,contentW-(p.wide and (e.price and labelW or 0) or 64)),ns,measure)
        local rows={};local contentH=#lines*Layout.normalHeight(ns)+(e.img and (p.wide and 12 or 20) or #sourceRows*4)
        for _,row in ipairs(sourceRows) do
            local valueLines=Layout.wrap(row[2],math.max(1,contentW-labelW),rs,measure)
            local rh=#valueLines*Layout.normalHeight(rs)+5;contentH=contentH+rh
            rows[#rows+1]={label=row[1],lines=valueLines,h=rh}
        end
        local extra=e.img and math.max(0,imageSize-contentH)/6 or 0
        local h=math.max(e.img and imageSize or 0,contentH)+(p.wide and 15 or 26)
        if draw then
            -- phArrive's forwards fill overrides the card's static rotation in the H5.
            nvgSave(self.vg);nvgTranslate(self.vg,x,y)
            box(self.vg,3,3,w,h,{43,33,29,76},6);box(self.vg,0,0,w,h,{43,33,29,255},6);box(self.vg,2,2,w-4,h-4,{251,248,239,242},5)
            if e.img then self:image('store/goods/'..e.img..'.png',pad,(h-imageSize)/2,imageSize,imageSize) end
            local tx=pad+imageW
            local top=p.wide and 7.5 or 14
            self:lines(lines,tx,top+extra/2,ns,Layout.normalHeight(ns),{43,33,29,255})
            if e.price then local ps=p.wide and 13 or 18;self:text(e.price,w-(p.wide and 10 or 14)-measure(e.price,ps),p.wide and 7 or 12,ps,{176,68,47,255}) end
            local ry=top+#lines*Layout.normalHeight(ns)+extra+4
            for _,row in ipairs(rows) do
                for dx=0,contentW-1,4 do box(self.vg,tx+dx,ry,math.min(2,contentW-dx),1,{43,33,29,46}) end
                self:text(row.label,tx,ry+5+extra/2+3,ss,{122,116,102,255})
                self:lines(row.lines,tx+labelW,ry+5+extra/2,rs,Layout.normalHeight(rs),{60,58,51,255});ry=ry+row.h+extra+4
            end
            nvgRestore(self.vg)
        end
        return h
    elseif e.kind=='pic' then
        if draw then self:image('store/goods/'..e.img..'.png',x+(width-170)/2,y+4,170,170);self:text(e.caption or '',x+(width-measure(e.caption or '',22))/2,y+180,22,LIGHT,true) end
        return 8+170+6+Layout.normalHeight(22)
    elseif e.kind=='divider' then
        if draw then local tw=measure(e.text,13);box(self.vg,x,y+18,(width-tw-20)/2,1,{240,237,223,89});self:text(e.text,x+(width-tw)/2,y+10,13,{240,237,223,179});box(self.vg,x+(width+tw)/2+10,y+18,(width-tw-20)/2,1,{240,237,223,89}) end
        return 25.6
    end
    local size=p.wide and 12 or 16
    local lines=Layout.wrap(e.text or '',math.max(1,width-8),size,measure)
    if draw then self:lines(lines,x+4,y,size,size*1.2,LIGHT,true) end
    return #lines*Layout.normalHeight(size)
end
function Canvas:render()
    if self.disposed then return end
    if not self.fontReady then
        nvgBeginFrame(self.vg,self.w,self.h,self.dpr);require('render.CaptionOverlay').drawLoading(self);nvgEndFrame(self.vg);return
    end
    local vg=self.vg;self.hits={};self.thread=false;self.composer=false;self.hitClip=false;self.panel=false;self.reactAnchor=false
    nvgBeginFrame(vg,self.w,self.h,self.dpr)
    if self.probeBackdrop then box(vg,0,0,self.w,self.h,{29,26,36,255});self:text('NVG 界面校验 · 非剧情场景',20,20,16,LIGHT) end
    -- Dialog wash < interaction prompts < phone/cards < dialog ink < finale/menus.
    if self.sceneBackdrop then nvgSave(vg);self.sceneBackdrop(self);nvgRestore(vg)end
    if self.sceneActions then self.sceneActions:render() end
    if self.channel=='browse'and self.story.browse.presentation=='look'then
        self.panel=false;require('render.LookCard').draw(self,self.story.browse)
    elseif self.channel then
        local isBrowse=self.channel=='browse';local state=isBrowse and self.story.browse or self.story.phone
        local placement=isBrowse and self.story.browse or self.placement
        local p=Layout.panel(self.w,self.h,placement,state.k);if self.story.mode=='dream' and not isBrowse then p.x=p.x+(state.jitter or 0)end;self.panel=p
        if self.touchUI and not p.wide then p.y=math.max(72,p.y) end
        nvgGlobalAlpha(vg,math.min(1,state.k*1.2));self:drawHeader(p,isBrowse)
        local list={};if isBrowse then for i,text in ipairs(state.choices) do list[#list+1]={id='choice:'..(i-1),text=text,quietReply=i==#state.choices and #state.choices>1} end else list=state.buttons end
        local footer=self:drawChoices(p,list,p.bottom,not isBrowse and state.view=='chat')
        local top=p.y+p.headerH+p.gap
        if not isBrowse and state.view=='lock' then self:drawLock(p,top,footer-p.gap)
        else
            local x,width=p.x+3,math.max(1,p.w-6);local entries=isBrowse and state.entries or Layout.transcript(state)
            local heights={};local total=20
            local gap=isBrowse and (p.wide and 8 or 14) or p.threadGap
            for i,e in ipairs(entries) do
                heights[i]=isBrowse and self:browseEntry(e,x,0,width,p,false) or Layout.message(e,width,p,function(t,s)return self:measure(t,s)end).h
                total=total+heights[i]+(i>1 and gap or 0)
            end
            local h=math.max(0,footer-p.gap-top)
            self.thread={x=p.x,y=top,w=p.w,h=h};self.maxScroll=math.max(0,total-h)
            if self.scrollBottom then self.scroll[self.channel]=self.maxScroll;self.scrollBottom=false end
            self.scroll[self.channel]=math.max(0,math.min(self.maxScroll,self.scroll[self.channel]))
            nvgSave(vg);nvgIntersectScissor(vg,p.x,top,p.w,h)
            local y=top+4-self.scroll[self.channel]
            for i,e in ipairs(entries) do
                if y+heights[i]>=top and y<top+h then
                    if isBrowse then
                        local motion=Motion.arrive(self.elapsed-(self.browseArrivals[i] or 0))
                        nvgSave(vg);nvgGlobalAlpha(vg,math.min(1,state.k*1.2)*motion.alpha)
                        self:browseEntry(e,x,y+motion.y,width,p,true);nvgRestore(vg)
                    else
                        local arrival=self.arrivals[e.id];local age=arrival and self.elapsed-arrival.t or 1
                        local motion=arrival and arrival.outgoing and Motion.send(age) or Motion.arrive(arrival and arrival.animate and age or 1)
                        self:drawMessage(e,x,y,width,p,motion,math.min(1,state.k*1.2))
                    end
                end
                y=y+heights[i]+gap
            end
            nvgRestore(vg)
            if not isBrowse then Extras.reactionBar(self,p)end
            if self.maxScroll>0 and h>0 then
                local bar=math.max(20,h*h/total);box(vg,p.x+p.w-2,top+(h-bar)*self.scroll[self.channel]/self.maxScroll,2,bar,{240,237,223,100},1)
            end
        end
    end
    if self.story.mode=='dream'and self.channel=='phone' and self.panel then
        local p=self.panel;local offset=(self.story.t*60/1.6)%6
        nvgSave(vg);nvgGlobalAlpha(vg,self.story.phone.k);nvgIntersectScissor(vg,p.x,p.y,p.w,p.bottom-p.y)
        for y=p.y-6+offset,p.bottom,6 do box(vg,p.x,y,p.w,2,{53,121,241,23})end
        nvgRestore(vg)
    end
    if self.sceneHUD then nvgSave(vg);nvgGlobalAlpha(vg,1);self.sceneHUD(self);nvgRestore(vg) end
    if self.externalHUD then nvgSave(vg);nvgGlobalAlpha(vg,1);self.externalHUD(self);nvgRestore(vg) end
    require('render.TimelinePortal').draw(self)
    require('render.CaptionOverlay').drawLoading(self)
    nvgEndFrame(vg)
end
function Canvas:dispose()
    if self.disposed then return end
    self:cancelPointer();for _,im in pairs(self.images) do if im.id>0 then nvgDeleteImage(self.vg,im.id) end end
    nvgDelete(self.vg);self.disposed=true
end
return Canvas
