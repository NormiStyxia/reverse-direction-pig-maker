-- Native room, cutouts, holograms and laptop from the frozen build-time export.
local Base=require('render.Chapter1Renderer')
local Renderer=setmetatable({},{__index=Base});Renderer.__index=Renderer
local function mix(a,b,k) return a+(b-a)*k end
local function smooth(v) v=math.max(0,math.min(1,v));return v*v*(3-2*v) end
local function rgb(hex)
    local n=tonumber(hex:sub(2),16);local c={}
    for i,p in ipairs({65536,256,1}) do local v=math.floor(n/p)%256/255;c[i]=v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end
    return c
end
local function colors(a,b,k) a,b=rgb(a),rgb(b);return {mix(a[1],b[1],k),mix(a[2],b[2],k),mix(a[3],b[3],k)} end
local function param(m,k,v) m:SetShaderParameter(k,Variant(v)) end
function Renderer.new(story,look)
    local s=setmetatable({},Renderer);s.data=require('game.data.Chapter03DormScene');s.view=require('render.StoreRenderer').new(s.data)
    s.ready=false;s.time=0;s.camYaw=0;s.look=look or {x=0,y=1.9,z=-.4};s.camDist=1;s.camPitch=math.rad(16);s.normiMaterial=0;s.slideMaterial=0
    return s
end
function Renderer:lighting(story)
    local v,H=self.view,self.data.handles;local k=smooth(story.duskK)
    local sky,ground=colors('#cfe0f5','#a98a86',k),colors('#9a8a7a','#3a2c2e',k)
    for _,m in ipairs(v.litMaterials) do
        param(m,'hemi_sky',Vector3(sky[1],sky[2],sky[3]));param(m,'hemi_ground',Vector3(ground[1],ground[2],ground[3]));param(m,'hemi_intensity',mix(1.7,.95,k))
    end
    local c=colors('#fff1d8','#ffaa66',k);v.sun.color=Color(c[1],c[2],c[3]);v.sun.brightness=mix(2.6,1.5,k)
    v.sun.node.position=Vector3(mix(-3,4,k),mix(9,4.5,k),12);v.sun.node:LookAt(Vector3(0,0,-.5))
    c=colors('#dfe8f2','#c98a6a',k);v.zone.fogColor=Color(c[1],c[2],c[3]);self:tint(H.drape,colors('#c4d8ec','#b9786a',k))
    c=colors('#ffffff','#c98a76',k);for i=1,3 do c[i]=c[i]*mix(1.15,.85,k) end;self:tint(H.window,c)
    v:updatePointUniforms()
end
function Renderer:update(dt,story)
    local v,H=self.view,self.data.handles;if not v.ready then return end
    self.ready=true;self.time=story.t;self:updateCamera(dt,story);self:actor(story)
    self:visible(H.parcel,story.parcel)
    local id=story.screenImage and H.screenLitMaterial or self.data.nodes[H.screen].materials[1]
    if self.slideMaterial~=id then self:material(H.screen,id);self.slideMaterial=id end
    self:visible(H.tablePig,story.pig.visible)
    local pig=story.pig;local p=pig.position;local node=v.nodes[H.tablePig]
    node.position=Vector3(p.x,p.y,-p.z);node.scale=Vector3(pig.scale,pig.scale,pig.scale);node.rotation=Quaternion(-math.deg(self.camYaw),Vector3(0,1,0))
    local frame=math.floor(pig.spinT)%8;local uv=Vector4(.25,.5,(frame%4)/4,math.floor(frame/4)/2)
    local mat=v.materials[self.data.nodes[H.tablePig].materials[1]];param(mat,'map_uv',uv);param(mat,'emit_uv',uv)
    for _,h in ipairs(H.tonight) do
        local active=h.answer==story.tonightAnswer;self:visible(h.id,active and story.tonightVisible)
        if active then
            local t=story.t;local flick=math.random()<.025 and .45 or 1
            for _,mid in ipairs(h.mats) do self:alpha(mid,math.min(1,(.84+math.sin(t*3+h.seed)*.05)*flick)) end
            self:alpha(h.edge,.75*flick);self:alpha(h.base,.5+math.sin(t*2+h.seed)*.15);param(v.materials[h.scan],'map_uv',Vector4(1,1,0,t*.35))
            v.nodes[h.baseNode].rotation=Quaternion(90,Vector3(1,0,0))*Quaternion(math.deg(t*.5),Vector3(0,0,1))
        end
    end
    local k=story.foldK;local root=v.nodes[H.root];local scale=math.max(.001,1-k)
    local q=Quaternion(math.deg(-k*.5),Vector3(1,0,0))*Quaternion(math.deg(-k*2.4),Vector3(0,1,0))*Quaternion(math.deg(k*.6),Vector3(0,0,1))
    local a=self.data.pivot;local pivot=Vector3(a[1],a[2],-a[3]);root.rotation=q;root.scale=Vector3(scale,scale,scale);root.position=pivot-q*(pivot*scale)
    self:lighting(story)
end
function Renderer:screenBounds()
    local n=self.view.nodes[self.data.handles.screen];local c=self.view.camera
    local x0,y0,x1,y1=1,1,0,0
    for _,p in ipairs({{-.35,-.21},{.35,-.21},{-.35,.21},{.35,.21}}) do
        local v=c:WorldToScreenPoint(n:LocalToWorld(Vector3(p[1],p[2],0)));x0=math.min(x0,v.x);y0=math.min(y0,v.y);x1=math.max(x1,v.x);y1=math.max(y1,v.y)
    end
    return x0,y0,x1,y1
end
return Renderer
