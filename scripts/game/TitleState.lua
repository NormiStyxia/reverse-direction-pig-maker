-- Frozen src/title-screen.js. Engine-independent animation/menu state.
-- Menu selections and level choices keep H5's zero-based indices.
local Title = {}
Title.__index = Title
local function clamp(x, a, b) return math.min(b or 1, math.max(a or 0, x)) end
local function ease(x) x=clamp(x); return x < .5 and 4*x*x*x or 1-(-2*x+2)^3/2 end
local function easeOut(x) return 1-(1-clamp(x))^3 end
local function sign(x) return x == 0 and 0 or (x > 0 and 1 or -1) end
local function inWindows(t, windows)
    for _,w in ipairs(windows) do if t>=w[1] and t<w[2] then return true end end
    return false
end
local FLASH={{.32,.4},{.5,.55},{.66,.74},{.86,1},{1.12,1.5}}
local GSIL={{.16,.22},{.38,.43},{.56,.6}}
function Title.new(reached, random)
    local self=setmetatable({},Title)
    self:init(reached,random)
    return self
end
function Title:init(reached,random)
    self.random=random or math.random
    self.reached=clamp(reached or 0,0,6)
    self.opts={motion=true,parallax=true,muted=false}
    self.st={t=0,world=0,intro=0,phase='intro',prog=0,reveal=0,zoom=2.3,
        cam={x=.245,y=.33},sil=0,flash=0,rewind=0,wash=0,glitch=0,gsil=0,
        auto={stage='wait',t=0,next=5+self.random()*5},par={x=0,y=0},parT={x=0,y=0},
        dial=0,clock=23*3600+38*60,pigA=.35,pigSpin=0,pigSpinV=0,holding=false,
        leaveT=0,choice=false,started=false}
    self.panel=false; self.sel=0; self.menuSel=0; self.active=true; self.covering=true
    self.view={blueprintDrawn=false,uiIn=false,washOn=false,gone=false}
    self.events={}
end
function Title:drainEvents() local events=self.events; self.events={}; return events end
function Title:skipIntro()
    if self.st.phase=='intro' and self.st.intro<5.6 then self.st.intro=5.6 end
end
function Title:count() return self.panel=='chapters' and 7 or 4 end
function Title:disabled(i)
    if self.panel=='chapters' then return i>self.reached end
    return not self.panel and i==1 and self.reached==0
end
function Title:select(i)
    local n=self:count()
    for k=0,n-1 do local j=(i+k)%n; if not self:disabled(j) then i=j; break end end
    self.sel=i
    if not self.panel then self.menuSel=i end
end
function Title:step(dir)
    local i=self.sel
    for _=1,self:count() do i=(i+dir)%self:count(); if not self:disabled(i) then break end end
    self:select(i)
