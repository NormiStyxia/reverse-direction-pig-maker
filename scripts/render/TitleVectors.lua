-- Direct NanoVG paths: no SVG binding or widget runtime is required.
local Glyphs=require('game.data.TitleGlyphPaths')
local V={}
local CX,CY,R=784.8,435.4,404.7
local function stroke(vg,width,r,g,b,alpha)
    nvgStrokeWidth(vg,width);nvgStrokeColor(vg,nvgRGBA(r,g,b,math.floor(alpha*255+.5)));nvgStroke(vg)
end
local function line(vg,x,y,xx,yy)
    nvgBeginPath(vg);nvgMoveTo(vg,x,y);nvgLineTo(vg,xx,yy)
end
function V.logo(vg,mirror)
    for pass=1,2 do
        local offset=pass==1 and 5 or 0
        nvgSave(vg);nvgTranslate(vg,offset,offset)
        nvgFillColor(vg,pass==1 and nvgRGBA(1,64,196,255) or nvgRGBA(255,255,255,255))
        for i,glyph in ipairs(Glyphs) do
            nvgSave(vg)
            if i==1 then nvgTranslate(vg,68,0);nvgScale(vg,mirror,1);nvgTranslate(vg,-68,0) end
            nvgBeginPath(vg)
            for _,contour in ipairs(glyph) do
                for _,cmd in ipairs(contour.commands) do
                    if cmd[1]=='M' then nvgMoveTo(vg,cmd[2],cmd[3])
                    elseif cmd[1]=='L' then nvgLineTo(vg,cmd[2],cmd[3])
                    elseif cmd[1]=='C' then nvgBezierTo(vg,cmd[2],cmd[3],cmd[4],cmd[5],cmd[6],cmd[7])
                    elseif cmd[1]=='Q' then nvgQuadTo(vg,cmd[2],cmd[3],cmd[4],cmd[5]) end
                end
                nvgClosePath(vg);nvgPathWinding(vg,contour.winding)
            end
            nvgFill(vg);nvgRestore(vg)
        end
        nvgRestore(vg)
    end
end
function V.dial(vg,title,drawn,alpha)
    local st,v=title.st,title.view
    local r,g,b=10,60,184
    if v.alt then r,g,b=242,246,255 end
    nvgSave(vg)
    nvgTransform(vg,st.zoom,0,0,st.zoom,1280-(st.cam.x-st.par.x*.004)*2560*st.zoom,576-(st.cam.y-st.par.y*.003)*1152*st.zoom)
    local plane=alpha*(v.planeOpacity or 0)
    nvgGlobalAlpha(vg,plane*(v.blueprintOpacity or 0));nvgLineCap(vg,NVG_BUTT)
    for _,s in ipairs({{0,CY,2560,CY},{CX,0,CX,1152},{CX-1400,CY-868,CX+1400,CY+868},{CX-700,CY+1260,CX+700,CY-1260}}) do
        line(vg,s[1],s[2],s[1]+(s[3]-s[1])*drawn,s[2]+(s[4]-s[2])*drawn)
        stroke(vg,1.6,r,g,b,.5)
    end
    if drawn>0 then
        for _,rad in ipairs({R*1.55,R*.42}) do
            nvgBeginPath(vg);nvgArc(vg,CX,CY,rad,0,2*math.pi*drawn,NVG_CW)
            stroke(vg,1.6,r,g,b,.5)
        end
    end
    nvgFontFace(vg,'title-sans');nvgFontSize(vg,22);nvgTextLetterSpacing(vg,2.2)
    nvgTextAlign(vg,NVG_ALIGN_LEFT+NVG_ALIGN_BASELINE);nvgFillColor(vg,nvgRGBA(r,g,b,153))
    for _,l in ipairs({{CX-R-96,CY-12,'90°'},{CX+14,CY+R+40,'180°'},{CX+R*1.55+16,CY-14,'R 1.55'},{1700,120,'FIG.0 — DRAFT / 草稿'}}) do nvgText(vg,l[1],l[2],l[3]) end
    nvgGlobalAlpha(vg,plane)
    nvgSave(vg);nvgTranslate(vg,CX,CY);nvgRotate(vg,st.dial*math.pi/180)
    for i=0,119 do
        local a=i/120*2*math.pi;local major=i%10==0
        local r0,r1=R+16,R+(major and 44 or 28)
        line(vg,math.sin(a)*r0,-math.cos(a)*r0,math.sin(a)*r1,-math.cos(a)*r1)
        stroke(vg,major and 3 or 2,r,g,b,major and .8 or .55)
    end
    nvgRestore(vg)
    nvgSave(vg);nvgTranslate(vg,CX,CY);nvgRotate(vg,(st.dial*2.4-90)*math.pi/180)
    nvgLineCap(vg,NVG_ROUND);nvgBeginPath(vg);nvgArc(vg,0,0,R,0,50*math.pi/180,NVG_CW)
    stroke(vg,4,201,162,94,1)
    nvgBeginPath(vg);nvgCircle(vg,R,0,7);nvgFillColor(vg,nvgRGBA(201,162,94,255));nvgFill(vg)
    nvgRestore(vg);nvgRestore(vg)
end
return V
