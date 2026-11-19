local _,FB=...
local U,A=FB.UI,FB.Arena
local positions={
    {x=20,y=19,penguinX=114,penguinY=211,scoreX=83,scoreY=2,attackX=25,attackY=213,dotX=149,dotY=28,malusX=12,malusY=183},
    {x=492,y=19,penguinX=586,penguinY=211,scoreX=553,scoreY=2,attackX=496,attackY=214,dotX=483,dotY=28,malusX=628,malusY=183},
    {x=20,y=247,penguinX=114,penguinY=439,scoreX=83,scoreY=465,attackX=24,attackY=442,dotX=149,dotY=258,malusX=12,malusY=411},
    {x=492,y=247,penguinX=586,penguinY=439,scoreX=553,scoreY=465,attackX=496,attackY=442,dotX=483,dotY=258,malusX=628,malusY=411},
}
function U:BuildRooms(text,button,input,makeBoard)
    local p=self.panels.rooms
    self.makeArenaBoard=makeBoard
    self.roomLabel=text(p,"Arena rooms",0,0,18,238)
    self.roomRules=text(p,"",0,37,13,348)
    self.createRoom=button(p,"Host room",0,70,105,A.Host)
    self.roomStart=button(p,"Start round",118,70,108,A.Start)
    self.roomLeave=button(p,"Leave room",238,70,110,function() A.Leave() end)
    self.roomTarget=input(p,0,112,195,"")
    self.roomJoin=button(p,"Join by host",206,109,142,function()
        self.roomTarget:ClearFocus(); A.Join(self.roomTarget:GetText())
    end)
    self.roomAnnounce=button(p,"Announce room",0,150,165,A.Announce)
    self.roomView=button(p,"View round",181,150,167,function() self:ShowGame() end)
    self.roomNotice=text(p,"",0,191,13,348)
    self.roomRows={}
    for i=1,5 do
        local row
        row=button(p,"",0,232+(i-1)*32,348,function() if row.host then A.Join(row.host) end end)
        self.roomRows[i]=row
    end
    self.roomPrev=button(p,"Previous",0,397,105,function() self.roomPage=self.roomPage-1; self:RefreshRooms() end)
    self.roomNext=button(p,"More rooms",240,397,108,function() self.roomPage=self.roomPage+1; self:RefreshRooms() end)
    self.keepRoom=button(p,"",0,436,170,function()
        if not FB.Net.match then FB.db.arenaContinue=FB.db.arenaContinue==false; self:RefreshRooms() end
    end)
    self.targetRule=button(p,"",181,436,167,function()
        if not FB.Net.match then FB.db.arenaTargeting=FB.db.arenaTargeting==false; self:RefreshRooms() end
    end)
    self.roomPage=1
    self.arenaHUD=CreateFrame("Frame",nil,self.gameLayer)
    self.arenaHUD:SetSize(640,480); self.arenaHUD:SetScale(1.6); self.arenaHUD:SetPoint("TOPLEFT")
    self.arenaHUD:SetFrameLevel(self.layers.hud); self.arenaHUD:Hide()
    self.miniLabels={}; self.miniPenguins={}; self.attackIcons={}; self.threats={}; self.miniBoards={}; self.roomChats={}; self.leftSigns={}
    for i,pos in ipairs(positions) do
        local slot="rp"..i
        local label=text(self.arenaHUD,"",pos.scoreX-78,pos.scoreY,11,156)
        label:SetJustifyH("CENTER"); label:SetWordWrap(false); self.miniLabels[i]=label
        self.miniPenguins[i]=FB.Animation.Image(self.arenaHUD,"anime-shooter-"..slot,pos.penguinX,pos.penguinY)
        self.attackIcons[i]=FB.Animation.Image(self.arenaHUD,"target-"..slot,pos.attackX,pos.attackY)
        self.threats[i]=FB.Animation.Image(self.arenaHUD,"target-me-"..slot,185,448)
        local chat=CreateFrame("Frame",nil,self.arenaHUD)
        local left=i%2==1
        chat:SetSize(174,17); chat:SetPoint("TOPLEFT",left and 5 or 460,i<3 and -230 or -460)
        FB.Animation.Image(chat,left and "arena-chat-left" or "arena-chat-right",0,0,nil,nil,"BACKGROUND")
        chat.line=text(chat,"",4,2,10,166); chat.line:SetJustifyH("CENTER"); chat.line:SetWordWrap(false)
        self.roomChats[i]=chat; chat:Hide()
        self.leftSigns[i]=FB.Animation.Image(self.arenaHUD,"arena-left-"..slot,pos.x-1,pos.y-2)
        self.leftSigns[i]:Hide()
    end
