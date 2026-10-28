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
local Catalog=require('game.LevelCatalog')
local postSettings=require('game.PostSettings').new()
local save
local saveFixture=false
local levelMode=false
local controls
local playerContext,playerAction
local goNode,travel
local timelineResume
local suspendedChapter
local validation
local history
---@type {answer:string,stage:string,finished:boolean}|false
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
    if save and save.close then save:close()end
    postSettings:reset()
    if history then history:dispose()end
    history=require('render.EchoHistory').new()
    controls=require('render.PlayerControls').new(function() return playerContext() end,function(id) playerAction(id) end)
    SoundBank.get():reset()
    require('game.ScreenEffects').shared:reset()
    require('game.SpriteParticles').shared:reset()
    save=NativeSave.open(validation and validation.filename)
    if validation and validation.reset then save.data={chapters={}}end
    title=Title.new(save:reached());title.latest=save:latest();title.saveLoading=save.loading;audio:SetMasterGain(SOUND_MASTER,1)
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
local function startStore(diagnostic,day)
    if store.demo and (store.demo.story.mode=='store-day')~=not not day then store.demo:dispose();store.demo=nil end
    if not store.demo then store.demo=StoreDemo.new(day and {day=true,answer=save:answer()});store.demo.touchInput=controls;controls:attach(store.demo.screen);SubscribeToEvent(store.demo.screen.vg,'NanoVGRender','StorePreviewRender') end
    if chapter.demo then chapter.demo:dispose();chapter.demo=nil end
    store.demo.active=true;probe.demo.active=false;store.demo.view:activate()
    if store.demo.post then store.demo.post:setEnabled(store.demo.post.enabled) end
    store.demo.diagnostic=diagnostic or false
    store.demo.story.postSettings=postSettings:enter('store')
    if not diagnostic and not levelMode and not day then save:unlock('2338') end
end
local function startEcho(reset,theme,answer,startLevel,diagnostic)
    if reset and echo.demo then echo.demo:dispose();echo.demo=nil end
    if not echo.demo then
        local look=theme=='meeting' and chapter.demo and chapter.demo.view.look or store.demo and store.demo.view.look or nil
        local function progress(event)
            if levelMode then return end
            local set=assert(Catalog.find(theme or 'store'))
            if event.kind=='loadLevel' then save:unlock(set.node)
            elseif event.kind=='exitReached' then save:passFloor(set.node,event.level) end
            if theme=='store' or theme==nil then
                if event.kind=='loadLevel' then save:echoLoaded(event.level)
                elseif event.kind=='echoFinished' then save:echoFinished() end
            end
        end
        local demo=EchoDemo.new(look,theme,answer,startLevel,not diagnostic and progress or nil);echo.demo=demo;demo.touchInput=controls;controls:attach(demo.screen);SubscribeToEvent(demo.screen.vg,'NanoVGRender','EchoPreviewRender')
        demo.allowFixtureProgress=saveFixture
    end
    echo.demo.history=history;echo.demo.run.storyFinale=not levelMode and echo.demo.run.theme=='dorm'
    echo.demo.historyAnswers={meeting=save:answer(),office=save:morningBranch(),dorm=save:dormChoice()}
    echo.demo.run.postSettings=postSettings:enter('echo')
    echo.demo.view.topOn=(save:chapter('preferences')or {}).topView or false
    echo.demo.active=true;echo.demo:focus(true);probe.demo.active=false;echo.demo.view:activate()
    if store.demo then
        if store.demo.finished or levelMode then store.demo:dispose();store.demo=nil
        else store.demo.active=false;store.demo.screen:cancelPointer() end
    end
    if chapter.demo then chapter.demo:dispose();chapter.demo=nil end
