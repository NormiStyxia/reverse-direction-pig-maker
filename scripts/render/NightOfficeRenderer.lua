-- Night-specific lights and coworker movement on the frozen native geometry.
local Base=require('render.Chapter1Renderer')
local R=setmetatable({},{__index=Base});R.__index=R
local function smooth(t,a,b)local k=math.max(0,math.min(1,(t-a)/(b-a)));return k*k*(3-2*k)end
local function param(m,k,v)m:SetShaderParameter(k,Variant(v))end
local function rgb(n)local out={};for i,p in ipairs({65536,256,1})do local v=math.floor(n/p)%256/255;out[i]=v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end;return out end
function R.new(story,look)
    local s=setmetatable({},R);s.data=require('game.data.Chapter03NightScene');s.view=require('render.StoreRenderer').new(s.data);s.ready=false;s.time=0;s.camYaw=0;s.look=look or {x=3.525,y=1.45,z=1.35};s.camDist=.4;s.camPitch=math.rad(9);s.normiMaterial=0;s.slideMaterial=0;return s
end
function R:spot(id,story)
    local v,H=self.view,self.data.handles
    if id=='monitor' then return v.nodes[H.screen].worldPosition+Vector3(0,.46,0)
    elseif id=='notes' then return v.nodes[H.screen].worldPosition+Vector3(-.62,.3,-.05)
    elseif id=='box' then return v.nodes[H.archive].worldPosition+Vector3(0,.62,0)
    elseif id=='window' then return Vector3(-6.775,3.6,5.6)
    elseif id=='door' then return Vector3(7.975,3.7,-1.9)
    elseif id=='empty' then local p=story.people['coworker-glasses'].home;return Vector3(p[1]+15.825,2.2,-p[3])end
end
function R:hud(c,s)
    if not s:controlEnabled()then return end
    local goal=s.pending and 'msg' or s.phase=='go' and (s.carrying and 'door' or 'box') or nil
    local target=goal~='msg' and goal or nil;local options=s:nearbyInteractions();local found=false
    for _,o in ipairs(options)do if o.id==target then found=true end end
    if target and not found then options[#options+1]={id=target,far=true}end
    local vg=c.vg
    for _,o in ipairs(options)do
        local w=self:spot(o.id,s)
        if w then local p=self.view.camera:WorldToScreenPoint(w)
            if self.view.cameraNode:WorldToLocal(w).z>0 and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1 then
                local x,y=p.x*c.w,p.y*c.h;local active=o.id==s.interactionId or o.far;local size=active and 9 or 6
                nvgBeginPath(vg);nvgMoveTo(vg,x,y-size);nvgLineTo(vg,x+size*.24,y-size*.24);nvgLineTo(vg,x+size,y);nvgLineTo(vg,x+size*.24,y+size*.24)
                nvgLineTo(vg,x,y+size);nvgLineTo(vg,x-size*.24,y+size*.24);nvgLineTo(vg,x-size,y);nvgLineTo(vg,x-size*.24,y-size*.24);nvgClosePath(vg)
                nvgFillColor(vg,o.id==target and nvgRGBA(232,194,122,255)or nvgRGBA(245,247,251,active and 230 or 140));nvgFill(vg)
            end
        end
    end
    if goal then
        local data={msg={'J','看手机','群里来消息了'},box={'F','拿上档案盒','去楼下便利店'},door={'F','去电梯间','下楼'}}
        local row=data[goal];local wide=c.w/c.h>=2;local size,subSize=wide and 12 or 19,wide and 10 or 15
        local label='    '..row[1]..'  '..row[2];local w=c:measure(label,size);local gap=wide and 6 or 10
        local x,y=(c.w-w-gap-c:measure(row[3],subSize))/2,wide and 44 or 66+c.h*.02
        nvgBeginPath(vg)
        for i=0,7 do local a=i*math.pi/4;local r=i%2==0 and size*.35 or size*.079
            local px,py=x+size*.4+math.sin(a)*r,y+size*.5-math.cos(a)*r
            if i==0 then nvgMoveTo(vg,px,py)else nvgLineTo(vg,px,py)end
        end
        nvgClosePath(vg);nvgFillColor(vg,nvgRGBA(232,194,122,255));nvgFill(vg)
        c:text(label,x,y,size,{232,194,122,255},true)
        c:text(row[3],x+w+gap,y+(size-subSize)/2,subSize,{240,237,223,191},true)
    end
end
function R:update(dt,story)
    local v,H=self.view,self.data.handles;if not v.ready then return end
    self:updateCamera(dt,story,not self.ready);self.ready=true;self.time=story.t;self:actor(story)
    self:visible(H.archive,not story.carrying);self:visible(H.asleep,story.asleep)
    local asleep=v.nodes[H.asleep];local a=self.data.nodes[H.asleep].position;asleep.position=Vector3(a[1],story.asleepY or 0,-a[3]);asleep.rotation=Quaternion(-math.deg(self.camYaw),Vector3(0,1,0))
    if story.waking then
        local c=v.nodes[H.chair];local home=self.data.nodes[H.chair];local k=1-(1-(story.chairSlide or 0))^3
        c.position=Vector3((-13.2+1.32)*(1-k)+home.position[1]*k,home.position[2],-((.75+.68)*(1-k)+home.position[3]*k))
        c.rotation=Quaternion(-90*(1-k)-math.deg(home.rotation and home.rotation[2] or 0)*k,Vector3(0,1,0))
    end
    for _,h in ipairs(H.people)do
        local p=story.people[h.who];self:visible(h.id,not p.standing);self:visible(h.stand,p.standing and not p.goneT)
        local n=v.nodes[h.stand];local t=p.leaveT or 0;local d=p.walkTo-p.home[1];local dur=math.abs(d)/4.2;local k=math.min(1,t/dur);local lift=smooth(t-dur,0,.8)
        n.position=Vector3(p.home[1]+d*k,.8+(k<1 and math.abs(math.sin(t*9))*.06 or 0)+lift*lift*7,-p.home[3]);n.rotation=Quaternion(-math.deg(self.camYaw),Vector3(0,1,0))
        local seated=v.nodes[h.id];seated.position=Vector3(p.home[1],p.home[2]+math.max(0,math.sin(story.t*9+h.phase))*.012,-p.home[3])
    end
    local lit=0
    for _,l in ipairs(H.lamps)do local k=story.lamps[l.who];v.lights[l.id].brightness=7*k;self:tint(l.tube,{.12+2.5*k,.12+2.4*k,.13+2.2*k});if l.who~='me' then lit=lit+k/4 end end
    local sky,ground=rgb(0x6f7f99),rgb(0x23262b)
    for _,m in ipairs(v.litMaterials)do param(m,'hemi_sky',Vector3(table.unpack(sky)));param(m,'hemi_ground',Vector3(table.unpack(ground)));param(m,'hemi_intensity',.26+.26*lit)end
    local c=rgb(0x8fa6d6);v.sun.color=Color(table.unpack(c));v.sun.brightness=.3+.28*lit;local x=story.normi.pos.x;v.sun.node.position=Vector3(x-6,11,14);v.sun.node:LookAt(Vector3(x,0,1));c=rgb(0x161b24);v.zone.fogColor=Color(table.unpack(c));v:updatePointUniforms()
end
return R
