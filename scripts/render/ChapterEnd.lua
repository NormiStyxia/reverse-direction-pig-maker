-- Raw NVG rendition of frozen #chapter-end; no separate UI framework.
local Ease=require('game.TitlePresentation')
local End={};End.__index=End
function End.new() return setmetatable({age=0,active=false,replay=false,press=false},End) end
function End:show() self.active=true;self.age=0;self.press=false end
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
    local top=(canvas.h-144)/2
    text('第一章 · 完',top,40,12,255)
    text('反方向的猪 · 谢谢游玩',top+61,15,3,153)
    local label='再玩一次';local width=canvas:measure(label,16)+24;local h=33
    local x=(canvas.w-width)/2;local y=top+111;self.button={x=x,y=y,w=width,h=h}
    nvgBeginPath(vg);nvgRoundedRect(vg,x+2,y+2,width,h,11);nvgFillColor(vg,nvgRGBA(43,33,29,115));nvgFill(vg)
    nvgBeginPath(vg);nvgRoundedRect(vg,x,y,width,h,11);nvgFillColor(vg,nvgRGBA(239,228,207,255));nvgFill(vg)
    nvgStrokeWidth(vg,2);nvgStrokeColor(vg,nvgRGBA(43,33,29,255));nvgStroke(vg)
    canvas:text(label,x+12,y+7,16,{43,33,29,255});nvgGlobalAlpha(vg,1)
end
return End
