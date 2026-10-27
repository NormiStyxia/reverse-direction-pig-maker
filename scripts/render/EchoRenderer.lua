-- Exact exported room geometry with native UrhoX presentation. No browser runtime.
local MeshScene=require('render.StoreRenderer')
local Pose=require('game.EchoPose')
local Rain=require('game.EchoRain')
local Renderer={}
Renderer.__index=Renderer
local function vec(a) return Vector3(a[1],a[2],-a[3]) end
local function quat(a) return Quaternion(a[4],-a[1],-a[2],a[3]) end
local function linear(v) v=v/255;return v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end
local function color(hex) return {linear(math.floor(hex/65536)%256),linear(math.floor(hex/256)%256),linear(hex%256)} end
---@param m Material
local function param(m,k,v) m:SetShaderParameter(k,Variant(v)) end
function Renderer.new(run,look)
    local self=setmetatable({},Renderer);self:init(run,look);return self
end
function Renderer:init(run,look)
    self.pose=Pose.new();self.look=look or {x=0,y=2.05,z=-1.1};self.yawOff=0;self.fovMul=1;self.camYaw=0;self.time=0
    self.camDist=1;self.camPitch=math.rad(16);self.bindings={}
    self:load(run);return self
end
function Renderer:load(run)
    local old=self.view
    self.data=require('game.data.Echo03'..run.theme..(run.theme=='store' and 'same' or run.answer)..run.index)
    self.view=MeshScene.new(self.data);self.loadId=run.loadId;self.ready=false
    self.rain=Rain.new(self.data.handles.rainSeeds or {})
    self.rainVertices={};self.rainDirty=true
    self.bindings={};for i,c in ipairs(run.sim.room.crates) do self.bindings[c]=self.data.handles.crates[i] end
    if old then old:dispose() end
