-- Native geometry imported from frozen buildStore(). Source coordinates convert here only.
---@class StoreSceneData
---@field textures table[]
---@field materials table[]
---@field nodes table[]
---@field geometries table[]
---@field handles table
---@field normiLayout table
---@field dynamics table
---@field tune table
---@type StoreSceneData
local Data=require('game.data.StoreScene')
local Dynamics=require('game.StoreDynamics')
local Renderer={}
Renderer.__index=Renderer
local function vec(a) return Vector3(a[1],a[2],-a[3]) end
local function quat(a) return Quaternion(a[4],-a[1],-a[2],a[3]) end
---@param a number[]
---@param i number
---@return number
local function component(a,i) return assert(a[i],'Incomplete imported vertex attribute') end
---@param node Node
local function transform(node,data)
    node.position=vec(data.position);node.rotation=quat(data.quaternion)
    node.scale=Vector3(data.scale[1],data.scale[2],data.scale[3])
end
---@param material Material
local function parameter(material,name,value) material:SetShaderParameter(name,Variant(value)) end
function Renderer.new(data)
    local self=setmetatable({},Renderer);self:init(data);return self
end
function Renderer:init(data)
    self.data=data or Data
    local Data=self.data
    self.disposed=false;self.ready=false;self.pending=0;self.textures={};self.materials={};self.models={};self.nodes={};self.drawables={};self.lights={}
    self.look={x=0,y=2.05,z=-1.1};self.camYaw=0;self.time=0;self.active=true
    self.instanceMaterials={};self.litMaterials={};self.noReceiveMaterials={}
    ---@type Node[]
    self.billboards={}
    self.children={[0]={}};self.visible={}
    self.dynamics=Dynamics.new();self.sourceDrawables={}
    self.pointCache={}
    self.scene=Scene();self.scene:CreateComponent('Octree')
    self.zone=self.scene:CreateComponent('Zone')
    self.zone.boundingBox=BoundingBox(Vector3(-1600,-1600,-1600),Vector3(1600,1600,1600))
    self.zone.ambientSource=AMBIENT_COLOR;self.zone.ambientColor=Color(0,0,0)
    self.zone.fogColor=Color(22/255,28/255,36/255);self.zone.depthFogEnable=true
    self.zone.depthFogStart=34;self.zone.depthFogEnd=150;self.zone.heightFogEnable=false
    self.zone.tonemapMode=TONEMAP_MODE_ACES;self.zone.autoExposureEnabled=false
    -- Tonemap is part of Bloom's final composite even when bloom strength is zero.
    self.zone:SetAttribute('Bloom Enable',Variant(true));self.zone.bloomWeight=0
    self.cameraNode=self.scene:CreateChild('StoreCamera');self.camera=self.cameraNode:CreateComponent('Camera')
    self.camera.fov=24;self.camera.nearClip=1;self.camera.farClip=1400;self.camera.viewMask=1
    self.viewport=Viewport:new(self.scene,self.camera)
    local path=self.viewport:GetRenderPath():Clone()
    -- The bare Urho Forward path only has base/light passes. UrhoX custom-light
    -- materials and the linear HDR composite require the complete CEMap path.
    local pathFile=assert(cache:GetResource('XMLFile','EngineRes/RenderPaths/CEMapSSAO.xml'),'Missing packaged CEMapSSAO')
    assert(path:Load(pathFile));self.viewport:SetRenderPath(path)
    self:activate();self:updateCamera(0,nil)
    local lightNode=self.scene:CreateChild('NightStreetSun');lightNode.position=Vector3(-2.2,7.2,14)
    lightNode:LookAt(Vector3(-.6,0,2.4))
    self.sun=lightNode:CreateComponent('Light');self.sun.lightType=LIGHT_DIRECTIONAL
    self.sun.color=Color(1,.3662526,.0886556);self.sun.brightness=2.3;self.sun.castShadows=true;self.sun.viewMask=3
    -- Native reverse-Z bias is not Three's signed depth offset. The old .0008
    -- constant erased contact shadows; zero caused acne. Fixed-frame source
    -- comparison preserves floor contact with this small constant-only bias.
    self.sun.shadowBias=BiasParameters(.00005,0,0);self.shadowBiasStep=4
    self.sun.shadowCascade=CascadeParameters(40,0,0,0,.8)
    renderer.shadowMapSize=2048
    -- DWP may return placeholders synchronously. Build only when every actual texture is available.
    local paths={[Data.whitePath or 'store/generated/white.png']=true}
    for _,t in ipairs(Data.textures) do paths[t.path]=true end
    for _ in pairs(paths) do self.pending=self.pending+1 end
    for resourcePath in pairs(paths) do
        cache:GetResourceAsync('Texture2D',resourcePath,function(resource)
            if self.disposed then return end
            assert(resource,'STORE_TEXTURE_FAILED: '..resourcePath)
            ---@type Texture2D
            local texture=resource
            texture.sRGB=false;texture.filterMode=FILTER_TRILINEAR
            self.textures[resourcePath]=texture;self.pending=self.pending-1
            if self.pending==0 then self:build() end
        end)
    end
