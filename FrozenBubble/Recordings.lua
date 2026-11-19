-- Personal recordings use the desktop game's 50 Hz action timeline. Store
-- mouse aim losslessly as well as keyboard turns. Playback uses fresh engines.
local _,FB=...
local R={}
FB.Recordings=R
local labels={random="Random",training="Training",endless="Endless",versus="2P Game"}

local function save()
    local capture=R.capture
    if not capture or not (capture.marked or FB.db.autoRecord) then return end
    local record=capture.record
    if capture.saved or not capture.hasInput or record.frames==0 then return end
    FB.db.recordings=FB.db.recordings or {}
    table.insert(FB.db.recordings,1,record)
    if #FB.db.recordings>10 then table.remove(FB.db.recordings) end
    capture.saved=true
end

local function shot(game,_,inside)
    local t=game.recordTrack
    local list=inside and t.input or t.before
    list[#list+1]={t.frame+1,"fire",string.format("%.17g",game.angle)}
    t.angle=nil
    R.capture.hasInput=true
end

function R.Clock(game,value)
    local t=game.recordTrack
    t.before[#t.before+1]={t.frame+1,"clock",value}
end

function R.EndTick(game)
    local t=game.recordTrack
    t.frame=t.frame+1
    local angle,turn=game.angle,game.turning or 0
    if angle~=t.angle or turn~=t.turn then
        t.pose[#t.pose+1]={t.frame,string.format("%.17g",angle),turn}
        t.angle,t.turn=angle,turn
        R.capture.hasInput=true
    end
    if game==R.capture.right then R.capture.record.frames=t.frame end
end

function R.CloseRound()
    local c=R.capture
    if not c then return end
    save()
    c.right.recordTrack,c.right.onShoot=nil,nil
    if c.left then c.left.recordTrack,c.left.onShoot=nil,nil end
    R.capture=nil
end

function R.Begin(seed,right,match)
    R.CloseRound()
    if not labels[right.mode] or right.mode=="versus" and not match then return end
    local record={version=1,mode=right.mode,seed=seed,chains=right.chainReaction,timed=right.timed~=false,
        frames=0,date=time(),tracks={}}
    if match then record.wins={match.wins[1],match.wins[2]} end
    R.capture={record=record,right=right,left=match and match.left}
    local function attach(game)
        local data={before={},input={},pose={}}
        record.tracks[#record.tracks+1]=data
        game.recordTrack={before=data.before,input=data.input,pose=data.pose,frame=0,angle=0,turn=0}
        game.onShoot=shot
    end
    attach(right)
    if match then attach(match.left) end
end

function R.Mark()
    if not R.capture or R.playback then FB.Print("Record a random, training, endless or shared-keyboard game."); return end
    R.capture.marked=true; save()
    FB.Print("This round will be saved in Recordings.")
end

local function apply(game,list,key,frame)
    local cursor=game.replayCursor
    local i=cursor[key]
    local event=list[i]
    while event and event[1]==frame do
        if key=="pose" then game.angle=tonumber(event[2]); game.turning=event[3]
        elseif event[2]=="clock" then game.timed=event[3]; game.idle=0; game.hurryVisible=false
        else game:Shoot(tonumber(event[3])) end
        i=i+1; event=list[i]
    end
    cursor[key]=i
end

function R.NewPlayback(record,sound)
    if not record or record.version~=1 or not labels[record.mode] then return end
    local play
    if record.mode=="versus" then
        play=FB.LocalVersus.New(record.seed,record.chains,{record.wins[1],record.wins[2]},sound)
    else
        play={right=FB.Engine.New(nil,record.seed,record.mode,record.chains,sound)}
    end
    play.record,play.frame,play.elapsed=record,0,0
    for i,game in ipairs({play.right,play.left}) do
        local track=record.tracks[i]
        game.timed=record.timed
        game.replayCursor={before=1,input=1,pose=1}
        game.replayInput=function() apply(game,track.input,"input",play.frame) end
    end
    return play
end

function R.Step(play)
    if play.frame>=play.record.frames then return false end
    play.frame=play.frame+1
    local tracks=play.record.tracks
    apply(play.right,tracks[1].before,"before",play.frame)
    if play.left then
        apply(play.left,tracks[2].before,"before",play.frame)
        FB.LocalVersus.Step(play,play.right.replayInput,play.left.replayInput)
        apply(play.left,tracks[2].pose,"pose",play.frame)
    else
        local previous=play.right.status
        play.right:Step(0.02,play.right.replayInput)
        if previous~=play.right.status then
            if play.right.status=="lost" then play.right.sound("lose")
            elseif play.right.status=="finished" then play.right.sound("cancel") end
        end
    end
    apply(play.right,tracks[1].pose,"pose",play.frame)
    return true
end

local function clock(frames)
    local seconds=math.floor(frames/50)
    return string.format("%d:%02d",math.floor(seconds/60),seconds%60)
end
function R.Library()
    if InCombatLockdown() then return end
    save()
    local ui=FB.UI
    ui.frame:Show(); ui:Panel("recordings")
    local rows=FB.db.recordings or {}
    ui.emptyRecords:SetShown(#rows==0)
    for i,button in ipairs(ui.recordButtons) do
        local rec=rows[i]
        button:SetShown(rec~=nil)
        if rec then button:SetText(labels[rec.mode].."   "..date("%b %d %H:%M",rec.date).."   "..clock(rec.frames)) end
    end
end
function R.Play(index)
    if InCombatLockdown() then return end
    if FB.Net.match or FB.Net.queue then FB.Print("Leave multiplayer before watching a recording."); return end
    save()
    local record=(FB.db.recordings or {})[index]
    if not record then R.Library(); return end
    R.playback=R.NewPlayback(record,FB.Sound)
    if not R.playback then FB.Print("This recording needs another playback version."); R.Library(); return end
    if FB.game then FB.game.paused=true end
    FB.UI.frame:Show(); FB.UI:Panel("replay"); R.Render()
end

function R.Update(dt)
    local p,ui=R.playback,FB.UI
    if not ui.frame:IsShown() or ui.inactive or InCombatLockdown() then return end
    p.elapsed=p.elapsed+math.min(dt,0.25)
    while p.elapsed+1e-9>=0.02 do
        p.elapsed=p.elapsed-0.02
        if not R.Step(p) then R.Library(); return end
        if FB.db.graphicsLevel==3 and not FB.db.reducedMotion then
            FB.Animation.Penguin(ui.penguin,p.right,"p1",0.02)
            if p.left then FB.Animation.Penguin(ui.remotePenguin,p.left,"p2",0.02) end
        end
    end
end

function R.Render()
    local p,ui=R.playback,FB.UI
    ui:RenderBoard(ui.board,p.right)
    ui.penguin:SetShown(FB.db.graphicsLevel==3)
    if FB.db.graphicsLevel==3 then FB.Animation.Penguin(ui.penguin,p.right,"p1",0) end
    if p.left then
        ui:RenderBoard(ui.remoteBoard,p.left,true)
        if FB.db.graphicsLevel==3 then FB.Animation.Penguin(ui.remotePenguin,p.left,"p2",0) end
        ui.remotePenguin:SetShown(FB.db.graphicsLevel==3)
        ui.remoteLabel:SetText(tostring(p.wins[2]))
    end
    ui.hud:SetText(p.left and tostring(p.wins[1]) or (labels[p.record.mode].."\n"..p.right.score.." points"))
    local game=p.right
    if game.status~="playing" then
        local winner=p.left and (game.status=="won" and game or game.status=="lost" and p.left)
        ui.result:SetShown(ui:ResultReady(game,p.left,winner) or false)
        if game.status=="finished" then
            ui.resultArt:Hide(); ui:ShowTrainingResult(true); ui.trainingScore:SetText(tostring(game.score))
        else
            local art=winner and (winner==game and "local-win-p1" or "local-win-p2") or
                (game.status=="won" and "win-panel" or game.status=="draw" and "panel" or "lose-panel")
            ui.resultArt:SetSize(art=="lose-panel" and 552 or 526.4,art=="lose-panel" and 198.4 or 254.4)
            FB.Animation.Frame(ui.resultArt,art,1)
            if game.status=="draw" then ui.resultDetail:SetText("Draw"); ui.resultDetail:Show() end
        end
    end
    ui.replayTime:SetText(clock(p.frame).." / "..clock(p.record.frames))
    if p.record.mode=="training" then
        local seconds=math.floor(p.right:TrainingTimeLeft())
        ui.trainingTime:SetText(string.format("%d'%02d\"",math.floor(seconds/60),seconds%60))
    end
end
