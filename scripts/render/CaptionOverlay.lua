-- Source main.js world-anchored captions and top hint, in logical NVG pixels.
local Layout=require('game.StoryPanelLayout')
local Layer={};Layer.__index=Layer
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
function Layer:draw(c,s,view)
    local wide=c.w/c.h>=2;local v=view.view or view
    for i=#self.items,1,-1 do if self.items[i].untilAt<=s.t then table.remove(self.items,i)end end
    for _,item in ipairs(self.items)do
        local inner=item.style=='inner' or item.style=='voice';local size=wide and math.max(12,math.min(14,c.h*.028)) or inner and 30 or 16
        local x,y=c.w*.5,c.h*.78;local maxWidth=wide and math.min(c.w*.4,360) or c.w*.8
        if inner then
            if item.style=='voice' then y=c.h*.86
            elseif c.channel then local p=c.channel=='browse' and s.browse or c.placement;x=(p.clearCenter or .25)*c.w;maxWidth=(p.clearWidth or .5)*c.w-28;y=c.h*.82 end
        else
            local world=anchor(view,s,item.speaker)+Vector3(0,math.min(1,(s.t-item.at)/item.life)*.4,0);local p=v.camera:WorldToScreenPoint(world)
            if v.cameraNode:WorldToLocal(world).z>0 then x=math.max(.08,math.min(.92,p.x))*c.w;y=math.max(.1,math.min(.92,p.y))*c.h else y=-100 end
        end
        local lines=Layout.wrap(item.text,maxWidth,size,function(t,z)return c:measure(t,z)end)
        local w=0;for _,line in ipairs(lines)do w=math.max(w,c:measure(line,size))end
        local h=#lines*size*1.45;local left=math.max(12,math.min(c.w-w-12,x-w/2));local top=y-(inner and h/2 or h+8)
        local life=item.untilAt-s.t;local alpha=math.min(1,(s.t-item.at)/item.life*8,life/item.life*3)
        nvgSave(c.vg);nvgGlobalAlpha(c.vg,math.max(0,alpha))
        if not inner then band(c,left-12,top-4,w+24,h+8)end
        c:lines(lines,left,top,size,size*1.45,inner and {246,244,238,255}or {16,32,63,255},inner);nvgRestore(c.vg)
    end
end
function Layer.hint(c,text,remaining)
    if remaining<=0 or text=='' then return end
    local wide=c.w/c.h>=2;if wide and c.channel=='browse' then return end
    local size=wide and 11 or 15;local lines=Layout.wrap(text,c.w*.6-44,size,function(t,z)return c:measure(t,z)end)
    local w=0;for _,line in ipairs(lines)do w=math.max(w,c:measure(line,size))end
    local x,y=(c.w-w)/2,wide and 8 or 18;local h=#lines*size*1.4
    nvgSave(c.vg);nvgGlobalAlpha(c.vg,math.min(1,remaining/.2));band(c,x-22,y,w+44,h+14)
    c:lines(lines,x,y+7,size,size*1.4,{16,32,63,255});nvgRestore(c.vg)
end
return Layer
