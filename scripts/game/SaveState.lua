-- Frozen save.js chapter merge semantics and main.js progress hooks.
-- Transport/JSON are injected so unavailable storage falls back to this session.
local Save={};Save.__index=Save
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
function Save:meetingFinished(answer)
    assert(answer=='same' or answer=='late' or answer=='done','Invalid answer')
    self:saveChapter('ch1',{answer=answer})
end
return Save
