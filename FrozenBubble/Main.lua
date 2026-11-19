local addon, FB = ...
function FB.GameSeed() return (time()+math.floor(GetTime()*1000))%2147483646+1 end
function FB.CanStart()
    if InCombatLockdown() then FB.Print("Start a game after combat."); return false end
    if FB.Net.match and FB.Net.match.phase~="done" then FB.Print("Leave or finish multiplayer first."); return false end
    if FB.Net.match then FB.Net.Leave() end
    if FB.Net.queue then FB.Net.SetQueue(false) end
    return true
end
function FB.StopGameMusic()
    if FB.musicTrack and StopMusic then StopMusic() end
    if FB.oldMusicVolume then
        local set=(C_CVar and C_CVar.SetCVar) or SetCVar
        if set then set("Sound_MusicVolume",FB.oldMusicVolume) end
        FB.oldMusicVolume=nil
    end
    FB.musicTrack,FB.appliedMusicVolume=nil,nil
end
function FB.Music()
    if not FB.UI.frame then return end
    if FB.db.audioEnabled~=false and FB.db.music and FB.UI.frame:IsShown() and PlayMusic then
        local scene=FB.Transitions.demo and FB.DemoData.scenes[FB.Transitions.demo] or FB.Demos.scene
        local screen=FB.Transitions.target or FB.UI.screen
        local board=screen=="game" or screen=="opponent"
        local namingBoard=screen=="scoreEntry" and FB.game and FB.game.scoreEntry==FB.UI.namingScore
        local muted=FB.UI.inactive or InCombatLockdown() or (board and FB.game and FB.game.paused)
        if muted and not FB.musicTrack then return end
        local get=(C_CVar and C_CVar.GetCVar) or GetCVar
        local set=(C_CVar and C_CVar.SetCVar) or SetCVar
        if get and set then
            if not FB.oldMusicVolume then FB.oldMusicVolume=get("Sound_MusicVolume") end
            local volume=muted and 0 or (FB.db.musicVolume or 0.8)
            if FB.appliedMusicVolume~=volume then
                set("Sound_MusicVolume",volume); FB.appliedMusicVolume=volume
            end
        end
        if muted then return end
        local track="introzik.ogg"
        if scene then track=scene.background=="solo-background" and "frozen-mainzik-1p.ogg" or "frozen-mainzik-2p.ogg"
        elseif screen=="replay" and FB.Recordings.playback then track=(FB.Recordings.playback.left or FB.Recordings.playback.arena) and "frozen-mainzik-2p.ogg" or "frozen-mainzik-1p.ogg"
        elseif board or namingBoard then track=screen=="opponent" and "frozen-mainzik-2p.ogg" or "frozen-mainzik-1p.ogg" end
        if FB.musicTrack~=track and PlayMusic(FB.media..track)~=false then FB.musicTrack=track end
    else FB.StopGameMusic() end
end
function FB.StartCampaign(level,run)
    if not FB.CanStart() then return end
    FB.LeaveBoard(); FB.LocalVersus.match=nil
    level=FB.Clamp(math.floor(level),1,FB.db.unlocked)
    FB.level=level; FB.run=run or {score=0,seconds=0,eligible=level==1}
    FB.game=FB.Engine.New(FB.Levels[level],FB.GameSeed(),"campaign",nil,FB.Sound,true)
    FB.game.lowGraphics=FB.db.graphicsLevel==1
    FB.game.timed=FB.db.shotClock~=false
    FB.Debug.Log("GAME","campaign",level)
    FB.UI.editing=false; FB.Transitions.Open("game"); FB.UI.frame:Show(); FB.UI.level:SetText(tostring(level))
    FB.db.checkpoint={level=level,score=FB.run.score,seconds=FB.run.seconds,eligible=FB.run.eligible}
    FB.Music()
end
function FB.ContinueCampaign()
    local cp=FB.db.checkpoint
    local game=FB.game
    if cp and game and game.mode=="campaign" and game.status=="playing" then
        if FB.CanStart() then FB.UI.frame:Show(); FB.UI:ShowGame() end
    elseif cp then FB.StartCampaign(cp.level,{score=cp.score,seconds=cp.seconds,eligible=cp.eligible})
    else FB.StartCampaign(FB.db.unlocked) end
