-- Extend the existing imported store without replacing its geometry or parameters.
local base=require('game.data.StoreScene')
local extra=require('game.data.Chapter03WalkersScene')
local function copy(t)local o={};for k,v in pairs(t)do o[k]=v end;return o end
local out=copy(base)
for _,key in ipairs({'nodes','materials','textures','geometries','handles'})do out[key]=copy(base[key])end
local offsets={nodes=#base.nodes,materials=#base.materials,textures=#base.textures,geometries=#base.geometries}
for _,key in ipairs({'textures','geometries','materials','nodes'})do
    for _,original in ipairs(extra[key])do
        local n=copy(original);n.id=n.id+offsets[key]
        if key=='materials'then
            for _,field in ipairs({'map','emissiveMap','alphaMap','gradientMap'})do if n[field]and n[field]>0 then n[field]=n[field]+offsets.textures end end
        elseif key=='nodes'then
            n.parent=n.parent==0 and 0 or n.parent+offsets.nodes
            if n.geometry then n.geometry=n.geometry+offsets.geometries end
            if n.materials then n.materials=copy(n.materials);for i,id in ipairs(n.materials)do n.materials[i]=id+offsets.materials end end
        end
        out[key][#out[key]+1]=n
    end
end
out.handles.rider=extra.handles.rider+offsets.nodes
return out
