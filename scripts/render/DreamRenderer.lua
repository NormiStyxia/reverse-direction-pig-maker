-- Native geometry and camera for dream.js; every floating object is a real node.
local Base=require('render.Chapter1Renderer')
local R=setmetatable({},{__index=Base});R.__index=R
local function mix(a,b,k)return a+(b-a)*k end
local function param(m,k,v)m:SetShaderParameter(k,Variant(v))end
local function euler(a)
    return Quaternion(-math.deg(a[1]),Vector3(1,0,0))*Quaternion(-math.deg(a[2]),Vector3(0,1,0))*Quaternion(math.deg(a[3]),Vector3(0,0,1))
end
function R.new(story)
    local s=setmetatable({},R);s.data=require('game.data.Chapter03DreamScene');s.view=require('render.StoreRenderer').new(s.data);s.ready=false;s.time=0;s.camYaw=.06;s.look={x=-13.4,y=2.5,z=.7};s.camDist=.32;s.camPitch=math.rad(3);s.normiMaterial=0;return s
end
function R:updateCamera(dt,story,snap)
    local request=story:cam();if not request then return end;snap=snap or request.snap
    local k=snap and 1 or math.min(1,dt*3.2);self.look.x=mix(self.look.x,request.target.x,k);self.look.y=mix(self.look.y,request.target.y,k);self.look.z=mix(self.look.z,request.target.z,k)
    k=snap and 1 or math.min(1,dt*2);self.camDist=mix(self.camDist,request.dist,k);self.camPitch=mix(self.camPitch,request.pitch,k);self.camYaw=mix(self.camYaw,request.yaw or 0,k)
    local dolly=story.dolly or 0;local dz=dolly>0 and math.sin((1-dolly)*math.pi)or 0;local fov=24*(1+dz*1.5);local distance=22*math.tan(math.rad(12))/math.tan(math.rad(fov/2))*self.camDist
    local yaw,p=self.camYaw,self.camPitch;local l=self.look;local v=self.view
    v.camera.fov=fov;v.cameraNode.position=Vector3(l.x+math.sin(yaw)*math.cos(p)*distance,l.y+math.sin(p)*distance,-(l.z+math.cos(yaw)*math.cos(p)*distance))
    if v.screenEffects then local x,y=v.screenEffects:camera(dt);v.cameraNode.position=v.cameraNode.position+Vector3(x,y,0)end
    v.cameraNode:LookAt(Vector3(l.x,l.y,-l.z))
end
function R:update(dt,story)
    local v,H=self.view,self.data.handles;if not v.ready then return end
    self:updateCamera(dt,story,not self.ready);self.ready=true;self.time=story.t
    for id,tr in pairs(story.transforms)do local n=v.nodes[id];local p,s=tr.p,tr.s;n.position=Vector3(p[1],p[2],-p[3]);n.scale=Vector3(s[1],s[2],s[3]);if tr.r then n.rotation=euler(tr.r)end;self:visible(id,tr.visible)end
    for id,a in pairs(story.alphas)do self:alpha(id,a)end
    self:actor(story);local actor=v.nodes[H.normi];actor.rotation=Quaternion(-math.deg(self.camYaw),Vector3(0,1,0))*actor.rotation
    local p=story.gp;self:visible(H.guide,story.guideVisible);local n=v.nodes[H.guide];n.position=Vector3(p.x,p.y+(p.bob or 0),-p.z);n.rotation=Quaternion(-math.deg(self.camYaw),Vector3(0,1,0));n.scale=Vector3(.66,.66,.66)
    local uv=Vector4(.25,.5,(p.frame%4)/4,math.floor(p.frame/4)/2);local mat=v.materials[self.data.nodes[H.guide].materials[1]];param(mat,'map_uv',uv);param(mat,'emit_uv',uv)
    for _,m in ipairs(v.litMaterials)do param(m,'hemi_sky',Vector3(1,1,1));param(m,'hemi_ground',Vector3(.346704,.456411,.791298));param(m,'hemi_intensity',1.25)end
    v.sun.color=Color(1,1,1);v.sun.brightness=1.6;local x=story.normi.pos.x;v.sun.node.position=Vector3(x-5,13,-6);v.sun.node:LookAt(Vector3(x+2,0,1.5));v.zone.fogColor=Color(.854993,.887923,.955973);v:updatePointUniforms()
end
return R
