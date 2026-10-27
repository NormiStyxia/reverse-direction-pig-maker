-- Source main.js world-anchored captions and top hint, in logical NVG pixels.
local Layout=require('game.StoryPanelLayout')
local Layer={};Layer.__index=Layer
function Layer.width(c,text,size,spacing)
    return c:measure(text,size)+(utf8.len(text)or 0)*(spacing or 0)
end
function Layer.ink(c,text,x,y,size,color,spacing,shadow)
    local vg=c.vg
    local function draw(dx,dy,tint,blur)
        nvgFontBlur(vg,blur or 0);local xx=x+dx
        for _,cp in utf8.codes(text)do local ch=utf8.char(cp);c:text(ch,xx,y+dy,size,tint);xx=xx+c:measure(ch,size)+(spacing or 0)end
    end
    nvgSave(vg)
    if shadow=='light'then draw(0,0,{250,252,255,242},10);draw(0,0,{250,252,255,230},3)
    elseif shadow then draw(0,0,{5,10,20,115},16);draw(0,1,{5,10,20,179},2)end
    draw(0,0,color,0);nvgRestore(vg)
end
function Layer.new()return setmetatable({items={}},Layer)end
function Layer:event(e,t)
    if e.kind=='clearCaptions' then for _,c in ipairs(self.items)do c.untilAt=math.min(c.untilAt,t+.25)end;return end
    if e.kind~='caption' then return end
    local style=e.style or 'soft';local speaker=e.speaker or 'normi'
    if style=='soft' then for _,c in ipairs(self.items)do if c.style=='soft' and t-c.at<1.4 then return end end end
    for _,c in ipairs(self.items)do if c.speaker==speaker then c.untilAt=math.min(c.untilAt,t+.3)end end
    local life=style=='voice' and 5.2 or style=='inner' and 3.2 or style:sub(1,4)=='talk' and 1.9 or 2.4
    self.items[#self.items+1]={text=e.text,style=style,speaker=speaker,at=t,life=life,untilAt=t+life}
end
local function band(c,x,y,w,h)
    local vg=c.vg;nvgBeginPath(vg);nvgRect(vg,x,y,w,h);nvgFillColor(vg,nvgRGBA(245,247,251,224));nvgFill(vg)
    nvgBeginPath(vg)
    for _,p in ipairs({{x,y,1,1},{x+w,y,-1,1},{x,y+h,1,-1},{x+w,y+h,-1,-1}})do
        nvgMoveTo(vg,p[1]+p[3]*9,p[2]);nvgLineTo(vg,p[1],p[2]);nvgLineTo(vg,p[1],p[2]+p[4]*9)
    end
    nvgStrokeWidth(vg,1);nvgStrokeColor(vg,nvgRGBA(16,32,63,180));nvgStroke(vg)
end
Layer.band=band
local function anchor(view,s,speaker)
    local v=view.view or view;local H=(view.data or v.data).handles
    if type(speaker)=='table' then return Vector3(speaker.x,speaker.y,-speaker.z)end
    if speaker=='normi' then local p=s.normi.pos;return Vector3(p.x,p.y+(s.sitting and 2.25 or 2.75),-p.z)end
    if speaker=='clerk' then return Vector3(6.2,.82+1.85*.88,-.05)end
    for _,p in ipairs(require('game.data.Chapter1Data').people)do
        if p.kind==speaker then return Vector3(p.home.x,.72+p.h*.86,-p.home.z)end
    end
    if H.people then for _,h in ipairs(H.people)do if h.who==speaker then
        local stand=s.people and s.people[h.who] and s.people[h.who].standing
        local world=v.nodes[stand and h.stand or h.id].worldPosition
        local height=.8+2.45*.95
        if not stand then
            local data=view.data or v.data;local source=data.nodes[h.id];local points=data.geometries[source.geometry].attributes.position.array;local top=0
            for j=2,#points,3 do top=math.max(top,points[j])end
            height=world.y+top*.92
        end
        return Vector3(world.x,height,world.z)
    end end end
    local id=H[speaker];if type(id)=='number' and v.nodes[id]then return v.nodes[id].worldPosition+Vector3(0,1.2,0)end
    local p=s.normi.pos;return Vector3(p.x,p.y+2.75,-p.z)
end
local function dashed(c,x,y,w,h)
    local vg=c.vg;nvgBeginPath(vg);nvgRect(vg,x,y,w,h);nvgFillColor(vg,nvgRGBA(245,247,251,224));nvgFill(vg)
    nvgBeginPath(vg)
    for i=0,w-1,6 do local d=math.min(3,w-i);nvgRect(vg,x+i,y,d,1);nvgRect(vg,x+i,y+h-1,d,1)end
    for i=0,h-1,6 do local d=math.min(3,h-i);nvgRect(vg,x,y+i,1,d);nvgRect(vg,x+w-1,y+i,1,d)end
    nvgFillColor(vg,nvgRGBA(16,32,63,107));nvgFill(vg)
end
function Layer:draw(c,s,view)
    local wide=c.w/c.h>=2;local compact=c.w>c.h and c.h<=600;local v=view.view or view
    local looking=c.channel and ((s.phone and s.phone.k or 0)>.3 or(s.browse and s.browse.k or 0)>.3)
    local innerShown=false
    for i=#self.items,1,-1 do
        local item=self.items[i]
        if item.untilAt<=s.t or(looking and item.style=='inner'and innerShown)then table.remove(self.items,i)
        elseif looking and item.style=='inner'then innerShown=true end
    end
    for _,item in ipairs(self.items)do
        local voice=item.style=='voice';local inner=item.style=='inner' or voice;local sharp=item.style:find('sharp',1,true)
        local size=wide and math.max(12,math.min(14,c.h*.028))or compact and(inner and not looking and math.max(14,math.min(17,c.h*.04))or math.max(12,math.min(15,c.h*.034)))or voice and(c.w<=600 and 21 or 30)or inner and(looking and 25 or 30)or sharp and 19 or 16
        local spacing=wide and size*.04 or compact and inner and size*.08 or voice and size*(c.w<=600 and .18 or .32)or inner and size*.12 or item.style:sub(1,4)=='talk'and size*.06 or 0
        local x,y=c.w*.5,c.h*.78;local maxWidth=wide and math.min(c.w*.4,360)or compact and c.w*.7 or c.w*.8
        if inner then
            if voice then y=c.h*.86
            elseif looking then local p=c.channel=='browse' and s.browse or c.placement;x=(p.clearCenter or .25)*c.w;maxWidth=math.min(maxWidth,(p.clearWidth or .5)*c.w-28);y=c.h*.82 end
        else
            local world=anchor(view,s,item.speaker)+Vector3(0,math.min(1,(s.t-item.at)/item.life)*.4,0);local p=v.camera:WorldToScreenPoint(world)
            if v.cameraNode:WorldToLocal(world).z>0 then x=math.max(.08,math.min(.92,p.x))*c.w;y=math.max(.1,math.min(.92,p.y))*c.h else y=-100 end
        end
        local measure=function(text,z)return Layer.width(c,text,z,spacing)end
        local lines=Layout.wrap(item.text,maxWidth,size,measure)
        local w=0;for _,line in ipairs(lines)do w=math.max(w,measure(line,size))end
        local lineH=(wide or compact)and size*1.45 or Layout.normalHeight(size)
        local h=#lines*lineH;local left=math.max(12,math.min(c.w-w-12,x-w/2));local top=y-(inner and h/2 or h+9)
        local life=item.untilAt-s.t;local alpha=math.min(1,(s.t-item.at)/item.life*8,life/item.life*3)
        local dream=s.mode=='dream';local color=voice and {11,29,79,255}or inner and(dream and {16,32,63,255}or {246,244,238,255})or sharp and {90,31,44,255}or {16,32,63,255}
        nvgSave(c.vg);nvgGlobalAlpha(c.vg,math.max(0,alpha))
        if not inner then
            if item.style=='soft'then dashed(c,left-13,top-5,w+26,h+10)else band(c,left-13,top-5,w+26,h+10)end
        end
        for i,line in ipairs(lines)do Layer.ink(c,line,left,top+(i-1)*lineH+(lineH-Layout.normalHeight(size))/2,size,color,spacing,inner and((dream or voice)and 'light'or 'dark'))end
        nvgRestore(c.vg)
    end
end
function Layer.clock(c,s)
    if not s.clockShow then return end
    if c.clockStory~=s then c.clockStory=s;c.clockAt=s.t end
    local wide=c.w/c.h>=2;local compact=c.w>c.h and c.h<=600
    local size=wide and 16 or compact and 18 or 30;local text=s:hm();local spacing=size*.08
    local x=c.w-(compact and 16 or 22)-Layer.width(c,text,size,spacing)
    local y=wide and s:canSkip()and 44 or compact and 12 or 18
    local alpha=require('game.TitlePresentation').bezier(math.max(0,math.min(1,(s.t-c.clockAt)/.8)),.25,.1,.25,1)
    nvgSave(c.vg);nvgGlobalAlpha(c.vg,alpha)
    Layer.ink(c,text,x+2,y+2,size,{43,33,29,255},spacing)
    Layer.ink(c,text,x,y,size,s.clockSpin and {255,230,168,255}or {246,238,223,255},spacing)
    nvgRestore(c.vg)
end
function Layer.touchHint(text)
    return (text:gsub('J%s*/%s*空格%s*看手机','点「手机」查看消息')
        :gsub('WASD%s*/%s*方向键%s*走动','左下摇杆走动'):gsub('WASD%s*走动','左下摇杆走动'):gsub('WASD%s*移动','左下摇杆移动')
        :gsub('按住%s*K%s*/%s*Shift','按住「倒带」'):gsub('按住%s*K','按住「倒带」')
        :gsub('J%s*/%s*空格','点「冲撞」'):gsub('R%s*重来','点「重来」'):gsub('按%s*F','点「交互」')
        :gsub('%f[%w]F%f[%W]%s*','点「交互」'):gsub('Tab%s*换一个','点「换一个」'))
end
function Layer.hint(c,text,remaining)
    if remaining<=0 or text=='' then return end
    if c.touchUI then text=Layer.touchHint(text)end
    local wide=c.w/c.h>=2;if wide and c.channel=='browse' then return end
    local size=wide and 11 or 15;local spacing=size*.16;local measure=function(t,z)return Layer.width(c,t,z,spacing)end;local lines=Layout.wrap(text,c.w*.6-44,size,measure)
    local w=0;for _,line in ipairs(lines)do w=math.max(w,measure(line,size))end
    local x,y=(c.w-w)/2,wide and 8 or 18;local lineH=Layout.normalHeight(size);local h=#lines*lineH
    nvgSave(c.vg);nvgGlobalAlpha(c.vg,math.min(1,remaining/.2));band(c,x-23,y,w+46,h+16)
    for i,line in ipairs(lines)do Layer.ink(c,line,x,y+8+(i-1)*lineH,size,{16,32,63,255},spacing)end;nvgRestore(c.vg)
end
-- Scene readiness is separate from the fade. Keep three prepared updates covered
-- to allow the camera/post setup to settle; this is not a GPU completion fence.
function Layer.loadStep(c,dt,ready)
    dt=math.max(0,dt)
    c.loadingTime=(c.loadingTime or 0)+math.max(0,dt)
    if not ready or not c.fontReady then c.loadingFrames=0;c.loadingAlpha=1
    else
        c.loadingFrames=(c.loadingFrames or 0)+1
        if c.loadingFrames>=3 then c.loadingAlpha=math.max(0,(c.loadingAlpha or 1)-math.min(dt,.05)/.25)end
    end
    c.loading=(c.loadingAlpha or 1)>0
    return c.loading
end
function Layer.drawLoading(c)
    local a=c.loadingAlpha or (not c.fontReady and 1 or 0)
    if a<=0 then return end
    local vg=c.vg;local x,y=c.w/2,c.h/2;local radius=c.w/c.h>=2 and 24 or 32
    nvgSave(vg);nvgGlobalAlpha(vg,a)
    nvgBeginPath(vg);nvgRect(vg,0,0,c.w,c.h);nvgFillColor(vg,nvgRGBA(248,250,253,255));nvgFill(vg)
    nvgStrokeColor(vg,nvgRGBA(10,60,184,145));nvgStrokeWidth(vg,1)
    for i=0,11 do local angle=i*math.pi/6
        nvgBeginPath(vg);nvgMoveTo(vg,x+math.sin(angle)*(radius-4),y-math.cos(angle)*(radius-4));nvgLineTo(vg,x+math.sin(angle)*radius,y-math.cos(angle)*radius);nvgStroke(vg)
    end
    local angle=-(c.loadingTime or 0)*2.4
    nvgBeginPath(vg);nvgMoveTo(vg,x,y);nvgLineTo(vg,x+math.sin(angle)*radius*.65,y-math.cos(angle)*radius*.65)
    nvgStrokeWidth(vg,2);nvgStrokeColor(vg,nvgRGBA(10,60,184,255));nvgStroke(vg)
    if c.fontReady then
        local text='正在进入场景…';local size=c.w/c.h>=2 and 12 or 15
        Layer.ink(c,text,x-Layer.width(c,text,size,size*.12)/2,y+radius+18,size,{10,60,184,255},size*.12)
    end
    nvgRestore(vg)
end
return Layer
