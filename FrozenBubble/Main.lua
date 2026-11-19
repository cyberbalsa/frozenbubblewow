local addon, FB = ...
function FB.GameSeed() return (time()+math.floor(GetTime()*1000))%2147483646+1 end
function FB.CanStart()
    if InCombatLockdown() then FB.Print("Start a game after combat."); return false end
    if FB.Net.match and FB.Net.match.phase~="done" then FB.Print("Leave or finish multiplayer first."); return false end
    if FB.Net.match then FB.Series.Leave(FB.Net.match); FB.Net.match=nil end
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
    FB.musicTrack=nil
end
function FB.Music()
    if not FB.UI.frame then return end
    if FB.db.music and FB.UI.frame:IsShown() and PlayMusic then
        local muted=FB.UI.inactive or InCombatLockdown()
        if muted and not FB.musicTrack then return end
        local get=(C_CVar and C_CVar.GetCVar) or GetCVar
        local set=(C_CVar and C_CVar.SetCVar) or SetCVar
        if get and set then
            if not FB.oldMusicVolume then FB.oldMusicVolume=get("Sound_MusicVolume") end
            set("Sound_MusicVolume",muted and 0 or (FB.db.musicVolume or 0.8))
        end
        if muted then return end
        local versus=FB.game and FB.game.mode=="versus"
        if FB.Demos.scene then versus=FB.Demos.scene~=FB.DemoData.scenes[1] end
        local track=FB.UI.menu and FB.UI.menu:IsShown() and "introzik.ogg"
            or (versus and "frozen-mainzik-2p.ogg" or "frozen-mainzik-1p.ogg")
        if FB.musicTrack~=track then PlayMusic(FB.media..track); FB.musicTrack=track end
    else FB.StopGameMusic() end
end
function FB.StartCampaign(level,run)
    if not FB.CanStart() then return end
    FB.LocalVersus.match=nil
    level=FB.Clamp(math.floor(level),1,FB.db.unlocked)
    FB.level=level; FB.run=run or {score=0,seconds=0,eligible=level==1}
    FB.game=FB.Engine.New(FB.Levels[level],FB.GameSeed(),"campaign")
    FB.Debug.Log("GAME","campaign",level)
    FB.UI.editing=false; FB.UI.frame:Show(); FB.UI:Panel("game"); FB.UI.level:SetText(tostring(level))
    FB.db.checkpoint={level=level,score=FB.run.score,seconds=FB.run.seconds,eligible=FB.run.eligible}
    FB.Music()
end
function FB.ContinueCampaign()
    local cp=FB.db.checkpoint
    if cp then FB.StartCampaign(cp.level,{score=cp.score,seconds=cp.seconds,eligible=cp.eligible})
    else FB.StartCampaign(FB.db.unlocked) end
end
function FB.StartSolo(mode,chainReaction)
    if not FB.CanStart() then return end
    FB.LocalVersus.match=nil
    FB.game=FB.Engine.New(nil,FB.GameSeed(),mode,chainReaction); FB.run=nil; FB.level=1
    FB.UI.editing=false; FB.UI.frame:Show(); FB.UI:Panel("game"); FB.Music()
end
function FB.StartCustomBoard(set,index)
    local board=set.boards[index]
    local grid=not set.builtin and FB.Engine.Unpack(board)
    if not board or (not set.builtin and not grid) or not FB.CanStart() then return end
    FB.LocalVersus.match=nil; FB.run=nil
    FB.game=FB.Engine.New(set.builtin and board or {},FB.GameSeed(),"custom")
    if grid then
        FB.game.grid=grid
        for key=1,FB.Engine.ROWS*8 do
            if grid[key] then FB.game.attachedOrder[#FB.game.attachedOrder+1]=key end
        end
        FB.game.current=FB.game:Color(); FB.game.next=FB.game:Color()
    end
    FB.game.customSet,FB.game.customIndex=set,index
    FB.UI.frame:Show(); FB.UI:Panel("game"); FB.Music()
end
function FB.StartCustom(data,id)
    FB.StartCustomBoard({boards={data},id=id,title="Custom level"},1)
end
function FB.PlayCustom(id,index)
    local item=FB.db.custom[id]
    if item then FB.StartCustomBoard({id=id,title=item.title,boards=FB.Community.Boards(item)},index or 1) end
end
function FB.StartVersus(matchSeed,chainReaction)
    FB.LocalVersus.match=nil
    FB.UI.keys={}
    FB.Debug.Log("GAME","versus",matchSeed)
    FB.game=FB.Engine.New(nil,matchSeed,"versus",chainReaction); FB.run=nil
    FB.UI.editing=false; FB.UI.frame:Show(); FB.UI:Panel("opponent"); FB.Music()
end
function FB.TogglePause()
    if not FB.game then return end
    if FB.game.mode=="versus" and not FB.LocalVersus.match then FB.Print("Versus matches cannot pause. Leave multiplayer to forfeit."); return end
    if InCombatLockdown() then return end
    FB.UI.focusPausedGame=nil
    FB.game.paused=not FB.game.paused
end
function FB.Fire()
    if InCombatLockdown() or FB.UI.editing or not FB.game then return end
    if FB.game:Shoot() then FB.Sound("launch") end
end
function FB.NextLevel()
    local game=FB.game
    if not game or game.status~="won" then return end
    if game.customSet and game.customIndex<#game.customSet.boards then
        FB.StartCustomBoard(game.customSet,game.customIndex+1)
    elseif game.mode=="campaign" and FB.level<100 then FB.StartCampaign(FB.level+1,FB.run) end
end
local function finishSolo()
    local game=FB.game
    if not game or game.mode=="versus" or game.status=="playing" or game.recorded then return end
    game.recorded=true; FB.Sound(game.status=="finished" and "cancel" or game.status=="won" and "applause" or "lose")
    if game.mode=="campaign" then
        FB.run.score=FB.run.score+game.score; game.score=0
        FB.run.seconds=FB.run.seconds+game.elapsed
        if game.status=="won" and FB.level<100 then
            FB.db.unlocked=math.max(FB.db.unlocked,FB.level+1)
            FB.db.checkpoint={level=FB.level+1,score=FB.run.score,seconds=FB.run.seconds,eligible=FB.run.eligible}
        else
            if FB.run.eligible then game.scoreEntry=FB.Scores.Record("campaign",FB.run.score,FB.level,FB.run.seconds,game.status=="won") end
            FB.db.checkpoint=nil
        end
    elseif game.mode=="endless" or game.mode=="training" and game.status=="finished" then
        game.scoreEntry=FB.Scores.Record(game.chainReaction and "training-chain" or game.mode,game.score,1,game.elapsed)
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
        if FB.db.checkpoint and FB.game and FB.game.mode=="campaign" and FB.game.status=="playing" then
            -- Restarting a partially played board is practice, preventing checkpoint score farming.
            FB.db.checkpoint.eligible=false
        end
    end
end)
events:SetScript("OnUpdate",function(_,dt)
    if not FB.db then return end
    FB.Invitations.Update()
    FB.UI:UpdateVisibility(dt)
    if FB.LocalVersus.match and not FB.UI.editing then
        FB.LocalVersus.Update(dt,FB.UI.keys)
    elseif FB.game and not FB.UI.editing then
        FB.game:Update(dt)
        local game=FB.game
        if game.changed then
            game.boardChanged=true
        end
        if game.boardChanged then
            if game.mode=="versus" then FB.Net.State() end
            game.boardChanged=false
        end
        FB.BoardSounds(game)
        finishSolo()
    end
    FB.Community.Update(); FB.Net.Update(dt); FB.UI:Update(dt)
end)
