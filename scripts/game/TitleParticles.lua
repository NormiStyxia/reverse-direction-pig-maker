-- Authored world-time particle paths from frozen title-screen.js.
local Particles={}
local FW,FH=2560,1152
local feathers={{w=70,h=64,ax=207,ay=148},{w=129,h=108,ax=448,ay=0},
    {w=115,h=96,ax=813,ay=0},{w=133,h=124,ax=311,ay=0},
    {w=123,h=144,ax=0,ay=0},{w=180,h=128,ax=127,ay=0},
    {w=113,h=86,ax=90,ay=148},{w=140,h=108,ax=581,ay=0}}
local birds={{w=81,h=87,ax=932,ay=0},{w=60,h=41,ax=281,ay=148},
    {w=86,h=87,ax=0,ay=148},{w=84,h=96,ax=725,ay=0}}
local function rnd(i,k) local x=math.sin(i*127.1+k*311.7)*43758.5453; return x-math.floor(x) end
local particles={}
for i=0,6 do particles[#particles+1]={s=feathers[i%#feathers+1],kind='feather',
    period=22+rnd(i,1)*14,phase=rnd(i,2)*40,x0=-120+rnd(i,3)*2300,
    drift=380+rnd(i,4)*420,scale=.55+rnd(i,5)*.5,depth=.3+rnd(i,6)*1.1,rot=rnd(i,7)*6.28} end
for i=0,2 do particles[#particles+1]={s=birds[i%#birds+1],kind='bird',
    period=30+rnd(i,11)*16,phase=rnd(i,12)*50,x0=1350+rnd(i,13)*500,
    y0=640+rnd(i,14)*260,scale=.45+rnd(i,15)*.3,depth=.15+rnd(i,16)*.3} end
function Particles.quad(cx,cy,w,h,rot,u0,v0,u1,v1,alpha,depth,occlude,anchorBottom)
    local c,s=math.cos(rot),math.sin(rot)
    local top,bottom=-h/2,h/2
    if anchorBottom then top=-h; bottom=0 end
    local vertices={{-w/2,top,u0,v0},{w/2,top,u1,v0},{w/2,bottom,u1,v1},{-w/2,bottom,u0,v1}}
    for _,v in ipairs(vertices) do local x,y=v[1],v[2]; v[1]=(cx+x*c-y*s)/FW; v[2]=(cy+x*s+y*c)/FH end
    return {vertices=vertices,alpha=alpha,depth=depth,occlude=occlude}
end
function Particles.build(world)
    local result={}
    for _,p in ipairs(particles) do
        local s=p.s; local k=(world+p.phase)%p.period/p.period
        local fade=math.min(1,k*6,(1-k)*6)
        local x,y,rot,h=0,0,0,s.h*p.scale
        if p.kind=='feather' then
            x=p.x0+p.drift*k+math.sin(world*.7+p.phase)*40
            y=-160+k*(FH+320); rot=p.rot+math.sin(world*.55+p.phase)*.7+k*1.2
        else
            x=p.x0+k*1500; y=p.y0-k*900+math.sin(world*1.3+p.phase)*18
            rot=-.15; h=h*(1+.18*math.sin(world*9+p.phase))
        end
        result[#result+1]=Particles.quad(x,y,s.w*p.scale,h,rot,s.ax/1024,s.ay/235,(s.ax+s.w)/1024,(s.ay+s.h)/235,fade*.95,p.depth,0,false)
    end
    return result
end
function Particles.pig(st,aspect)
    local a,steps=st.pigA,math.sin(st.t*9)
    local nx,ny=-math.sin(a),-math.cos(a)
    local px,py=784.8+nx*(404.7-3),435.4+ny*(404.7-3)
    local ph,pw=100,100*aspect
    local lift,rot=math.abs(steps)*5,math.pi-a+steps*.04
    -- JS remainder is signed; abs(remainder) must not use Lua's positive modulo.
    local rem=st.pigSpin-math.modf(st.pigSpin/(math.pi*2))*math.pi*2
    if math.abs(st.pigSpinV)>.05 or math.abs(rem)>.01 then
        return Particles.quad(px-nx*(ph/2+lift),py-ny*(ph/2+lift),pw,ph,rot+st.pigSpin,1,0,0,1,1,.45,1,false)
    end
    return Particles.quad(px-nx*lift,py-ny*lift,pw,ph,rot,1,0,0,1,1,.45,1,true)
end
return Particles
