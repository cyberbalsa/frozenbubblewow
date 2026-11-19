local _,FB=...
local U,A=FB.UI,FB.Arena
local positions={
    {x=20,y=19,penguinX=114,penguinY=211,scoreX=83,scoreY=2,attackX=25,attackY=213,dotX=149,dotY=28,malusX=12,malusY=183},
    {x=492,y=19,penguinX=586,penguinY=211,scoreX=553,scoreY=2,attackX=496,attackY=214,dotX=483,dotY=28,malusX=628,malusY=183},
    {x=20,y=247,penguinX=114,penguinY=439,scoreX=83,scoreY=465,attackX=24,attackY=442,dotX=149,dotY=258,malusX=12,malusY=411},
    {x=492,y=247,penguinX=586,penguinY=439,scoreX=553,scoreY=465,attackX=496,attackY=442,dotX=483,dotY=258,malusX=628,malusY=411},
}
function U:BuildArenaHUD(makeBoard)
    self.makeArenaBoard=makeBoard
    self.arenaHUD=CreateFrame("Frame",nil,self.gameLayer)
    self.arenaHUD:SetSize(640,480); self.arenaHUD:SetScale(1.6); self.arenaHUD:SetPoint("TOPLEFT")
    self.arenaHUD:SetFrameLevel(self.layers.hud); self.arenaHUD:Hide()
    self.miniLabels={}; self.miniPenguins={}; self.attackIcons={}; self.threats={}; self.miniBoards={}; self.roomChats={}; self.leftSigns={}
    for i,pos in ipairs(positions) do
        local slot="rp"..i
        self.miniLabels[i]=FB.Plaques.Caption(self.arenaHUD,pos.scoreX,pos.scoreY,1)
        self.miniPenguins[i]=FB.Animation.Image(self.arenaHUD,"anime-shooter-"..slot,pos.penguinX,pos.penguinY)
        self.attackIcons[i]=FB.Animation.Image(self.arenaHUD,"target-"..slot,pos.attackX,pos.attackY)
        self.threats[i]=FB.Animation.Image(self.arenaHUD,"target-me-"..slot,185,448)
        local left=i%2==1
        self.roomChats[i]=FB.MatchChat.Panel(self.arenaHUD,left and "arena-chat-left" or "arena-chat-right",left and 5 or 460,i<3 and 230 or 460,1)
        self.leftSigns[i]=FB.Animation.Image(self.arenaHUD,"arena-left-"..slot,pos.x-1,pos.y-2)
        self.leftSigns[i]:Hide()
    end
end
function U:LayoutArena(m)
    FB.Animation.Frame(self.gameBackground,"arena-background",1)
    self:WindowControls("arena")
    self.menuControl:ClearAllPoints(); self.menuControl:SetPoint("TOPLEFT",318,-621)
    FB.MatchChat.Position(true)
    self.arenaHUD:Show(); self.remoteBoard:Hide(); self.remoteLabel:Hide(); self.remotePenguin:Hide()
    self:PlaceBoard(self.board,304,70.4,1.6)
    self.result:ClearAllPoints(); self.result:SetPoint("TOPLEFT",238.4,-304)
    self.board.fbPenaltyX,self.board.fbPenaltyY,self.board.fbNextY=-21,420,412
    if not self.roomBadges then
        self.roomBadges=CreateFrame("Frame",nil,self.result); self.roomBadges:SetAllPoints(); self.roomBadges:SetFrameLevel(self.layers.panel)
        self.loserIcons={}
        for i=1,4 do self.loserIcons[i]=FB.Animation.Image(self.roomBadges,"net-lose-local",0,118.4,64,49.6) end
    end
    self.penguin:ClearAllPoints(); self.penguin:SetPoint("TOPLEFT",644.8,-672)
    self.roomOpponents=A.Opponents(m)
    for i,pos in ipairs(positions) do
        local visible=self.roomOpponents[i]~=nil
        local board=self.miniBoards[i]
        if visible and not board then
            board=self.makeArenaBoard(self.gameLayer,0,0); self.miniBoards[i]=board
            board:SetFrameLevel(self.layers.board); board.fbMiniSeat=i
        end
        if board then
            board:SetShown(visible)
            if visible then
                self:PlaceBoard(board,pos.x*1.6,pos.y*1.6,0.8)
                board.fbPenaltyX,board.fbPenaltyY=(pos.malusX-pos.x)*2,(pos.malusY-pos.y)*2
                board.fbNextY=i<3 and 410 or 412
                board.hurry:ClearAllPoints(); board.hurry:SetPoint("TOPLEFT",10,-((i<3 and 128 or 345)-pos.y)*2)
                for n,dot in ipairs(board.progress) do
                    dot:ClearAllPoints(); dot:SetPoint("TOPLEFT",(pos.dotX-pos.x)*2,-(pos.dotY-pos.y+(n-1)*8)*2)
                    dot:SetSize(14,14)
                end
            end
        end
        self.miniLabels[i]:SetShown(visible); self.miniPenguins[i]:SetShown(visible)
        self.attackIcons[i]:Hide(); self.threats[i]:Hide(); self.roomChats[i]:Hide(); self.leftSigns[i]:Hide()
    end
    self.board.hurry:ClearAllPoints(); self.board.hurry:SetPoint("TOPLEFT",10,-221)
    for n,dot in ipairs(self.board.progress) do
        dot:ClearAllPoints(); dot:SetPoint("TOPLEFT",257,16-(n-1)*8)
    end