end
function Renderer:activate()
    self.active=true;renderer.hdrRendering=true;renderer:SetViewport(0,self.viewport)
end
function Renderer:shadowDiagnostic(toggle)
    if toggle then renderer.drawShadows=not renderer.drawShadows end
    local casters,visible=0,0
    for _,d in ipairs(self.drawables) do if d.castShadows then casters=casters+1;if d.enabled then visible=visible+1 end end end
    local s=self.sun;local bias=s.shadowBias;local focus=s.shadowFocus
    print('SHADOW_DIAGNOSTIC: '..cjson.encode({drawShadows=renderer.drawShadows,mapSize=renderer.shadowMapSize,quality=renderer.shadowQuality,
        sunCast=s.castShadows,intensity=s.shadowIntensity,resolution=s.shadowResolution,cameraMask=self.camera.viewMask,lightViewMask=s.viewMask,
        softness=renderer.shadowSoftness,extrusion=s.shadowMaxExtrusion,nearFarRatio=s.shadowNearFarRatio,
        casters=casters,enabledCasters=visible,bias={bias.constantBias,bias.slopeScaledBias,bias.normalOffset},
        focus={focus.focus,focus.nonUniform,focus.autoSize,focus.quantize,focus.minView},splits=s.numShadowSplits}))
end
function Renderer:shadowSoftnessDiagnostic()
    self.softnessProbe=((self.softnessProbe or 0)%3)+1
    ---@type number[]
    local values={0,1,2}
    renderer.shadowSoftness=values[self.softnessProbe]
    self:shadowDiagnostic(false)
end
function Renderer:shadowSignedBiasDiagnostic()
    self.signedBiasProbe=((self.signedBiasProbe or 0)%5)+1
    ---@type number[]
    local values={0,-.00005,-.0002,-.001,.00005}
    self.sun.shadowBias=BiasParameters(values[self.signedBiasProbe],0,0)
    self:shadowDiagnostic(false)
end
function Renderer:shadowNormalDiagnostic()
    self.normalProbe=((self.normalProbe or 0)%3)+1
    ---@type number[]
    local values={.08,.03,0}
    self.sun.shadowBias=BiasParameters(.00005,0,values[self.normalProbe])
    self:shadowDiagnostic(false)
end
function Renderer:shadowMapDiagnostic()
    self.mapProbe=((self.mapProbe or 0)%3)+1
    ---@type integer[]
    local values={4096,1024,2048}
    renderer.shadowMapSize=values[self.mapProbe]
    self:shadowDiagnostic(false)
end
function Renderer:shadowBiasDiagnostic()
    self.shadowBiasStep=((self.shadowBiasStep or 0)+1)%5
    local settings={{.0008,.5,.03},{.0008,.5,0},{0,0,0},{.0008,0,0},{.00005,0,0}}
    local b=settings[self.shadowBiasStep+1];self.sun.shadowBias=BiasParameters(b[1],b[2],b[3])
    self:shadowDiagnostic(false)
end
function Renderer:shadowFocusDiagnostic()
    self.focusProbe=((self.focusProbe or 0)%4)+1
    ---@type boolean[][]
    local cases={{false,true,true},{true,true,false},{false,false,false},{true,true,true}}
    local f=cases[self.focusProbe]
    self.sun.shadowFocus=FocusParameters(f[1],f[2],f[3],.5,3)
    self:shadowDiagnostic(false)
end
function Renderer:shadowReceiverDiagnostic()
    self.receiverProbe=not self.receiverProbe
    local m=self.materials[1]
    if self.receiverProbe then
        m=m:Clone()
        parameter(m,'receive_shadow',0)
        print('SHADOW_RECEIVER_PROBE: noReceive=true explicit directional shadow factor')
    else print('SHADOW_RECEIVER_PROBE: noReceive=false') end
    for _,d in ipairs(self.sourceDrawables[2] or {}) do d:SetMaterial(0,m) end
