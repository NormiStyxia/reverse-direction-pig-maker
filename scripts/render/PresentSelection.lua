-- Reconstruct frozen rewind-levels.js markPresent calls from exported handles.
-- Match post.js cutout exactly; translucent textured papers are NOT solid masks.
local Selection={}
function Selection.ids(data)
    if not data.definition then return {} end
    local roots,plates={},{}
    for i,c in ipairs(data.definition.crates or {}) do
        local kind=c.kind or (c.gold and 'gold' or 'card')
        if c.gold or kind=='tonight' or kind=='bag' or kind=='now' then roots[data.handles.crates[i].id]=true end
    end
    if data.handles.merged then roots[data.handles.merged.id]=true end
    for i,p in ipairs(data.definition.plates or {}) do
        if p.gold then plates[data.handles.plates[i]]=true end
    end
    local result,under={},{}
    for _,n in ipairs(data.nodes) do
        under[n.id]=roots[n.id] or under[n.parent] or false
        local marked=under[n.id];local cutout=n.type=='Sprite'
        for _,id in ipairs(n.materials or {}) do
            local m=data.materials[id]
            if plates[id] then marked=true end
            if m.map and m.map~=0 and (m.transparent or (m.alphaTest or 0)>0) then cutout=true end
        end
        if marked and not cutout and n.geometry then result[#result+1]=n.id end
    end
    return result
end
return Selection
