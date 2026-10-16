-- Frozen phArrive and phSend CSS keyframes, in seconds/logical pixels.
local Curves=require('game.TitlePresentation')
local Motion={}
function Motion.arrive(age)
    local t=Curves.ease(age/.32)
    return {alpha=t,y=10*(1-t),scale=1}
end
function Motion.send(age)
    local t=math.max(0,math.min(1,age/.5))
    if t<.65 then
        local k=Curves.bezier(t/.65,.2,.9,.25,1)
        return {alpha=k,y=42-45*k,scale=.82+.205*k}
    end
    local k=Curves.bezier((t-.65)/.35,.2,.9,.25,1)
    return {alpha=1,y=-3+3*k,scale=1.025-.025*k}
end
return Motion
