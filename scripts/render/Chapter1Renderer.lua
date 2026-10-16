-- Native meeting/office adapter. Frozen mesh data; no H5 runtime or screen-plane scene.
local MeshScene=require('render.StoreRenderer')
local Catalog=require('game.data.Chapter1Data')
local Renderer={};Renderer.__index=Renderer
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function mix(a,b,k) return a+(b-a)*k end
local function linear(v) v=v/255;return v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end
local function rgb(value)
    local n=tonumber(value:sub(2),16)
    return {linear(math.floor(n/65536)%256),linear(math.floor(n/256)%256),linear(n%256)}
end
local function colorMix(a,b,k) local c,d=rgb(a),rgb(b);return {mix(c[1],d[1],k),mix(c[2],d[2],k),mix(c[3],d[3],k)} end
---@param m Material
local function param(m,k,v) m:SetShaderParameter(k,Variant(v)) end
function Renderer.new(story,look) local self=setmetatable({},Renderer);self:init(story,look);return self end
function Renderer:init(story,look)
    self.data=require('game.data.Chapter1'..(story.mode=='morning' and 'Morning' or 'Meeting')..'Scene')
    self.view=MeshScene.new(self.data);self.ready=false;self.time=0;self.camYaw=0
    self.look=look or {x=0,y=2.05,z=-1.1};self.camDist=1;self.camPitch=math.rad(16)
    self.normiMaterial=0;self.slideMaterial=0
end
function Renderer:activate() self.view:activate() end
function Renderer:visible(id,on) if id and id~=0 and self.view.visible[id]~=on then self.view:setSourceVisible(id,on) end end
function Renderer:tint(id,c,a)
    local m=self.data.materials[id];param(self.view.materials[id],'tint',Vector4(c[1],c[2],c[3],a or m.opacity))
end
function Renderer:alpha(id,a) self:tint(id,self.data.materials[id].color,a) end
function Renderer:material(id,material)
    local m=self.view:sourceMaterial(self.data.nodes[id],material)
    for _,d in ipairs(self.view.sourceDrawables[id] or {}) do d:SetMaterial(0,m) end
end
function Renderer:lighting(story)
    local tn=story.tune;local v,H=self.view,self.data.handles;local morning=story.mode=='morning'
    local dk=morning and 0 or (story.lightDusk or 0)
    if self.lastDusk~=dk then
        local sky=colorMix(tn.hemiSky,tn.duskHemiSky,dk);local ground=colorMix(tn.hemiGround,tn.duskHemiGround,dk)
        for _,m in ipairs(v.litMaterials) do
            param(m,'hemi_sky',Vector3(sky[1],sky[2],sky[3]));param(m,'hemi_ground',Vector3(ground[1],ground[2],ground[3]))
            param(m,'hemi_intensity',mix(tn.hemiIntensity,tn.duskHemiIntensity,dk))
        end
        local c=morning and rgb('#fff8ec') or colorMix(tn.sunColor,tn.duskSunColor,dk)
        v.sun.color=Color(c[1],c[2],c[3]);v.sun.brightness=morning and tn.sunIntensity*1.05 or mix(tn.sunIntensity,tn.duskSunIntensity,dk)
        c=colorMix(tn.fogColor,tn.duskFog,dk);v.zone.fogColor=Color(c[1],c[2],c[3])
        self:tint(H.drape,colorMix(tn.drape,tn.duskDrape,dk))
        local tint=rgb(tn.duskSkyTint)
        for _,skyView in ipairs(H.skyViews) do
            local b=skyView.base
            self:tint(skyView.material,morning and {b[1]*.97,b[2]*1.02,b[3]*1.08} or {mix(b[1],tint[1]*1.05,dk*.85),mix(b[2],tint[2]*1.05,dk*.85),mix(b[3],tint[3]*1.05,dk*.85)})
        end
        for _,id in ipairs(H.duskPlanes) do self:alpha(id,dk*tn.duskGlow) end
        if H.sunGlow then self:alpha(H.sunGlow.material,dk*tn.duskGlow);v.nodes[H.sunGlow.id].position=Vector3(mix(-15,-18,dk),1.6,7.05) end
        self.lastDusk=dk
    end
    local lx=clamp(story.normi.pos.x,-19,morning and -8 or 2)
    if morning then v.sun.node.position=Vector3(lx+7,12,10);v.sun.node:LookAt(Vector3(lx,0,.5))
    else v.sun.node.position=Vector3(lx-mix(8,12,dk),mix(13,tn.duskSunHeight,dk),mix(4,13,dk));v.sun.node:LookAt(Vector3(lx,0,-mix(-1,.5,dk))) end
    v.lights[H.lamp].brightness=morning and 0 or tn.lamp
    v.lights[H.deskLamp].brightness=0
    -- Frozen M.update changes the lamp color to (1,.84,.62) at stress zero.
    self.data.nodes[H.lamp].light.color={1,.84,.62}
    v:updatePointUniforms()
end
function Renderer:updateCamera(dt,story,snap)
    local n=story.normi.pos;local request=story:cam();local k=snap and 1 or math.min(1,dt*3.2)
    local target=request and request.target or {x=clamp(n.x,-4,4)*.7,y=2.05,z=n.z*.45-1.1}
    local look=self.look;look.x=mix(look.x,target.x,k);look.y=mix(look.y,target.y,k);look.z=mix(look.z,target.z,k)
    k=snap and 1 or math.min(1,dt*2)
    self.camDist=mix(self.camDist,request and request.dist or 1,k);self.camPitch=mix(self.camPitch,request and request.pitch or math.rad(16),k)
    local distance=22*self.camDist*math.max(1,story.wideFrame/(graphics:GetWidth()/math.max(1,graphics:GetHeight())))
    local p=self.camPitch;local v=self.view
    v.cameraNode.position=Vector3(look.x,look.y+math.sin(p)*distance,-(look.z+math.cos(p)*distance));v.cameraNode:LookAt(Vector3(look.x,look.y,-look.z))
