-- Web File storage is volatile. Only the documented clientCloud API persists it.
-- One read before any write; one write in flight; stale callbacks cannot win.
local State=require('game.SaveState')
local Cloud={}
local KEY='reverse_pig_save_v1'
local nodes={};for _,n in ipairs(require('game.data.TimelineNodes'))do nodes[n.id]=n end
local function copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
end
local function valid(v)
    if type(v)~='table' or type(v.chapters)~='table' then return false end
    for _,chapter in pairs(v.chapters)do if type(chapter)~='table' then return false end end
    local t=v.chapters.timeline
    if t then
        if type(t.nodes)~='table' or type(t.floors)~='table' then return false end
        for _,id in pairs(t.nodes)do if type(id)~='string' or not nodes[id]then return false end end
        for id,n in pairs(t.floors)do
            local spec=nodes[id]
            if not spec or not spec.floors or type(n)~='number' or n~=n or n%1~=0 or n<0 or n>spec.floors then return false end
        end
    end
    return true
end
local function merge(remote,localData)
    local out=copy(remote)
    for id,fields in pairs(localData.chapters)do
        if type(fields)=='table' then
            local dest=type(out.chapters[id])=='table' and out.chapters[id] or {}
            if id=='timeline' then
                local nodes,seen={},{}
                for _,list in ipairs({dest.nodes or {},fields.nodes or {}})do
                    for _,node in ipairs(list)do if not seen[node]then nodes[#nodes+1]=node;seen[node]=true end end
                end
                local floors=copy(dest.floors or {})
                for node,n in pairs(fields.floors or {})do floors[node]=math.max(tonumber(floors[node])or 0,tonumber(n)or 0)end
                dest.nodes=nodes;dest.floors=floors
            else
                for k,v in pairs(fields)do
                    if id=='ch1'and k=='tried'then
                        local seen,answers={},{}
                        for _,list in ipairs({dest.tried or {},v or {}})do for _,answer in ipairs(list)do
                            if (answer=='same'or answer=='late'or answer=='done')and not seen[answer]then seen[answer]=true;answers[#answers+1]=answer end
                        end end
                        dest.tried=answers
                    elseif id=='echo' and k=='reached' then dest[k]=math.max(tonumber(dest[k])or 0,tonumber(v)or 0)
                    elseif id=='echo' and k=='done' then dest[k]=dest[k]or v
                    else dest[k]=copy(v)end
                end
            end
            out.chapters[id]=dest
        end
    end
    return out
end
function Cloud.open(api,codec)
    local now,revision,ack,token=0,0,0,0
    local readDone,inflight,dead=false,nil,false
    local nextAt=0
    local state
    state=State.new({read=function()return nil end,write=function()
        revision=revision+1;nextAt=math.max(nextAt,now+.3);return false
    end},codec)
    state.loading=true;state.cloud=true;state.status='loading'
    local function failure(kind)
        inflight=nil;nextAt=now+5;state.loading=false;state.persisted=false
        state.error=kind;state.status='offline'
    end
    local function request(reading)
        token=token+1;local own=token;local sent=revision
        inflight={at=now,token=own};state.status=reading and 'loading' or 'saving'
        local function current()return not dead and inflight and inflight.token==own end
        local events={error=function()if current()then failure(reading and 'cloud-read' or 'cloud-write')end end,
            timeout=function()if current()then failure('cloud-timeout')end end}
        events.ok=function(values)
            if not current()then return end
            if reading then
                if type(values)~='table' then failure('invalid-cloud-response');return end
                local remote=values[KEY]
                if type(remote)=='string' then local ok,v=pcall(codec.decode,remote);remote=ok and v or false end
                if remote~=nil and not valid(remote)then failure('invalid-cloud-save');return end
                if remote then
                    state.data=revision>0 and merge(remote,state.data)or copy(remote)
                end
                readDone=true;state.loading=false
                state.persisted=remote~=nil and revision==0
            else
                ack=sent;state.persisted=ack==revision
            end
            inflight=nil;state.error=false;nextAt=now
            state.status=revision>ack and 'saving' or 'ready'
        end
        local ok
        if reading then ok=pcall(function()api:Get(KEY,events)end)
        else
            local encoded,raw=pcall(codec.encode,state.data)
            if not encoded then failure('encode-save');return end
            ok=pcall(function()api:Set(KEY,raw,events)end)
        end
        if not ok and current()then failure(reading and 'cloud-read' or 'cloud-write')end
    end
    function state:tick(dt)
        if dead then return end
        now=now+math.max(0,dt)
        if inflight and now-inflight.at>=8 then failure('cloud-timeout')end
        if inflight or now<nextAt then return end
        if not api then failure('cloud-unavailable');return end
        if not readDone then request(true)
        elseif revision>ack then request(false)end
    end
    function state:close()dead=true;token=token+1;inflight=nil end
    state:tick(0)
    return state
end
return Cloud
