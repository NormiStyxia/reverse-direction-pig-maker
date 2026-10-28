-- Touch-only paper/ink dials, sharing the dialogue portrait's warm tick marks.
local Skin={}
local PAPER={243,237,220,245};local INK={26,35,47,255};local GOLD={232,194,122,210}
local function color(v) return nvgRGBA(table.unpack(v))end
local function circle(vg,x,y,r,fill,stroke)
    nvgBeginPath(vg);nvgCircle(vg,x,y,r)
    if fill then nvgFillColor(vg,color(fill));nvgFill(vg)end
    if stroke then nvgStrokeWidth(vg,1);nvgStrokeColor(vg,color(stroke));nvgStroke(vg)end
end
local function line(vg,x,y,x2,y2,tint,weight)
    nvgBeginPath(vg);nvgMoveTo(vg,x,y);nvgLineTo(vg,x2,y2)
    nvgStrokeColor(vg,color(tint));nvgStrokeWidth(vg,weight or 1);nvgStroke(vg)
end
local function ticks(vg,x,y,r,n,tint)
    for i=0,n-1 do
        local a=i*math.pi*2/n;local inner=r-(i%3==0 and 4 or 2)
        line(vg,x+math.sin(a)*inner,y-math.cos(a)*inner,x+math.sin(a)*r,y-math.cos(a)*r,tint)
    end
end
local function diamond(vg,x,y,r,tint)
    nvgBeginPath(vg);nvgMoveTo(vg,x,y-r);nvgLineTo(vg,x+r*.6,y)
    nvgLineTo(vg,x,y+r);nvgLineTo(vg,x-r*.6,y);nvgClosePath(vg)
    nvgStrokeColor(vg,color(tint));nvgStrokeWidth(vg,1.2);nvgStroke(vg)
end
function Skin.stick(c,r,dx,dy)
    local vg=c.vg;local cx,cy=r.x+r.w/2,r.y+r.h/2
    circle(vg,cx,cy,r.w/2-1,{12,20,30,120},{243,237,220,90})
    ticks(vg,cx,cy,r.w/2-5,24,GOLD)
    circle(vg,cx,cy,r.w*.32,nil,{243,237,220,55})
    local x,y=cx+dx*r.w*.32,cy+dy*r.h*.32
    line(vg,cx,cy,x,y,{232,194,122,145},2)
    circle(vg,x,y+2,r.knob/2,{7,11,22,100})
    circle(vg,x,y,r.knob/2,PAPER,GOLD)
    circle(vg,x,y,r.knob/2-3,nil,{26,35,47,60})
    diamond(vg,x,y,5,INK)
end
local function glyph(vg,id,x,y,tint)
    if id=='charge'then
        nvgBeginPath(vg);nvgMoveTo(vg,x+3,y-7);nvgLineTo(vg,x-5,y+1)
        nvgLineTo(vg,x,y+1);nvgLineTo(vg,x-2,y+7);nvgLineTo(vg,x+6,y-1)
        nvgLineTo(vg,x+1,y-1);nvgClosePath(vg);nvgFillColor(vg,color(tint));nvgFill(vg)
    elseif id=='rewind'then
        for i=0,1 do local sx=x-1+i*7
            nvgBeginPath(vg);nvgMoveTo(vg,sx,y-4);nvgLineTo(vg,sx-6,y)
            nvgLineTo(vg,sx,y+4);nvgClosePath(vg);nvgFillColor(vg,color(tint));nvgFill(vg)
        end
    elseif id=='cycle'then
        for i=0,1 do local sign=i==0 and 1 or -1;local yy=y+sign*3
            line(vg,x-sign*6,yy,x+sign*6,yy,tint,1.2)
            line(vg,x+sign*6,yy,x+sign*3,yy-sign*3,tint,1.2)
        end
    else
        diamond(vg,x,y,7,tint);line(vg,x-10,y,x-7,y,tint);line(vg,x+7,y,x+10,y,tint)
    end
end
function Skin.button(c,r,pressed)
    local vg=c.vg;local cx,cy=r.x+r.w/2,r.y+r.h/2
    nvgTranslate(vg,cx,cy+(pressed and 1.5 or 0))
    if pressed then nvgScale(vg,.95,.95)end
    nvgTranslate(vg,-cx,-cy)
    local light=r.primary or pressed;local tint=light and INK or PAPER
    if r.kind=='tool'then
        nvgBeginPath(vg);nvgRoundedRect(vg,r.x+1,r.y+1,r.w-2,r.h-2,5)
        nvgFillColor(vg,color(pressed and PAPER or {15,23,33,185}));nvgFill(vg)
        nvgStrokeWidth(vg,1);nvgStrokeColor(vg,color({232,194,122,135}));nvgStroke(vg)
        c:text(r.text,cx-c:measure(r.text,r.size)/2,cy-r.size*.6,r.size,tint)
        return
    end
    local radius=math.min(r.w,r.h)/2-1
    circle(vg,cx,cy+2,radius,{7,11,22,90})
    circle(vg,cx,cy,radius,light and PAPER or {15,23,33,195},GOLD)
    circle(vg,cx,cy,radius-4,nil,light and {26,35,47,70}or {243,237,220,55})
    if r.primary then ticks(vg,cx,cy,radius-1.5,24,{26,35,47,85})end
    glyph(vg,r.id,cx,r.y+(r.id=='rewind'and 12 or 18),tint)
    local y=r.id=='rewind'and r.y+20 or r.y+r.h-23
    c:text(r.text,cx-c:measure(r.text,r.size)/2,y,r.size,tint)
    if r.id=='rewind'then c:text('按住',cx-c:measure('按住',9)/2,r.y+r.h-14,9,light and INK or GOLD)end
end
return Skin
