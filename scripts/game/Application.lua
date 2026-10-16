-- Native game lifecycle. Diagnostic controls are explicitly opt-in.
local Diagnostics=require('game.Diagnostics')
local Title=require('game.TitleState')
local TitleScene=require('render.TitleRenderer')
local TitleCanvas=require('render.TitleOverlay')
local PanelDemo=Diagnostics.enabled and require('preview.PanelProbe')
local StoreDemo=require('preview.StoreProbe')
local EchoDemo=require('preview.EchoProbe')
local ChapterDemo=require('preview.Chapter1Probe')
local NativeSave=require('game.NativeSave')
local SoundBank=require('game.AudioPlayback')
local save
local saveFixture=false
---@type {answer:string,stage:string,finished:boolean}|false
local fullRoute=false
local title=Title.new(0)
---@type TitleRenderer
local view
local overlay={}
local probe={}
local store={}
local echo={}
local chapter={}
local width,height,dpr=0,0,0
function Start()
    SoundBank.get():reset()
    require('game.ScreenEffects').shared:reset()
    require('game.SpriteParticles').shared:reset()
    save=NativeSave.open();title=Title.new(save:reached());audio:SetMasterGain(SOUND_MASTER,1)
    print('SAVE_LOADED: reached='..save:reached()..' answer='..save:answer()..' persistent='..tostring(save.persisted))
    if Diagnostics.enabled then
    local storageOk,storageError=pcall(require('preview.SaveSmoke').run)
    if not storageOk then print('NATIVE_SAVE_SMOKE: FAIL; '..tostring(storageError)..'; game retains memory fallback') end
    require('preview.PrologueSmoke').run()
    require('preview.Chapter1Smoke').run()
    end
    graphics.windowTitle='反方向的猪'
    input.mouseMode=MM_ABSOLUTE
    view=TitleScene.new()
    view:update(title)
    overlay.screen=TitleCanvas.new(title)
    local function noop() end
    probe.demo=PanelDemo and PanelDemo.new() or {active=false,update=noop,screen={resize=noop,cancelPointer=noop,dispose=noop}}
    probe.demo.active=false
    SubscribeToEvent(overlay.screen.vg,'NanoVGRender','TitlePreviewRender')
    if Diagnostics.enabled then SubscribeToEvent(probe.demo.screen.vg,'NanoVGRender','StoryPanelPreviewRender') end
    SubscribeToEvent('Update','TitlePreviewUpdate')
    SubscribeToEvent('PostUpdate','GameAudioFlush')
    SubscribeToEvent('KeyDown','TitlePreviewKeyDown')
    SubscribeToEvent('KeyUp','TitlePreviewKeyUp')
    SubscribeToEvent('MouseMove','TitlePreviewMouseMove')
    SubscribeToEvent('MouseButtonDown','TitlePreviewMouseDown')
    SubscribeToEvent('MouseButtonUp','TitlePreviewMouseUp')
    SubscribeToEvent('MouseWheel','StoryPanelPreviewWheel')
    SubscribeToEvent('TouchBegin','TitlePreviewTouchBegin')
    SubscribeToEvent('TouchMove','TitlePreviewTouchMove')
    SubscribeToEvent('TouchEnd','TitlePreviewTouchEnd')
    SubscribeToEvent('InputFocus','TitlePreviewFocus')
    if Diagnostics.enabled then print('TITLE_RENDER_PROBE: native SurfaceShader + raw NVG paths; story pending')
    print('STORY_PANEL_PROBE: 群聊; frozen fixture; F7 next, F8 title; not playable story') end
end
local function startStore(diagnostic)
    if not store.demo then store.demo=StoreDemo.new();SubscribeToEvent(store.demo.screen.vg,'NanoVGRender','StorePreviewRender') end
    store.demo.active=true;probe.demo.active=false;store.demo.view:activate()
    if store.demo.post then store.demo.post:setEnabled(store.demo.post.enabled) end
    store.demo.diagnostic=diagnostic or false
    if fullRoute then store.demo.route=require('preview.StoryRoute').new('store',fullRoute.answer);fullRoute.stage='store';print('FULL_ROUTE_STAGE: store') end
