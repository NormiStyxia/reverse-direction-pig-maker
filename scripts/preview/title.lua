-- Development render probe, derived from scaffold-3d-scene.lua lifecycle.
-- Not the game entry: story scenes are still being integrated.
local Title=require('game.TitleState')
local TitleScene=require('render.TitleRenderer')
local TitleCanvas=require('render.TitleOverlay')
local title=Title.new(0)
---@type TitleRenderer
local view
local overlay={}
local width,height,dpr=0,0,0
function Start()
    graphics.windowTitle='反方向的猪 · 标题渲染校验'
    input.mouseMode=MM_ABSOLUTE
    view=TitleScene.new()
    overlay.screen=TitleCanvas.new(title)
    SubscribeToEvent(overlay.screen.vg,'NanoVGRender','TitlePreviewRender')
    SubscribeToEvent('Update','TitlePreviewUpdate')
    SubscribeToEvent('KeyDown','TitlePreviewKeyDown')
    SubscribeToEvent('KeyUp','TitlePreviewKeyUp')
    SubscribeToEvent('MouseMove','TitlePreviewMouseMove')
    SubscribeToEvent('MouseButtonDown','TitlePreviewMouseDown')
    SubscribeToEvent('MouseButtonUp','TitlePreviewMouseUp')
    SubscribeToEvent('TouchBegin','TitlePreviewTouchBegin')
    SubscribeToEvent('TouchMove','TitlePreviewTouchMove')
    SubscribeToEvent('TouchEnd','TitlePreviewTouchEnd')
    SubscribeToEvent('InputFocus','TitlePreviewFocus')
    print('TITLE_RENDER_PROBE: native SurfaceShader + raw NVG + SVG; story pending')
end
function TitlePreviewRender() overlay.screen:render() end
---@param eventData UpdateEventData
function TitlePreviewUpdate(eventType,eventData)
    local w,h,p=graphics:GetWidth(),graphics:GetHeight(),graphics:GetDPR()
    if w~=width or h~=height or p~=dpr then
        width=w;height=h;dpr=p;view:resize(w,h);overlay.screen:resize(w,h,p)
    end
    title:update(eventData:GetFloat('TimeStep'))
    view:update(title)
    overlay.screen:update()
    for _,event in ipairs(title:drainEvents()) do
        if event.kind=='start' then print('TITLE_START_REQUEST: '..event.choice.kind..' (story integration pending)') end
    end
end
---@param eventData KeyDownEventData
function TitlePreviewKeyDown(eventType,eventData)
    local key=eventData:GetInt('Key')
    local keys={[KEY_K]='K',[KEY_SHIFT]='Shift',[KEY_LSHIFT]='Shift',[KEY_RSHIFT]='Shift',
        [KEY_UP]='ArrowUp',[KEY_DOWN]='ArrowDown',[KEY_W]='w',[KEY_S]='s',
        [KEY_RETURN]='Enter',[KEY_SPACE]=' ',[KEY_F]='f',[KEY_ESCAPE]='Escape',[KEY_BACKSPACE]='Backspace'}
    overlay.screen:cancelPointer();title:keyDown(keys[key] or '',eventData:GetBool('Repeat'))
end
---@param eventData KeyUpEventData
function TitlePreviewKeyUp(eventType,eventData)
    local key=eventData:GetInt('Key')
    if key==KEY_K or key==KEY_SHIFT or key==KEY_LSHIFT or key==KEY_RSHIFT then title:keyUp('K') end
end
---@param eventData InputFocusEventData
function TitlePreviewFocus(eventType,eventData)
    if not eventData:GetBool('Focus') then title:blur();overlay.screen:cancelPointer() end
end
function TitlePreviewMouseMove()
    local p=input:GetMousePosition();overlay.screen:pointerMove(p.x,p.y,'mouse')
end
---@param eventData MouseButtonDownEventData
function TitlePreviewMouseDown(eventType,eventData)
    if eventData:GetInt('Button')==MOUSEB_LEFT then
        local p=input:GetMousePosition();overlay.screen:pointerDown(p.x,p.y,'mouse')
    end
end
---@param eventData MouseButtonUpEventData
function TitlePreviewMouseUp(eventType,eventData)
    if eventData:GetInt('Button')==MOUSEB_LEFT then
        local p=input:GetMousePosition();overlay.screen:pointerUp(p.x,p.y,'mouse')
    end
end
---@param eventData TouchBeginEventData
function TitlePreviewTouchBegin(eventType,eventData)
    overlay.screen:pointerDown(eventData:GetInt('X'),eventData:GetInt('Y'),eventData:GetInt('TouchID'))
end
---@param eventData TouchMoveEventData
function TitlePreviewTouchMove(eventType,eventData)
    overlay.screen:pointerMove(eventData:GetInt('X'),eventData:GetInt('Y'),eventData:GetInt('TouchID'))
end
---@param eventData TouchEndEventData
function TitlePreviewTouchEnd(eventType,eventData)
    overlay.screen:pointerUp(eventData:GetInt('X'),eventData:GetInt('Y'),eventData:GetInt('TouchID'))
end
function Stop() overlay.screen:dispose();view:dispose() end
