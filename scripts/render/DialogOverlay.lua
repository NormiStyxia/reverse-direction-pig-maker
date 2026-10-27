-- Raw NVG version of frozen dialog.js: dial portrait, typing and a light band.
local Layout=require('game.StoryPanelLayout')
local Ink=require('render.CaptionOverlay')
local Dialog={}
local function star(vg,x,y,r,color)
    nvgBeginPath(vg)
    for i=0,7 do local a=i*math.pi/4;local k=i%2==0 and r or r*.226
        if i==0 then nvgMoveTo(vg,x+math.sin(a)*k,y-math.cos(a)*k)else nvgLineTo(vg,x+math.sin(a)*k,y-math.cos(a)*k)end
    end
    nvgClosePath(vg);nvgFillColor(vg,nvgRGBA(table.unpack(color)));nvgFill(vg)
end
local glyphs={'▯','▒','░','■','□','#','%','&','0','1','2','3','4','5','6','7','8','9'}
local function stamp(c,d,t)
    -- Presentation-only RNG; never consume the game's simulation RNG.
    local tick=math.floor(t/.09)
    if c.dialogGlitchAt~=tick or c.dialogGlitchLine~=d then
        c.dialogGlitchAt=tick;c.dialogGlitchLine=d
        local out={};local seed=(tick*1103515245+12345)%2147483648
        for _,code in utf8.codes(d.stamp~='' and d.stamp or '23:1? · ▒▒')do
            local ch=utf8.char(code)
            if ch:match('%d')or ch=='?'or ch=='▒'then seed=(seed*1664525+1013904223)%4294967296;ch=glyphs[seed%#glyphs+1]end
            out[#out+1]=ch
        end
        c.dialogGlitch=table.concat(out)
    end
    return c.dialogGlitch
end
-- Multiply the frozen horizontal gradient by its vertical CSS mask. Thin,
-- non-antialiased strips avoid seams without allocating a texture each frame.
function Dialog.band(c,x,cy,w,dm,dream,alpha)
    local vg=c.vg;local h=dm*.82;local count=math.ceil(h*c.dpr)
    local rgb=dream and {248,250,255}or {7,11,22};local opacity=dream and 247 or 224
    nvgSave(vg);nvgShapeAntiAlias(vg,false)
    local paint=nvgLinearGradient(vg,x+w*.32,cy,x+w,cy,nvgRGBA(rgb[1],rgb[2],rgb[3],opacity),nvgRGBA(rgb[1],rgb[2],rgb[3],0))
    for i=0,count-1 do
        local v=(i+.5)/count;local mask=math.min(1,v/.28,(1-v)/.28)
        nvgGlobalAlpha(vg,alpha*mask);nvgBeginPath(vg)
        nvgRect(vg,x,cy-h/2+i*h/count,w,h/count);nvgFillPaint(vg,paint);nvgFill(vg)
    end
    nvgRestore(vg)
end
function Dialog.draw(canvas,story,layer)
    local d=story.dialog;if not d then return end
    local t=story.t-d.at;if t>d.hold+.6 then return end
    local c,vg=canvas,canvas.vg;local wide=c.w/c.h>=2;local compact=c.w>c.h and c.h<=600
    local phone=story.browse and story.browse.presentation~='look'and story.browse.k>.3 and story.browse or story.phone
    local panel=phone and phone.k>.3
    local alpha=math.min(1,t*10)*math.max(0,1-math.max(0,t-d.hold)/.6)
    local size=wide and math.max(12,math.min(14,c.h*.028)) or compact and (panel and math.max(12,math.min(15,c.h*.034))or math.max(14,math.min(17,c.h*.04)))or math.max(22,math.min(30,c.h*.039))
    local dm=wide and (panel and 36 or math.max(40,math.min(56,c.h*.1))) or compact and (panel and math.max(48,math.min(68,c.h*.14))or math.max(60,math.min(90,c.h*.2)))or (panel and math.max(88,math.min(150,c.h*.2)) or math.max(118,math.min(190,c.h*.24)))
    local left=(wide or compact)and 16 or 16+c.w*.03;local right=wide and c.w*.54 or compact and 16 or 16+c.w*.03
    if panel then
        local place=phone.frostEdge and phone or canvas.placement
        if place.layoutSide=='left' then left=(place.frostEdge or .5)*c.w+16;right=(wide or compact)and 16 or right
        else right=(1-(place.frostEdge or .5))*c.w+16 end
    end
    if compact and not wide and story.browse and story.browse.presentation=='look'and story.browse.k>.3 then right=170 end
    local gap=wide and (panel and 8 or 10) or compact and (panel and 10 or 14)or (panel and 14 or 22)
    local tw=math.max(1,c.w-left-right-dm-gap);local typed=Layout.utf8Prefix(d.text,math.min(utf8.len(d.text),math.floor(t/.055)))
    local spacing=size*(wide and .04 or .1)
    local measure=function(text,s)return Ink.width(c,text,s,spacing)end
    local lines=Layout.wrap(typed,tw,size,measure)
    local nameSize=wide and (panel and 10 or 11)or compact and (panel and 12 or 13)or 18
    local nameSpacing=nameSize*(wide and .16 or compact and .22 or .4)
    local meta=Layout.normalHeight(nameSize)+(wide and 4 or 8)
    local lineH=size*(wide and 1.45 or compact and 1.4 or 1.5)
    local padding=wide and 6 or compact and 8 or 14
    local height=math.max(dm,meta+#lines*lineH+padding*2)
    local bottom=wide and 32 or compact and 28 or 40+c.h*.04
    if c.touchUI and story:controlEnabled() then bottom=wide and 100 or 116 end
    local y=c.h-bottom-height;local cy=y+height/2;local x=left+dm+gap
    local dream=story.dialogTheme=='dream'
    local accent=dream and {1,64,196,255} or {232,194,122,255};local ink=dream and {11,29,79,255} or {243,241,234,255}
    nvgSave(vg);nvgGlobalAlpha(vg,alpha)
    if layer~='foreground' then
        Dialog.band(c,left+dm*.45,cy,math.max(1,c.w-right-left-dm*.45),dm,dream,alpha)
    end
    if layer=='background' then nvgRestore(vg);return end
    c:image('dialog/normi-'..d.face..(dream and '-blue' or '')..'.png',left+dm*.116,cy-dm*.384,dm*.768,dm*.768,'circle')
    nvgStrokeColor(vg,nvgRGBA(table.unpack(accent)));local cx=left+dm/2
    for i=0,59 do
        local a=i/60*math.pi*2+story.t*math.rad(3);local r0=dm*(i%5==0 and 81 or 88)/190;local r1=dm*94/190
        nvgBeginPath(vg);nvgMoveTo(vg,cx+math.sin(a)*r0,cy-math.cos(a)*r0);nvgLineTo(vg,cx+math.sin(a)*r1,cy-math.cos(a)*r1);nvgStrokeWidth(vg,i%5==0 and 1.3 or .7);nvgStroke(vg)
    end
    nvgBeginPath(vg);nvgCircle(vg,cx,cy,dm*74/190);nvgStrokeWidth(vg,1);nvgStroke(vg)
    local arc=-story.t*math.rad(24);nvgBeginPath(vg)
    for i=0,24 do local a=arc+i/24*math.pi/2;local ax,ay=cx+math.sin(a)*dm*89/190,cy-math.cos(a)*dm*89/190
        if i==0 then nvgMoveTo(vg,ax,ay)else nvgLineTo(vg,ax,ay)end
    end
    nvgStrokeWidth(vg,dm*3/190);nvgStrokeColor(vg,dream and nvgRGBA(53,121,241,255)or nvgRGBA(232,194,122,160));nvgStroke(vg)
    star(vg,cx,cy-dm/2,dm*11/190,accent)
    local textY=y+(height-meta-#lines*lineH)/2
    Ink.ink(c,'诺米',x,textY,nameSize,accent,nameSpacing)
    local stampText=dream and stamp(c,d,t)or d.stamp;local sx=x+Ink.width(c,'诺米',nameSize,nameSpacing)+(wide and 8 or 14)
    local sy=textY+2;local stampSize=wide and (panel and 8 or 9)or compact and 10 or 11
    if compact and not wide and panel then stampText=''end
    nvgGlobalAlpha(vg,alpha*.7)
    for _,code in utf8.codes(stampText)do
        local ch=utf8.char(code)
        if ch=='▯'then
            nvgBeginPath(vg);nvgRect(vg,sx+stampSize*.13,sy+stampSize*.12,stampSize*.34,stampSize*.8)
            nvgStrokeColor(vg,nvgRGBA(table.unpack(accent)));nvgStrokeWidth(vg,.8);nvgStroke(vg)
        else c:text(ch,sx,sy,stampSize,accent)end
        sx=sx+stampSize*.76
    end
    nvgGlobalAlpha(vg,alpha)
    for i,line in ipairs(lines)do Ink.ink(c,line,x,textY+meta+(i-1)*lineH+(lineH-Layout.normalHeight(size))/2,size,ink,spacing,dream and 'light'or 'dark')end
    if typed==d.text then
        local pulse=.5-.5*math.cos((t-utf8.len(d.text)*.055)*math.pi*2/1.1)
        local r=(wide and 3.5 or 6)*(.8+.35*pulse);local last=lines[#lines]or ''
        local sx=x+measure(last,size)+(wide and 8 or 14)+r
        local sy=textY+meta+(#lines-1)*lineH+lineH*.5
        nvgGlobalAlpha(vg,alpha*(.25+.75*pulse));star(vg,sx,sy,r,accent)
    end
    nvgRestore(vg)
end
return Dialog