end
function Renderer:shadowCasterDiagnostic()
    self.casterProbe=((self.casterProbe or 0)%4)+1
    ---@type string[]
    local modes={'none','roof','leaves','both'}
    local mode=modes[self.casterProbe]
    for _,source in ipairs(self.data.nodes) do
        if source.type=='Mesh' and not self.data.materials[source.materials[1]].colorWrite then
            local isLeaves=source.id==self.data.handles.leaves
            local cast=mode=='both' or (isLeaves and mode=='leaves') or (not isLeaves and mode=='roof')
            for _,d in ipairs(self.sourceDrawables[source.id] or {}) do d.castShadows=cast end
        end
    end
    print('SHADOW_CASTER_PROBE: '..mode..'; fixed-frame diagnostic only')
end
function Renderer:model(id,slots)
    local Data=self.data or Data
    local key=id..':'..slots;if self.models[key] then return self.models[key] end
    ---@type table
    local source=Data.geometries[id]
    ---@type table<string,{array:number[]}>
    local a=source.attributes
    local p,n,uv,c=a.position.array,a.normal and a.normal.array,a.uv and a.uv.array,a.color and a.color.array
    local indices=source.index or {};if not source.index then for i=0,#p/3-1 do indices[#indices+1]=i end end
    local groups=slots>1 and source.groups or {{start=0,count=#indices,materialIndex=0}}
    local scratch=self.scene:CreateChild('MeshImport');local g=scratch:CreateComponent('CustomGeometry')
    g.enabled=false;g:SetNumGeometries(slots)
    for slot=0,slots-1 do
        g:BeginGeometry(slot,TRIANGLE_LIST)
        for _,group in ipairs(groups) do if group.materialIndex==slot then
            for first=group.start+1,group.start+group.count,3 do
                -- Reflection changes handedness; reverse triangle winding once.
                for _,offset in ipairs({0,2,1}) do
                    local index=indices[first+offset];local j=index*3+1;local k=index*2+1
                    g:DefineVertex(Vector3(component(p,j),component(p,j+1),-component(p,j+2)))
                    g:DefineNormal(n and Vector3(component(n,j),component(n,j+1),-component(n,j+2)) or Vector3(0,0,-1))
                    g:DefineTexCoord(uv and Vector2(component(uv,k),1-component(uv,k+1)) or Vector2(0,0))
                    g:DefineColor(c and Color(component(c,j),component(c,j+1),component(c,j+2),1) or Color(1,1,1,1))
                end
            end
        end end
    end
    g:Commit();local model=Model();assert(g:FillModel(model),'STORE_MODEL_CONVERSION_FAILED')
    self.models[key]=model;scratch:Remove();return model
end
function Renderer:sourceMaterial(source,id)
    return (not source.receiveShadow and self.noReceiveMaterials[id]) or self.materials[id]
end
---@param node Node
function Renderer:drawable(node,source,instance)
    local Data=self.data or Data
    local drawable=node:CreateComponent('StaticModel')
    drawable.model=self:model(source.geometry,#source.materials)
    for slot,id in ipairs(source.materials) do
        local material=self:sourceMaterial(source,id)
        if instance then
            local c=instance.color;local key=id..':'..tostring(source.receiveShadow)..':'..table.concat(c,',')
            if not self.instanceMaterials[key] then
                local clone=material:Clone()
                -- This installed runtime's COLOR path ignores the instance stream.
                -- Preserve source linear color in an explicit uniform, without gamma conversion.
                parameter(clone,'instance_tint',Vector3(c[1],c[2],c[3]))
                self.instanceMaterials[key]=clone
                local kind=Data.materials[id].type
                if kind=='MeshToonMaterial' or kind=='MeshLambertMaterial' then self.litMaterials[#self.litMaterials+1]=clone end
            end
            material=self.instanceMaterials[key]
        end
        drawable:SetMaterial(slot-1,material)
    end
    drawable.castShadows=source.castShadow;drawable.viewMask=1
    -- StoreShadowOnly retains the source geometry in the directional shadow
    -- view and discards it in the perspective color/depth passes.
    self.drawables[#self.drawables+1]=drawable
    self.sourceDrawables[source.id]=self.sourceDrawables[source.id] or {}
    table.insert(self.sourceDrawables[source.id],drawable)
end
function Renderer:build()
    local Data=self.data or Data
    for _,m in ipairs(Data.materials) do
        self.materials[m.id]=assert(cache:GetResource('Material',m.path),m.path):Clone()
        if m.noReceivePath then
            self.noReceiveMaterials[m.id]=assert(cache:GetResource('Material',m.noReceivePath),m.noReceivePath):Clone()
            self.litMaterials[#self.litMaterials+1]=self.noReceiveMaterials[m.id]
        end
        if m.type=='MeshToonMaterial' or m.type=='MeshLambertMaterial' then
            self.litMaterials[#self.litMaterials+1]=self.materials[m.id]
            parameter(self.materials[m.id],'hemi_sky',Vector3(.323143,.401978,.496933))
            parameter(self.materials[m.id],'hemi_ground',Vector3(.03434,.042312,.045186))
            parameter(self.materials[m.id],'hemi_intensity',.72)
        end
    end
    -- This installed runtime lacks Material:GetShaderParameter despite the dev-kit
    -- declaration. Validation uses the frozen material XML and rendered output.
    self.omitted={}
    for _,source in ipairs(Data.nodes) do
        ---@type Node
        local parent=source.parent==0 and self.scene or self.nodes[source.parent]
        local node=parent:CreateChild(source.name~='' and source.name or ('Source'..source.id));self.nodes[source.id]=node
        transform(node,source);node.enabled=source.visible
        self.children[source.id]={};self.visible[source.id]=source.visible
        table.insert(self.children[source.parent],source.id)
        if source.light then
            local d=source.light;local l=node:CreateComponent('Light');l.lightType=LIGHT_POINT
            l.color=Color(d.color[1],d.color[2],d.color[3]);l.brightness=d.intensity;l.range=d.distance
            l.castShadows=false;self.lights[source.id]=l
            -- Source point lights have no shadows and use a different attenuation law.
            -- Evaluate their exact source terms in SurfaceShader; avoid double lighting.
            l.enabled=false
        elseif source.type=='Mesh' then
            if source.instances then
                for i,instance in ipairs(source.instances) do
                    local child=node:CreateChild('Product'..i);transform(child,instance);self:drawable(child,source,instance)
                end
            else self:drawable(node,source,nil) end
        elseif source.type=='Sprite' then
            -- Frozen night.js lamp halos use centered, size-attenuated sprites
            -- with zero material rotation. Keep their actual quad, UV, scale and
            -- additive texture; only orient the quad to the active view.
            self:drawable(node,source,nil)
            table.insert(self.billboards,node)
        elseif source.type=='LineSegments' then
            local line=node:CreateComponent('CustomGeometry');line:SetNumGeometries(1);line:BeginGeometry(0,LINE_LIST)
            local p=Data.geometries[source.geometry].attributes.position.array
            for i=1,#p,3 do line:DefineVertex(Vector3(p[i],p[i+1],-p[i+2]));line:DefineColor(Color(1,1,1,1));line:DefineTexCoord(Vector2(0,0)) end
            line:Commit();line:SetMaterial(0,self.materials[source.materials[1]]);line.castShadows=false
            self.drawables[#self.drawables+1]=line;self.sourceDrawables[source.id]={line}
        elseif source.geometry then
            -- Retain source metadata; these require their own billboard/particle renderer.
            self.omitted[#self.omitted+1]={id=source.id,type=source.type}
        end
    end
    self:setSourceVisible(0,true);self:updatePointUniforms();self:updateBillboards()
    self.ready=true
    print((self.data.theme and 'ECHO_NATIVE_READY: ' or 'STORE_NATIVE_READY: ')..#Data.nodes..' source nodes, '..#self.drawables..' native meshes; '..#self.omitted..' particle/billboard objects pending')
end
function Renderer:setSourceVisible(id,visible)
    local Data=self.data or Data
    -- Urho Node.enabled does not hide descendants; Three Object3D.visible does.
    -- Preserve each child's own visibility while applying the inherited state.
    self.visible[id]=visible
    local function visit(current,inherited)
        local effective=inherited and self.visible[current]
        if current~=0 then self.nodes[current].enabled=effective end
        -- Product instances are native children of one source Mesh node.
        for _,drawable in ipairs(self.sourceDrawables and self.sourceDrawables[current] or {}) do drawable.enabled=effective end
        for _,child in ipairs(self.children[current]) do visit(child,effective) end
    end
    local parent=id~=0 and Data.nodes[id].parent or 0
    visit(id,parent==0 or self.nodes[parent].enabled)
end
function Renderer:updatePointUniforms()
    local Data=self.data or Data
    local index=0
    for _,source in ipairs(Data.nodes) do if source.light then
        assert(index<8,'Frozen store has more point lights than its shader supports')
        local d=source.light
        ---@type Vector3
        local p=self.nodes[source.id].worldPosition
        local intensity=self.lights[source.id].brightness
        self:setPoint(index,{p.x,p.y,p.z,d.distance},{d.color[1]*intensity,d.color[2]*intensity,d.color[3]*intensity,d.decay})
        index=index+1
    end end
end
function Renderer:setPoint(index,position,color)
    local function same(a,b) return a and a[1]==b[1] and a[2]==b[2] and a[3]==b[3] and a[4]==b[4] end
    local cached=self.pointCache[index] or {}
    local positionChanged=not same(cached.position,position);local colorChanged=not same(cached.color,color)
    if positionChanged or colorChanged then for _,m in ipairs(self.litMaterials) do
        if positionChanged then parameter(m,'point_position_'..index,Vector4(position[1],position[2],position[3],position[4])) end
        if colorChanged then parameter(m,'point_color_'..index,Vector4(color[1],color[2],color[3],color[4])) end
    end end
    self.pointCache[index]={position=position,color=color}
end
function Renderer:referenceFrame(story)
    local Data=self.data or Data
    self.dynamics=Dynamics.new(function() return .37 end)
    self.look={x=0,y=2.05,z=-1.1};self.time=0;self:update(0,story)
    -- The source exporter calls Normi.update(0), which clamps the initial Z to
    -- its constructor bounds. Use its captured transform, not the live-story bounds.
    local id=Data.handles.normi;transform(self.nodes[id],Data.nodes[id])
    self:setSourceVisible(Data.handles.archive,Data.nodes[Data.handles.archive].visible)
end
function Renderer:updateDynamics(dt,story)
    local Data=self.data or Data
    local p=story.normi.pos;local d=self.dynamics;local H=Data.handles
    d:update(dt,{stress=story.sv,time=self.time,power=story.power,flickBoost=story.flickBoost,
        fold=story.fx.fold,pos={p.x,p.y,p.z}})
    for _,flat in ipairs(d.flats) do
        local node=self.nodes[H.flats[flat.name]]
        node.position=vec(flat.position);node.rotation=quat(flat.quaternion);node.scale=Vector3(flat.scale,flat.scale,flat.scale)
    end
    for i,pane in ipairs(H.doorPanes) do
        ---@type number[]
        local position=Data.nodes[pane.id].position
        self.nodes[pane.id].position=Vector3(component(d.panes,i),component(position,2),-component(position,3))
    end
    self.nodes[H.leaves].position=vec(d.leaves)
    self.nodes[H.emptyChair].position=vec(d.chairPosition)
    self.nodes[H.emptyChair].scale=Vector3(d.chairScale,d.chairScale,d.chairScale)
    self.nodes[H.clerk].rotation=Quaternion(math.deg(d.clerkAngle),Vector3(0,0,1))
    if self.visible[H.clerk]~=d.clerkVisible then self:setSourceVisible(H.clerk,d.clerkVisible) end
    for _,id in ipairs(H.foodSpin) do self.nodes[id].rotation=quat(d.foodQuaternion) end
    for i,id in ipairs(H.tubes) do
        local c=d.tubeColors[i];parameter(self.materials[Data.nodes[id].materials[1]],'tint',Vector4(c[1],c[2],c[3],1))
    end
    for i,id in ipairs(H.ceiling) do self.lights[id].brightness=d.ceiling[i] end
    for i,b in ipairs(H.bounce) do self.lights[b.id].brightness=d.bounce[i] end
    for i,id in ipairs(H.foodLights) do self.lights[id].brightness=d.food[i] end
    self.lights[H.fridge].brightness=d.fridge
    self:updatePointUniforms()
    -- Source applyNight blends colors in linear space as power changes.
    local power=story.power
    local function linear(v) v=v/255;return v<=.04045 and v/12.92 or ((v+.055)/1.055)^2.4 end
    local function mix(a,b) return linear(a)+(linear(b)-linear(a))*power end
    if self.lastPower~=power then
        for _,m in ipairs(self.litMaterials) do
            parameter(m,'hemi_sky',Vector3(mix(125,154),mix(143,170),mix(163,187)))
            parameter(m,'hemi_ground',Vector3(mix(29,52),mix(33,58),mix(37,60)))
            parameter(m,'hemi_intensity',d.hemiIntensity);parameter(m,'shadow_step',d.shadowStep)
        end
        self.lastPower=power
    end
    local glow=story.doodleK;local material=self.materials[Data.nodes[H.doodle].materials[1]]
    parameter(material,'tint',Vector4(.35+glow*2.2,.4+glow*2,.75+glow*1.4,story.doodleGone and glow or 1))
    local pig=story.tablePig;local tablePos=Data.dynamics.table;local node=self.nodes[H.tablePig]
    if self.visible[H.tablePig]~=pig.visible then self:setSourceVisible(H.tablePig,pig.visible) end
    node.position=Vector3(tablePos.x,tablePos.y+.06,-tablePos.z);node.scale=Vector3(pig.scale,pig.scale,pig.scale)
    local frame=math.floor(pig.spinT)%8;local uv=Vector4(.25,.5,(frame%4)/4,math.floor(frame/4)/2)
    local pigMat=self.materials[Data.nodes[H.tablePig].materials[1]]
    parameter(pigMat,'map_uv',uv);parameter(pigMat,'emit_uv',uv)
    local intensity=pig.visible and pig.light or 0
    self:setPoint(8,{tablePos.x,tablePos.y+.9,-(tablePos.z+.6),3.2},{linear(169)*intensity,linear(216)*intensity,intensity,2})
    for i,m in ipairs(Data.materials) do if m.programKey:find('night',1,true) then
        parameter(self.materials[i],'elapsed',self.time);parameter(self.materials[i],'wind_time',d.windTime)
        parameter(self.materials[i],'wind_gust',d.windGust)
    end end
end
function Renderer:updateBillboards()
    for _,node in ipairs(self.billboards) do node.worldRotation=self.cameraNode.worldRotation end
end
function Renderer:updateCamera(dt,story)
    if story then
        local p=story.normi.pos;local k=math.min(1,dt*3.2)
        self.look.x=self.look.x+(math.max(-4,math.min(4,p.x))*.7-self.look.x)*k
        self.look.y=self.look.y+(2.05-self.look.y)*k
        self.look.z=self.look.z+(p.z*.45-1.1-self.look.z)*k
    end
    local p=self.look;local pitch=math.rad(16)
    self.cameraNode.position=Vector3(p.x,p.y+math.sin(pitch)*22,-(p.z+math.cos(pitch)*22))
    self.cameraNode:LookAt(Vector3(p.x,p.y,-p.z))
    self:updateBillboards()
end
function Renderer:update(dt,story)
    local Data=self.data or Data
    if not self.ready then return end
    self.time=self.time+dt;self:updateCamera(dt,story)
    self:updateDynamics(dt,story)
    local actor=story.normi;local node=self.nodes[Data.handles.normi]
    local rock=actor.walkRock*(1-actor.collapse);local hang=actor.hang
    node.position=Vector3(actor.pos.x-math.sin(rock)*hang,actor.pos.y+hang+actor.lift+(math.cos(rock)-1)*hang,-actor.pos.z)
    node.rotation=Quaternion(math.deg(-actor.sway*actor.side*(1-actor.collapse)+rock),Vector3(0,0,1))
    node.scale=Vector3(actor.flipScale or 1,1,1);node.enabled=actor.visible
    local layout=Data.normiLayout;local material=self.materials[Data.nodes[Data.handles.normi].materials[1]]
    parameter(material,'map_uv',Vector4(1/layout.columns,1/layout.rows,(actor.pose%layout.columns)/layout.columns,math.floor(actor.pose/layout.columns)/layout.rows))
    parameter(material,'emit_uv',Vector4(1/layout.columns,1/layout.rows,(actor.pose%layout.columns)/layout.columns,math.floor(actor.pose/layout.columns)/layout.rows))
    if self.visible[Data.handles.archive]~=story.archiveVisible then self:setSourceVisible(Data.handles.archive,story.archiveVisible) end
    for i,id in ipairs(Data.handles.clockHands) do
        local total=23*60+38+story.clock
        local angle=i==1 and -((total/60)%12)/12*360 or -(total%60)/60*360
        self.nodes[id].rotation=Quaternion(angle,Vector3(0,0,1))
    end
end
function Renderer:actorScreen(story)
    local p=story.normi.pos
    local a=self.camera:WorldToScreenPoint(Vector3(p.x-.65,p.y+1.3,-p.z))
    local b=self.camera:WorldToScreenPoint(Vector3(p.x+.65,p.y+1.3,-p.z))
    return a.x,b.x
end
function Renderer:dispose() self.disposed=true;self.scene:Dispose() end
return Renderer
