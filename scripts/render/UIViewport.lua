-- CSS-pixel viewport shared by every raw NVG overlay and its pointer routing.
local Viewport={}
function Viewport.isMobile()
    local platform=GetPlatform and GetPlatform() or ''
    return platform=='Android' or platform=='iOS' or platform=='HarmonyOS' or platform=='OHOS'
end
function Viewport.resolve(w,h,dpr)
    w=math.max(1,w);h=math.max(1,h)
    local ratio=dpr or 1
    if ratio~=ratio or ratio<=0 or ratio==math.huge then ratio=1 end
    -- Android/OHOS can report the engine fallback DPR=1. These UI dimensions
    -- were ported from CSS, so treating a full-HD phone as 1920 CSS px makes
    -- both text and hit targets microscopic. Keep genuine DPRs and desktop/Web
    -- dimensions intact; only the missing native density uses a 360px baseline.
    -- This is a presentation fallback, not a measurement of hardware density.
    local short=math.min(w,h)
    if ratio<=1 and short>=700 and Viewport.isMobile() then
        ratio=math.min(4,short/360)
    end
    return w/ratio,h/ratio,ratio
end
return Viewport