end
function EchoPreviewRender() if echo.demo and echo.demo.active then echo.demo.screen:render() end end
local function startChapter(mode,answer,diagnostic,options)
    options=options or {}
    if mode=='meeting'and not options.morningBranch then options.tried=save:tried()end
    local look=echo.demo and echo.demo.view.look or nil
    if mode=='timeline' then
        options=options or {}
        -- timeline.js leaves the world's sun in place while adding its own.
        -- Copy plain values before disposing the outgoing native scene.
        local previous=chapter.demo and chapter.demo.active and chapter.demo or echo.demo and echo.demo.active and echo.demo or store.demo and store.demo.active and store.demo
        local mesh=previous and (previous.view.view or previous.view)
        if mesh and mesh.sun then
            local p,q=mesh.sun.node.worldPosition,mesh.sun.node.worldRotation
            options.timelineSun={position={p.x,p.y,p.z},rotation={q.w,q.x,q.y,q.z}}
        end
    end
    if chapter.demo and chapter.demo.story.mode~=(mode or 'meeting') then chapter.demo:dispose();chapter.demo=nil end
    if not chapter.demo then local demo=ChapterDemo.new(mode or 'meeting',look,answer,options);chapter.demo=demo;demo.touchInput=controls;if mode~='timeline' then controls:attach(demo.screen) end;SubscribeToEvent(demo.screen.vg,'NanoVGRender','Chapter1PreviewRender') end
    chapter.demo.story.postSettings=postSettings:enter(mode or 'meeting')
    chapter.demo.active=true;chapter.demo:focus(true);chapter.demo.view:activate();probe.demo.active=false
    chapter.demo.post:setEnabled(chapter.demo.post.enabled)
    chapter.demo.diagnostic=diagnostic or false
    if mode~='timeline' and mode~='dream' and not diagnostic and not levelMode then save:unlock(mode=='night' and '2312' or mode=='morning' and '0958' or mode=='dorm' and '0815' or '1447') end
    if echo.demo then echo.demo:dispose();echo.demo=nil end
    if store.demo then store.demo.active=false end
end
goNode=function(id,floor)
    floor=floor or 0;controls:cancel()
    if suspendedChapter then suspendedChapter:dispose();suspendedChapter=nil end
    if chapter.demo then chapter.demo:dispose();chapter.demo=nil end
    if echo.demo then echo.demo:dispose();echo.demo=nil end
    if store.demo then store.demo:dispose();store.demo=nil end
    if id=='2312' then startChapter('night',nil,false,{wake=true})
    elseif id=='2338' then startStore()
    elseif id=='1447' then startChapter('meeting',nil,false,{rewound=true})
    elseif id=='0958' then startChapter('morning',save:answer())
    elseif id=='0815' then startChapter('dorm',nil,false,{skipRewind=true})
    else local set=assert(Catalog.find(id));local answer=set.theme=='meeting' and save:answer() or set.theme=='office' and save:morningBranch() or set.theme=='dorm' and save:dormChoice() or nil;startEcho(true,set.theme,answer,floor+1) end
end
travel=function(dest,go,from,floor,diagnostic)
    if levelMode or diagnostic or not save:hasNode(dest) then if not levelMode and not diagnostic then save:unlock(dest) end;go();return end
    controls:cancel();timelineResume={dest=dest,floor=floor or 0,go=go}
    startChapter('timeline',nil,false,{save=save,dest=dest,from=from,floor=floor or 0})
end
function Chapter1PreviewRender() if chapter.demo and chapter.demo.active then chapter.demo.screen:render() end end
local function activeScreen() return chapter.demo and chapter.demo.active and chapter.demo.screen or echo.demo and echo.demo.active and echo.demo.screen or store.demo and store.demo.active and store.demo.screen or (probe.demo.active and probe.demo.screen or overlay.screen) end
function StorePreviewRender() if store.demo and store.demo.active then store.demo.screen:render() end end
function TitlePreviewRender()
    if title.active and title.st.started then overlay.screen:renderBridge();return end
    if not (chapter.demo and chapter.demo.active) and not (echo.demo and echo.demo.active) and not probe.demo.active and not (store.demo and store.demo.active) then overlay.screen:render() end
end
function StoryPanelPreviewRender() if probe.demo.active then probe.demo.screen:render() end end
local function replayFromTitle(landed)
    postSettings:reset(landed)
    local muted=title.opts.muted
    SoundBank.get():reset()
    require('game.ScreenEffects').shared:reset()
    require('game.SpriteParticles').shared:reset()
    levelMode=false;timelineResume=nil;controls:cancel()
    if history then history:clear()end
    if suspendedChapter then suspendedChapter:dispose();suspendedChapter=nil end
    if chapter.demo then chapter.demo:dispose();chapter.demo=nil end
    if echo.demo then echo.demo:dispose();echo.demo=nil end
    if store.demo then store.demo:dispose();store.demo=nil end
    probe.demo.active=false;overlay.screen:dispose();title=Title.new(save:reached());title.latest=save:latest();overlay.screen=TitleCanvas.new(title);overlay.screen.touchMode=controls.mobile
    title.opts.muted=muted;audio:SetMasterGain(SOUND_MASTER,muted and 0 or 1)
    SubscribeToEvent(overlay.screen.vg,'NanoVGRender','TitlePreviewRender')
    renderer.hdrRendering=false;renderer:SetViewport(0,view.viewport)
    print('CHAPTER_REPLAY: disposed chapter state, returned to fresh title')