end
function U:RefreshRooms()
    if not self.roomRules then return end
    local m=FB.Net.match
    local room=m and m.arena and m
    local free=not m and not FB.Net.queue
    local limit=room and room.limit or FB.db.versusLimit
    local chains=room and room.chainReaction or not room and FB.db.versusChains
    self.roomLabel:SetText(room and ("Host · "..room.peer) or "Arena rooms")
    self.roomRules:SetText(FB.Series.Label(limit).."  ·  "..(chains and "Chain reactions on" or "Standard rules"))
    self.createRoom:SetEnabled(free); self.roomJoin:SetEnabled(free)
    self.roomStart:SetEnabled(room and (room.host and room.phase=="room" and #room.names>=3 or room.phase=="done" and not A.Complete(room)) or false)
    self.roomStart:SetText(room and room.phase=="done" and "Next round" or "Start round")
    self.roomLeave:SetEnabled(room and true or false)
    local keep,targets=FB.db.arenaContinue~=false,FB.db.arenaTargeting~=false
    if room and room.phase~="joining" then keep,targets=room.keepRoom,room.targeting end
    self.keepRoom:SetEnabled(free); self.targetRule:SetEnabled(free)
    self.keepRoom:SetText(keep and "On leave: continue" or "On leave: end room")
    self.targetRule:SetText(targets and "Targeting: on" or "Targeting: off")
    self.roomAnnounce:SetEnabled(room and room.host and room.phase=="room" or false)
    self.roomView:SetEnabled(room and room.played or false)
    self.roomNotice:SetText(room and (room.phase=="room" and (#room.names.."/5 players · "..table.concat(room.names,", ")) or FB.Net.notice)
        or "Join an open room below, or enter its host’s Player-Realm name.")
    local names={}
    if free then for name,listing in pairs(A.rooms) do if listing.count<5 then names[#names+1]=name end end end
    table.sort(names)
    local pages=math.max(1,math.ceil(#names/5)); self.roomPage=FB.Clamp(self.roomPage,1,pages)
    for i,row in ipairs(self.roomRows) do
        local name=names[(self.roomPage-1)*5+i]
        row.host=name; row:SetShown(name~=nil)
        if name then
            local listing=A.rooms[name]
            row:SetText(name.." · "..listing.count.."/5 · "..FB.Series.Label(listing.limit)..(listing.chains and " · Chain" or ""))
        end
    end
    self.roomPrev:SetShown(pages>1); self.roomNext:SetShown(pages>1)
    self.roomPrev:SetEnabled(self.roomPage>1); self.roomNext:SetEnabled(self.roomPage<pages)
end
function U:LayoutArena(m)
    FB.Animation.Frame(self.gameBackground,"arena-background",1)
    self:WindowControls(true)
    self.menuControl:ClearAllPoints(); self.menuControl:SetPoint("TOPLEFT",321,-9)
    FB.MatchChat.Position(true)
    self.arenaHUD:Show(); self.remoteBoard:Hide(); self.remoteLabel:Hide(); self.remotePenguin:Hide()
    self:PlaceBoard(self.board,304,70.4,1.6)
    self.result:ClearAllPoints(); self.result:SetPoint("TOPLEFT",238.4,-304)
    self.board.fbPenaltyX,self.board.fbPenaltyY,self.board.fbNextY=-21,420,412
    if not self.roomBadges then
        self.roomBadges=CreateFrame("Frame",nil,self.result); self.roomBadges:SetAllPoints()
        self.loserIcons={}
        for i=1,4 do self.loserIcons[i]=FB.Animation.Image(self.roomBadges,"net-lose-local",0,118.4,64,49.6) end
    end
    self.hud:ClearAllPoints(); self.hud:SetPoint("TOPLEFT",self.gameLayer,"TOPLEFT",352,-16)
    self.hud:SetWidth(320); self.hud:SetJustifyH("CENTER"); self.hud:Show()
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
function U:RenderArena(m,dt)
    local me=m.players[m.me]
    self.hud:SetText(me.label.." · "..me.wins)
    self.hud:Show(); self.footer:Hide(); self.pauseArt:Hide()
    self.trainingClock:Hide(); self.trainingTime:Hide(); self.nextButton:Hide()
    local ready=m.phase=="done"
    local winner=m.names[m.winner or 0]
    local winnerArt="net-win-local"
    local threats=0
    for i,v in ipairs(self.roomOpponents) do
        self.miniBoards[i]:SetShown(not v.left)
        self.leftSigns[i]:SetShown(v.left or false)
        if not v.left then self:RenderBoard(self.miniBoards[i],v.remote,true) end
        self.miniLabels[i]:SetText(v.label.." · "..v.wins)
        local chat=self.roomChats[i]
        chat:SetShown(not v.left and v.chatUntil~=nil and GetTime()<v.chatUntil)
        if chat:IsShown() then chat.line:SetText(v.chatText) end
        self.attackIcons[i]:SetShown(m.target==v.name)
        local threat=v.target==m.me and not v.lost and not FB.MatchChat.input:IsShown()
        self.threats[i]:SetShown(threat)
        if threat then
            self.threats[i]:ClearAllPoints(); self.threats[i]:SetPoint("TOPLEFT",185+24*threats,-448)
            threats=threats+1
        end
        self.miniPenguins[i]:SetShown(not v.left and FB.db.graphicsLevel==3)
        if not v.left and FB.db.graphicsLevel==3 then FB.Animation.Penguin(self.miniPenguins[i],v.remote,"rp"..i,FB.db.reducedMotion and 0 or dt) end
        if v.name==winner then winnerArt="arena-win-rp"..i end
    end
    if ready and not FB.db.reducedMotion then
        for _,v in pairs(m.players) do
            local game=v.name==m.me and FB.game or v.remote
            if not v.left and (not game.endOrder or game.endIndex<#game.endOrder or (game.status=="won" and FB.db.graphicsLevel>1 and #game.effects>0)) then ready=false end
        end
    end
    self.resultGame=FB.game
    self.result:SetShown(ready)
    if not ready then return end
    FB.Animation.Frame(self.resultArt,winner and winnerArt or "panel",1)
    self.resultArt:SetSize(526.4,254.4)
    self.winnerName:SetShown(winner~=nil); self.winnerName:SetText(winner or "")
    self.trainingResult:Hide(); self.resultBadge:Hide(); self.resultScores:Hide()
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
    self.retryButton:Show(); self.retryButton:SetEnabled(not m.wantNext)
    self.retryButton:SetText(A.Complete(m) and "Back to lobby" or m.wantNext and "Waiting for opponents…" or "Next round")
    self.leaveSeries:SetShown(not A.Complete(m))
end
