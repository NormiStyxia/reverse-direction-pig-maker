-- Frozen phone.js sticker grid and per-message reactions, drawn in logical NVG pixels.
local Data=require('game.data.Story03Data')
local Extras={}
local function box(c,x,y,w,h,color,r)
    local vg=c.vg;nvgBeginPath(vg);nvgRoundedRect(vg,x,y,w,h,r or 6);nvgFillColor(vg,nvgRGBA(table.unpack(color)));nvgFill(vg)
end
function Extras.reset(c)c.stickersOpen=false;c.reactFor=false;c.longPressed=false;c.composerScroll=0 end
function Extras.action(c,id)
    local p=c.story.phone;if not p.stickers then return false end
    if id=='stickers' then c.stickersOpen=not c.stickersOpen;c.reactFor=false;c.composerScroll=0;c.scrollBottom=true;return true end
    if id:sub(1,5)=='stab:' then c.stickerTab=id:sub(6);return true end
    if id:sub(1,9)=='reactbar:' then c.reactFor=c.reactFor~=id:sub(10) and id:sub(10) or false;c.stickersOpen=false;return true end
    if id=='dismiss-react' then c.reactFor=false;return true end
    if id:sub(1,8)=='sticker:' then c.stickersOpen=false;c.reactFor=false;c.composerScroll=0;c.scrollBottom=true;return false end
    if id:sub(1,6)=='react:' then
        c.reactFor=false
        local mid,key=id:match('^react:([^:]+):(.+)$');if not mid then return true end
        p.reacts=p.reacts or {};local list=p.reacts[mid] or {};p.reacts[mid]=list
        for i,r in ipairs(list)do if r==key then table.remove(list,i);if c.story.saveChat then c.story:saveChat()end;return true end end
        list[#list+1]=key;c.story:onPhone(id);return true
    end
    return false
end
function Extras.input(c,p,y,h)
    if not c.story.phone.stickers then return 0 end
    h=h or 44;local size=36;local vg=c.vg;local cy=y+h/2;local cx=p.x+size/2
    box(c,p.x,y,size,h,c.stickersOpen and {205,238,211,255}or {250,251,244,230},6)
    -- Same outlined smile as phone.js; never depend on a platform emoji font.
    nvgBeginPath(vg);nvgCircle(vg,cx,cy,10);nvgStrokeWidth(vg,1.6);nvgStrokeColor(vg,nvgRGBA(79,95,76,255));nvgStroke(vg)
    nvgBeginPath(vg);nvgMoveTo(vg,cx-4,cy+3);nvgBezierTo(vg,cx-2,cy+7,cx+2,cy+7,cx+4,cy+3);nvgStroke(vg)
    nvgBeginPath(vg);nvgCircle(vg,cx-3,cy-3,.8);nvgCircle(vg,cx+3,cy-3,.8);nvgFillColor(vg,nvgRGBA(79,95,76,255));nvgFill(vg)
    c:addHit('stickers','表情',p.x,y,size,h);return size+(p.wide and 5 or 8)
end
function Extras.gridLayout(c,p)
    if not c.stickersOpen or not c.story.phone.stickers then return nil end
    local group=Data.STICKERS[1];for _,g in ipairs(Data.STICKERS)do if g.id==c.stickerTab then group=g end end
    local pad=p.wide and 6 or 10;local top=p.wide and 6 or 8
    local size=math.max(1,(p.w-2*pad-12)/4)
    if not p.small then size=math.min(92,size)end
    local tabH=require('game.StoryPanelLayout').normalHeight(14)+6
    return {group=group,pad=pad,top=top,size=size,tabH=tabH,gridY=top+tabH+6,h=top+tabH+6+math.ceil(#group.list/4)*(size+4)-4+pad}
end
function Extras.grid(c,p,top,g)
    if not g then return end
    box(c,p.x,top,p.w,g.h,{250,251,244,235},8)
    local x=p.x+g.pad
    for _,group in ipairs(Data.STICKERS)do
        local width=c:measure(group.label,14)+24
        box(c,x,top+g.top,width,g.tabH,group==g.group and {205,238,211,255}or {250,251,244,0},12)
        c:text(group.label,x+12,top+g.top+3,14,{59,88,64,255});c:addHit('stab:'..group.id,group.label,x,top+g.top,width,g.tabH);x=x+width+4
    end
    for i,s in ipairs(g.group.list)do
        local xx=p.x+g.pad+((i-1)%4)*(g.size+4);local y=top+g.gridY+math.floor((i-1)/4)*(g.size+4)
        c:image('stickers/'..s[1]..'.png',xx+6,y+6,math.max(1,g.size-12),math.max(1,g.size-12));c:addHit('sticker:'..s[1],s[2],xx,y,g.size,g.size)
    end
end
function Extras.message(c,m,bx,by,layout,p)
    if not m.id or m.me or not c.story.phone.stickers or c.channel~='phone' then return end
    local thread=c.thread;local top=math.max(by,thread.y);local bottom=math.min(by+layout.bubbleH,thread.y+thread.h)
    if bottom>top then c:addHit('reactbar:'..m.id,'回应',bx,top,layout.w,bottom-top);c.hits[#c.hits].message=true end
    for _,r in ipairs(layout.reactions)do
        local x,y=bx+r.x,by+layout.bubbleH+6+r.y
        box(c,x,y,r.w,r.h,{250,251,244,225},13);c:image('stickers/'..r.key..'.png',x+3,y+2,r.h-4,r.h-4)
        c:text('1',x+r.w-11,y+7,10,{60,75,58,255})
        if y>=thread.y and y+r.h<=thread.y+thread.h then c:addHit('react:'..m.id..':'..r.key,'取消回应',x,y,r.w,r.h)end
    end
    if c.reactFor==m.id then c.reactAnchor={x=bx,y=by,w=layout.w,h=layout.bubbleH}end
end
function Extras.reactionBar(c,p)
    local a=c.reactAnchor;if not c.reactFor or not a or not c:inputEnabled()then return end
    local size=c.touchUI and 44 or (p.small and 30 or 36);local cols=math.max(1,math.min(9,math.floor((p.w-12)/(size+2))))
    local w=cols*(size+2)+10;local h=math.ceil(#Data.REACTIONS/cols)*(size+2)+10
    local x=math.max(p.x,math.min(p.x+p.w-w,a.x));local y=a.y-h-6
    if y<c.thread.y then y=a.y+a.h+6 end
    y=math.max(c.thread.y,math.min(c.thread.y+c.thread.h-h,y))
    c:addHit('dismiss-react','关闭回应',p.x,c.thread.y,p.w,c.thread.h)
    box(c,x,y,w,h,{252,252,246,248},18)
    local selected={};for _,r in ipairs(c.story.phone.reacts[c.reactFor] or {})do selected[r]=true end
    for i,r in ipairs(Data.REACTIONS)do
        local xx=x+5+(i-1)%cols*(size+2);local yy=y+5+math.floor((i-1)/cols)*(size+2)
        if selected[r[1]]then box(c,xx,yy,size,size,{205,238,211,255},size/2)end
        c:image('stickers/'..r[1]..'.png',xx+3,yy+3,size-6,size-6);c:addHit('react:'..c.reactFor..':'..r[1],r[2],xx,yy,size,size)
    end
end
return Extras