end
playerContext=function()
    local e=echo.demo and echo.demo.active and echo.demo or nil
    local demo=chapter.demo and chapter.demo.active and chapter.demo or store.demo and store.demo.active and store.demo or nil
    local bridge=e and e.bridge or demo and demo.bridge
    local loading=e and not e.view.view.ready or demo and not demo.view.ready
    local covered=title.active or loading or (e and e.screen.loading) or (demo and demo.screen.loading) or (bridge and bridge.on) or false
    local ending=(e and(e.screen.ending.active or e.run.phase=='finale')) or (chapter.demo and chapter.demo.active and chapter.demo.ending.active) or false
    return {echo=e,card=e and e.card and e.card.open,hasCard=e and e.card and e.card.card,paused=e and e.playerPaused or false,ending=ending,covered=covered,
        moveOnly=demo and demo.story.mode=='dream',
        cycle=demo and demo.story.nearbyInteractions and #demo.story:nearbyInteractions()>1 or false,
        canSkip=not covered and not ending and demo and demo.story:canSkip() or false,
        movable=not covered and not ending and ((e and e.run.phase=='play' and not e.playerPaused and not e.card.open) or (demo and demo.story:controlEnabled())) or false}
end
playerAction=function(id)
    local c=playerContext();local e=c.echo
    if c.card then if id=='cardClose'then e.card.open=false;e:setPaused(false)end;return end
    if id=='mechanism' or id=='topview' then
        if not e or c.covered or c.ending or c.paused then return end
        if id=='mechanism' then e.card:toggle();e.screen:cancelPointer()
        else e.view.topOn=not e.view.topOn;save:saveChapter('preferences',{topView=e.view.topOn}) end
        return
    end
    if id=='resume' and e then e:setPaused(false)
    elseif id=='home' then replayFromTitle()
    elseif id=='pause' and e and not c.covered and not c.ending then e:setPaused(true)
    elseif (id=='interact' or id=='cycle') and c.movable and not e then
        local demo=chapter.demo and chapter.demo.active and chapter.demo or store.demo
        if id=='interact'then demo.story:interact()else demo.story:cycleInteraction()end
        demo:events()
    elseif id=='skip' and c.canSkip then
        local demo=chapter.demo and chapter.demo.active and chapter.demo or store.demo
        demo.story:skip();demo:events();demo.screen:cancelPointer()
    elseif e and not e.paused and not c.covered and not c.ending then
        if id=='charge' then e.charge=true elseif id=='restart' then e.restart=true end
    end
