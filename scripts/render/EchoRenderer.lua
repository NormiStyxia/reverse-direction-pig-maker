-- Exact exported room geometry with native UrhoX presentation. No browser runtime.
local MeshScene=require('render.StoreRenderer')
local Pose=require('game.EchoPose')
local Rain=require('game.EchoRain')
local RainSeeds=require('game.data.EchoRainSeeds')
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
    self.data=require('game.data.'..(run.theme=='meeting' and ('Ch1Echo'..run.answer..run.index) or ('EchoScene'..run.index)))
    self.view=MeshScene.new(self.data);self.loadId=run.loadId;self.ready=false
    self.rain=Rain.new(run.theme=='store' and RainSeeds[run.index] or {})
    self.rainVertices={};self.rainDirty=true
    self.bindings={};for i,c in ipairs(run.sim.room.crates) do self.bindings[c]=self.data.handles.crates[i] end
    if old then old:dispose() end
end
function Renderer:activate() self.view:activate() end
function Renderer:configure(run)
    local v=self.view;local sky=color(0x5d6b88);local ground=color(0x1c2430);local sun=color(0x9fb3dd)
    local meeting=run.theme=='meeting';local depth=(run.index-1)/math.max(1,#run.levels-1)
    if meeting then
        sky=color(0xf3e6cf);ground=color(0x6a5a48);sun=color(0xffe2b0);local dusk=color(0xffc590)
        for i=1,3 do sun[i]=sun[i]+(dusk[i]-sun[i])*depth end
    end
    for _,m in ipairs(v.litMaterials) do
        param(m,'hemi_sky',Vector3(sky[1],sky[2],sky[3]));param(m,'hemi_ground',Vector3(ground[1],ground[2],ground[3]));param(m,'hemi_intensity',meeting and 1.25 or .85)
    end
    v.sun.node.position=meeting and Vector3(9,13,-7) or Vector3(-7,14,-9);v.sun.node:LookAt(Vector3(0,0,0))
    v.sun.color=Color(sun[1],sun[2],sun[3]);v.sun.brightness=meeting and 1.5 or .9
    local a=color(meeting and 0xd9c7a8 or 0x1c2330);local b=color(meeting and 0xc99d82 or 0x262f42)
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
function Renderer:hologram(h,t,k)
    if not h then return end
    local v=self.view;local flick=math.random()<.025 and .45 or 1;local bag=h.sprite~=0
    local alpha=math.min(1,((bag and .82 or .84)+math.sin(t*3+h.seed)*(bag and .06 or .05)+k*(bag and .2 or .15))*flick)
    for _,id in ipairs(h.mats) do self:tint(id,alpha) end
    if h.edge~=0 then self:tint(h.edge,.75*flick+k*.2);param(v.materials[h.scan],'map_uv',Vector4(1,1,0,t*.35)) end
    self:tint(h.base,.5+math.sin(t*2+h.seed)*.15)
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
    local p=run.pig.pos;local k=math.min(1,dt*3.2);local look=self.look
    local meeting=run.theme=='meeting'
    look.x=look.x+((meeting and p.x*.12 or math.max(-4.5,math.min(4.5,p.x))*.85)-look.x)*k
    look.y=look.y+((meeting and .5 or .8)-look.y)*k;look.z=look.z+((meeting and (-.7+p.z*.08) or (p.z*.7+.4))-look.z)*k
    local spin=run.pig.spinSpeed
    local target=spin>.3 and (math.sin(self.time*.9)*.05+.12*spin) or 0
    self.yawOff=self.yawOff+(target-self.yawOff)*math.min(1,dt*2)
    self.fovMul=self.fovMul+(1+spin*.1-self.fovMul)*math.min(1,dt*3)
    self.camDist=self.camDist+((meeting and 1.32 or 1)-self.camDist)*math.min(1,dt*2)
    self.camPitch=self.camPitch+(math.rad(meeting and 23 or 16)-self.camPitch)*math.min(1,dt*2)
    local pitch=self.camPitch;local dist=22*self.camDist*(self.bridgeDistance or 1);local yaw=self.yawOff;local v=self.view
    v.camera.fov=24*self.fovMul
    v.cameraNode.position=Vector3(look.x+math.sin(yaw)*math.cos(pitch)*dist,look.y+math.sin(pitch)*dist,-(look.z+math.cos(yaw)*math.cos(pitch)*dist))
    if v.screenEffects then local x,y=v.screenEffects:camera(dt);v.cameraNode.position=v.cameraNode.position+Vector3(x,y,0) end
    v.cameraNode:LookAt(Vector3(look.x,look.y,-look.z))
    self.camYaw=math.atan(v.cameraNode.position.x-look.x,-v.cameraNode.position.z-look.z)
end
function Renderer:update(dt,run)
    if self.loadId~=run.loadId then self:load(run) end
    if not self.view.ready then return end
    if not self.ready then self:configure(run) end
    self.time=self.time+dt;self.pose:update(run,dt)
    self:updateRain(dt)
    local p,H,v=self.pose,self.data.handles,self.view
    self:node(H.root,p.root.position,p.root.quaternion,p.root.scale)
    for i,c in ipairs(p.crates) do
        local handle=self.bindings[c.source]
        if not handle then assert(c.source.kind=='now' and H.merged,'Missing merged crate');handle=H.merged;self.bindings[c.source]=handle end
        self:node(handle.id,c.position,nil,c.scale);v:setSourceVisible(handle.id,true)
        self:hologram(handle.holo,run.t,p.rwK)
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
    if v.visible[H.ring]~=p.exitOn then v:setSourceVisible(H.ring,p.exitOn) end
    v.nodes[H.ring].rotation=Quaternion(90,Vector3(1,0,0))*Quaternion(math.deg(p.ringAngle),Vector3(0,0,1))
    for i,id in ipairs(H.hands) do v.nodes[id].rotation=Quaternion(math.deg(p.hands[i]),Vector3(0,0,1)) end
    self:pig(H.pig,run.pig.pose,run.pig.frame)
    for i,g in ipairs(run.pig.ghosts) do
        local id=H.ghosts[i]
        if v.visible[id]~=g.visible then v:setSourceVisible(id,g.visible) end
        if g.visible then self:pig(id,g,g.frame);self:tint(self.data.nodes[id].materials[1],g.opacity,color(g.color)) end
    end
    v:updatePointUniforms();self:updateCamera(dt,run)
end
function Renderer:dispose() self.view:dispose() end
return Renderer
