-- Personal recordings use the desktop game's 50 Hz action timeline. Store
-- mouse aim losslessly as well as keyboard turns. Playback uses fresh engines.
local _,FB=...
local R={}
FB.Recordings=R
local labels={random="Random",training="Training",endless="Endless",versus="2P Game"}

local function keep(record)
    FB.db.recordings=FB.db.recordings or {}
    table.insert(FB.db.recordings,1,record)
    if #FB.db.recordings>10 then table.remove(FB.db.recordings) end
end

local function save()
    local capture=R.capture
    if not capture or not (capture.marked or FB.db.autoRecord) then return end
    local record=capture.record
    if capture.saved or not capture.hasInput or record.frames==0 then return end
    keep(record)
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

function R.Graphics(game,low)
    if game.recordTrack then
        local t=game.recordTrack
        t.before[#t.before+1]={t.frame+1,"graphics",low}
    end
    game.lowGraphics=low
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
    local record={version=right.desktopRandom and 2 or 1,lowGraphics=right.lowGraphics,mode=right.mode,seed=seed,chains=right.chainReaction,timed=right.timed~=false,
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

-- The desktop record_protocol:0 format stores changes to held keys, with
-- both players' changes indexed by the same simulation frame.
function R.Import(source)
    if type(source)~="string" then return nil,"Paste a plain-text Frozen Bubble recording." end
    local allowed={left=true,right=true,center=true,fire=true,hadfire=true}
    local header,tracks={},{}
    for i=1,2 do tracks[i]={before={},input={},pose={},keys={}} end
    local last,second=0,false
    for line in source:gmatch("[^\r\n]+") do
        local key,value=line:match("^([%w_]+):(.*)$")
        if not key then return nil,"Expected a key and value on each line." end
        if key=="frame_action" then
            local frame,seat,action,pressed=value:match("^(%d+)|p([12])|(%a+)|([01]?)$")
            frame=FB.Integer(frame,1,2147483647)
            if not frame or frame<last or not allowed[action] then return nil,"Invalid recording action." end
            last=frame
            if seat=="2" then second=true end
            if action~="hadfire" then
                local list=tracks[tonumber(seat)].keys
                list[#list+1]={frame,action,pressed=="1"}
            end
        elseif key=="players" and value~="p1" and value~="p1,p2" then
            return nil,"Choose a solo or shared-keyboard recording."
        elseif key=="record_protocol" or key=="players" or key=="gametype" or key=="current_level"
            or key=="srand" or key=="chainreaction" or key=="time" or key=="comment" then
            if header[key]~=nil then return nil,"Duplicate recording header." end
            header[key]=value
        else return nil,"Unrecognized recording field." end
    end
    if header.record_protocol~="0" then return nil,"Expected Frozen Bubble recording protocol 0." end
    local seed=FB.Integer(header.srand,0,4294967295)
    local mode
    if header.players=="p1,p2" and header.current_level=="" then mode="versus"
    elseif header.players=="p1" and not second then
        mode=({random="random",mp_train="training"})[header.current_level]
    end
    if not mode or not seed or last==0 then return nil,"Missing local game, seed or recorded actions." end
    if header.chainreaction~="1" and header.chainreaction~="0" and header.chainreaction~="" then
        return nil,"Invalid chain-reaction setting."
    end
    if mode~="versus" then tracks[2]=nil end
    local record={version=2,mode=mode,seed=seed,chains=header.chainreaction=="1",timed=true,
        date=FB.Integer(header.time,0,2147483647) or time(),frames=last,tracks=tracks,wins=mode=="versus" and {0,0} or nil}
    save(); keep(record)
    return record
end

local function apply(game,list,key,frame)
    local cursor=game.replayCursor
    local i=cursor[key]
    local event=list[i]
    while event and event[1]==frame do
        if key=="keys" then game.replayHeld[event[2]]=event[3]
        elseif key=="pose" then game.angle=tonumber(event[2]); game.turning=event[3]
        elseif event[2]=="graphics" then game.lowGraphics=event[3]
        elseif event[2]=="clock" then game.timed=event[3]; game.idle=0; game.hurryVisible=false
        else game:Shoot(tonumber(event[3])) end
        i=i+1; event=list[i]
    end
    cursor[key]=i
end

function R.NewPlayback(record,sound)
    if not record or (record.version~=1 and record.version~=2) or not labels[record.mode] then return end
    local play
    if record.mode=="versus" then
        play=FB.LocalVersus.New(record.seed,record.chains,{record.wins[1],record.wins[2]},sound,record.version==2)
    else
        play={right=FB.Engine.New(nil,record.seed,record.mode,record.chains,sound,record.version==2)}
    end
    play.record,play.frame,play.elapsed=record,0,0
    for i,game in ipairs({play.right,play.left}) do
        local track=record.tracks[i]
        game.lowGraphics=record.lowGraphics
        game.timed=record.timed
        game.replayCursor={before=1,input=1,pose=1}
        if track.keys then
            local held={}
            game.replayHeld=held; game.replayCursor.keys=1
            game.replayInput=function(_,launchTick)
                apply(game,track.keys,"keys",play.frame)
                FB.Controls.Aim(game,held.left,held.right,held.center,0.03)
                if held.fire and game:Shoot(nil,launchTick) then held.fire=false end
            end
        else game.replayInput=function() apply(game,track.input,"input",play.frame) end end
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
function R.OpenImport()
    local ui=FB.UI
    ui:Panel("editorText"); ui.importingRecording=true
    ui.codeFormat:Hide(); ui.codeImport:Show()
    ui.codeHeading:SetText("Import desktop recording")
    ui.codeNotice:SetText("Paste the uncompressed text of a solo or shared-keyboard recording.")
    ui.levelCode:SetMaxBytes(524288); ui.levelCode:SetText(""); ui.levelCode:SetFocus()
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