end
function Renderer:actor(story)
    local v,H=self.view,self.data.handles;local n=story.normi;local node=v.nodes[H.normi];local rock=n.walkRock*(1-n.collapse)
    node.position=Vector3(n.pos.x-math.sin(rock)*n.hang,n.pos.y+n.hang+n.lift+(math.cos(rock)-1)*n.hang,-n.pos.z)
    node.rotation=Quaternion(math.deg(-n.sway*n.side*(1-n.collapse)+rock),Vector3(0,0,1));node.scale=Vector3(n.flipScale or 1,1,1)
    self:visible(H.normi,n.visible)
    local frame=story:faceFrame();local face=frame~=nil and frame~=false
    local id=face and H.normiFaceMaterial or H.normiBaseMaterial
    if id~=self.normiMaterial then self:material(H.normi,id);self.normiMaterial=id end
    local columns=face and 3 or self.data.normiLayout.columns;local rows=face and 3 or self.data.normiLayout.rows
    frame=face and frame or n.pose
    local uv=Vector4(1/columns,1/rows,(frame%columns)/columns,math.floor(frame/columns)/rows)
    param(v.materials[id],'map_uv',uv);param(v.materials[id],'emit_uv',uv)
end
function Renderer:update(dt,story)
    local v,H=self.view,self.data.handles
    if not v.ready then return end
    self.ready=true;self.time=story.t
    self:updateCamera(dt,story);self:actor(story)
    for i,id in ipairs(H.clockHands) do
        local minutes=story.clockMin;local angle=i==1 and -((minutes/60)%12)/12*360 or -(minutes%60)/60*360
        v.nodes[id].rotation=Quaternion(angle,Vector3(0,0,1))
    end
    for i,person in ipairs(H.people) do
        local p=story.people[i];self:visible(person.flat,p.visible)
        v.nodes[person.flat].position=Vector3(0,p.y,0);v.nodes[person.flat].rotation=Quaternion(math.deg(p.rz),Vector3(0,0,1))
    end
    for _,p in ipairs(H.doorPanes) do local s=self.data.nodes[p.id].position;v.nodes[p.id].position=Vector3(s[1],s[2],-(p.z+p.side*story.doorK*.95)) end
    for _,p in ipairs(H.officePeople) do
        v.nodes[p.id].position=Vector3(p.home[1],p.home[2]+(story.frozen and 0 or math.max(0,math.sin(story.t*9+p.phase))*.012),-p.home[3])
    end
    for _,id in ipairs(H.billboards) do v.nodes[id].rotation=Quaternion(0,Vector3(0,1,0)) end
    self:visible(H.box,story.boxVisible);self:visible(H.deskBox,story.deskBoxVisible)
    local sm=story.slide and H.titleSlideMaterial or self.data.nodes[H.screen].materials[1]
    if sm~=self.slideMaterial then self:material(H.screen,sm);self.slideMaterial=sm end
    if H.tablePig~=0 then
        local p=Catalog.pivot;local pig=story.pig;local node=v.nodes[H.tablePig];self:visible(H.tablePig,pig.visible)
        node.position=Vector3(p.x,p.y,-p.z);node.scale=Vector3(pig.scale,pig.scale,pig.scale)
        local frame=math.floor(pig.spinT)%8;local uv=Vector4(.25,.5,(frame%4)/4,math.floor(frame/4)/2)
        local mat=v.materials[self.data.nodes[H.tablePig].materials[1]];param(mat,'map_uv',uv);param(mat,'emit_uv',uv)
    end
    for _,h in ipairs(H.tonight) do
        local active=h.answer==story.tonightAnswer;self:visible(h.id,active and story.tonightVisible)
        if active then
            local t=story.t;local flick=math.random()<.025 and .45 or 1
            for _,id in ipairs(h.mats) do self:alpha(id,math.min(1,(.84+math.sin(t*3+h.seed)*.05)*flick)) end
            self:alpha(h.edge,.75*flick);self:alpha(h.base,.5+math.sin(t*2+h.seed)*.15)
            param(v.materials[h.scan],'map_uv',Vector4(1,1,0,t*.35))
            v.nodes[h.baseNode].rotation=Quaternion(90,Vector3(1,0,0))*Quaternion(math.deg(t*.5),Vector3(0,0,1))
        end
    end
    local k=story.foldK;local root=v.nodes[H.root];local scale=math.max(.001,1-k)
    local q=Quaternion(math.deg(-k*.5),Vector3(1,0,0))*Quaternion(math.deg(-k*2.4),Vector3(0,1,0))*Quaternion(math.deg(k*.6),Vector3(0,0,1))
    local p=Catalog.pivot;local pivot=Vector3(p.x,p.y,-p.z)
    root.rotation=q;root.scale=Vector3(scale,scale,scale);root.position=pivot-q*(pivot*scale)
    self:lighting(story)
end
function Renderer:actorScreen(story) return self.view:actorScreen(story) end
function Renderer:cameraPosition() local p=self.view.cameraNode.position;return {x=p.x,y=p.y,z=-p.z} end
function Renderer:dispose() self.view:dispose() end
return Renderer
