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
function Actions:layout()
    local c,s=self.canvas,self.getStory();local buttons={}
    if not s or not c.fontReady then return buttons end
    local options=s:nearbyInteractions();local total=0
    local blocked=self.phone and (s.normi:busy() or s.t-s.interactionAt<1)
    for _,o in ipairs(options) do
        local selected=o.id==s.interactionId
        local text=(selected and 'F · ' or '')..o.text
        local width=math.max(c:measure(o.object,12),c:measure(text,18))+36
        buttons[#buttons+1]={id=o.id,name=o.object,text=text,w=width,h=61,selected=selected,enabled=not blocked}
        total=total+width+(#buttons>1 and 8 or 0)
    end
    local hint=#buttons>1 and 'Tab 切换 · 点击也可交互' or false
    -- Fixed left:50%, width:auto is shrink-to-fit. The full-width flex hint
    -- still participates in the source CSS intrinsic maximum width.
    local natural=total+(hint and 8+c:measure(hint,13) or 0)
    local width=math.min(c.w/2,natural,c.w-32)
    local rows={};local row={items={},w=0}
    for _,b in ipairs(buttons) do
        if #row.items>0 and row.w+8+b.w>width then rows[#rows+1]=row;row={items={},w=0} end
        row.w=row.w+(#row.items>0 and 8 or 0)+b.w;row.items[#row.items+1]=b
    end
    if #row.items>0 then rows[#rows+1]=row end
    local height=#rows*61+math.max(0,#rows-1)*8+(hint and 23 or 0)
    local y=c.h-76-height
    for _,r in ipairs(rows) do
        local x=(c.w-r.w)/2
        for _,b in ipairs(r.items) do b.x=x;b.y=y;x=x+b.w+8 end
        y=y+69
    end
    local hintBox=hint and {text=hint,x=(c.w-c:measure(hint,13))/2,y=c.h-91} or false
    -- Match source body.phone-open: follow animation progress on both opening
    -- and closing, including browsing panels, rather than the target open flag.
    local panelExpanded=(s.phone and s.phone.k>.3) or (s.browse and s.browse.k>.3)
    if self.phone and not s.phoneButtonHidden and not panelExpanded then
        buttons[#buttons+1]={id='phone',text='手机',x=c.w-96,y=c.h-157.6,w=80,h=97.6,enabled=true,phone=true}
    end
    return buttons,hintBox
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
        if hit.phone then s:togglePhone() else s:interact(hit.id) end
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
        if b.phone then
            if pressed then nvgTranslate(vg,x+b.w/2,y+b.h/2+2);nvgScale(vg,.95,.95);nvgTranslate(vg,-x-b.w/2,-y-b.h/2) end
            if hovered or pressed then rect(vg,x,y,b.w,b.h,238,241,220,pressed and 56 or 33,16) end
            c:image('store/phone-icon.png',x+8,y+5,64,64,false)
            c:fontSize(18);nvgTextLetterSpacing(vg,2.16)
            nvgTextAlign(vg,NVG_ALIGN_CENTER+NVG_ALIGN_TOP)
            nvgFillColor(vg,nvgRGBA(36,53,33,255));nvgText(vg,x+40+1,y+71+1,'手机')
            nvgFillColor(vg,nvgRGBA(246,238,223,255));nvgText(vg,x+40,y+71,'手机')
        else
            if pressed then x=x+1;y=y+1 end
            rect(vg,x+(pressed and 1 or 2),y+(pressed and 1 or 2),b.w,b.h,43,33,29,115)
            if b.selected then rect(vg,x,y,b.w,b.h,215,231,191,255)
            else rect(vg,x,y,b.w,b.h,236,234,210,235) end
            nvgStrokeColor(vg,b.selected and nvgRGBA(57,84,60,255) or nvgRGBA(43,33,29,255));nvgStrokeWidth(vg,2);nvgStroke(vg)
            c:text(b.name,x+18,y+11,12,{43,33,29,178})
            c:text(b.text,x+18,y+11+Layout.normalHeight(12)+3,18,{43,33,29,255})
        end
        nvgRestore(vg)
    end
    if hint then c:text(hint.text,hint.x,hint.y,13,{246,238,223,255},true) end
end
return Actions
