-- Frozen style.css phone title media query (132px rail / 44px rows).
-- Coordinates are CSS pixels; the title illustration remains in design space.
local Compact={}
local Catalog=require('game.LevelCatalog')
function Compact.active(c)
    local w,h=c.logicalW,c.logicalH
    return w>h and(w/h>=2 or(c.touchMode and h<=600))
end
function Compact.frame(c)
    return c.offsetX*c.scale,c.offsetY*c.scale,2560*c.scale,1152*c.scale
end
function Compact.layout(c)
    local fx,fy,fw,fh=Compact.frame(c)
    local rows,sections={},{}
    if not c.title.panel then
        for i=0,4 do rows[#rows+1]={id='menu:'..i,index=i,x=fx+fw-132,y=fy+fh/2-110+i*44,w=132,h=44}end
        return rows,sections
    end
    local w=math.min(c.logicalW*.65,360);local x=fx+fw-w
    local border=8*c.scale;local left=x+border+16;local inner=w-border-32
    local y=fy+65
    if c.title.panel=='levelmode' then
        for group,set in ipairs(Catalog)do
            sections[#sections+1]={x=left,y=y+14,text=({'第一章','第二章','第三章','第四章'})[group]..' · '..set.name..'回响'}
            y=y+30
            for level,data in ipairs(set.levels)do
                local index=#rows
                rows[#rows+1]={id='levelmode:'..index,index=index,x=left,y=y,w=inner,h=44,text=data.name,no=({'一','二','三','四'})[group]..string.format('%02d',level)}
                y=y+44
            end
        end
    else
        for i=0,c.title:count()-1 do
            local label=c.title.panel=='options'and({'画面动态','鼠标视差','声音','返回'})[i+1]or(i==0 and'序章 · 23:38'or('第 '..i..' 层'))
            rows[#rows+1]={id=c.title.panel..':'..i,index=i,x=left,y=y,w=inner,h=44,text=label};y=y+44
        end
    end
    c.compactScrollMax=math.max(0,y+12-(fy+fh))
    c.compactScroll=math.max(0,math.min(c.compactScroll or 0,c.compactScrollMax))
    if c.compactSelection~=c.title.sel then
        local selected=rows[c.title.sel+1]
        if selected then
            local top=selected.y-c.compactScroll
            if top<fy+65 then c.compactScroll=selected.y-fy-65
            elseif top+44>fy+fh-12 then c.compactScroll=selected.y+44-fy-fh+12 end
        end
        c.compactSelection=c.title.sel
    end
    for _,r in ipairs(rows)do r.y=r.y-c.compactScroll end
    for _,r in ipairs(sections)do r.y=r.y-c.compactScroll end
    rows[#rows+1]={id=c.title.panel..':back',x=fx+fw-84,y=fy+12,w=60,h=44,text='‹ 返回'}
    return rows,sections,{x=x,y=fy,w=w,h=fh,left=left,inner=inner}
end
function Compact.hit(c,x,y)
    local _,fy,_,fh=Compact.frame(c)
    for _,r in ipairs(Compact.layout(c))do
        local visible=not c.title.panel or r.index==nil or(y>=fy+65 and y<fy+fh-12)
        if visible and(r.index==nil or not c.title:disabled(r.index))and x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then return r.id,r.index end
    end
    return false
end
function Compact.draw(c,alpha,text,rect,names,paper,blue,ink,white)
    local vg=c.vg;local rows,sections,p=Compact.layout(c)
    nvgSave(vg);nvgResetTransform(vg);nvgResetScissor(vg);nvgGlobalAlpha(vg,alpha)
    if p then
        rect(vg,p.x,p.y,p.w,p.h,paper,.9);rect(vg,p.x,p.y,8*c.scale,p.h,blue)
        text(vg,c.title.panel=='levelmode'and'关卡模式'or c.title.panel=='chapters'and'选择关卡'or'设置',p.left,p.y+12,18,ink)
        text(vg,c.title.panel=='levelmode'and'LEVEL MODE'or c.title.panel=='chapters'and'CHAPTERS'or'OPTIONS',p.left,p.y+42,9,ink,nil,.72,nil,.6)
    else
        local r=rows[1];rect(vg,r.x,r.y,r.w,220,paper,.88)
    end
    nvgSave(vg)
    if p then nvgIntersectScissor(vg,p.left,p.y+65,p.inner,math.max(0,p.h-77))end
    for _,s in ipairs(sections)do text(vg,s.text,s.x,s.y,10,ink,nil,.8,nil,.6)end
    for _,r in ipairs(rows)do if r.index~=nil then
        local selected=(p and c.title.sel or c.title.menuSel)==r.index
        local disabled=c.title:disabled(r.index);local fg=selected and white or ink
        nvgGlobalAlpha(vg,alpha*(disabled and .38 or 1))
        if p then
            if selected then rect(vg,r.x,r.y,r.w,r.h,blue)end
            rect(vg,r.x,r.y+r.h-2*c.scale,r.w,2*c.scale,ink,.14)
            local tx=r.x+6
            if r.no then text(vg,r.no,tx,r.y+16,10,fg,nil,.8,nil,.6);tx=tx+38 end
            text(vg,r.text,tx,r.y+13,13,fg)
            if c.title.panel=='options'and r.index<3 then
                local on=({c.title.opts.motion,c.title.opts.parallax,not c.title.opts.muted})[r.index+1]
                text(vg,on and'开 ON'or'关 OFF',r.x+r.w-6,r.y+16,10,fg,NVG_ALIGN_RIGHT,.8,nil,.7)
            end
        else
            local amount=c.rowAmounts[r.index+1]
            rect(vg,r.x+r.w*(1-amount),r.y+4*c.scale,r.w*amount,44-8*c.scale,blue)
            text(vg,string.format('%02d',r.index+1),r.x+8,r.y+14,9,fg,nil,.72,nil,selected and .8 or .55)
            text(vg,names[r.index+1][1],r.x+r.w-12,r.y+7*c.scale,13,fg,NVG_ALIGN_RIGHT,1.56,'title-bold')
            text(vg,r.index==1 and not c.title.latest and c.title.reached==0 and'NO SAVE'or names[r.index+1][2],r.x+r.w-12,r.y+7*c.scale+13*1.15+c.scale,8,fg,NVG_ALIGN_RIGHT,.64,nil,.65)
        end
    end end
    nvgRestore(vg);nvgGlobalAlpha(vg,alpha)
    if p then local r=rows[#rows];rect(vg,r.x,r.y,r.w,r.h,paper);text(vg,r.text,r.x+6,r.y+15,12,ink)
    else
        local r=rows[c.title.menuSel+1];local w=62*c.scale;local h=c.pigHeight*c.scale
        nvgTranslate(vg,r.x-70*c.scale+w/2,r.y+4*c.scale+h/2)
        nvgRotate(vg,-2*math.pi*require('game.TitlePresentation').mirror((c.title.st.t-c.cursorSpinAt)/.6))
        nvgBeginPath(vg);nvgRect(vg,-w/2,-h/2,w,h);nvgFillPaint(vg,nvgImagePattern(vg,-w/2,-h/2,w,h,0,c.pig,1));nvgFill(vg)
    end
    nvgRestore(vg)
end
return Compact
