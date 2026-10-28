-- Raw NVG rendition of frozen #chapter-end; no separate UI framework.
local Ease=require('game.TitlePresentation')
local Layout=require('game.StoryPanelLayout')
local End={};End.__index=End
function End.new() return setmetatable({age=0,active=false,replay=false,press=false},End) end
function End:show(title,subtitle) self.active=true;self.age=0;self.press=false;self.title=title;self.subtitle=subtitle end
function End:update(dt) if self.active then self.age=self.age+dt end end
function End:cancel() self.press=false end
function End:inside(canvas,x,y)
    local r=self.button;if not r then return false end
    x=x/canvas.dpr;y=y/canvas.dpr
    return x>=r.x and x<=r.x+r.w and y>=r.y and y<=r.y+r.h
end
function End:down(canvas,x,y,id) self.press=self:inside(canvas,x,y) and {id=id,x=x,y=y} or false end
function End:up(canvas,x,y,id)
    local p=self.press;self.press=false
    if p and p.id==id and math.abs(p.x-x)+math.abs(p.y-y)<=6*canvas.dpr and self:inside(canvas,x,y) then self.replay=true end
end
function End:render(canvas)
    if not self.active then return end
    local vg=canvas.vg;local alpha=Ease.ease(self.age/2.4)
    nvgBeginPath(vg);nvgRect(vg,0,0,canvas.w,canvas.h);nvgFillColor(vg,nvgRGBA(12,16,14,math.floor(255*.92*alpha*alpha)));nvgFill(vg)
    nvgGlobalAlpha(vg,alpha)
    local function text(value,y,size,spacing,opacity)
        canvas:fontSize(size);nvgTextLetterSpacing(vg,spacing);nvgTextAlign(vg,NVG_ALIGN_CENTER+NVG_ALIGN_TOP)
        nvgFillColor(vg,nvgRGBA(240,237,223,opacity));nvgText(vg,canvas.w/2,y,value)
    end
    local wide=canvas.w/canvas.h>=2
    local titleSize=wide and math.max(22,math.min(30,canvas.h*.05))or math.min(40,canvas.w/10)
    local subSize=wide and 12 or 15;local buttonSize=wide and 12 or 16
    local titleH=Layout.normalHeight(titleSize);local subH=Layout.normalHeight(subSize)
    local label='再玩一次';local spacing=buttonSize*.06
    local width=canvas:measure(label,buttonSize)+utf8.len(label)*spacing+22
    local h=math.max((wide or canvas.touchUI)and 44 or 0,Layout.normalHeight(buttonSize)+12)
    -- Frozen flex column: 14px gaps and 18px margin above the replay button.
    local top=(canvas.h-titleH-subH-h-46)/2
    text(self.title or '第一章 · 完',top,titleSize,titleSize*.3,255)
    text(self.subtitle or '反方向的猪 · 谢谢游玩',top+titleH+14,subSize,subSize*.2,153)
    local x=(canvas.w-width)/2;local y=top+titleH+subH+46;self.button={x=x,y=y,w=width,h=h}
    -- The final frozen CSS overrides the early rounded/shadowed button style.
    nvgBeginPath(vg);nvgRect(vg,x,y,width,h);nvgFillColor(vg,nvgRGBA(43,33,29,255));nvgFill(vg)
    nvgBeginPath(vg);nvgRect(vg,x+1,y+1,width-2,h-2);nvgFillColor(vg,nvgRGBA(239,228,207,255));nvgFill(vg)
    canvas:fontSize(buttonSize);nvgTextLetterSpacing(vg,spacing);nvgTextAlign(vg,NVG_ALIGN_CENTER+NVG_ALIGN_TOP)
    nvgFillColor(vg,nvgRGBA(43,33,29,255));nvgText(vg,canvas.w/2,y+(h-Layout.normalHeight(buttonSize))/2,label)
    nvgGlobalAlpha(vg,1)
end
return End
