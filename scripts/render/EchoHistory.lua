-- Native retained room trees; materials/models remain referenced by cloned drawables.
-- Completed rooms retain their actual transforms. Direct chapter entry fills only gaps.
local History={};History.__index=History
local BASE={store=0,meeting=6,office=11,dorm=15}
function History.new()return setmetatable({storage=Scene(),rooms={},at=-1},History)end
function History.index(run)return BASE[run.theme]+run.index-1 end
local function clean(node)
    node:RemoveComponents('Light')
    for _,child in ipairs(node:GetChildren())do clean(child)end
end
function History:capture(view,run)
    local id=History.index(run);local old=self.rooms[id]
    if old then old.node:Remove()end
    local root=view.view.nodes[view.data.handles.root]:Clone()
    root:SetParent(self.storage);root.enabled=false;clean(root)
    -- Walk the built native tree: instanced product nodes can precede exported
    -- children, so exported sibling indices do not identify cloned nodes.
    local sourceRoot=view.view.nodes[view.data.handles.root]
    local function relative(sourceId)
        local indices={};local current=view.view.nodes[sourceId]
        while current and current~=sourceRoot do
            local parent=current:GetParent();if not parent then return end
            local idx
            for i,child in ipairs(parent:GetChildren())do if child==current then idx=i-1;break end end
            if not idx then return end
            table.insert(indices,1,idx);current=parent
        end
        if current~=sourceRoot then return end
        local n=root;for _,i in ipairs(indices)do n=n:GetChild(i);if not n then return end end;return n
    end
    local rain=relative(view.data.handles.rain);if rain then rain.enabled=false end
    self.rooms[id]={node=root,theme=run.theme,answer=run.answer,completed=run.phase=='out'or run.phase=='finale',loadId=run.loadId}
end
function History:park()
    for _,r in pairs(self.rooms)do r.node:SetParent(self.storage);r.node.enabled=false end
    self.at=-1
end
function History:place(scene,at)
    self.at=at
    for j,r in pairs(self.rooms)do
        r.node:SetParent(scene);r.node.enabled=j<at
        if j<at then
            local k=j-at;local a=k*math.rad(38)
            r.node.position=Vector3(math.sin(a)*34,k*5.5,34-math.cos(a)*34)
            r.node.rotation=Quaternion(-math.deg(a),Vector3.UP);r.node.scale=Vector3(1,1,1)
        end
    end
end
function History:fill(active,run,answers)
    local at=History.index(run)
    if self.pending then
        local p=self.pending;p.view.view:pumpBuild()
        if p.view.view.ready then
            p.view:update(0,p.run);self:capture(p.view,p.run);p.view:dispose();self.pending=nil
            self:place(active.view.scene,at)
        end
        active:activate();return
    end
    for j=0,at-1 do if not self.rooms[j]then
        local set,i=require('game.LevelCatalog').at(j)
        local r=require('game.EchoRun').new(set.levels,set.theme);r:load(i+1);r.answer=answers[set.theme]or set.answer
        r.phase='play';r.fold=1;r.t=3;r:drainEvents()
        local v=require('render.EchoRenderer').new(r);self.pending={run=r,view=v};active:activate();return
    end end
end
function History:complete(at)for j=0,at-1 do if not self.rooms[j]then return false end end;return true end
function History:clear()
    self:park();for _,r in pairs(self.rooms)do r.node:Remove()end;self.rooms={}
    if self.pending then self.pending.view:dispose();self.pending=nil end
end
function History:dispose()self:clear();self.storage:Dispose()end
return History
