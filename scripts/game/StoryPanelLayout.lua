-- Frozen phone/browse CSS layout in logical CSS pixels (NVG resolution mode B).
-- Text widths are supplied by the real font renderer, never guessed by byte count.
local Layout={}
-- Chromium's normal line box for the frozen WenKai face (928/-256 units, UPM 1000).
function Layout.normalHeight(size) return math.floor(size*.928+.5)+math.floor(size*.256+.5) end
function Layout.place(state,left,right)
    local center=(left+right)/2
    if not state.layoutSide then state.layoutSide=center>.5 and 'left' or 'right'
    elseif state.layoutSide=='right' and center>.58 then state.layoutSide='left'
    elseif state.layoutSide=='left' and center<.42 then state.layoutSide='right' end
    state.frostEdge=state.layoutSide=='right' and math.max(.48,right+.035) or math.min(.52,left-.035)
    state.clearCenter=state.layoutSide=='right' and state.frostEdge/2 or (1+state.frostEdge)/2
    state.clearWidth=state.layoutSide=='right' and state.frostEdge or 1-state.frostEdge
end
function Layout.utf8Prefix(text,count)
    local nextByte=utf8.offset(text,count+1)
    return nextByte and text:sub(1,nextByte-1) or text
end
function Layout.wrap(text,width,size,measure)
    local lines={};local line=''
    for _,cp in utf8.codes(text or '') do
        local char=utf8.char(cp)
        if char=='\n' then lines[#lines+1]=line;line=''
        elseif line~='' and measure(line..char,size)>width then lines[#lines+1]=line;line=char
        else line=line..char end
    end
    lines[#lines+1]=line
    return lines
end
function Layout.panel(w,h,placement,k)
    local small=w<=800
    local wide=w/h>=2
    local width=math.max(.12,placement.layoutSide=='right' and 1-placement.frostEdge or placement.frostEdge)*w
    -- On portrait phones the original half-panel leaves <200px for controls.
    -- Keep desktop geometry exact; keep text and touch controls usable below 600px.
    if w<600 then width=math.max(width,math.min(w-16,340)) end
    local outerX=placement.layoutSide=='right' and w-width or 0
    local near=wide and 18 or (small and 26 or math.max(36,math.min(92,w*.07)));local far=wide and 12 or (small and 14 or 32)
    local x=outerX+(placement.layoutSide=='right' and near or far)
    local padding=small and 10 or 14
    local y=h*(small and .03 or .05)+padding+(1-k)*18
    local bottom=h*(small and .88 or .92)-padding+(1-k)*18
    local headerH=Layout.normalHeight(small and 20 or 24)+3+Layout.normalHeight(small and 11 or 13)+(small and 10 or 16)+1
    if wide then
        return {x=x,y=8+(1-k)*18,w=math.max(1,width-near-far),bottom=h-8+(1-k)*18,headerH=48,gap=6,
            wide=true,small=true,outerX=outerX,outerW=width,contactSize=13,metaSize=10,subtitleSize=10,
            avatar=24,messageGap=6,bubbleSize=math.max(12,math.min(14,h*.028)),lineHeight=1.45,
            bubblePadX=8,bubblePadY=6,threadGap=8}
    end
    return {x=x,y=y,w=math.max(1,width-near-far),bottom=bottom,headerH=headerH,gap=small and 12 or 20,
        small=small,outerX=outerX,outerW=width,contactSize=small and 20 or 24,metaSize=small and 11 or 14,
        avatar=small and 32 or 44,messageGap=small and 7 or 11,bubbleSize=small and 17 or 20,
        lineHeight=small and 1.45 or 1.55,bubblePadX=small and 10 or 13,bubblePadY=small and 8 or 10,
        threadGap=small and 15 or 22}
end
function Layout.choices(list,width,small,measure,touch,wide)
    local buttons={};local x,y,rowH=0,0,0
    local size=small and 14 or 16;local px,py=small and 9 or 12,small and 7 or 8
    if wide then size=12;px=9;py=7 end
    for _,item in ipairs(list) do
        if item.id~='close' then
            local bx,by=px,py;local fontSize=size
            if item.id=='chat' and not wide then bx=24;by=10 end
            if item.terse and not wide then fontSize=18 end
            if item.quietReply and not wide then fontSize=15 end
            local bw=math.min(width,math.max(touch and 44 or 0,measure(item.text,fontSize)+2*bx+2))
            local lines=Layout.wrap(item.text,math.max(1,bw-2*bx-2),fontSize,measure)
            local bh=math.max(touch and 44 or 0,#lines*Layout.normalHeight(fontSize)+2*by+2)
            if x>0 and x+bw>width then x=0;y=y+rowH+8;rowH=0 end
            buttons[#buttons+1]={id=item.id,text=item.text,x=x,y=y,w=bw,h=bh,lines=lines,size=fontSize,px=bx,py=by,quietReply=item.quietReply}
            x=x+bw+8;rowH=math.max(rowH,bh)
        end
    end
    -- Flex's default align-items:stretch gives shorter buttons the row height.
    for _,b in ipairs(buttons) do
        local row=0;for _,other in ipairs(buttons) do if b.y==other.y then row=math.max(row,other.h) end end
        b.h=row
    end
    return buttons,y+rowH
end
function Layout.transcript(phone)
    local result={}
    ---@type table|false
    local previous=false
    local lastStamp=false;local lastOwn=false
    for _,m in ipairs(phone.msgs) do if not m.them and m.status~='recalled' then lastOwn=m.id end end
    local all={}
    for i,m in ipairs(phone.history) do
        all[#all+1]={id='h'..(i-1),me=m.me,history=true,stamp=m.stamp,text=m.text,sticker=m.sticker,name=m.name,avatar=m.avatar,truthUntil=m.truthUntil,gl=m.gl,gx=m.gx,gt=m.gt}
    end
    for _,m in ipairs(phone.msgs) do
        local row={};for key,value in pairs(m) do row[key]=value end;row.me=not m.them;all[#all+1]=row
    end
    for _,m in ipairs(all) do
        m.reacts=phone.reacts and phone.reacts[m.id] or {}
        local stamp=m.stamp or (m.time and (not previous or previous.history or m.minute-previous.minute>=3) and m.time) or false
        if m.stamp or m.time then previous=m end
        m.displayStamp=stamp and stamp~=lastStamp and stamp or false
        m.showRead=m.id==lastOwn
        lastStamp=stamp or lastStamp;result[#result+1]=m
    end
    return result
end
function Layout.message(m,width,p,measure)
    -- Lua's byte-based [] cannot safely classify Chinese punctuation.
    local terse=true
    for _,cp in utf8.codes(m.text) do if not ({[63]=true,[46]=true,[0xff1f]=true,[0x3002]=true,[0x2026]=true,[0xff01]=true})[cp] then terse=false;break end end
    local font=terse and not p.wide and 22 or p.bubbleSize
    local px,py=terse and not p.wide and 14 or p.bubblePadX,terse and not p.wide and 8 or p.bubblePadY
    local maxWidth=width*(p.small and 1 or .95)-p.avatar-p.messageGap
    local bubbleW=math.min(maxWidth,measure(m.text,font)+2*px)
    local lines=Layout.wrap(m.text,math.max(1,bubbleW-2*px),font,measure)
    local nameH=not m.me and m.name and Layout.normalHeight(p.wide and 10 or 13)+4 or 0
    local bubbleH=#lines*font*p.lineHeight+2*py
    if m.sticker then bubbleW=math.min(maxWidth,p.wide and 64 or p.small and 88 or 124);bubbleH=bubbleW end
    local reactions={};local rx,ry=0,0
    local rw,rh=p.wide and 34 or 44,p.wide and 26 or 30
    for _,key in ipairs(m.reacts or {})do
        if rx>0 and rx+rw>maxWidth then rx=0;ry=ry+rh+6 end
        reactions[#reactions+1]={key=key,x=rx,y=ry,w=rw,h=rh};rx=rx+rw+6
    end
    local reactH=#reactions>0 and ry+rh+6 or 0
    local stampH=m.displayStamp and Layout.normalHeight(13)+14 or 0
    return {w=bubbleW,h=stampH+math.max(p.avatar,nameH+bubbleH+reactH+(m.showRead and Layout.normalHeight(12)+6 or 0)),reactions=reactions,reactH=reactH,
        bubbleH=bubbleH,nameH=nameH,stampH=stampH,lines=lines,size=font,px=px,py=py,lineH=font*p.lineHeight}
end
return Layout
