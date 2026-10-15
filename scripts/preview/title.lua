-- Development render probe, derived from scaffold-3d-scene.lua lifecycle.
-- Not the game entry: title UI/dial and story scenes are still being integrated.
local Title=require('game.TitleState')
local TitleScene=require('render.TitleRenderer')
local title=Title.new(0)
---@type TitleRenderer
local view
local width,height=0,0
function Start()
    graphics.windowTitle='反方向的猪 · 标题渲染校验'
    input.mouseMode=MM_ABSOLUTE
    view=TitleScene.new()
    SubscribeToEvent('Update','TitlePreviewUpdate')
    SubscribeToEvent('KeyDown','TitlePreviewKeyDown')
    SubscribeToEvent('KeyUp','TitlePreviewKeyUp')
    SubscribeToEvent('InputFocus','TitlePreviewFocus')
    print('TITLE_RENDER_PROBE: native SurfaceShader; UI/dial/story pending')
end
---@param eventData UpdateEventData
function TitlePreviewUpdate(eventType,eventData)
    local w,h=graphics:GetWidth(),graphics:GetHeight()
    if w~=width or h~=height then width=w; height=h; view:resize(w,h) end
    local frame=Title.layout(w,h)
    title:pointer((input.mousePosition.x-frame.x)/frame.width*2-1,(input.mousePosition.y-frame.y)/frame.height*2-1)
    if input:GetMouseButtonPress(MOUSEB_LEFT) then title:skipIntro() end
    title:update(eventData:GetFloat('TimeStep'))
    view:update(title)
end
---@param eventData KeyDownEventData
function TitlePreviewKeyDown(eventType,eventData)
    local key=eventData:GetInt('Key')
    if title.st.phase=='intro' then title:skipIntro()
    elseif key==KEY_K or key==KEY_SHIFT or key==KEY_LSHIFT or key==KEY_RSHIFT then
        title:keyDown('K',eventData:GetBool('Repeat'))
    end
end
---@param eventData KeyUpEventData
function TitlePreviewKeyUp(eventType,eventData)
    local key=eventData:GetInt('Key')
    if key==KEY_K or key==KEY_SHIFT or key==KEY_LSHIFT or key==KEY_RSHIFT then title:keyUp('K') end
end
---@param eventData InputFocusEventData
function TitlePreviewFocus(eventType,eventData) if not eventData:GetBool('Focus') then title:blur() end end
function Stop() view:dispose() end