end
---@param eventData UpdateEventData
function TitlePreviewUpdate(eventType,eventData)
    if save.tick then save:tick(eventData:GetFloat('TimeStep'))end
    title.reached=save:reached();title.latest=save:latest();title.saveLoading=save.loading;title.saveStatus=save.cloud and save.status or nil
    if validation and validation.step({title=title,chapter=chapter.demo,store=store.demo,echo=echo.demo,save=save,controls=controls,screen=activeScreen(),home=replayFromTitle,levelMode=levelMode})then return end
    local dt=eventData:GetFloat('TimeStep')*(validation and validation.timeScale or 1)
    local sound=SoundBank.get();sound.clock=sound.clock+math.max(0,dt)
    local active=chapter.demo and chapter.demo.active and chapter.demo or echo.demo and echo.demo.active and echo.demo or store.demo and store.demo.active and store.demo
    local scope=active and(active.run and 'echo'or active.story.mode or 'store')or 'title'
    sound.score:setScene(scope)
    sound.score:update(dt,active and (not active.focused or active.playerPaused or active.card and active.card.open)or false,active and active.run and active.run.pig.spinning or false)
    if active then local v=active.view.view or active.view;require('render.TimelinePortal').update(active.screen,dt,v.ready)end
    local w,h,p=graphics:GetWidth(),graphics:GetHeight(),graphics:GetDPR()
    if w~=width or h~=height or p~=dpr then
        width=w;height=h;dpr=p;view:resize(w,h);overlay.screen:resize(w,h,p);probe.demo.screen:resize(w,h,p)
        if store.demo then store.demo.screen:resize(w,h,p) end
        if echo.demo then echo.demo.screen:resize(w,h,p) end
        if chapter.demo then chapter.demo.screen:resize(w,h,p) end
    end
    if title.active and title.st.started then
        local ready=(chapter.demo and chapter.demo.active and chapter.demo.view.ready) or (store.demo and store.demo.active and store.demo.view.ready) or
            (echo.demo and echo.demo.active and echo.demo.view.view.ready)
        if ready then title:update(dt);overlay.screen:update() end
    end
    if chapter.demo and chapter.demo.active then
        chapter.demo:update(dt)
        if chapter.demo.ending.replay then replayFromTitle(true);return end
        if chapter.demo.finished then
            local s=chapter.demo.story;local diagnostic=chapter.demo.diagnostic
            if s.mode=='timeline' then
                local result=s.result;local resume=timelineResume;timelineResume=nil
                if result.back and suspendedChapter then
                    chapter.demo:dispose();chapter.demo=suspendedChapter;suspendedChapter=nil
                    chapter.demo.active=true;chapter.demo.finished=false;chapter.demo:focus(true);chapter.demo.view:activate();chapter.demo.post:setEnabled(true)
                    chapter.demo.story.postSettings=postSettings:enter('meeting')
                elseif result.back then replayFromTitle()
                elseif resume and result.node==resume.dest and result.floor==resume.floor then resume.go()
                else goNode(result.node,result.floor) end
                if not result.back then require('render.TimelinePortal').attach(activeScreen(),result.node)end
            elseif s.mode=='dream' then startChapter('night',nil,diagnostic,{wake=true})
            elseif s.mode=='night' then startStore(diagnostic)
            elseif s.mode=='meeting' then
                if s.result and s.result.toStore then
                    save:noteTried(s.answer);startStore(diagnostic,true)
                elseif s.result and s.result.toTimeline then
                    save:noteTried(s.answer);chapter.demo.finished=false;chapter.demo.active=false;chapter.demo.screen:cancelPointer()
                    suspendedChapter=chapter.demo;chapter.demo=nil
                    startChapter('timeline',nil,diagnostic,{save=save,dest='1447',from='1447',backLabel='回到工位'})
                elseif s.branch then travel('echo3',function()startEcho(true,'office',s.morningBranch,1,diagnostic)end,'0958',0,diagnostic)
                else
                    if not diagnostic then save:meetingFinished(s.answer) end
                    travel('echo2',function()startEcho(true,'meeting',s.answer,1,diagnostic)end,'1447',0,diagnostic)
                end
            elseif s.mode=='morning' then
                if not diagnostic then save:morningFinished(s.morningBranch) end
                startChapter('meeting',nil,diagnostic,{morningBranch=s.morningBranch})
            elseif s.mode=='dorm' then
                if s.result.ended then replayFromTitle()
                else
                    if not diagnostic then save:dormFinished(s.dormChoice) end
                    travel('echo4',function()startEcho(true,'dorm',s.dormChoice,1,diagnostic)end,'0815',0,diagnostic)
                end
            end
        end
        return
    end
    if echo.demo and echo.demo.active then
        echo.demo:update(dt)
        if echo.demo.screen.ending.replay then replayFromTitle();return end
        if echo.demo.run.phase=='done' then
            if levelMode then
                local _,index=Catalog.find(echo.demo.run.theme);local nextSet=Catalog[index+1]
                if nextSet then startEcho(true,nextSet.theme,nextSet.answer,1)
                elseif not echo.demo.screen.ending.active then echo.demo.screen.ending:show('关卡模式 · 完','全部 4 章 19 层') end
            else
                local theme,answer,diagnostic=echo.demo.run.theme,echo.demo.run.answer,not echo.demo.onProgress
                if theme=='office' then travel('0815',function()startChapter('dorm',nil,diagnostic)end,'echo3',0,diagnostic)
                elseif theme=='dorm' then
                    local assembled=echo.demo.finale~=nil
                    startChapter('dorm',nil,diagnostic,{afterEcho=true,dormChoice=answer,assemble=assembled})
                    if assembled then history:clear()end
                else local dest=theme=='meeting' and '0958' or '1447';travel(dest,function()startChapter(theme=='meeting' and 'morning' or 'meeting',answer,diagnostic)end,theme=='meeting' and 'echo2' or 'echo1',0,diagnostic) end
            end
        end
        return
    end
    if store.demo and store.demo.active then
        store.demo:update(dt)
        if store.demo.finished then
            local diagnostic=store.demo.diagnostic
            if store.demo.story.mode=='store-day'then store.demo:dispose();store.demo=nil;startChapter('meeting',save:answer(),diagnostic,{fromStore=true})
            else travel('echo1',function()startEcho(true,'store',nil,1,diagnostic)end,'2338',0,diagnostic)end
        end
        return
    end
    title:update(dt)
    view:update(title)
    overlay.screen:update()
    probe.demo:update(dt)
    for _,event in ipairs(title:drainEvents()) do
        if event.kind=='start' then
            if event.choice.kind=='new' then startChapter('dream',nil,false,{deferIntro=true})
            elseif event.choice.kind=='timeline' then local id=save:latest();startChapter('timeline',nil,false,{save=save,dest=id,floor=save:passed(id)})
            elseif event.choice.kind=='echo' then startEcho(true,'store',nil,event.choice.level+1);echo.demo.bridge:start()
            elseif event.choice.kind=='levels' then
                levelMode=true;controls:cancel()
                local set=assert(Catalog.find(event.choice.set))
                startEcho(true,set.theme,set.answer,event.choice.level+1);echo.demo.bridge:start()
            end
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
    SoundBank.get().score:unlock()
    if Diagnostics.blocks(key) then return end
    if echo.demo and echo.demo.active and echo.demo.card.open then
        if not eventData:GetBool('Repeat')and (key==KEY_J or key==KEY_SPACE or key==KEY_RETURN or key==KEY_F or key==KEY_ESCAPE or key==KEY_H)then playerAction('cardClose')end
        return
    end
    if echo.demo and echo.demo.active and not playerContext().covered and not echo.demo.playerPaused and not eventData:GetBool('Repeat')then
        if key==KEY_H then playerAction('mechanism');return elseif key==KEY_V then playerAction('topview');return end
    end
    if echo.demo and echo.demo.active and echo.demo.playerPaused then
        if not eventData:GetBool('Repeat') then
            if key==KEY_ESCAPE then playerAction('resume') elseif key==KEY_RETURN then playerAction('home') end
        end
        return
    end
    if title.active and title.st.started then return end
    if not title.active and playerContext().covered then return end
    if key==KEY_ESCAPE and not eventData:GetBool('Repeat') then
        if chapter.demo and chapter.demo.story.mode=='timeline' then chapter.demo.story:back();chapter.demo:events();return end
        local c=playerContext()
        if c.echo then playerAction('pause') else playerAction('skip') end
        if c.echo or store.demo or chapter.demo then return end
    end
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
        print('FULL_ROUTE: legacy 11-floor replay retired; increment03 full-story acceptance pending');return
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
    if echo.demo then echo.demo.suppressed[key]=nil end
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
    SoundBank.get().score:unlock()
    if Diagnostics.enabled then print('NATIVE_POINTER_DOWN: button='..eventData:GetInt('Button')..' left='..MOUSEB_LEFT..' event='..eventData:GetInt('X')..','..eventData:GetInt('Y')..' cursor='..input:GetMousePosition().x..','..input:GetMousePosition().y) end
    if eventData:GetInt('Button')==MOUSEB_LEFT then
        local p=input:GetMousePosition();activeScreen():pointerDown(p.x,p.y,'mouse');if probe.demo.active then probe.demo.live=true end
    elseif eventData:GetInt('Button')==MOUSEB_RIGHT and activeScreen().contextMenu then
        local p=input:GetMousePosition();activeScreen():contextMenu(p.x,p.y)
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
    SoundBank.get().score:unlock()
    controls.mobile=true;overlay.screen.touchMode=true;activeScreen().touchUI=true
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
    local screen=activeScreen()
    if screen.wheel then local p=input:GetMousePosition();screen:wheel(eventData:GetInt('Wheel'),p.x,p.y) end
end
function Stop() if history then history:dispose();history=nil end;if suspendedChapter then suspendedChapter:dispose();suspendedChapter=nil end;if save and save.close then save:close()end;SoundBank.get():dispose();if chapter.demo then chapter.demo:dispose() end;if echo.demo then echo.demo:dispose() end;if store.demo then store.demo:dispose() end;overlay.screen:dispose();probe.demo.screen:dispose();view:dispose() end
return {configureValidation=function(config)
    assert(not save,'Validation must be configured before Start')
    assert(config.filename:match('^reverse%-pig%-increment03%-[%w%-]+%.json$'),'Validation must use an isolated save file')
    assert(not config.timeScale or(config.timeScale>=1 and config.timeScale<=2),'Validation clock scale outside 1..2')
    validation=config
end}
