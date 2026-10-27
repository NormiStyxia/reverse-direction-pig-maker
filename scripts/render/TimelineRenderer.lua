local Base=require('render.Chapter1Renderer')
local R=setmetatable({},{__index=Base});R.__index=R
local function param(m,k,v)m:SetShaderParameter(k,Variant(v))end
local function euler(a)return Quaternion(-math.deg(a[1]),Vector3(1,0,0))*Quaternion(-math.deg(a[2]),Vector3(0,1,0))*Quaternion(math.deg(a[3]),Vector3(0,0,1))end
function R.new(story)
    local s=setmetatable({},R);s.data=require('game.data.Chapter03TimelineScene');s.view=require('render.StoreRenderer').new(s.data);s.ready=false;s.time=0;s.camYaw=0
    local v=s.view
    -- Source show() retains the world light and adds a second, unshadowed sun.
    -- The title's hidden DreamIntro already points the world sun at its actor.
    if story.timelineSun then
        v.sun.node.position=Vector3(table.unpack(story.timelineSun.position))
        v.sun.node.rotation=Quaternion(table.unpack(story.timelineSun.rotation))
    else
        v.sun.node.position=Vector3(-20.9,13,-6);v.sun.node:LookAt(Vector3(-13.9,0,1.5))
    end
    v.sun.color=Color(1,1,1);v.sun.brightness=1.6
    local node=v.scene:CreateChild('TimelinePageSun');node.position=Vector3(6,10,-8);node:LookAt(Vector3(0,0,0))
    s.pageSun=node:CreateComponent('Light');s.pageSun.lightType=LIGHT_DIRECTIONAL
    s.pageSun.color=Color(1,1,1);s.pageSun.brightness=1.6;s.pageSun.castShadows=false;s.pageSun.viewMask=3
    v.zone.fogColor=Color(.85499260812105,.8879231178794776,.9559733532492861);v.zone.fogStart=28;v.zone.fogEnd=120
    return s
end
function R:update(dt,story)
    local v,H=self.view,self.data.handles;if not v.ready then return end
    if not self.ready then
        for _,s in ipairs(H.shards)do if not story.unlocked[s.n.id]then self:material(s.face,H.lockedMaterial)end end
        -- Both hemispheres point up, so summing their linear sky/ground terms
        -- is exactly equivalent to evaluating both source lights separately.
        for _,m in ipairs(v.litMaterials)do
            param(m,'hemi_sky',Vector3(.85499260812105*1.6+1.25,.8879231178794776*1.6+1.25,2.85))
            param(m,'hemi_ground',Vector3(.2746773120495699*1.6+.34670405634441115*1.25,.36625259558833256*1.6+.45641102317066595*1.25,.6724431569510133*1.6+.7912979403281551*1.25))
            param(m,'hemi_intensity',1)
        end
    end
    self.ready=true;self.time=story.t
    for id,tr in pairs(story.transforms)do local n=v.nodes[id];n.position=Vector3(tr.p[1],tr.p[2],-tr.p[3]);n.scale=Vector3(table.unpack(tr.s));if tr.r then n.rotation=euler(tr.r)end;self:visible(id,tr.visible)end
    for id,a in pairs(story.alphas)do self:alpha(id,a)end
    local c,p,t=story.camera,story.par,story.t;local dist=c.d*math.max(1,1.45/(graphics:GetWidth()/math.max(1,graphics:GetHeight())));local yaw,pitch=p.x*.13,.03-p.y*.08;self.camYaw=yaw
    v.camera.fov=32;v.cameraNode.position=Vector3(c.lx+math.sin(yaw)*math.cos(pitch)*dist+math.sin(t*90)*.12*c.shake,c.ly+math.sin(pitch)*dist+math.cos(t*77)*.08*c.shake,-math.cos(yaw)*math.cos(pitch)*dist);v.cameraNode:LookAt(Vector3(c.lx,c.ly,0))
    for _,s in ipairs(H.stars)do v.nodes[s.m]:LookAt(v.cameraNode.position)end
    v:updatePointUniforms()
end
function R:project(x,y,z)local w=Vector3(x,y,-z);local p=self.view.camera:WorldToScreenPoint(w);return p.x,p.y,self.view.cameraNode:WorldToLocal(w).z end
function R:actorScreen()return .45,.55 end
local function sign(p,a,b)return(p.x-b.x)*(a.y-b.y)-(a.x-b.x)*(p.y-b.y)end
function R:hitShard(x,y)
    if not self.ready then return end;local best,depth=nil,math.huge
    for i,s in ipairs(self.data.handles.shards)do
        local n=self.data.nodes[s.face];local g=self.data.geometries[n.geometry];local pos=g.attributes.position.array;local idx=g.index
        local points={};for k=1,#pos,3 do local w=self.view.nodes[s.face]:LocalToWorld(Vector3(pos[k],pos[k+1],-pos[k+2]));local p=self.view.camera:WorldToScreenPoint(w);points[#points+1]={x=p.x,y=p.y,z=self.view.cameraNode:WorldToLocal(w).z}end
        for k=1,#idx,3 do local a,b,c=points[idx[k]+1],points[idx[k+1]+1],points[idx[k+2]+1];local p={x=x,y=y};local d1,d2,d3=sign(p,a,b),sign(p,b,c),sign(p,c,a)
            if not((d1<0 or d2<0 or d3<0)and(d1>0 or d2>0 or d3>0))then local d=(a.z+b.z+c.z)/3;if d>=0 and d<depth then best=i;depth=d end end
        end
    end
    return best
end
return R