end
function Title:openPanel(kind,keep) self.panel=kind; self:select(keep or 0) end
function Title:closePanel() self.panel=false; self:select(self.menuSel) end
function Title:leave(choice) self.st.phase='leaving'; self.st.leaveT=0; self.st.choice=choice end
function Title:activate(i)
    i=i or self.sel
    if self.st.phase~='idle' or self:disabled(i) then return end
    if self.panel=='chapters' then
        self:leave(i==0 and {kind='new'} or {kind='echo',level=i-1})
    elseif self.panel=='options' then
        local keys={'motion','parallax','muted'}
        if i==3 then self:closePanel() else
            local key=keys[i+1]; self.opts[key]=not self.opts[key]
            if key=='muted' then self.events[#self.events+1]={kind='mute',muted=self.opts.muted} end
            self:openPanel('options',i)
        end
    elseif i==0 then self:leave({kind='new'})
    elseif i==1 then self:leave({kind='echo',level=self.reached-1})
    elseif i==2 then self:openPanel('chapters')
    elseif i==3 then self:openPanel('options') end
end
function Title:keyDown(key,repeated)
    local up=key=='ArrowUp' or key=='w' or key=='W'
    local down=key=='ArrowDown' or key=='s' or key=='S'
    if repeated and not (up or down) then return end
    if self.st.phase=='intro' then self:skipIntro(); return end
    if key=='k' or key=='K' or key=='Shift' then self.st.holding=true; return end
    if self.st.phase~='idle' then return end
    if up then self:step(-1) elseif down then self:step(1)
    elseif key=='Enter' or key==' ' or key=='f' or key=='F' then self:activate()
    elseif (key=='Escape' or key=='Backspace') and self.panel then self:closePanel() end
end
function Title:keyUp(key)
    if key=='k' or key=='K' or key=='Shift' then self.st.holding=false end
end
function Title:blur() self.st.holding=false end
function Title:pointer(x,y) self.st.parT.x=clamp(x,-1,1); self.st.parT.y=clamp(y,-1,1) end
function Title.layout(width,height)
    local w=math.min(width,height*20/9); local h=w*9/20
    return {x=(width-w)/2,y=(height-h)/2,width=w,height=h,scale=w/2560}
end
function Title:update(dt)
    if not self.active then return end
    local st,opts,v=self.st,self.opts,self.view
    -- H5 requestAnimationFrame clamps elapsed time before invoking update.
    dt=math.min(.05,math.max(0,dt))
    st.t=st.t+dt; st.intro=st.intro+dt; local it=st.intro
    if st.phase=='intro' then
        st.sil=clamp((it-.2)/.15); st.flash=inWindows(it,FLASH) and 1 or 0
        if it>.25 then v.blueprintDrawn=true end
        local pull=ease((it-1.8)/1.8)
        local z0=2.3+.15*clamp(it/1.9); local z1=1.06-.03*easeOut((it-3.6)/1.6)
        st.zoom=math.exp(math.log(z0)+(math.log(z1)-math.log(z0))*pull)
        st.cam.x=.245+(.5-.245)*pull; st.cam.y=.33+(.5-.33)*pull
        st.reveal=easeOut((it-1.75)/1.3); st.prog=ease((it-4.2)/1.2)
        if it>5 then v.uiIn=true end
        if it>5.6 then
            st.phase='idle'; st.reveal=1; st.sil=1; st.flash=0; st.cam.x=.5; st.cam.y=.5; self:select(0)
        end
    elseif st.phase=='idle' then
        local a=st.auto; a.t=a.t+dt
        if a.stage=='wait' and a.t>a.next then a.stage='glitch'; a.t=0
        elseif a.stage=='glitch' and a.t>.75 then a.stage='draft'; a.t=0; st.prog=0
        elseif a.stage=='draft' and a.t>5 then a.stage='glitchBack'; a.t=0
        elseif a.stage=='glitchBack' and a.t>.5 then
            a.stage='wait'; a.t=0; a.next=5+self.random()*5; if not st.holding then st.prog=1 end
        end
        local gT=a.stage=='glitch' and .75 or (a.stage=='glitchBack' and .5 or 0)
        st.glitch=gT>0 and math.sin(math.pi*a.t/gT)*(.55+.45*self.random()) or 0
        st.gsil=gT>0 and inWindows(a.t*.75/gT,GSIL) and 1 or 0; st.flash=st.gsil
        if a.stage=='draft' or a.stage=='glitchBack' then st.prog=0
        else st.prog=clamp(st.prog+sign((st.holding and 0 or 1)-st.prog)*dt*(st.holding and .95 or .7)) end
        st.zoom=st.zoom+(1.03+.004*math.sin(st.t*.4)-st.zoom)*math.min(1,dt*1.5)
    elseif st.phase=='leaving' then
        st.leaveT=st.leaveT+dt; local lt=st.leaveT
        st.prog=clamp(1-lt/.6); st.wash=easeOut((lt-.55)/.5)
        if lt>.5 then v.washOn=true end
        if lt>1.1 and not st.started then
            st.started=true; self.covering=false; v.gone=true
            self.events[#self.events+1]={kind='start',choice=st.choice}
        end
        if lt>2.4 then self.active=false; self.events[#self.events+1]={kind='dispose'} end
    end
    local held=st.holding and st.phase=='idle'
    local rewinding=(st.phase=='leaving' or held) and st.prog>0
    local atStart=held and st.prog==0
    st.rewind=st.rewind+((rewinding and 1 or 0)-st.rewind)*math.min(1,dt*6)
    v.held=held; v.atStart=atStart; v.glitch=st.glitch>.15
    st.world=st.world+dt*(opts.motion and (rewinding and -2.6 or (atStart and 0 or 1)) or 0)
    st.clock=st.clock-dt*(rewinding and 90 or (atStart and 0 or 1))
    st.dial=st.dial-dt*(rewinding and 160 or 5)
    st.pigA=st.pigA+dt*math.pi*2/46
    st.pigSpinV=st.pigSpinV+((rewinding and -14 or 0)-st.pigSpinV)*math.min(1,dt*4)
    st.pigSpin=st.pigSpin+st.pigSpinV*dt
    if not rewinding then
        local rounded=math.floor(st.pigSpin/(math.pi*2)+.5)
        st.pigSpin=st.pigSpin+(rounded*math.pi*2-st.pigSpin)*math.min(1,dt*3)
    end
    local k=opts.parallax and math.min(1,dt*3) or 1
    st.par.x=st.par.x+((opts.parallax and st.parT.x or 0)-st.par.x)*k
    st.par.y=st.par.y+((opts.parallax and st.parT.y or 0)-st.par.y)*k
    st.cam.x=clamp(st.cam.x,.5/st.zoom,1-.5/st.zoom); st.cam.y=clamp(st.cam.y,.5/st.zoom,1-.5/st.zoom)
    v.blueprintOpacity=(1-st.prog)*clamp((it-.2)*2)
    local introDial=st.phase=='intro' and clamp((it-.3)*3)*(1-st.prog)*.9 or 0
    v.planeOpacity=math.max(introDial,.35+.65*clamp(st.prog*1.4+(st.phase=='intro' and 0 or st.rewind*.4)))
    local seconds=math.floor(st.clock)%86400
    v.clockText=string.format('LAT. %02d:%02d:%02d',math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60)
end
return Title
