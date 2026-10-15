-- CSS timing functions used by the frozen title. No wall clock or engine state.
local P={}
local function clamp(x) return math.max(0,math.min(1,x)) end
function P.bezier(t,x1,y1,x2,y2)
    t=clamp(t)
    local function value(u,a,b) return 3*(1-u)^2*u*a+3*(1-u)*u*u*b+u^3 end
    local lo,hi=0,1
    for _=1,30 do local mid=(lo+hi)/2; if value(mid,x1,x2)<t then lo=mid else hi=mid end end
    return value((lo+hi)/2,y1,y2)
end
function P.ease(t) return P.bezier(t,.25,.1,.25,1) end
function P.slide(t) return P.bezier(t,.2,.7,.2,1) end
function P.reveal(t) return P.bezier(t,.7,0,.2,1) end
function P.mirror(t) return P.bezier(t,.3,0,.2,1) end
function P.blueprint(t) return P.bezier(t,.6,0,.2,1) end
function P.track(track,target,time,duration,curve)
    local function sample()
        return track.from+(track.target-track.from)*curve((time-track.start)/duration)
    end
    local current=sample()
    if target~=track.target then track.from=current;track.target=target;track.start=time end
    return current
end
function P.channel(value) return {from=value,target=value,start=0} end
return P