end
local function startEcho(reset,theme,answer,startLevel,diagnostic)
    if reset and echo.demo then echo.demo:dispose();echo.demo=nil end
    if not echo.demo then
        local look=theme=='meeting' and chapter.demo and chapter.demo.view.look or store.demo and store.demo.view.look or nil
        local function progress(event)
            if theme~='meeting' then
                if event.kind=='loadLevel' then save:echoLoaded(event.level)
                elseif event.kind=='echoFinished' then save:echoFinished() end
            end
        end
        local demo=EchoDemo.new(look,theme,answer,startLevel,not diagnostic and progress or nil);echo.demo=demo;SubscribeToEvent(demo.screen.vg,'NanoVGRender','EchoPreviewRender')
        demo.allowFixtureProgress=saveFixture
        if fullRoute then demo:beginInputReplay();fullRoute.stage='echo-'..(theme or 'store');print('FULL_ROUTE_STAGE: '..fullRoute.stage) end
    end
    echo.demo.active=true;echo.demo:focus(true);probe.demo.active=false;echo.demo.view:activate()
    if store.demo then
        if store.demo.finished then store.demo:dispose();store.demo=nil
        else store.demo.active=false;store.demo.screen:cancelPointer() end
    end
    if chapter.demo then chapter.demo:dispose();chapter.demo=nil end
end
function EchoPreviewRender() if echo.demo and echo.demo.active then echo.demo.screen:render() end end
local function startChapter(mode,answer,diagnostic)
    local look=echo.demo and echo.demo.view.look or nil
    if chapter.demo and chapter.demo.story.mode~=(mode or 'meeting') then chapter.demo:dispose();chapter.demo=nil end
    if not chapter.demo then local demo=ChapterDemo.new(mode or 'meeting',look,answer);chapter.demo=demo;SubscribeToEvent(demo.screen.vg,'NanoVGRender','Chapter1PreviewRender') end
    chapter.demo.active=true;chapter.demo:focus(true);chapter.demo.view:activate();probe.demo.active=false
    chapter.demo.post:setEnabled(chapter.demo.post.enabled)
    chapter.demo.diagnostic=diagnostic or false
    if fullRoute then chapter.demo.route=require('preview.StoryRoute').new(mode or 'meeting',fullRoute.answer);fullRoute.stage=mode or 'meeting';print('FULL_ROUTE_STAGE: '..fullRoute.stage) end
    if echo.demo then echo.demo:dispose();echo.demo=nil end
    if store.demo then store.demo.active=false end
end
function Chapter1PreviewRender() if chapter.demo and chapter.demo.active then chapter.demo.screen:render() end end
local function activeScreen() return chapter.demo and chapter.demo.active and chapter.demo.screen or echo.demo and echo.demo.active and echo.demo.screen or store.demo and store.demo.active and store.demo.screen or (probe.demo.active and probe.demo.screen or overlay.screen) end
function StorePreviewRender() if store.demo and store.demo.active then store.demo.screen:render() end end
function TitlePreviewRender()
    if title.active and title.st.started then overlay.screen:renderBridge();return end
    if not (chapter.demo and chapter.demo.active) and not (echo.demo and echo.demo.active) and not probe.demo.active and not (store.demo and store.demo.active) then overlay.screen:render() end
end
function StoryPanelPreviewRender() if probe.demo.active then probe.demo.screen:render() end end
local function replayFromTitle()
    SoundBank.get():reset()
    require('game.ScreenEffects').shared:reset()
    require('game.SpriteParticles').shared:reset()
    fullRoute=false
    if chapter.demo then chapter.demo:dispose();chapter.demo=nil end
    if echo.demo then echo.demo:dispose();echo.demo=nil end
    if store.demo then store.demo:dispose();store.demo=nil end
    probe.demo.active=false;overlay.screen:dispose();title=Title.new(save:reached());overlay.screen=TitleCanvas.new(title)
    audio:SetMasterGain(SOUND_MASTER,1)
    SubscribeToEvent(overlay.screen.vg,'NanoVGRender','TitlePreviewRender')
    renderer.hdrRendering=false;renderer:SetViewport(0,view.viewport)
    print('CHAPTER_REPLAY: disposed chapter state, returned to fresh title')