end
function FB.LeaveBoard()
    FB.Recordings.CloseRound()
    local cp,game=FB.db.checkpoint,FB.game
    if cp and game and game.mode=="campaign" and game.status=="playing" and (game.shots>0 or game.elapsed>0) then
        -- The checkpoint has the board's opening state. Replaying it cannot
        -- count toward the same timed highscore after this game is discarded.
        cp.eligible=false
    end
end
function FB.StartSolo(mode,chainReaction)
    if not FB.CanStart() then return end
    FB.LeaveBoard(); FB.LocalVersus.match=nil
    local seed=FB.GameSeed()
    FB.game=FB.Engine.New(nil,seed,mode,chainReaction,FB.Sound,true); FB.run=nil; FB.level=1
    FB.game.lowGraphics=FB.db.graphicsLevel==1
    FB.game.timed=FB.db.shotClock~=false
    FB.Recordings.Begin(seed,FB.game)
    FB.UI.editing=false; FB.Transitions.Open("game"); FB.UI.frame:Show(); FB.Music()
end
function FB.StartCustomBoard(set,index)
    local board=set.boards[index]
    if not board or not set.builtin and not FB.Community.Validate(board) then return end
    local game=FB.Engine.New(board,FB.GameSeed(),"custom",nil,FB.Sound,true)
    if not game or not FB.CanStart() then return end
    FB.LeaveBoard(); FB.LocalVersus.match=nil; FB.run=nil; FB.game=game
    game.lowGraphics=FB.db.graphicsLevel==1
    game.timed=FB.db.shotClock~=false
    FB.game.customSet,FB.game.customIndex=set,index
    FB.Transitions.Open("game"); FB.UI.frame:Show(); FB.Music()
end
function FB.StartCustom(data,id)
    FB.StartCustomBoard({boards={data},id=id,title="Custom level"},1)
end
function FB.PlayCustom(id,index)
    local item=FB.db.custom[id]
    if item and not item.emptyBoard then
        FB.StartCustomBoard({id=id,title=item.title,boards=FB.Community.Boards(item)},index or 1)
    end
end
function FB.StartVersus(matchSeed,chainReaction)
    local resultKey=FB.UI.keys.resultKey
    FB.LeaveBoard(); FB.LocalVersus.match=nil
    FB.UI.keys={}
    FB.Debug.Log("GAME","versus",matchSeed)
    FB.game=FB.Engine.New(nil,matchSeed,"versus",chainReaction,FB.Sound); FB.run=nil
    FB.game.lowGraphics=FB.db.graphicsLevel==1
    FB.UI.editing=false; FB.Transitions.Open("opponent"); FB.UI.keys.resultKey=resultKey
    FB.UI.frame:Show(); FB.Music()
end
function FB.TogglePause(key)
    if not FB.game or FB.game.status~="playing" then return end
    if FB.game.mode=="versus" and not FB.LocalVersus.match then FB.Print("Versus matches cannot pause. Leave multiplayer to forfeit."); return end
    if InCombatLockdown() then return end
    FB.UI.focusPausedGame=nil
    FB.game.paused=not FB.game.paused
    FB.UI.keys={}
    if key then FB.UI.keys[key]=true end
    if FB.game.paused then FB.Sound("pause") end
    FB.UI:UpdatePause(0); FB.Music()
end
function FB.Fire()
    if InCombatLockdown() or FB.UI.editing or FB.Transitions.target or not FB.game then return end
    FB.UI:SamplePointer(FB.game); FB.game:Shoot()
end
function FB.NextLevel()
    local game=FB.game
    if not game or game.status~="won" then return end
    if game.customSet and game.customIndex<#game.customSet.boards then
        FB.StartCustomBoard(game.customSet,game.customIndex+1)
    elseif game.mode=="campaign" and FB.level<100 then FB.StartCampaign(FB.level+1,FB.run) end
