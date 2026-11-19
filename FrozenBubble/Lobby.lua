-- Online game selection uses the 640 x 480 smg_choose_game screen.
local _,FB=...
local U,N,A,C=FB.UI,FB.Net,FB.Arena,FB.Community
local function chatMode(mode) return mode=="chat" or mode=="roomChat" end
local locale=GetLocale and GetLocale()
local localeFont=(locale=="koKR" or locale=="zhCN" or locale=="zhTW") and STANDARD_TEXT_FONT
local font=localeFont or FB.media.."DejaVuSans.ttf"
local italic=localeFont or FB.media.."DejaVuSans-Oblique.ttf"
local function lettering(region,face)
    region:SetFont(face,40/3,"")
    region:SetShadowColor(0,0,0,1); region:SetShadowOffset(1,-1)
end
local function back(page)
    if page==U.panels.rooms then U:ShowLobby() else U:ShowMenu() end
end
local function selectRow(page,row)
    if page.selected==row.id then return end
    page.selected=row.id
    page.highlight:ClearAllPoints()
    page.highlight:SetPoint("TOPLEFT",row,"TOPLEFT",0,1)
end
local function stopEntry(page)
    page.entryMode=nil
    page.input:ClearFocus(); page.input:Hide(); page.prompt:Hide()
end
local function enter(page,mode)
    page.entryMode=mode
    local chat=chatMode(mode)
    if mode=="roomChat" and page.fbDraftRoom~=N.match then
        page.fbDraftRoom=N.match; page.roomSent={}; page.drafts.roomChat=nil
    end
    page.history=mode=="roomChat" and page.roomSent or page.sent
    local channel=mode=="chat" and page.fbActiveRoom
    page.prompt:SetText(mode=="roomChat" and "Room:" or channel and "Channel:" or chat and "Say:" or "Player-Realm:")
    page.input:ClearAllPoints()
    local left=channel and 140 or chat and 121 or 175
    page.input:SetPoint("TOPLEFT",left,-318)
    page.input:SetWidth(595-left)
    page.input:SetMaxBytes(chat and 160 or 100)
    page.input:SetText(page.drafts[mode] or ""); page.prompt:Show(); page.input:Show(); page.input:SetFocus()
    page.historyIndex=#page.history+1
end
local function addLog(frame,line)
    frame:AddMessage(line,1,1,1)
    frame:ScrollToBottom()
end
function U:AppendLobbyLine(entry)
    if not self.panels or not self.panels.rooms.log then return end
    addLog(self.panels.lobby.log,entry); addLog(self.panels.rooms.log,entry)
end
local function scroll(page,up)
    for _=1,4 do
        if up then page.log:ScrollUp() else page.log:ScrollDown() end
    end
end
local function activate(page,row,button)
    if not row or not row.available or InCombatLockdown() or U.inactive then return end
    if button=="RightButton" and row.id~="limit" then return end
    stopEntry(page); FB.Sound("menu_selected"); row.action(button)