end
function Renderer:activate() self.view:activate() end
function Renderer:configure(run)
    local v=self.view
    local palette={
        store={0x5d6b88,0x1c2430,.85,0x9fb3dd,0x9fb3dd,.9,{-7,14,9},0x1c2330,0x262f42},
        meeting={0xf3e6cf,0x6a5a48,1.25,0xffe2b0,0xffc590,1.5,{9,13,7},0xd9c7a8,0xc99d82},
        office={0xf0d6c0,0x5a4048,1.2,0xffc590,0xff9e6a,1.6,{-9,9,-6},0xd8b49c,0xb98a86},
        dorm={0xf4ecdc,0x7a6a58,1.35,0xfff1d8,0xffe0b0,1.45,{-8,11,-7},0xe6dccb,0xd9c6ae}}
    local T=assert(palette[run.theme]);local sky,ground,sun,dusk=color(T[1]),color(T[2]),color(T[4]),color(T[5])
    local meeting=run.theme~='store';local depth=(run.index-1)/math.max(1,#run.levels-1)
    for i=1,3 do sun[i]=sun[i]+(dusk[i]-sun[i])*depth end
    for _,m in ipairs(v.litMaterials) do
        param(m,'hemi_sky',Vector3(sky[1],sky[2],sky[3]));param(m,'hemi_ground',Vector3(ground[1],ground[2],ground[3]));param(m,'hemi_intensity',T[3])
    end
    v.sun.node.position=vec(T[7]);v.sun.node:LookAt(Vector3(0,0,0))
    v.sun.color=Color(sun[1],sun[2],sun[3]);v.sun.brightness=T[6]
    local a,b=color(T[8]),color(T[9])
    v.zone.fogColor=Color(a[1]+(b[1]-a[1])*depth,a[2]+(b[2]-a[2])*depth,a[3]+(b[3]-a[3])*depth)
    if #self.rain.drops>0 then
        ---@type CustomGeometry
        local line=v.nodes[self.data.handles.rain]:GetComponent('CustomGeometry')
        line:SetDynamic(true);self.rainLine=line
        for i=0,#self.rain.drops*2-1 do self.rainVertices[i+1]=line:GetVertex(0,i) end
    end
    self.ready=true
end
function Renderer:updateRain(dt)
    if #self.rain.drops==0 or (dt==0 and not self.rainDirty) then return end
    self.rain:update(dt,self.pose.rwK)
    for i,p in ipairs(self.rain.drops) do
        self.rainVertices[i*2-1].position=Vector3(p[1],p[2],-p[3])
        self.rainVertices[i*2].position=Vector3(p[1]+.04,p[2]+.4,-p[3])
    end
    self.rainLine:Commit();self.rainDirty=false
end
function Renderer:hologram(h,t,k,off)
    if not h then return end
    off=off or 0
    local v=self.view;local flick=math.random()<.025 and .45 or 1;local bag=h.sprite~=0
    local alpha=math.min(1,((bag and .82 or .84)+math.sin(t*3+h.seed)*(bag and .06 or .05)+k*(bag and .2 or .15))*flick)
    local offAlpha=bag and (math.sin(t*7+h.seed)>0 and .16 or .06) or .06
    for _,id in ipairs(h.mats) do self:tint(id,alpha+(offAlpha-alpha)*off) end
    if h.edge~=0 then
        local a=.75*flick+k*.2;local b=math.sin(t*7+h.seed)>0 and .5 or .15
        self:tint(h.edge,a+(b-a)*off);self:tint(h.scan,.35*(1-off));param(v.materials[h.scan],'map_uv',Vector4(1,1,0,t*.35))
    end
    self:tint(h.base,(.5+math.sin(t*2+h.seed)*.15)*(1-off*.7))
    v.nodes[h.baseNode].rotation=Quaternion(90,Vector3(1,0,0))*Quaternion(math.deg(t*.5),Vector3(0,0,1))
    if bag then v.nodes[h.sprite].rotation=Quaternion(-math.deg(self.camYaw),Vector3(0,1,0)) end
end
function Renderer:node(id,position,rotation,scale)
    local n=self.view.nodes[id]
    if position then n.position=vec(position) end
    if rotation then n.rotation=quat(rotation) end
    if scale then n.scale=Vector3(scale,scale,scale) end
end
function Renderer:tint(id,alpha,c)
    local m=self.data.materials[id];c=c or m.color
    param(self.view.materials[id],'tint',Vector4(c[1],c[2],c[3],alpha or m.opacity))
end
function Renderer:pig(id,pose,frame)
    local n=self.view.nodes[id];local p=pose.position;local s=pose.scale
    n.position=Vector3(p.x,p.y,-p.z)
    -- Source uses YXZ: yaw about Y, then charge roll about Z.
    n.rotation=Quaternion(-math.deg(pose.yaw),Vector3(0,1,0))*Quaternion(math.deg(pose.roll),Vector3(0,0,1))
    n.scale=Vector3(s.x,s.y,s.z)
    local uv=Vector4(.25,.5,(frame%4)/4,math.floor(frame/4)/2)
    local m=self.view.materials[self.data.nodes[id].materials[1]]
    param(m,'map_uv',uv);param(m,'emit_uv',uv)
end
function Renderer:updateCamera(dt,run)
    self.topK=(self.topK or 0)+((self.topOn and 1 or 0)-(self.topK or 0))*math.min(1,dt*2.6)
    local top=self.topK
    local p=run.pig.pos;local k=math.min(1,dt*3.2);local look=self.look
    local meeting=run.theme~='store'
    local target=run.exitCamera or {x=meeting and p.x*.12 or math.max(-4.5,math.min(4.5,p.x))*.85,y=meeting and .5 or .8,z=meeting and (-.7+p.z*.08) or (p.z*.7+.4)}
    target={x=target.x*(1-top),y=target.y*(1-top),z=target.z+(-.5-target.z)*top}
    look.x=look.x+(target.x-look.x)*k
    look.y=look.y+(target.y-look.y)*k;look.z=look.z+(target.z-look.z)*k
    local spin=run.pig.spinSpeed
    local target=spin>.3 and (math.sin(self.time*.9)*.05+.12*spin) or 0
    self.yawOff=self.yawOff+(target-self.yawOff)*math.min(1,dt*2)
    self.fovMul=self.fovMul+(1+spin*.1-self.fovMul)*math.min(1,dt*3)
    self.camDist=self.camDist+((meeting and 1.32 or 1)-self.camDist)*math.min(1,dt*2)
    self.camPitch=self.camPitch+(math.rad(meeting and 23 or 16)-self.camPitch)*math.min(1,dt*2)
    local pitch=self.camPitch;local dist=22*self.camDist*(self.bridgeDistance or 1);local yaw=self.yawOff;local v=self.view
    local fit=math.max(12.5*.62/math.tan(math.rad(12)),17.5/2/(math.tan(math.rad(12))*graphics:GetWidth()/math.max(1,graphics:GetHeight())))
    pitch=pitch+(math.rad(70)-pitch)*top;dist=dist+(fit-dist)*top;yaw=yaw*(1-top)
    v.camera.fov=24*(self.fovMul+(1-self.fovMul)*top)
    v.cameraNode.position=Vector3(look.x+math.sin(yaw)*math.cos(pitch)*dist,look.y+math.sin(pitch)*dist,-(look.z+math.cos(yaw)*math.cos(pitch)*dist))
    if v.screenEffects then local x,y=v.screenEffects:camera(dt);v.cameraNode.position=v.cameraNode.position+Vector3(x,y,0) end
    v.cameraNode:LookAt(Vector3(look.x,look.y,-look.z))
    self.camYaw=math.atan(v.cameraNode.position.x-look.x,-v.cameraNode.position.z-look.z)
end
function Renderer:update(dt,run)
    if self.loadId~=run.loadId then self:load(run) end
    if not self.view.ready then return end
    if not self.ready then self:configure(run) end
    self.time=self.time+dt;self.pose:update(run,dt);run.topK=self.topK or 0
    self:updateRain(dt)
    local p,H,v=self.pose,self.data.handles,self.view
    self:node(H.root,p.root.position,p.root.quaternion,p.root.scale)
    for i,c in ipairs(p.crates) do
        local handle=self.bindings[c.source]
        if not handle then
            assert(c.source.kind=='now' and H.merged,'Missing merged crate')
            handle=H.mergedByOrigin and H.mergedByOrigin[c.source.origin] or H.merged;self.bindings[c.source]=handle
        end
        self:node(handle.id,c.position,nil,c.scale);v:setSourceVisible(handle.id,true)
        self:hologram(handle.holo,run.t,p.rwK,c.off)
        for _,id in ipairs(handle.glow) do
            local e=self.data.materials[id].emissive
            param(v.materials[id],'emissive_color',Vector3(e[1]*c.glow,e[2]*c.glow,e[3]*c.glow))
        end
    end
    for _,c in ipairs(p.faded) do local handle=self.bindings[c.source]
        if handle then self:node(handle.id,c.position,nil,c.scale);v:setSourceVisible(handle.id,c.visible);if c.visible then self:hologram(handle.holo,run.t,c.holoK) end end
    end
    for i,c in ipairs(p.cabinets) do self:node(H.cabinets[i].pivot,c.position,c.quaternion);self:node(H.cabinets[i].body,c.body) end
    for _,pane in ipairs(H.panes) do self:node(pane.id,{pane.side*p.doorOffset,0,0}) end
    self:tint(H.glow,p.doorGlow);self:tint(H.sign,nil,{p.sign,p.sign,p.sign})
    for i,c in ipairs(p.plates) do self:tint(H.plates[i],p.plateAlpha[i],c) end
    if H.curtain then
        self:tint(H.curtain.material,p.curtain.alpha);v.nodes[H.curtain.id].scale=Vector3(p.curtain.scale,1,1)
        param(v.materials[H.curtain.material],'map_uv',Vector4(4,1,p.curtain.offset,0))
    end
    self:tint(H.exit,p.exitAlpha)
    v:setSourceVisible(H.ring,p.exitK>.02);self:tint(H.ringMat,p.exitK*.95)
    v.nodes[H.ring].scale=Vector3(p.ringScale,p.ringScale,p.ringScale)
    local es=p.exitScale;v.nodes[H.exitNode].scale=Vector3(es[1],es[2],es[3])
    local ex=run.levels[run.index].exit;v.nodes[H.exitNode].position=Vector3(ex[1],2.4*es[2],-ex[2])
    v:setSourceVisible(H.dashed.id,p.exitK<.98);self:tint(H.dashed.material,.75*(1-p.exitK))
    v.nodes[H.dashed.id].rotation=Quaternion(90,Vector3(1,0,0))*Quaternion(math.deg(run.t*.08),Vector3(0,0,1))
    local function smooth(x,a,b) local k=math.max(0,math.min(1,(x-a)/(b-a)));return k*k*(3-2*k) end
    for _,q in ipairs(H.papers) do
        local k=(p.paperT*q.spin*.6+q.ph)%1;local a=q.ph*17+k*math.pi*3.4
        v:setSourceVisible(q.id,p.exitK>.02);v.nodes[q.id].position=Vector3(math.cos(a)*q.r,.2+k*4.4,-math.sin(a)*q.r)
        v.nodes[q.id].rotation=Quaternion(-math.deg(math.sin(run.t*1.7+q.ph*9)*.45),Vector3(1,0,0))*Quaternion(math.deg(a-math.pi/2),Vector3(0,1,0))*Quaternion(math.deg(math.sin(run.t*1.3+q.ph*5)*.35),Vector3(0,0,1))
        self:tint(q.material,p.exitK*smooth(k,0,.12)*(1-smooth(k,.78,1)))
    end
    v.nodes[H.ring].rotation=Quaternion(90,Vector3(1,0,0))*Quaternion(math.deg(p.ringAngle),Vector3(0,0,1))
    for i,id in ipairs(H.hands) do v.nodes[id].rotation=Quaternion(math.deg(p.hands[i]),Vector3(0,0,1)) end
    self:pig(H.pig,run.pig.pose,run.pig.frame);v:setSourceVisible(H.pig,(self.topK or 0)<=.5)
    for i,g in ipairs(run.pig.ghosts) do
        local id=H.ghosts[i]
        if v.visible[id]~=g.visible then v:setSourceVisible(id,g.visible) end
        if g.visible then self:pig(id,g,g.frame);self:tint(self.data.nodes[id].materials[1],g.opacity,color(g.color)) end
    end
    v:updatePointUniforms();self:updateCamera(dt,run)
end
function Renderer:dispose() self.view:dispose() end
return Renderer