end
-- A failed board can be retried within the same timed campaign. Settle
-- the run only on a finish request or after its last level is cleared.
function FB.FinishCampaignRun()
    local game,run=FB.game,FB.run
    if not game or game.mode~="campaign" or not run then return end
    if run.closed then return game.scoreEntry end
    run.closed=true
    if not game.recorded then
        run.score=run.score+game.score; run.seconds=run.seconds+game.elapsed
        game.recorded=true; game.score=0
    end
    local completed=game.status=="won" and FB.level==100
    local reached=game.status=="won" and math.min(100,FB.level+1) or FB.level
    if run.eligible then game.scoreEntry=FB.Scores.Finish("campaign",run.score,reached,run.seconds,completed) end
    if not completed then game.status="retired"; game.paused=true end
    FB.db.checkpoint=nil
    return game.scoreEntry
end
local function finishSolo()
    local game=FB.game
    if not game or game.mode=="versus" or game.status=="playing" or game.recorded then return end
    game.recorded=true
    if game.status=="finished" then FB.Sound("cancel")
    elseif game.status=="lost" and not game.lossSoundPlayed then FB.Sound("lose") end
    if game.mode=="campaign" then
        FB.run.score=FB.run.score+game.score; game.score=0
        FB.run.seconds=FB.run.seconds+game.elapsed
        if game.status=="won" and FB.level==100 then FB.FinishCampaignRun()
        else
            local level=game.status=="won" and FB.level+1 or FB.level
            FB.db.unlocked=math.max(FB.db.unlocked,level)
            FB.db.checkpoint={level=level,score=FB.run.score,seconds=FB.run.seconds,eligible=FB.run.eligible}
        end
    elseif game.mode=="endless" or game.mode=="training" and game.status=="finished" then
        game.scoreEntry=FB.Scores.Finish(game.chainReaction and "training-chain" or game.mode,game.score,1,game.elapsed)
    end
end
local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then
        if (...)~=addon then return end
        FrozenBubbleDB=type(FrozenBubbleDB)=="table" and FrozenBubbleDB or {}
        FB.db=FrozenBubbleDB; FB.Scores.Init(FB.db); FB.Controls.Load(FB.db.bindings)
        FB.db.graphicsLevel=FB.Integer(FB.db.graphicsLevel,1,3) or 3
        FB.Debug.Init()
        FB.UI:Build()
        FB.Options.Init(); FB.Invitations.Init()
        C_ChatInfo.RegisterAddonMessagePrefix(FB.PREFIX)
        events:RegisterEvent("CHAT_MSG_ADDON"); events:RegisterEvent("CHAT_MSG_CHANNEL")
        events:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE"); events:RegisterEvent("PLAYER_REGEN_DISABLED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:RegisterEvent("PLAYER_LOGOUT"); events:RegisterEvent("PLAYER_ENTERING_WORLD")
        SLASH_FROZENBUBBLE1="/fb"; SLASH_FROZENBUBBLE2="/frozenbubble"
        SlashCmdList.FROZENBUBBLE=function(command)
            if command:match("^debug") then FB.Debug.Command(command:match("^debug%s*(.*)$"))
            elseif command=="record" then FB.Recordings.Mark()
            elseif command=="replays" then FB.Recordings.Library()
            elseif command=="replay" then FB.Recordings.Play(1)
            elseif command=="settings" then FB.Options.Open()
            elseif command=="queue" then FB.UI:ShowLobby(); FB.Net.SetQueue(true)
            elseif command=="scores" then FB.UI.frame:Show(); FB.UI:ShowScores()
            elseif command=="levels" then FB.UI.frame:Show(); FB.UI:ShowMarket()
            elseif command=="join" then FB.Community.Join(); FB.UI:ShowLobby()
            else FB.UI.frame:SetShown(not FB.UI.frame:IsShown()) end
        end
        FB.Print("Loaded. Type /fb to play.")
    elseif event=="CHAT_MSG_ADDON" then
        local prefix,message,channel,sender,_,_,localID,channelName=...
        if channel~="CHANNEL" or (FB.Community.id and localID==FB.Community.id) or channelName==FB.Community.name then
            FB.Net.Receive(prefix,message,channel,sender)
        end
    elseif event=="CHAT_MSG_CHANNEL" then
        local message,sender,_,_,_,_,_,_,channelName=...
        FB.Community.Chat(message,sender,channelName)
    elseif event=="CHAT_MSG_CHANNEL_NOTICE" then
        local notice,_,_,_,_,_,_,channelID,channelName=...
        if notice=="NOT_ALLOWED_IN_CHANNEL" and (channelName==FB.Community.name or channelID==FB.Community.id) then FB.Community.Blocked() end
    elseif event=="PLAYER_ENTERING_WORLD" then
        if FB.db.community and not FB.Community.joined then FB.Community.Join() end
    elseif event=="PLAYER_REGEN_DISABLED" then
        FB.UI.focusPausedGame=nil
        FB.UI:SetCombatInput(true)
        FB.UI.keys={}; FB.UI.board:EnableKeyboard(false)
        local match=FB.Net.match
        if match and match.arena then FB.Arena.Leave("Combat started."); match=nil end
        if match and (match.phase=="restart" or match.phase=="barrier" or match.phase=="done") then FB.Series.Leave(match) end
        if match and match.phase~="playing" and match.phase~="done" then
            FB.Net.Whisper("CANCEL",match.id); FB.Net.match=nil
        end
        if FB.game then
            if FB.game.mode=="versus" and FB.Net.match and FB.Net.match.phase=="playing" then
                FB.Net.Finish("aborted","Combat started. Match canceled without a result.",false)
                FB.Net.Whisper("CANCEL",FB.Net.match.id)
            else FB.game.paused=true end
        end
    elseif event=="PLAYER_REGEN_ENABLED" then
        FB.UI:SetCombatInput(false)
    elseif event=="PLAYER_LOGOUT" then
        FB.UI:StoreEditorDraft()
        FB.StopGameMusic()
        FB.LeaveBoard()
    end