end
---@param eventData UpdateEventData
function TitlePreviewUpdate(eventType,eventData)
    local sound=SoundBank.get();sound.clock=sound.clock+math.max(0,eventData:GetFloat('TimeStep'))
    local w,h,p=graphics:GetWidth(),graphics:GetHeight(),graphics:GetDPR()
    if w~=width or h~=height or p~=dpr then
        width=w;height=h;dpr=p;view:resize(w,h);overlay.screen:resize(w,h,p);probe.demo.screen:resize(w,h,p)
        if store.demo then store.demo.screen:resize(w,h,p) end
        if echo.demo then echo.demo.screen:resize(w,h,p) end
        if chapter.demo then chapter.demo.screen:resize(w,h,p) end
    end
    if title.active and title.st.started then
        local ready=(store.demo and store.demo.active and store.demo.view.ready) or
            (echo.demo and echo.demo.active and echo.demo.view.view.ready)
        if ready then title:update(eventData:GetFloat('TimeStep'));overlay.screen:update() end
    end
    if chapter.demo and chapter.demo.active then
        chapter.demo:update(eventData:GetFloat('TimeStep'))
        if fullRoute and chapter.demo.ending.active and not fullRoute.finished then
            fullRoute.finished=true
            local check=NativeSave.open('reverse-pig-full-route-check.json')
            assert(check:reached()==6 and check:chapter('echo').done and check:answer()==fullRoute.answer,'Continuous route save mismatch')
            print('FULL_ROUTE: PASS; title/store/6 echoes/meeting/office/5 echoes/09:58/end; answer='..fullRoute.answer..'; reached=6; done=true; isolated save readback; visual acceptance pending')
        end
        if chapter.demo.ending.replay then replayFromTitle();return end
        if chapter.demo.finished and chapter.demo.story.mode=='meeting' then
            if not chapter.demo.diagnostic then save:meetingFinished(chapter.demo.story.answer) end
            startEcho(true,'meeting',chapter.demo.story.answer,1,chapter.demo.diagnostic)
        end
        return
    end
    if echo.demo and echo.demo.active then
        echo.demo:update(eventData:GetFloat('TimeStep'))
        if echo.demo.run.phase=='done' then startChapter(echo.demo.run.theme=='meeting' and 'morning' or 'meeting',echo.demo.run.answer,not echo.demo.onProgress) end
        return
    end
    if store.demo and store.demo.active then
        store.demo:update(eventData:GetFloat('TimeStep'))
        if store.demo.finished then startEcho(true,'store',nil,1,store.demo.diagnostic) end
        return
    end
    title:update(eventData:GetFloat('TimeStep'))
    if fullRoute and fullRoute.stage=='title' and title.st.phase=='idle' then title:keyDown('Enter',false) end
    view:update(title)
    overlay.screen:update()
    probe.demo:update(eventData:GetFloat('TimeStep'))
    for _,event in ipairs(title:drainEvents()) do
        if event.kind=='start' then
            if event.choice.kind=='new' then startStore();store.demo.bridge:start()
            elseif event.choice.kind=='echo' then startEcho(true,'store',nil,event.choice.level+1);echo.demo.bridge:start() end
        elseif event.kind=='mute' then
            audio:SetMasterGain(SOUND_MASTER,event.muted and 0 or 1)
            print('TITLE_SOUND: muted='..tostring(event.muted))
        end
    end
