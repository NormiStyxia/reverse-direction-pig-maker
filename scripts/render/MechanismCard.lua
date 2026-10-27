local Cards=require('game.data.MechanismCards')
local Diagrams=require('game.data.MechanismDiagrams')
local Layout=require('game.StoryPanelLayout')
local Card={};Card.__index=Card
function Card.new()return setmetatable({seen={},open=false},Card)end
function Card:setLevel(theme,index)
    self.key=theme..':'..(index-1);self.card=Cards[self.key];if not self.card then self.open=false end
end
function Card:encounter()if self.card and not self.seen[self.key]then self.seen[self.key]=true;self.open=true;return true end end
function Card:toggle()if self.card then self.open=not self.open end;return self.open end
local function rgb(s)
    s=s or '#2b211d'
    if #s==4 then s='#'..s:sub(2,2):rep(2)..s:sub(3,3):rep(2)..s:sub(4,4):rep(2)end
    local n=tonumber(s:sub(2),16)or 0
    return {(n>>16)&255,(n>>8)&255,n&255,255}
end
local function color(s,alpha)
    if not s or s=='none'then return end
    if s=='#fff'then s='#ffffff'end
    local n=tonumber(s:sub(2),16);if not n then return end
    return nvgRGBA((n>>16)&255,(n>>8)&255,n&255,math.floor((alpha or 1)*255))
end
local function path(vg,d)
    local tokens={};for t in d:gmatch('[A-Za-z][^A-Za-z]*')do tokens[#tokens+1]=t end
    local x,y=0,0;local lastX,lastY
    for _,t in ipairs(tokens)do
        local op=t:sub(1,1);local n={};for num in t:sub(2):gmatch('[-+]?%d*%.?%d+')do n[#n+1]=tonumber(num)end
        lastX,lastY=x,y
        if op=='M'then x,y=n[1],n[2];nvgMoveTo(vg,x,y)
        elseif op=='L'then for i=1,#n,2 do lastX,lastY=x,y;x,y=n[i],n[i+1];nvgLineTo(vg,x,y)end
        elseif op=='H'then x=n[1];nvgLineTo(vg,x,y)
        elseif op=='V'then y=n[1];nvgLineTo(vg,x,y)
        elseif op=='C'then nvgBezierTo(vg,table.unpack(n));lastX,lastY=n[3],n[4];x,y=n[5],n[6]
        elseif op=='z'or op=='Z'then nvgClosePath(vg)end
    end
    return x,y,lastX,lastY
end
local function draw(c,node,opacity)
    local a=node.attrs;local vg=c.vg;local function num(k,d)return tonumber(a[k])or d or 0 end
    nvgSave(vg);opacity=opacity*(tonumber(a.opacity)or 1);nvgGlobalAlpha(vg,opacity)
    if a.transform then local x,y=a.transform:match('translate%(([-.%d]+)[, ]+([-%.%d]+)%)');if x then nvgTranslate(vg,tonumber(x),tonumber(y))end end
    local fill=color(a.fill or '#000000');local stroke=color(a.stroke);local x,y,px,py
    if node.tag=='text'then
        local size=num('font-size',12);local tx=num('x');if a['text-anchor']=='middle'then tx=tx-c:measure(node.text,size)/2 end
        c:text(node.text,tx,num('y')-size*.928,size,rgb(a.fill))
    elseif node.tag~='svg'and node.tag~='g'then
        nvgBeginPath(vg)
        if node.tag=='rect'then nvgRoundedRect(vg,num('x'),num('y'),num('width'),num('height'),num('rx'))
        elseif node.tag=='circle'then nvgCircle(vg,num('cx'),num('cy'),num('r'))
        elseif node.tag=='ellipse'then nvgEllipse(vg,num('cx'),num('cy'),num('rx'),num('ry'))
        elseif node.tag=='line'then nvgMoveTo(vg,num('x1'),num('y1'));nvgLineTo(vg,num('x2'),num('y2'));fill=nil
        elseif node.tag=='path'then x,y,px,py=path(vg,a.d);if a['marker-end']then fill=nil end end
        if fill then nvgFillColor(vg,fill);nvgFill(vg)end
        if stroke then nvgStrokeColor(vg,stroke);nvgStrokeWidth(vg,num('stroke-width',1));nvgStroke(vg)end
        if x and a['marker-end']and px then
            local angle=math.atan(y-py,x-px);nvgBeginPath(vg);nvgMoveTo(vg,x,y)
            nvgLineTo(vg,x-8*math.cos(angle-.5),y-8*math.sin(angle-.5));nvgLineTo(vg,x-8*math.cos(angle+.5),y-8*math.sin(angle+.5));nvgClosePath(vg);nvgFillColor(vg,stroke);nvgFill(vg)
        end
    end
    for _,child in ipairs(node.children)do draw(c,child,opacity)end
    nvgRestore(vg)
end
function Card:render(c)
    if not self.open or not self.card then return end
    local vg=c.vg;local wide=c.w/c.h>=2 or c.h<480;local w=math.min(c.w-24,640);local h=math.min(c.h-20,540);local x,y=(c.w-w)/2,(c.h-h)/2
    local function rect(x,y,w,h,col)nvgBeginPath(vg);nvgRect(vg,x,y,w,h);nvgFillColor(vg,nvgRGBA(table.unpack(col)));nvgFill(vg)end
    rect(0,0,c.w,c.h,{15,20,30,170});rect(x,y,w,h,{249,244,228,255})
    local card=self.card;local size=wide and 13 or 17;local top=y+14
    c:text(card.no,x+18,top,11,{125,108,78,255});top=top+18
    c:text(card.title,x+18,top,wide and 18 or 24,{43,33,29,255});top=top+(wide and 26 or 34)
    local function lines(text,sz)
        local ls=Layout.wrap(text,w-36,sz,function(t,s)return c:measure(t,s)end)
        for _,v in ipairs(ls)do c:text(v,x+18,top,sz,{74,65,54,255});top=top+sz*1.45 end
    end
    lines(card.sub,wide and 12 or 14);top=top+6
    local tipSize=wide and 12 or 14;local tipHeight=0
    for _,tip in ipairs(card.tips)do
        local wrapped=Layout.wrap(tip[1]..'：'..tip[2],w-36,tipSize,function(t,s)return c:measure(t,s)end)
        tipHeight=tipHeight+#wrapped*tipSize*1.45+4
    end
    local diagramSpace=y+h-38-top-tipHeight-8
    local scale=math.max(0,math.min((w-30)/520,1,diagramSpace/190))
    nvgSave(vg);nvgTranslate(vg,x+(w-520*scale)/2,top);nvgScale(vg,scale,scale);draw(c,Diagrams[self.key],1);nvgRestore(vg);top=top+190*scale+8
    for _,tip in ipairs(card.tips)do lines(tip[1]..'：'..tip[2],wide and 12 or 14);top=top+4 end
    c:text('知道了  ·  J / 空格 / Enter / F / Esc / 点击关闭',x+18,y+h-26,wide and 11 or 13,{1,64,196,255})
end
return Card
