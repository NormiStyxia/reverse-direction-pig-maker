-- Frozen 8.4-second spiral reveal: existing completed rooms, gold helix, breakup.
local Finale={};Finale.__index=Finale
local function smooth(t,a,b)local u=math.max(0,math.min(1,(t-a)/(b-a)));return u*u*(3-2*u)end
function Finale.new(view,history,run)
 local self=setmetatable({t=0,view=view,history=history,run=run,parts={}},Finale)
 self.top=require('render.EchoHistory').index(run)
 local v=view.view;self.from=v.cameraNode.position;self.look={x=view.look.x,y=view.look.y,z=view.look.z}
 local points={};for i=0,380 do local k=-self.top-.5+i*.05;local a=k*math.rad(38);points[#points+1]=Vector3(math.sin(a)*34,k*5.5+.3,34-math.cos(a)*34)end
 self.line=v.scene:CreateChild('CompletedSpiralLight');local draw=self.line:CreateComponent('StaticModel')
 self.model=TubeGeometry(points,900,.22,6):ToModel();draw.model=self.model;draw.castShadows=false
 self.geometry=self.model:GetGeometry(0,0);self.count=self.geometry:GetIndexCount()
 self.material=Material();self.material:SetTechnique(0,cache:GetResource('Technique','Techniques/NoTextureUnlit.xml'))
 self.material:SetShaderParameter('MatDiffColor',Variant(Vector4(5,3.4,1.6,1)));draw:SetMaterial(self.material);self.line.enabled=false
 view.topOn=false;run.topK=0;run.veil=nil;run.fx={blue=0}
 return self
end
function Finale:breakRoom(root)
 for _,node in ipairs(root:GetChildren())do
  if not node:GetComponent('Light')then
   local p=node.position;local x,z=p.x,p.z;local n=math.sqrt(x*x+z*z)
   if n<.1 then x,z=math.random()-.5,math.random()-.5;n=math.max(.001,math.sqrt(x*x+z*z))end
   local speed=2+math.random()*5
   self.parts[#self.parts+1]={node=node,p=p,q=node.rotation,s=node.scale,v=Vector3(x/n*speed,1+math.random()*4,z/n*speed),w=Vector3((math.random()-.5)*5,(math.random()-.5)*5,(math.random()-.5)*5),delay=math.random()*.5}
  end
 end
end
function Finale:update(dt)
 self.t=self.t+dt;local t=self.t;local view=self.view;local v=view.view;local r=self.run
 local k=smooth(t,0,3.6);local look=Vector3(self.look.x*(1-k),self.look.y+(-self.top*5.5*.5-self.look.y)*k,-self.look.z+(34+self.look.z)*k)
 local target=Vector3(0,-self.top*5.5*.5+math.sin(math.rad(15))*290,34-math.cos(math.rad(15))*290)
 v.cameraNode.position=self.from+(target-self.from)*k;v.cameraNode:LookAt(look);v.camera.fov=24
 local lk=smooth(t,1.2,4.4);self.line.enabled=lk>0 and t<7.2
 self.geometry:SetDrawRange(TRIANGLE_LIST,0,math.floor(self.count*lk/3)*3,false)
 local opacity=math.min(1,lk*3)*(1-smooth(t,6.6,7.2))
 self.material:SetShaderParameter('MatDiffColor',Variant(Vector4(5*opacity,3.4*opacity,1.6*opacity,1)))
 if t>6.6 then
  if not self.broken then
   self.broken=true
   for j,room in pairs(self.history.rooms)do if j<self.top then self:breakRoom(room.node)end end
   self:breakRoom(v.nodes[view.data.handles.root]);v:setSourceVisible(view.data.handles.pig,false)
   require('game.AudioPlayback').get().score:play('transition',.87)
  end
  for _,part in ipairs(self.parts)do
   local q=t-6.6-part.delay
   if q>0 then
    part.node.position=part.p+part.v*(1.5*q+1.5*q*q)
    local w=part.w;part.node.rotation=part.q*Quaternion(math.deg(w.x*q),Vector3.RIGHT)*Quaternion(math.deg(w.y*q),Vector3.UP)*Quaternion(math.deg(w.z*q),Vector3.FORWARD)
    part.node.scale=part.s*math.exp(-1.3*q)
   end
  end
 end
 r.fx.blue=smooth(t,6.6,8)*.92;r.veil=nil
 if t>8.1 and not self.flashed then self.flashed=true;if v.screenEffects then v.screenEffects.flash=.6 end end
 if t>8.4 then r.phase='done';r:emit('echoFinished',r.theme);return true end
end
function Finale:dispose()if self.line then self.line:Remove();self.line=nil end end
return Finale