end
function GameAudioFlush() SoundBank.get():update(0) end
---@param eventData KeyDownEventData
function TitlePreviewKeyDown(eventType,eventData)
    local key=eventData:GetInt('Key')
    if Diagnostics.blocks(key) then return end
    if key==KEY_M and not eventData:GetBool('Repeat') and (not title.active or title.st.started) then
        title.opts.muted=not title.opts.muted;audio:SetMasterGain(SOUND_MASTER,title.opts.muted and 0 or 1);return
    end
    if chapter.demo and chapter.demo.active then
        if key==KEY_F8 then replayFromTitle()
        else chapter.demo:key(key,eventData:GetBool('Repeat')) end
        return
    end
    if echo.demo and echo.demo.active then
        if key==KEY_F8 then replayFromTitle()
        else echo.demo:key(key,eventData:GetBool('Repeat')) end
        return
    end
    if key==KEY_F9 and not eventData:GetBool('Repeat') then startEcho(true,'store',nil,1,true);return end
    if key==KEY_F10 and not eventData:GetBool('Repeat') then startChapter('meeting',save:answer(),true);return end
    if store.demo and store.demo.active then
        if key==KEY_F8 then
            replayFromTitle()
        else store.demo:key(key,eventData:GetBool('Repeat')) end
        return
    end
    if key==KEY_F6 and not eventData:GetBool('Repeat') then startStore(true);return end
    if key==KEY_F3 and not eventData:GetBool('Repeat') then
        save=NativeSave.open('reverse-pig-preview-save-check.json');saveFixture=true;replayFromTitle()
        print('SAVE_MENU_DIAGNOSTIC: isolated file, reached='..save:reached()..'; player save untouched');return
    end
    if key==KEY_F2 and not eventData:GetBool('Repeat') then
        save=NativeSave.open('reverse-pig-full-route-check.json');saveFixture=true
        save:saveChapter('echo',{reached=0,done=false});save:meetingFinished('same')
        replayFromTitle();fullRoute={answer='done',stage='title',finished=false}
        print('FULL_ROUTE: begin; title UI Enter then real-time movement and interaction inputs; player save untouched');return
    end
    if key==KEY_F8 and not eventData:GetBool('Repeat') then probe.demo.active=not probe.demo.active;activeScreen():cancelPointer();return end
    if probe.demo.active then
        if key==KEY_F7 and not eventData:GetBool('Repeat') then probe.demo:cycle() end
        if key==KEY_ESCAPE then probe.demo.screen:dispatch('close');probe.demo.live=true end
        if key==KEY_J or key==KEY_SPACE then probe.demo.story:togglePhone();probe.demo.live=true end
        return
    end
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
    if store.demo then store.demo:focus(eventData:GetBool('Focus')) end
    if chapter.demo then chapter.demo:focus(eventData:GetBool('Focus')) end
    if echo.demo then echo.demo:focus(eventData:GetBool('Focus')) end
    if not eventData:GetBool('Focus') then title:blur();overlay.screen:cancelPointer();probe.demo.screen:cancelPointer() end
end
function TitlePreviewMouseMove()
    local p=input:GetMousePosition();activeScreen():pointerMove(p.x,p.y,'mouse')
end
---@param eventData MouseButtonDownEventData
function TitlePreviewMouseDown(eventType,eventData)
    if Diagnostics.enabled then print('NATIVE_POINTER_DOWN: button='..eventData:GetInt('Button')..' left='..MOUSEB_LEFT..' event='..eventData:GetInt('X')..','..eventData:GetInt('Y')..' cursor='..input:GetMousePosition().x..','..input:GetMousePosition().y) end
    if eventData:GetInt('Button')==MOUSEB_LEFT then
        local p=input:GetMousePosition();activeScreen():pointerDown(p.x,p.y,'mouse');if probe.demo.active then probe.demo.live=true end
    end
end
---@param eventData MouseButtonUpEventData
function TitlePreviewMouseUp(eventType,eventData)
    if Diagnostics.enabled then print('NATIVE_POINTER_UP: button='..eventData:GetInt('Button')..' event='..eventData:GetInt('X')..','..eventData:GetInt('Y')..' cursor='..input:GetMousePosition().x..','..input:GetMousePosition().y) end
    if eventData:GetInt('Button')==MOUSEB_LEFT then
        local p=input:GetMousePosition();activeScreen():pointerUp(p.x,p.y,'mouse')
    end
end
---@param eventData TouchBeginEventData
function TitlePreviewTouchBegin(eventType,eventData)
    activeScreen():pointerDown(eventData:GetInt('X'),eventData:GetInt('Y'),eventData:GetInt('TouchID'));if probe.demo.active then probe.demo.live=true end
end
---@param eventData TouchMoveEventData
function TitlePreviewTouchMove(eventType,eventData)
    activeScreen():pointerMove(eventData:GetInt('X'),eventData:GetInt('Y'),eventData:GetInt('TouchID'))
end
---@param eventData TouchEndEventData
function TitlePreviewTouchEnd(eventType,eventData)
    activeScreen():pointerUp(eventData:GetInt('X'),eventData:GetInt('Y'),eventData:GetInt('TouchID'))
end
---@param eventData MouseWheelEventData
function StoryPanelPreviewWheel(eventType,eventData)
    if probe.demo.active or (store.demo and store.demo.active) or (chapter.demo and chapter.demo.active) then local p=input:GetMousePosition();activeScreen():wheel(eventData:GetInt('Wheel'),p.x,p.y) end
end
function Stop() SoundBank.get():dispose();if chapter.demo then chapter.demo:dispose() end;if echo.demo then echo.demo:dispose() end;if store.demo then store.demo:dispose() end;overlay.screen:dispose();probe.demo.screen:dispose();view:dispose() end
