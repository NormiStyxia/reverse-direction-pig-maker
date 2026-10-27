-- Frozen timeline portal image persists across native scene disposal, then fades.
local P=require('game.TitlePresentation')
local Portal={}
function Portal.attach(canvas,id)
    canvas.portal={path='timeline/'..id..'.jpg',t=0}
end
function Portal.update(canvas,dt,ready)
    if canvas.portal and ready then
        canvas.portal.t=canvas.portal.t+dt
        if canvas.portal.t>=1.05 then canvas.portal=nil end
    end
end
function Portal.draw(c)
    local p=c.portal;if not p then return end
    local opacity=1-P.bezier(math.max(0,math.min(1,(p.t-.15)/.9)),.42,0,1,1)
    local vg=c.vg;nvgSave(vg);nvgGlobalAlpha(vg,opacity)
    nvgBeginPath(vg);nvgRect(vg,0,0,c.w,c.h);nvgFillColor(vg,nvgRGBA(10,53,160,255));nvgFill(vg)
    c:image(p.path,0,0,c.w,c.h,true);nvgRestore(vg)
end
return Portal
