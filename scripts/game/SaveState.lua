-- Frozen save.js chapter merge semantics and main.js progress hooks.
-- Transport/JSON are injected so unavailable storage falls back to this session.
local Save={};Save.__index=Save
local Nodes=require('game.data.TimelineNodes')
local byId={};for _,n in ipairs(Nodes) do byId[n.id]=n end
local function copy(value)
    if type(value)~='table' then return value end
    local out={};for k,v in pairs(value) do out[k]=copy(v) end;return out
end
function Save.new(storage,codec)
    local self=setmetatable({},Save);self:init(storage,codec);return self
end
function Save:init(storage,codec)
    self.storage=storage;self.codec=codec;self.data={chapters={}};self.persisted=false;self.error=false
    local ok,raw=pcall(storage.read)
    if ok and raw and raw~='' then
        local parsed,value=pcall(codec.decode,raw)
        if parsed and type(value)=='table' and type(value.chapters)=='table' then self.data=value;self.persisted=true
        else self.error='invalid-save' end
    elseif not ok then self.error='read-unavailable' end
end
function Save:chapter(id) return copy(self.data.chapters[id]) end
function Save:saveChapter(id,fields)
    local previous=self.data.chapters[id];local chapter=type(previous)=='table' and copy(previous) or {}
    for k,v in pairs(fields) do chapter[k]=copy(v) end
    self.data.chapters[id]=chapter
    local encoded,raw=pcall(self.codec.encode,self.data)
    local ok,result=false,false
    if encoded then ok,result=pcall(self.storage.write,raw) end
    self.persisted=ok and result~=false
    self.error=self.persisted and false or 'write-unavailable'
    return copy(chapter)
end
function Save:reached()
    local e=self.data.chapters.echo;local n=type(e)=='table' and tonumber(e.reached) or 0
    if not n or n~=n then n=0 end
    return math.floor(math.max(0,math.min(6,n)))
end
function Save:answer()
    local c=self.data.chapters.ch1;local a=type(c)=='table' and c.answer
    return (a=='same' or a=='late' or a=='done') and a or 'same'
end
function Save:echoLoaded(index)
    assert(index>=1 and index<=6 and index%1==0,'Invalid prologue progress')
    if self:reached()<index then self:saveChapter('echo',{reached=index}) end
end
function Save:echoFinished() self:saveChapter('echo',{done=true}) end
function Save:tried()
    local c=self.data.chapters.ch1 or {};local out={};local seen={}
    for _,v in ipairs(type(c.tried)=='table'and c.tried or {})do if (v=='same'or v=='late'or v=='done')and not seen[v]then out[#out+1]=v;seen[v]=true end end
    return out
end
function Save:noteTried(answer)
    local tried=self:tried();for _,v in ipairs(tried)do if v==answer then return end end
    assert(answer=='same'or answer=='late'or answer=='done');tried[#tried+1]=answer;self:saveChapter('ch1',{answer=answer,tried=tried})
end
function Save:meetingFinished(answer)
    assert(answer=='same' or answer=='late' or answer=='done','Invalid answer')
    self:saveChapter('ch1',{answer=answer})
end
-- Increment 03 progress uses completed floors, not the old loaded-floor index.
function Save:timeline()
    local t=self:chapter('timeline')
    if t then return {nodes=t.nodes or {},floors=t.floors or {}} end
    local c=self.data.chapters;local nodes,floors={},{}
    local e=c.echo or {};local ch=c.ch1 or {}
    if (tonumber(e.reached) or 0)>0 or e.done then
        nodes={'2312','2338','echo1'};floors.echo1=e.done and 6 or math.max(0,(tonumber(e.reached) or 1)-1)
    end
    if e.done then nodes[#nodes+1]='1447' end
    if ch.answer then nodes[#nodes+1]='echo2' end
    if ch.morningBranch then nodes[#nodes+1]='0958';nodes[#nodes+1]='echo3' end
    if ch.dormChoice then nodes[#nodes+1]='0815';nodes[#nodes+1]='echo4' end
    return {nodes=nodes,floors=floors}
end
function Save:hasNode(id)
    for _,n in ipairs(self:timeline().nodes) do if n==id then return true end end
    return false
end
function Save:unlock(id)
    assert(byId[id],'Invalid timeline node')
    if self:hasNode(id) then return false end
    local t=self:timeline();t.nodes[#t.nodes+1]=id;self:saveChapter('timeline',t);return true
end
function Save:passed(id) return self:timeline().floors[id] or 0 end
function Save:passFloor(id,n)
    assert(byId[id] and byId[id].floors and n>=1 and n<=byId[id].floors and n%1==0,'Invalid completed floor')
    local t=self:timeline()
    if (t.floors[id] or 0)<n then t.floors[id]=n;self:saveChapter('timeline',t) end
end
function Save:latest()
    for i=#Nodes,1,-1 do if self:hasNode(Nodes[i].id) then return Nodes[i].id end end
    return false
end
function Save:morningBranch()
    local c=self.data.chapters.ch1 or {};local v=c.morningBranch
    return (v=='fix' or v=='wreck' or v=='leave') and v or 'fix'
end
function Save:dormChoice()
    local c=self.data.chapters.ch1 or {};local v=c.dormChoice
    return (v=='sick' or v=='pc' or v=='off') and v or 'sick'
end
function Save:morningFinished(branch)
    assert(branch=='fix' or branch=='wreck' or branch=='leave','Invalid morning branch')
    self:saveChapter('ch1',{morningBranch=branch})
end
function Save:dormFinished(choice)
    assert(choice=='sick' or choice=='pc' or choice=='off','Invalid dorm choice')
    self:saveChapter('ch1',{dormChoice=choice})
end
return Save