end
function U:BuildLobby(text)
    for _,name in ipairs({"lobby","rooms"}) do
        local p=self.panels[name]
        p:ClearAllPoints(); p:SetScale(1.6); p:SetSize(640,480); p:SetPoint("TOPLEFT",self.frame,"TOPLEFT")
        p.map=FB.Animation.Image(p,"lobby-map",0,0,nil,nil,"BACKGROUND")
        p.highlight=FB.Animation.Image(p,"lobby-highlight",6,29,nil,nil,"BORDER")
        p.rows,p.byID,p.drafts,p.sent,p.page={}, {}, {}, {},1
        p.prompt=text(p,"",78,320,13,98); lettering(p.prompt,font); p.prompt:Hide()
        p.input=CreateFrame("EditBox",nil,p)
        p.input:SetAutoFocus(false); p.input:SetHeight(18); p.input:SetFont(font,40/3,""); p.input:Hide()
        p.input:SetScript("OnTextChanged",function(box)
            if p.entryMode then p.drafts[p.entryMode]=box:GetText() end
        end)
        p.input:SetScript("OnEscapePressed",function() stopEntry(p) end)
        p.input:SetScript("OnTabPressed",function(box)
            if not chatMode(p.entryMode) then return end
            local old=box:GetText()
            local cursor=box:GetCursorPosition()
            local completed=FB.LobbyCommands.Complete(old:sub(1,cursor),p.entryMode=="roomChat" and p.fbDraftRoom or nil)
            if #completed+#old-cursor<=160 then box:SetText(completed..old:sub(cursor+1)); box:SetCursorPosition(#completed) end
        end)
        p.input:SetScript("OnArrowPressed",function(box,key)
            if not chatMode(p.entryMode) or key~="UP" and key~="DOWN" then return end
            if p.historyIndex==#p.history+1 then p.unsent=box:GetText() end
            p.historyIndex=FB.Clamp(p.historyIndex+(key=="UP" and -1 or 1),1,#p.history+1)
            box:SetText(p.history[p.historyIndex] or p.unsent or "")
            box:SetCursorPosition(#box:GetText())
        end)
        p.input:SetScript("OnEnterPressed",function(box)
            if InCombatLockdown() or self.inactive then return end
            local mode,value=p.entryMode,box:GetText()
            if chatMode(mode) then
                if mode=="roomChat" and (not p.fbDraftRoom or p.fbDraftRoom~=N.match) then stopEntry(p); return end
                local ok,err=FB.LobbyCommands.Submit(value,mode=="roomChat" and p.fbDraftRoom or nil)
                if not ok then C.Log(err); return end
                p.history[#p.history+1]=value; if #p.history>32 then table.remove(p.history,1) end
                p.historyIndex=#p.history+1; p.unsent=""; box:SetText(""); return
            elseif mode=="challenge" then
                if not N.Challenge(value) then return end
            elseif mode=="join" then
                A.Join(value)
                if not N.match then C.Log("Enter the host's Player-Realm name."); return end
            else return end
            p.drafts[mode]=nil; stopEntry(p)
        end)
        p.players=text(p,"",78,336,13,548); lettering(p.players,font); p.players:SetWordWrap(false)
        local log=CreateFrame("ScrollingMessageFrame",nil,p); p.log=log
        log:SetSize(620,80); log:SetPoint("BOTTOMLEFT",10,29); lettering(log,font)
        log:SetJustifyH("LEFT"); log:SetJustifyV("BOTTOM"); log:SetFading(false); log:SetMaxLines(100)
        log:EnableMouseWheel(true); log:SetScript("OnMouseWheel",function(_,delta) scroll(p,delta>0) end)
        for _,entry in ipairs(C.log) do addLog(log,entry) end
        p:SetPropagateKeyboardInput(true)
        p:SetScript("OnHide",function() stopEntry(p) end)
        p:SetScript("OnKeyUp",function(_,key) self.keys[key]=nil end)
        p:SetScript("OnKeyDown",function(panel,key)
            if InCombatLockdown() then return end
            local active=not self.inactive and self:HasFocus() and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
            local current=p.byID[p.selected]
            local rule=current and current.available and (current.id=="limit" or current.id=="chains" or current.id=="continue" or current.id=="targeting")
            local adjust=rule and (key=="LEFT" or key=="RIGHT")
            local digit=rule and current.id=="limit" and (key:match("^%d$") or key:match("^NUMPAD(%d)$"))
            local used=active and (adjust or digit or key=="UP" or key=="DOWN" or key=="ENTER" or key=="NUMPADENTER" or key=="ESCAPE"
                or key=="PAGEUP" or key=="PAGEDOWN")
            panel:SetPropagateKeyboardInput(not used)
            if not used then return end
            if key=="UP" or key=="DOWN" then
                local step=key=="UP" and -1 or 1
                local i=current and current.index+step or 1
                while i>=1 and i<=p.count do
                    if p.rows[i].available then selectRow(p,p.rows[i]); FB.Sound("menu_change"); break end
                    i=i+step
                end
            elseif key=="PAGEUP" or key=="PAGEDOWN" then scroll(p,key=="PAGEUP")
            elseif not self.keys[key] then
                self.keys[key]=true
                if key=="ESCAPE" then back(p)
                elseif digit then A.SetRule("versusLimit",tonumber(digit))
                elseif adjust then activate(p,current,current.id=="limit" and key=="LEFT" and "RightButton" or "LeftButton")
                else activate(p,current) end
            end
        end)
    end
end

local function add(page,id,label,action,enabled)
    local index=page.count+1
    local row=page.rows[index]
    if not row then
        row=CreateFrame("Button",nil,page); page.rows[index]=row
        row.index=index; row:SetSize(627,16); row:SetPoint("TOPLEFT",6,-(30+16*(index-1)))
        local caption=row:CreateFontString(nil,"ARTWORK"); row.caption=caption
        caption:SetPoint("TOPLEFT",72,0); caption:SetWidth(532)
        caption:SetJustifyH("LEFT"); caption:SetWordWrap(false)
        row:RegisterForClicks("LeftButtonUp","RightButtonUp")
        row:SetScript("OnEnter",function()
            if row.available and not InCombatLockdown() and page.selected~=row.id then
                selectRow(page,row); FB.Sound("menu_change")
            end
        end)
        row:SetScript("OnMouseDown",function() row.fbPressedID=row.id end)
        row:SetScript("OnClick",function(_,button)
            if not row.fbPressedID or row.fbPressedID==row.id then activate(page,row,button) end
            row.fbPressedID=nil
        end)
    end
    page.count=index; page.byID[id]=row
    row.id,row.action,row.available=id,action,enabled~=false
    row.caption:SetText(label)
    local face=row.available and font or italic
    if row.fbFace~=face then lettering(row.caption,face); row.fbFace=face end
    row:SetEnabled(row.available); row:Show()
end
local function listPlayers(page,rooms)
    local names={}
    for name,item in pairs(rooms and A.rooms or N.peers) do
        local hidden=rooms and A.hiddenRoom and A.hiddenRoom.host==name and A.hiddenRoom.id==item.id
        if rooms and item.count<5 and not hidden or not rooms and item.queued then names[#names+1]=name end
    end
    table.sort(names)
    local pages=math.max(1,math.ceil(#names/5))
    page.page=FB.Clamp(page.page,1,pages)
    local first=(page.page-1)*5+1
    for i=first,math.min(first+4,#names) do
        local name=names[i]
        if rooms then
            local room=A.rooms[name]
            add(page,name..":"..room.id,"Join game: "..name.."  ·  "..room.count.."/5  ·  "..FB.Series.Label(room.limit)..(room.chains and "  ·  Chain" or ""),
                function()
                    local current=A.rooms[name]
                    if current and current.id==room.id and current.count<5 then A.Join(name) else U:RefreshLobby() end
                end)
        else
            local peer=N.peers[name]
            add(page,name..":"..FB.Series.Code(peer.chainReaction,peer.limit),
                "Challenge: "..name.."  ·  "..FB.Series.Label(peer.limit)..(peer.chainReaction and "  ·  Chain" or ""),
                function()
                    local current=N.peers[name]
                    if current and current.queued and current.limit==peer.limit and current.chainReaction==peer.chainReaction then
                        N.Challenge(name,false,peer)
                    else U:RefreshLobby() end
                end)
        end
    end
    if pages>1 then
        add(page,"previous","Previous listings",function() page.page=page.page-1; U:RefreshLobby() end,page.page>1)
        add(page,"more","More listings",function() page.page=page.page+1; U:RefreshLobby() end,page.page<pages)
    end
    return #names
end
local channelState={offline="Not joined",joining="Joining…",checking="Checking addon delivery…",ready="Connected",
    manual="Manual channel announcements",unavailable="Unavailable"}
function U:RefreshLobby()
    if not self.panels or self.screen~="rooms" and self.screen~="lobby" then return end
    local rooms=self.screen=="rooms"
    local p=self.panels[self.screen]
    local m=N.match; local room=m and m.arena and m
    local free=not m and not N.queue
    local selected=p.selected
    p.byID={}; p.count=0
    local activeRoom=room and room.phase=="room" and room or nil
    local supported=A.CanChat(activeRoom)
    if p.fbActiveRoom~=activeRoom then
        if chatMode(p.entryMode) then stopEntry(p) end
        p.fbActiveRoom=activeRoom
        selected=supported and "roomChat" or "chat"
    elseif p.entryMode=="roomChat" and not supported then stopEntry(p) end
    if activeRoom then
        add(p,"roomChat",supported and "Room chat" or "Room chat requires alpha.38 for all players",function() enter(p,"roomChat") end,supported)
        add(p,"chat","Public channel chat",function() enter(p,"chat") end)
    else add(p,"chat","Chat",function() enter(p,"chat") end) end
    if C.state~="ready" then
        add(p,"channel",C.state=="manual" and "Retry addon delivery" or ("Join "..C.name), C.Join)
    end
    if rooms then
        if free then
            add(p,"host","Create new game",A.Host)
            add(p,"join","Join by host name…",function() enter(p,"join") end)
        elseif room then
            if room.host and room.phase=="room" then
                add(p,"start","Start game",A.Start,#room.names>=3)
                add(p,"announce","Announce room",A.Announce)
            elseif room.phase=="done" and not A.Complete(room) then add(p,"start","Next round",A.Start) end
            if room.played then add(p,"view","View round",function() self:ShowGame() end) end
            add(p,"leave","Leave room",function() A.Leave() end)
        end
    else
        if not m then
            add(p,"queue",N.queue and "Stop matchmaking" or "Find match",function() N.SetQueue(not N.queue) end)
            if C.state=="manual" then
                add(p,"announce","Announce queue",function()
                    if not N.queue then N.SetQueue(true) end
                    if N.queue then C.Manual("QUEUE",N.QueueCode()) end
                end)
            end
            add(p,"challenge","Challenge by player name…",function() enter(p,"challenge") end)
        else
            if m.phase=="invite" then add(p,"accept","Accept challenge from "..m.peer,N.Accept) end
            if m.played or m.phase=="playing" or m.phase=="done" then add(p,"view","View match",function() self:ShowGame() end) end
            add(p,"leave","Leave / forfeit",N.Leave)
        end
        add(p,"rooms","Arena rooms (3–5 players)",function() self:Panel("rooms") end)
    end
    local editable=free or room and room.host and room.phase=="room" or false
    local chains=m and m.chainReaction or not m and FB.db.versusChains
    add(p,"chains","Chain-reaction: "..(chains and "enabled" or "disabled"),function()
        A.SetRule("versusChains",not chains)
    end,editable)
    add(p,"limit","Victories limit: "..FB.Series.Label(m and m.limit or FB.db.versusLimit),function(button)
        A.SetRule("versusLimit",FB.Series.Cycle(m and m.limit or FB.db.versusLimit,button=="RightButton" and -1 or 1))
    end,editable)
    if rooms then
        local keep,targets=FB.db.arenaContinue~=false,FB.db.arenaTargeting~=false
        if room and room.phase~="joining" then keep,targets=room.keepRoom,room.targeting end
        add(p,"continue","Continue when players leave: "..(keep and "enabled" or "disabled"),function()
            A.SetRule("arenaContinue",not keep)
        end,editable)
        add(p,"targeting","Single player targeting: "..(targets and "enabled" or "disabled"),function()
            A.SetRule("arenaTargeting",not targets)
        end,editable)
    end
    local count=0
    if free then count=listPlayers(p,rooms) end
    add(p,"back",rooms and "Back to multiplayer" or "Main menu",function() back(p) end)
    for i=p.count+1,#p.rows do p.rows[i]:Hide() end
    local nextRow=p.byID[selected]
    p.selected=nil; selectRow(p,nextRow and nextRow.available and nextRow or p.byID.chat)
    if room and #room.names>0 then
        local names={}
        for i,name in ipairs(room.names) do names[i]=room.players[name].label end
        p.players:SetText("Players in game: "..table.concat(names,", "))
    else
        local status=room and ("Joining "..room.peer) or m and ("Opponent: "..m.peer) or N.queue and "Searching for a match"
            or ((rooms and "Open games: " or "Queued players: ")..count)
        p.players:SetText(status.."   ·   "..C.name.."   ·   "..(channelState[C.state] or C.state))
    end
end
function U:ShowLobby() self.frame:Show(); self:Panel("lobby") end
