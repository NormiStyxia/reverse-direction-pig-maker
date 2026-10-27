-- Frozen look-card.js / style.css, drawn in the existing raw NVG frame.
local Text=require('game.StoryPanelLayout')
local Card={}
local function clamp(v,a,b)return math.max(a,math.min(b,v))end
function Card.layout(c,data)
    local wide=c.w/c.h>=2;local short=c.w>c.h and c.h<=600;local grid=wide or short
    local small=c.w<=800;local w=wide and math.min(c.w*.38,380)or short and clamp(c.w*.43,250,400)or small and clamp(c.w*.3,180,260)or clamp(c.w*.27,230,360)
    local x=wide and 16 or short and 20 or 20+c.w*.04;local y=grid and 16 or 30+c.h*.06
    if c.externalHUD and x<72 then x=72 end -- Reserve the native home arrow; keep desktop source placement.
    local px=grid and 12 or small and 12 or 16;local pt=grid and 10 or small and 10 or 14;local pb=grid and 10 or small and 8 or 10
    local gap=wide and 10 or 12;local inner=w-px*2-2
    local iw=grid and (inner-gap)*(wide and .8/2.1 or .85/2.15)or inner
    local tw=grid and inner-gap-iw or inner;local ih=iw*.75
    local titleSize=wide and 12 or short and 13 or 17;local rowSize=wide and 11 or short and 12 or small and 13 or 15;local labelSize=wide and 9 or short and 10 or 13
    local measure=function(t,s)return c:measure(t,s)end
    local title=Text.wrap(data.title,tw,titleSize,function(t,size)return measure(t,size)+(utf8.len(t)or 0)*size*.04 end);local titleH=#title*(grid and titleSize*1.4 or Text.normalHeight(titleSize))
    local rows={};local textH=titleH
    for _,row in ipairs(data.rows)do
        local pad=wide and 3 or short and 4 or 5;local valueW=grid and tw or math.max(1,tw-74)
        local lines=Text.wrap(row[2],valueW,rowSize,measure)
        local lineH=grid and rowSize*1.4 or Text.normalHeight(rowSize);local labelH=grid and labelSize*1.4 or 0
        local h=pad*2+1+labelH+#lines*lineH
        rows[#rows+1]={label=row[1],lines=lines,h=h,pad=pad,lineH=lineH,labelH=labelH};textH=textH+h
    end
    local h=pt+pb+2+(grid and math.max(ih,textH)or ih+6+textH)
    local rx=wide and 16 or short and 12 or 16+c.w*.02;local bottom=grid and 8 or 20+c.h*.02
    local backSize=wide and 11 or short and 13 or 14;local backText='回去 · 走开也行'
    local bw=16+c:measure(backText,backSize)+(utf8.len(backText)or 0)*backSize*.12+(c.touchUI and 0 or 30)
    return {x=x,y=y,w=w,h=h,grid=grid,px=px,pt=pt,iw=iw,ih=ih,tw=tw,gap=gap,textH=textH,title=title,titleSize=titleSize,titleLine=grid and titleSize*1.4 or Text.normalHeight(titleSize),rows=rows,rowSize=rowSize,labelSize=labelSize,
        back={x=c.w-rx-bw,y=c.h-bottom-44,w=bw,h=44,size=backSize,text=backText}}
end
local function dashed(vg,x0,y0,x1,y1)
    local mx=(x0+x1)/2;local lastX,lastY=x0,y0;local along=0
    nvgBeginPath(vg)
    for i=1,80 do
        local t=i/80;local u=1-t;local x=u^3*x0+3*u*u*t*mx+3*u*t*t*mx+t^3*x1;local y=u^3*y0+3*u*u*t*y0+3*u*t*t*y1+t^3*y1
        local dx,dy=x-lastX,y-lastY;local length=math.sqrt(dx*dx+dy*dy);local consumed=0
        while consumed<length do
            local phase=along%8;local step=math.min(length-consumed,(phase<3 and 3 or 8)-phase)
            if step<.00001 then step=math.min(length-consumed,.00001)end
            if phase<3 then nvgMoveTo(vg,lastX+dx*consumed/length,lastY+dy*consumed/length);nvgLineTo(vg,lastX+dx*(consumed+step)/length,lastY+dy*(consumed+step)/length)end
            consumed=consumed+step;along=along+step
        end
        lastX,lastY=x,y
    end
    nvgStrokeColor(vg,nvgRGBA(232,194,122,217));nvgStrokeWidth(vg,1.2);nvgStroke(vg)
    nvgBeginPath(vg);nvgCircle(vg,x1,y1,4);nvgFillColor(vg,nvgRGBA(232,194,122,255));nvgFill(vg)
end
function Card.draw(c,b)
    local data=b.lookCard;if not data then return end
    local r=Card.layout(c,data);c.lookCardLayout=r;local vg=c.vg;local age=c.story.t-data.at;local enter=clamp(age/.45,0,1);local k=1-(1-enter)^3
    local angle=math.rad(-3+1.8*k);local scale=.96+.04*k;local dy=14*(1-k)
    nvgSave(vg);nvgGlobalAlpha(vg,math.min(1,b.k*1.3))
    if b.open and b.k>.5 and c.lookProject then
        local tx,ty=c.lookProject(data.target)
        if tx then
            local w=(math.cos(angle)*r.w+math.abs(math.sin(angle))*r.h)*scale;local h=(math.cos(angle)*r.h+math.abs(math.sin(angle))*r.w)*scale
            dashed(vg,r.x+r.w/2+w/2,r.y+r.h/2+dy-h*.08,tx,ty)
        end
    end
    nvgSave(vg);nvgTranslate(vg,r.x+r.w/2,r.y+r.h/2+dy);nvgRotate(vg,angle);nvgScale(vg,scale,scale);nvgTranslate(vg,-r.w/2,-r.h/2)
    nvgGlobalAlpha(vg,math.min(1,b.k*1.3)*k)
    nvgBeginPath(vg);nvgRect(vg,-12,-2,r.w+24,r.h+42);nvgFillPaint(vg,nvgBoxGradient(vg,0,14,r.w,r.h,0,34,nvgRGBA(0,0,0,89),nvgRGBA(0,0,0,0)));nvgFill(vg)
    nvgBeginPath(vg);nvgRect(vg,0,0,r.w,r.h);nvgFillColor(vg,nvgRGBA(251,248,239,245));nvgFill(vg);nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(43,33,29,255));nvgStroke(vg)
    local ix=r.px+1;local iy=r.pt+1+(r.grid and math.max(0,r.textH-r.ih)/2 or 0)
    c:image(data.img,ix,iy,r.iw,r.ih,false)
    local tx=r.grid and ix+r.iw+r.gap or ix;local y=r.grid and r.pt+1+math.max(0,r.ih-r.textH)/2 or iy+r.ih+6
    for i,line in ipairs(r.title)do local x=tx
        for _,code in utf8.codes(line)do local ch=utf8.char(code);c:text(ch,x,y+(i-1)*r.titleLine,r.titleSize,{43,33,29,255});x=x+c:measure(ch,r.titleSize)+r.titleSize*.04 end
    end
    y=y+#r.title*r.titleLine
    for _,row in ipairs(r.rows)do
        y=y+row.pad
        for dx=0,r.tw,5 do nvgBeginPath(vg);nvgRect(vg,tx+dx,y,math.min(3,r.tw-dx),1);nvgFillColor(vg,nvgRGBA(43,33,29,46));nvgFill(vg)end
        y=y+row.pad+1;c:text(row.label,tx,y,r.labelSize,{122,116,102,255})
        c:lines(row.lines,tx+(r.grid and 0 or 74),y+row.labelH,r.rowSize,row.lineH,{60,58,51,255});y=y+row.labelH+#row.lines*row.lineH
    end
    nvgRestore(vg)
    local back=r.back;local bx=back.x+8;local by=back.y+(44-back.size)/2
    if not c.touchUI then nvgBeginPath(vg);nvgRect(vg,bx,back.y+12,20,20);nvgStrokeColor(vg,nvgRGBA(243,241,234,180));nvgStrokeWidth(vg,1);nvgStroke(vg);c:text('F',bx+6,back.y+16,11,{243,241,234,191},true);bx=bx+28 end
    for _,code in utf8.codes(back.text)do local ch=utf8.char(code);c:text(ch,bx,by,back.size,{243,241,234,191},true);bx=bx+c:measure(ch,back.size)+back.size*.12 end
    c:addHit('close',back.text,back.x,back.y,back.w,back.h,b.open)
    nvgRestore(vg)
end
return Card