end)
local function networkTick(game,dt)
    local m=FB.Net.match
    if m.arena then FB.Arena.StepBoards(m,game.lowGraphics) else FB.PeerView.StepDuel(m,game.lowGraphics) end
    local ui=FB.UI
    if ui.screen=="opponent" and ui.frame:IsShown() and not FB.Transitions.target then
        ui.AnimatePlayerTick(game,dt)
        if FB.db.graphicsLevel==3 and not FB.db.reducedMotion then
            if m.arena then ui:AnimateArena(m,dt)
            else FB.Animation.Penguin(ui.remotePenguin,m.remote,"p2",dt) end
        end
    end
end
events:SetScript("OnUpdate",function(_,dt)
    if not FB.db then return end
    FB.Invitations.Update()
    FB.UI:UpdateVisibility(dt)
    local playTime=FB.Transitions.Advance(dt)
    local networkRound
    if FB.Recordings.playback then
        FB.Recordings.Update(playTime)
    elseif FB.LocalVersus.match and not FB.UI.editing then
        FB.LocalVersus.Update(playTime,FB.UI.keys)
    elseif FB.game and not FB.UI.editing then
        local game=FB.game
        local elapsed=game.mode=="versus" and FB.Net.match and dt or playTime
        local ui=FB.UI
        local m=FB.Net.match
        networkRound=game.mode=="versus" and m and (m.opponents or m.remote) and (m.phase=="playing" or m.phase=="done")
        if networkRound then m.fixedClock=true end
        if ui.frame:IsShown() and (ui.screen=="game" or ui.screen=="opponent") and not FB.Transitions.target then
            if game.status=="playing" and not game.paused then ui:SamplePointer(game) end
            game:Update(elapsed,ui.PlayerInput,networkRound and networkTick or ui.AnimatePlayerTick)
        else
            if networkRound then game.aimKeys,game.turning=0,0 end
            game:Update(elapsed,nil,networkRound and networkTick or nil)
        end
        if game.boardChanged then
            if game.mode=="versus" then FB.Net.State() end
            game.boardChanged=false
        end
        finishSolo()
    end
    FB.Community.Update(); FB.Net.Update(dt,networkRound); FB.UI:Update(playTime)
end)