end
function U:AnimateArena(m,dt)
    for i,v in ipairs(m.opponents) do
        if not v.left then FB.Animation.Penguin(self.miniPenguins[i],v.remote,"rp"..i,dt) end
    end
end
function U:RenderArena(m,dt,replayGame,lastFrame)
    local me=m.players[m.me]
    FB.Plaques.center:SetNameScore(me.label,me.wins,14,220); FB.Plaques.center:Show()
    self.hud:Hide(); self.footer:Hide(); self.pauseArt:Hide()
    self.trainingClock:Hide(); self.nextButton:Hide()
    local restarting=m.phase=="seating" and m.played
    local winner=m.names[m.winner or 0]
    local winnerArt="net-win-local"
    local threats=0
    for i,v in ipairs(self.roomOpponents) do
        self.miniBoards[i]:SetShown(not v.left)
        self.leftSigns[i]:SetShown(v.left or false)
        if not v.left then self:RenderBoard(self.miniBoards[i],v.remote,true) end
        self.miniLabels[i]:SetNameScore(v.label,v.wins,8,132)
        local chat=self.roomChats[i]
        chat:SetShown(not v.left and v.remote.chatText~=nil)
        if chat:IsShown() then chat.line:SetText(v.remote.chatText) end
        self.miniLabels[i]:SetShown(i<3 or not chat:IsShown())
        self.attackIcons[i]:SetShown(m.target==v.name)
        local threat=v.target==m.me and not v.lost and not FB.MatchChat.input:IsShown()
        self.threats[i]:SetShown(threat)
        if threat then
            self.threats[i]:ClearAllPoints(); self.threats[i]:SetPoint("TOPLEFT",185+24*threats,-448)
            threats=threats+1
        end
        self.miniPenguins[i]:SetShown(not v.left and FB.db.graphicsLevel==3)
        if not v.left and FB.db.graphicsLevel==3 then FB.Animation.Penguin(self.miniPenguins[i],v.remote,"rp"..i,(m.fixedClock or FB.db.reducedMotion) and 0 or dt) end
        if v.name==winner then winnerArt="arena-win-rp"..i end
    end
    local game=replayGame or FB.game
    self.resultGame,self.resultStatus=game,game.status
    if m.closed then
        self.result:Show(); self.roomBadges:Hide(); self.winnerName:Hide(); self.resultBadge:Hide()
        self.drawPanel:Hide()
        FB.Animation.Frame(self.resultArt,"panel",1); self.resultArt:SetSize(526.4,254.4)
        self.resultDetail:SetText(m.closed); self.resultDetail:Show()
        return
    end
    local ready,advance
    if m.phase=="done" or restarting then
        local winnerBoard=winner and (winner==m.me and game or m.players[winner].remote)
        ready,advance=self:OnlineResultTiming(game,m,winnerBoard,lastFrame or restarting)
    end
    self.result:SetShown(ready or false)
    self.drawPanel:SetShown(ready and not winner or false)
    if not ready then return end
    if winner then FB.Animation.Frame(self.resultArt,winnerArt,1) else self.resultArt:Hide() end
    self.resultArt:SetSize(526.4,254.4)
    self.winnerName:SetShown(winner~=nil)
    if winner then self.winnerName:SetNameScore(winner,nil,14,198) end
    self:ShowTrainingResult(false); self.resultBadge:Hide(); self.resultScores:Hide()
    self.roomBadges:SetShown(winner~=nil)
    local x=#m.names==5 and 322 or #m.names==4 and 348 or 352
    local used=0
    for i=0,#self.roomOpponents do
        local v=i==0 and me or self.roomOpponents[i]
        if winner and v.name~=winner then
            used=used+1
            local icon=self.loserIcons[used]
            icon:ClearAllPoints(); icon:SetPoint("TOPLEFT",(x-149)*1.6,-118.4)
            FB.Animation.Frame(icon,i==0 and "net-lose-local" or "arena-lose-rp"..i,1)
            x=x+32
        end
    end
    for i=used+1,4 do self.loserIcons[i]:Hide() end
    self.resultDetail:Show()
    local result=winner and (A.Complete(m) and "Series won" or "Round "..m.round) or "Draw"
    self.resultDetail:SetText(result.." · "..FB.Series.Label(m.limit))
    if replayGame then return end
    self.retryButton:SetShown(advance or false); self.retryButton:SetEnabled(not restarting and not m.wantNext)
    self.retryButton:SetText(restarting and "Starting round…" or A.Complete(m) and "Back to lobby" or m.wantNext and "Waiting for opponents…" or "Next round")
    self.leaveSeries:SetShown(not A.Complete(m))
end
