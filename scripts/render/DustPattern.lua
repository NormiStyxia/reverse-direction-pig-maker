-- Exact frozen world.js buildDust positions (Float32Array, RH source space).
local Pattern={}
function Pattern.positions(count,spread,layer)
    local s=(count+layer*7)*2654435761 & 0xffffffff
    if s==0 then s=1 end
    local function random()
        s=(s ~ (s<<13)) & 0xffffffff
        s=s ~ (s>>17)
        s=(s ~ (s<<5)) & 0xffffffff
        return s/4294967296
    end
    local function f32(v) return (string.unpack('f',string.pack('f',v))) end
    local points={}
    for i=1,count do
        points[i]={f32((random()-.5)*spread[1]),f32(random()*spread[2]),f32((random()-.5)*spread[3])}
    end
    return points
end
Pattern.main=Pattern.positions(260,{44,12,30},0)
Pattern.near=Pattern.positions(46,{6,4,4},1)
return Pattern
