-- Frozen #store-interaction and #phoneBtn, drawn in the existing NVG frame.
local Layout=require('game.StoryPanelLayout')
---@class SceneActions
---@field canvas table
---@field getStory fun():table|nil
---@field phone boolean
---@field press table|false
---@field hover string|false
local Actions={};Actions.__index=Actions
local function inside(x,y,r) return x>=r.x and y>=r.y and x<r.x+r.w and y<r.y+r.h end
function Actions.new(canvas,getStory,phone)
    return setmetatable({canvas=canvas,getStory=getStory,phone=phone,press=false,hover=false},Actions)
end
function Actions:cancel() self.press=false;self.hover=false end
local function measure(c,text,size,spacing)
    return c:measure(text,size)+(utf8.len(text)or 0)*(spacing or 0)
end
local function spaced(c,text,x,y,size,color,spacing)
    for _,code in utf8.codes(text)do local ch=utf8.char(code);c:text(ch,x,y,size,color,true);x=x+c:measure(ch,size)+(spacing or 0)end
end
function Actions:phoneRow(s,rows)
    local c=self.canvas;local wide=c.w/c.h>=2
    if self.phone and not s.phoneButtonHidden and not s.look and s.phone.k<=.3 and s.browse.k<=.3 then
        local height=wide and 58 or 97.6;local bottom=wide and (c.touchUI and 72 or 56)or(c.touchUI and 94 or 60)
        rows[#rows+1]={id='phone',text='手机',x=c.w-(wide and 64 or 96),y=c.h-bottom-height,w=wide and 48 or 80,h=height,enabled=true,phone=true,wide=wide,unread=not not s.pending}
    end
end
function Actions:nightLayout(s,options)
    local c=self.canvas;local wide=c.w/c.h>=2;local touch=c.touchUI;local rows={};local current;local others={}
    for _,o in ipairs(options)do if o.id==s.interactionId then current=o else others[#others+1]=o.object end end
    if current then
        local size=wide and 12 or(c.w<=800 and 17 or 21);local key=touch and 0 or(wide and 18 or 26)
        local gap=wide and(touch and 8 or 5)or 12;local spacing=size*(wide and .04 or .14)
        local more=#others>0 and (touch and '切物件' or 'Tab 换一个 · '..table.concat(others,' / '))or ''
        if c.w<=800 and not touch then more=''end
        local tabSize=wide and 10 or 13;local tabSpacing=tabSize*.1
        local mw=more~=''and math.max(touch and 44 or 0,measure(c,more,tabSize,tabSpacing))or 0
        local width=(key>0 and key+gap or 0)+measure(c,current.text,size,spacing)+gap+measure(c,current.object,size,spacing)
        local tabGap=touch and gap or gap+(wide and 4 or 10)
        local full=width+(more~=''and tabGap+mw or 0)
        local x=wide and not touch and c.w-16-full or(c.w-full)/2
        local height=math.max(touch and 44 or key,Layout.normalHeight(size))
        local bottom=wide and(touch and 12 or 28)or 40+c.h*.04;local y=c.h-bottom-height
        rows[#rows+1]={id=current.id,office=true,text=current.text,name=current.object,textSize=size,key=key,gap=gap,spacing=spacing,keySize=wide and 10 or 14,
            x=x,y=y,w=width,h=height,enabled=not s.normi:busy()and s.t-s.interactionAt>=.8}
        if more~=''then rows[#rows+1]={id='cycle',officeCycle=true,text=more,textSize=tabSize,spacing=tabSpacing,x=x+width+tabGap,y=y,w=mw,h=height,enabled=touch}end
    end
    self:phoneRow(s,rows);return rows,false
end
function Actions:layout()
    local c,s=self.canvas,self.getStory();local buttons={}
    if not s or not c.fontReady then return buttons end
    local wide=c.w/c.h>=2;local touch=c.touchUI
    local options=s:nearbyInteractions()
    -- Meeting/morning use phone as their browse panel and have no browse field.
    -- Store/night/dream/dorm have both; either open panel hides wide prompts.
    if wide and ((s.phone and s.phone.k>.3)or(s.browse and s.browse.k>.3))then options={}end
    if s.mode=='night'then return self:nightLayout(s,options)end
    local blocked=self.phone and (s.normi:busy()or s.t-s.interactionAt<1)
    local key=touch and 0 or(wide and 18 or 26);local pad=touch and wide and 5 or 0
    local width=0
    for _,o in ipairs(options)do
        local selected=o.id==s.interactionId
        local size=wide and 12 or(c.w<=800 and(selected and 18 or 16)or(selected and 21 or 18))
        local objSize=wide and 11 or size*.72;local spacing=size*(wide and .04 or .14);local objSpacing=objSize*.22
        local w=(key>0 and key+12 or 0)+measure(c,o.text,size,spacing)+12+measure(c,o.object,objSize,objSpacing)+(pad>0 and pad*2 or 6)
        local h=math.max(touch and 44 or 0,6+math.max(key,Layout.normalHeight(size),Layout.normalHeight(objSize)))
        buttons[#buttons+1]={id=o.id,sourceRow=true,text=o.text,name=o.object,textSize=size,nameSize=objSize,spacing=spacing,nameSpacing=objSpacing,key=key,keySize=wide and 10 or 14,pad=pad,w=w,h=h,selected=selected,enabled=not blocked}
        width=math.max(width,w)
    end
    local hint=#buttons>1 and not touch and {text='Tab 切换 · 点击也可交互',size=12,spacing=1.68}or false
    if hint then hint.w=measure(c,hint.text,hint.size,hint.spacing);width=math.max(width,38+hint.w)end
    if touch and wide then
        local maxWidth=math.max(44,c.w-260);local rows={};local row={w=0,h=0,items={}}
        for _,button in ipairs(buttons)do
            if #row.items>0 and row.w+8+button.w>maxWidth then rows[#rows+1]=row;row={w=0,h=0,items={}}end
            row.w=row.w+(#row.items>0 and 8 or 0)+button.w;row.h=math.max(row.h,button.h);row.items[#row.items+1]=button
        end
        if #row.items>0 then rows[#rows+1]=row end
        local height=math.max(0,#rows-1)*4;for _,r in ipairs(rows)do height=height+r.h end
        local y=c.h-12-height
        for _,r in ipairs(rows)do local x=(c.w-r.w)/2;for _,button in ipairs(r.items)do button.x=x;button.y=y;x=x+button.w+8 end;y=y+r.h+4 end
    else
        local gap=wide and 5 or 4;local height=math.max(0,#buttons-1)*gap
        for _,button in ipairs(buttons)do height=height+button.h end
        if hint then height=height+gap+4+Layout.normalHeight(hint.size)end
        local bottom=wide and 28 or(touch and 24 or 36+c.h*.04);local y=c.h-bottom-height
        local left=wide and c.w-16-width or(c.w-width)/2
        for _,button in ipairs(buttons)do button.x=wide and c.w-16-button.w or left;button.y=y;y=y+button.h+gap end
        if hint then hint.x=wide and c.w-16-hint.w or left+38;hint.y=y+4 end
    end
    self:phoneRow(s,buttons);return buttons,hint
end
function Actions:hit(x,y)
    local c=self.canvas
    if c.channel and c.panel then
        ---@type table
        local p=c.panel
        if x>=p.x and x<p.x+p.w and y>=p.y and y<p.bottom then return false end
    end
    local buttons=self:layout()
    for i=#buttons,1,-1 do local b=buttons[i];if b.enabled and inside(x,y,b) then return b end end
    return false
end
function Actions:down(x,y,id)
    if self.press then return false end
    local c=self.canvas;local hit=self:hit(x/c.dpr,y/c.dpr)
    if not hit then return false end
    self.press={id=id,action=hit.id,x=x,y=y,dragged=false};return true
end
function Actions:move(x,y,id)
    local c,p=self.canvas,self.press
    if id=='mouse' then local hit=self:hit(x/c.dpr,y/c.dpr);self.hover=hit and hit.id or false end
    if p and p.id==id and math.abs(x-p.x)+math.abs(y-p.y)>6*c.dpr then p.dragged=true end
end
function Actions:up(x,y,id)
    local c,p=self.canvas,self.press
    if not p or p.id~=id then return false end
    self.press=false
    local hit=self:hit(x/c.dpr,y/c.dpr)
    if not p.dragged and math.abs(x-p.x)+math.abs(y-p.y)<=6*c.dpr and hit and hit.id==p.action then
        local s=self.getStory()
        if hit.phone then s:togglePhone() elseif hit.id=='cycle'then s:cycleInteraction() else s:interact(hit.id) end
    end
    return true
end
local function rect(vg,x,y,w,h,r,g,b,a,round)
    nvgBeginPath(vg)
    if round then nvgRoundedRect(vg,x,y,w,h,round) else nvgRoundedRectVarying(vg,x,y,w,h,10,12,9,11) end
    nvgFillColor(vg,nvgRGBA(r,g,b,a));nvgFill(vg)
end
function Actions:render()
    local c=self.canvas;local vg=c.vg;local buttons,hint=self:layout()
    for _,b in ipairs(buttons) do
        local pressed=self.press and not self.press.dragged and self.press.action==b.id
        local hovered=self.hover==b.id
        nvgSave(vg)
        if not b.enabled then nvgGlobalAlpha(vg,.65) end
        local x,y=b.x,b.y
        if b.office or b.sourceRow then
            if b.sourceRow then nvgGlobalAlpha(vg,not b.enabled and .35 or(b.selected and 1 or hovered and .85 or .58))end
            local tx=x+(b.pad or 0);local key=b.key or 0
            if key>0 then
                local ky=y+(b.h-key)/2
                if b.office or b.selected then
                    nvgBeginPath(vg);nvgRect(vg,tx,ky,key,key);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(243,241,234,180));nvgStroke(vg)
                    c:text('F',tx+(key-c:measure('F',b.keySize))/2,ky+(key-b.keySize)/2,b.keySize,{243,241,234,255},true)
                end
                tx=tx+key+(b.office and b.gap or 12)
            end
            spaced(c,b.text,tx,y+(b.h-Layout.normalHeight(b.textSize))/2,b.textSize,{243,241,234,255},b.spacing)
            tx=tx+measure(c,b.text,b.textSize,b.spacing)+(b.office and b.gap or 12)
            local ns=b.nameSize or b.textSize
            spaced(c,b.name,tx,y+(b.h-Layout.normalHeight(ns))/2,ns,{232,194,122,255},b.nameSpacing or b.spacing)
        elseif b.officeCycle then
            spaced(c,b.text,x,y+(b.h-Layout.normalHeight(b.textSize))/2,b.textSize,{243,241,234,166},b.spacing)
        elseif b.phone then
            if pressed then nvgTranslate(vg,x+b.w/2,y+b.h/2+2);nvgScale(vg,.95,.95);nvgTranslate(vg,-x-b.w/2,-y-b.h/2) end
            if hovered or pressed then rect(vg,x,y,b.w,b.h,238,241,220,pressed and 56 or 33,16) end
            local icon=b.wide and 32 or 64;local textY=y+icon+(b.wide and 6 or 7)
            c:image('store/phone-icon.png',x+8,y+3,icon,icon,false)
            if b.unread then
                nvgBeginPath(vg);nvgCircle(vg,x+b.w-12,y+10,b.wide and 4 or 6);nvgFillColor(vg,nvgRGBA(226,72,60,255));nvgFill(vg)
                nvgStrokeColor(vg,nvgRGBA(20,24,30,204));nvgStrokeWidth(vg,2);nvgStroke(vg)
            end
            c:fontSize(b.wide and 11 or 18);nvgTextLetterSpacing(vg,b.wide and 1 or 2.16)
            nvgTextAlign(vg,NVG_ALIGN_CENTER+NVG_ALIGN_TOP)
            nvgFillColor(vg,nvgRGBA(36,53,33,255));nvgText(vg,x+b.w/2+1,textY+1,'手机')
            nvgFillColor(vg,nvgRGBA(246,238,223,255));nvgText(vg,x+b.w/2,textY,'手机')
        end
        nvgRestore(vg)
    end
    if hint then spaced(c,hint.text,hint.x,hint.y,hint.size,{246,238,223,179},hint.spacing)end
end
return Actions
