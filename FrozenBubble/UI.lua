local _, FB = ...
local U={keys={},screen="help",editorColor=1,alpha=1}; FB.UI=U
-- Explicit frame levels: board < HUD < menu < panels < window controls.
U.layers={base=100,game=101,board=102,hud=110,menu=120,panel=130,chrome=150}
local E=FB.Engine
local white={0.88,0.95,1}; local muted={0.58,0.72,0.82}
local function text(parent,label,x,y,size,width,color)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont("Fonts\\ARIALN.TTF",size or 13)
    f:SetPoint("TOPLEFT",x,-y); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP")
    f:SetWidth(width or 300); f:SetTextColor(unpack(color or white)); f:SetText(label)
    return f
end
local function fill(parent,r,g,b,a)
    local t=parent:CreateTexture(nil,"BACKGROUND"); t:SetAllPoints(); t:SetColorTexture(r,g,b,a or 1); return t
end
local function button(parent,label,x,y,width,fn)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(width or 150,28); b:SetPoint("TOPLEFT",x,-y)
    local art=FB.Animation.Image(b,"ui-button",0,0,width or 150,28,"BACKGROUND")
    art:SetVertexColor(0.85,0.88,0.94)
    local caption=b:CreateFontString(nil,"OVERLAY")
    caption:SetFont("Fonts\\ARIALN.TTF",14,"OUTLINE"); caption:SetPoint("CENTER",0,0)
    caption:SetWidth((width or 150)-10); caption:SetTextColor(1,0.94,0.73)
    b:SetFontString(caption); b:SetText(label)
    b:SetScript("OnEnter",function()
        if b:IsEnabled() then art:SetVertexColor(1,1,1); caption:SetTextColor(1,1,1); FB.Sound("menu_change") end
    end)
    b:SetScript("OnLeave",function() art:SetVertexColor(0.85,0.88,0.94); caption:SetTextColor(1,0.94,0.73) end)
    b:SetScript("OnMouseDown",function() art:SetVertexColor(0.7,0.75,0.85) end)
    b:SetScript("OnMouseUp",function() art:SetVertexColor(1,1,1) end)
    b:SetScript("OnDisable",function() art:SetVertexColor(0.45,0.45,0.45); caption:SetTextColor(0.55,0.55,0.55) end)
    b:SetScript("OnEnable",function() art:SetVertexColor(0.85,0.88,0.94); caption:SetTextColor(1,0.94,0.73) end)
    b:SetScript("OnClick",function(...) if not InCombatLockdown() then fn(...) end end)
    return b
end
local function input(parent,x,y,width,value)
    local b=CreateFrame("EditBox",nil,parent)
    b:SetSize(width,24); b:SetPoint("TOPLEFT",x,-y); b:SetAutoFocus(false); b:SetMaxLetters(160)
    FB.Animation.Image(b,"ui-button",0,0,width,24,"BACKGROUND")
    b:SetFont("Fonts\\ARIALN.TTF",14,"OUTLINE"); b:SetTextColor(1,1,1); b:SetTextInsets(8,8,2,2)
    b:SetText(value or ""); b:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    b:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    return b
end
local function bubble(parent)
    local t=parent:CreateTexture(nil,"ARTWORK"); t:SetSize(32,32); return t
end
local function place(t,parent,x,y,color,size,alpha)
    t:ClearAllPoints(); t:SetPoint("CENTER",parent,"TOPLEFT",x,-y)
    t:SetSize(size or 32,size or 32); t:SetTexture(FB.media.."bubble"..color..".tga"); t.fbAsset=nil
    t:SetTexCoord(0,1,0,1); t:SetAlpha(alpha or 1); t:Show()
end
local function makeBoard(parent,x,y)
    local b=CreateFrame("Frame",nil,parent)
    b:SetSize(256,400); b:SetPoint("TOPLEFT",x,-y)
    -- The original background already contains the playfield. Do not cover it.
    b.bubbles={}; b.fx={}; b.dots={}
    for key=1,104 do b.bubbles[key]=bubble(b) end
    for i=1,100 do b.fx[i]=bubble(b); b.fx[i]:Hide() end
    b.limit=b:CreateTexture(nil,"OVERLAY"); b.limit:SetColorTexture(1,0.3,0.4,0)
    b.limit:SetSize(256,1); b.limit:SetPoint("TOPLEFT",0,-E.LIMIT)
    b.roof=b:CreateTexture(nil,"OVERLAY"); b.roof:SetColorTexture(0.5,0.85,1,0); b.roof:SetSize(256,3)
    b.compressor=FB.Animation.Image(b,"compressor",2,0,252,51,"OVERLAY"); b.compressor:Hide()
    b.projectile=bubble(b); b.current=bubble(b); b.next=bubble(b)
    b.shooter=b:CreateTexture(nil,"ARTWORK",nil,1); b.shooter:SetTexture(FB.media.."shooter.tga"); b.shooter:SetSize(128,128)
    b.shooter:SetPoint("CENTER",b,"TOPLEFT",128,-E.LAUNCH_Y)
    b.stick=FB.Animation.Image(b,"stick",0,0,32,32,"OVERLAY"); b.stick:Hide()
    for i=1,10 do
        local dot=b:CreateTexture(nil,"OVERLAY"); dot:SetColorTexture(0.8,0.94,1,0.55); dot:SetSize(3,3); b.dots[i]=dot
    end
    return b
end
function U:Build()
    local A=FB.Animation
    local f=CreateFrame("Frame","FrozenBubbleWindow",UIParent,"BackdropTemplate")
    self.frame=f
    f:SetSize(1024,768); f:SetPoint("CENTER"); f:SetFrameStrata("HIGH"); f:SetFrameLevel(self.layers.base); f:SetClampedToScreen(true)
    self:Resize()
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
    f:SetBackdropColor(0.1,0.06,0.12,1)
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
    f:SetScript("OnHide",function()
        self.keys={}; self.board:EnableKeyboard(false)
        if FB.game and FB.game.mode~="versus" then FB.game.paused=true end
        FB.StopGameMusic()
    end)
    f:SetScript("OnShow",function()
        self.focusGrace=GetTime()+1.5; self.alpha=1; f:SetAlpha(1); self:Resize(); FB.Music()
    end)
    UISpecialFrames[#UISpecialFrames+1]="FrozenBubbleWindow"
    self.gameLayer=CreateFrame("Frame",nil,f); self.gameLayer:SetAllPoints()
    self.gameLayer:SetFrameLevel(self.layers.game)
    self.gameBackground=A.Image(self.gameLayer,"solo-background",0,0,1024,768,"BACKGROUND")
    self.board=makeBoard(self.gameLayer,0,0)
    self.board:SetFrameLevel(self.layers.board)
    self.board:EnableMouse(true); self.board:EnableMouseWheel(true)
    self.board:SetScript("OnEnter",function(b) if not InCombatLockdown() then b:EnableKeyboard(true); b:SetPropagateKeyboardInput(true) end end)
    self.board:SetScript("OnLeave",function(b) b:EnableKeyboard(false); self.keys={} end)
    self.board:SetScript("OnMouseDown",function(_,which)
        if InCombatLockdown() then return end
        if self.editing then self:Paint(which) elseif which=="LeftButton" then FB.Fire() end
    end)
    self.board:SetScript("OnMouseWheel",function(_,delta)
        if self.editing then self.editorColor=(self.editorColor-1+delta)%8+1
        elseif FB.game then FB.game.angle=FB.Clamp(FB.game.angle+delta*0.045,-E.MAX_ANGLE,E.MAX_ANGLE) end
    end)
    self.board:SetScript("OnKeyDown",function(b,key)
        local used=key=="LEFT" or key=="RIGHT" or key=="A" or key=="D" or key=="SPACE" or key=="UP" or key=="P"
        b:SetPropagateKeyboardInput(not used)
        if InCombatLockdown() then b:EnableKeyboard(false); return end
        self.keys[key]=true
        if key=="SPACE" or key=="UP" then FB.Fire() elseif key=="P" then FB.TogglePause() end
    end)
    self.board:SetScript("OnKeyUp",function(_,key) self.keys[key]=nil end)
    self.overlay=CreateFrame("Frame",nil,self.board); self.overlay:SetAllPoints(); self.overlay:EnableMouse(false)
    self.overlay:SetFrameLevel(self.board:GetFrameLevel()+3)
    self.pauseArt=A.Image(self.overlay,"pause",33,130,190,143); self.pauseArt:Hide()
    self.overlayText=text(self.overlay,"",14,145,20,228)
    self.overlaySub=text(self.overlay,"",14,185,12,228)
    self.result=CreateFrame("Frame",nil,self.gameLayer); self.result:SetSize(526.4,320)
    self.result:SetPoint("TOPLEFT",238.4,-304); self.result:SetFrameLevel(self.layers.panel)
    self.resultArt=A.Image(self.result,"win-panel",0,0,526.4,254.4)
    self.resultDetail=text(self.result,"",0,250,18,526.4,{0.2,0.1,0.2}); self.resultDetail:SetJustifyH("CENTER")
    self.nextButton=button(self.result,"Next level",116,284,294,function() FB.NextLevel() end); self.nextButton:Hide()
    self.retryButton=button(self.result,"Try again",116,284,294,function()
        if FB.game and FB.game.mode=="campaign" then FB.StartCampaign(FB.level) else self:ShowMenu() end
    end)
    self.result:Hide()
    self.hud=text(self.gameLayer,"",30,113,23,245,{1,0.93,0.58})
    self.footer=text(self.gameLayer,"",20,235,14,225,{0.16,0.1,0.22})
    self.penguin=A.Image(self.gameLayer,"anime-shooter-p1",646.4,672,128,96)
    self.panels={}
    for _,name in ipairs({"help","lobby","scores","market","editor","opponent","solo","settings"}) do
        local p=CreateFrame("Frame",nil,f); p:SetSize(370,470); p:SetPoint("TOPLEFT",555,-146)
        p:SetFrameLevel(self.layers.panel); p:EnableMouse(true); p:Hide(); self.panels[name]=p
        if name~="opponent" then
            local bg=A.Image(p,"panel",-20,-24,410,514,"BACKGROUND")
            bg:SetVertexColor(0.6,0.65,0.75)
            button(p,"Back",266,-20,84,function() self:ShowMenu() end)
        end
    end
    self:BuildHelp(); self:BuildLobby(); self:BuildScores(); self:BuildMarket(); self:BuildEditor()
    self:BuildSolo(); self:BuildSettings()
    self.remoteBoard=makeBoard(self.gameLayer,0,0); self.remoteBoard:Hide()
    self.remoteBoard:SetFrameLevel(self.layers.board)
    self.remoteLabel=text(self.gameLayer,"",540,20,16,430)
    -- Original 640x480 menu, including its exact entry positions and source textures.
    local menu=CreateFrame("Frame",nil,f); self.menu=menu; menu:SetSize(640,480); menu:SetScale(1.6); menu:SetPoint("TOPLEFT",0,0)
    menu:SetFrameLevel(self.layers.menu)
    A.Image(menu,"menu-background",0,0,640,480,"BACKGROUND")
    self.menuLogo=A.Image(menu,"menu-logo",400,15)
    A.Image(menu,"menu-stamp",490,142)
    self.menuHover={}; self.menuButtons={}
    local entries={
        {"1pgame","1pgame",function() self:Panel("solo") end},
        {"2pgame","p1p2",function() self:ShowLobby() end},
        {"langame","langame",function() self:ShowLobby() end},
        {"netgame","netgame",function() FB.Community.Join(); self:ShowLobby() end},
        {"editor","editor",function() self:StartEditor() end},
        {"graphics","gfx-l1",function() self:Panel("settings") end},
        {"keys","keys",function() self:Panel("help") end},
        {"highscores","highscore",function() self:ShowScores() end},
    }
    for i,entry in ipairs(entries) do
        local key,animation,action=entry[1],entry[2],entry[3]
        local b=CreateFrame("Button",nil,menu); b:SetSize(202,46); b:SetPoint("TOPLEFT",89,-(14+(i-1)*56))
        local label=A.Image(b,"menu-"..key.."-off",0,0)
        local cursor=A.Image(menu,"hover-"..animation,248,22+(i-1)*56)
        self.menuHover[i]={texture=cursor,name="hover-"..animation}
        b:SetScript("OnEnter",function() self.menuSelection=i; FB.Sound("menu_change"); A.Frame(label,"menu-"..key.."-over",1) end)
        b:SetScript("OnLeave",function() A.Frame(label,"menu-"..key.."-off",1) end)
        b:SetScript("OnClick",function() FB.Sound("menu_selected"); action() end)
        self.menuButtons[i]=b
    end
    self.blinkEyes={
        A.Image(menu,"blink-green-left",411,385),A.Image(menu,"blink-green-right",434,378),
        A.Image(menu,"blink-purple-left",522,356),A.Image(menu,"blink-purple-right",535,356),
    }
    self.menuSelection=1
    button(menu,"Level marketplace",335,246,172,function() self:ShowMarket() end)
    button(menu,"Resume game",335,280,172,function() self:ShowGame() end)
    text(menu,"WoW Forever",500,244,10,100,{1,1,1})
    local versionCover=menu:CreateTexture(nil,"OVERLAY"); versionCover:SetColorTexture(0.47,0.035,0.27,1)
    versionCover:SetSize(38,154); versionCover:SetPoint("BOTTOMRIGHT",-2,0)
    -- A compact in-game menu/toolbar, like the Peggle addon, instead of an app sidebar.
    self.toolbar=CreateFrame("Frame",nil,self.gameLayer); self.toolbar:SetAllPoints(); self.toolbar:SetFrameLevel(self.layers.hud)
    button(self.toolbar,"Menu",16,728,90,function() self:ShowMenu() end)
    button(self.toolbar,"Pause",115,728,90,function() FB.TogglePause() end)
    self.editButton=button(self.toolbar,"Edit level",16,687,110,function() self:StartEditor(self.editID) end)
    self.editButton:Hide()
    local chrome=CreateFrame("Frame",nil,f); chrome:SetAllPoints(); chrome:SetFrameLevel(self.layers.chrome)
    button(chrome,"X",976,4,30,function() f:Hide() end)
    button(chrome,"−",900,4,28,function() FB.db.windowSize=math.max(0.55,(FB.db.windowSize or 1)-0.1); self:Resize() end)
    button(chrome,"+",932,4,28,function() FB.db.windowSize=math.min(1,(FB.db.windowSize or 1)+0.1); self:Resize() end)
    self:Options(); self:ShowMenu(); f:Hide()
end
function U:OwnsFocus(frame)
    for _=1,30 do
        if not frame then return false end
        if frame.IsForbidden and frame:IsForbidden() then return false end
        if frame==self.frame then return true end
        if not frame.GetParent then return false end
        frame=frame:GetParent()
    end
    return false
end
function U:HasFocus()
    -- PLAYER_FOCUS_CHANGED refers to a unit target, not UI or desktop focus.
    if GetCurrentKeyBoardFocus and self:OwnsFocus(GetCurrentKeyBoardFocus()) then return true end
    if GetMouseFoci then
        for _,frame in ipairs(GetMouseFoci()) do if self:OwnsFocus(frame) then return true end end
        return false
    end
    if GetMouseFocus then return self:OwnsFocus(GetMouseFocus()) end
    return self.frame:IsMouseOver()
end
function U:SetCombatInput(blocked)
    if self.combatInput==blocked then return end
    self.combatInput=blocked
    if blocked then
        self.mouseRestore={}
        local function disable(frame)
            if frame.IsMouseEnabled and frame:IsMouseEnabled() then
                self.mouseRestore[#self.mouseRestore+1]=frame; frame:EnableMouse(false)
            end
            if frame.ClearFocus then frame:ClearFocus() end
            if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do disable(child) end end
        end
        disable(self.frame)
        self.keys={}; self.board:EnableKeyboard(false)
    else
        for _,frame in ipairs(self.mouseRestore or {}) do frame:EnableMouse(true) end
        self.mouseRestore=nil
    end
end
function U:UpdateVisibility(dt)
    if not self.frame or not self.frame:IsShown() then return end
    local combat=InCombatLockdown()
    local focused=not combat and (GetTime()<(self.focusGrace or 0) or self:HasFocus())
    if focused then self.outsideSince=nil
    elseif not self.outsideSince then self.outsideSince=GetTime() end
    local inactive=combat or (not focused and GetTime()-(self.outsideSince or GetTime())>=0.6)
    self:SetCombatInput(combat)
    local target=combat and 0 or inactive and 0.15 or 1
    local step=math.min(1,dt/0.18)
    self.alpha=self.alpha+(target-self.alpha)*step
    if math.abs(self.alpha-target)<0.005 then self.alpha=target end
    self.frame:SetAlpha(self.alpha)
    self.frame:SetFrameStrata(inactive and "LOW" or "HIGH")
    if inactive~=self.inactive then
        self.inactive=inactive
        self.keys={}; self.board:EnableKeyboard(false)
        if FB.game and FB.game.mode~="versus" then
            if inactive and not FB.game.paused then FB.game.paused=true; self.focusPausedGame=FB.game
            elseif not inactive and self.focusPausedGame==FB.game and not combat then FB.game.paused=false; self.focusPausedGame=nil end
        end
        if inactive then FB.StopGameMusic() else FB.Music() end
        if not inactive and self.board:IsMouseOver() and self.gameLayer:IsShown() then
            self.board:EnableKeyboard(true); self.board:SetPropagateKeyboardInput(true)
        end
        FB.Debug.Log("FOCUS",combat and "combat" or inactive and "lost" or "gained")
    end
end
function U:Resize()
    local scale=math.min((UIParent:GetWidth()-30)/1024,(UIParent:GetHeight()-30)/768)*(FB.db.windowSize or 1)
    self.frame:SetScale(scale)
end
function U:PlaceBoard(board,x,y,scale)
    board:SetScale(scale); board:ClearAllPoints(); board:SetPoint("TOPLEFT",self.gameLayer,"TOPLEFT",x/scale,-y/scale)
end
function U:ShowMenu()
    self.focusPausedGame=nil
    self.keys={}; self.board:EnableKeyboard(false)
    if FB.game and FB.game.mode~="versus" then FB.game.paused=true end
    for _,panel in pairs(self.panels) do panel:Hide() end
    self.menu:Show(); self.gameLayer:Hide(); self.screen="menu"; FB.Music()
end
function U:ShowGame()
    if not FB.game then self:Panel("solo"); return end
    if FB.game.mode~="versus" and not InCombatLockdown() then FB.game.paused=false end
    self:Panel(FB.game.mode=="versus" and "opponent" or "game"); FB.Music()
end
function U:BuildSolo()
    local p=self.panels.solo
    text(p,"1 PLAYER GAME",0,0,24,350)
    button(p,"Play all 100 levels",0,58,340,function() FB.StartCampaign(1) end)
    button(p,"Continue campaign",0,102,340,function() FB.ContinueCampaign() end)
    text(p,"Start at an unlocked level (practice)",0,160,13,350)
    self.level=input(p,6,195,80,"1"); self.level:SetNumeric(true); self.level:SetMaxLetters(3)
    button(p,"Play level",102,193,240,function() FB.StartCampaign(tonumber(self.level:GetText()) or 1) end)
    button(p,"Endless game",0,254,340,function() FB.StartSolo("endless") end)
    text(p,"Match three bubbles. Drop the clusters hanging underneath. Clear the board before the ice comes down.",0,318,16,350)
end
function U:BuildSettings()
    local p=self.panels.settings
    text(p,"SOUND & DISPLAY",0,0,24,350)
    self.sound=button(p,"Sound: on",0,60,160,function() FB.db.sound=not FB.db.sound; self:Options() end)
    self.music=button(p,"Music: on",178,60,160,function() FB.db.music=not FB.db.music; FB.Music(); self:Options() end)
    text(p,"Game music volume",0,117,15,350)
    self.musicValue=text(p,"",0,155,16,110)
    button(p,"Quieter",110,150,105,function() FB.db.musicVolume=math.max(0.1,(FB.db.musicVolume or 0.8)-0.1); FB.Music(); self:Options() end)
    button(p,"Louder",230,150,105,function() FB.db.musicVolume=math.min(1,(FB.db.musicVolume or 0.8)+0.1); FB.Music(); self:Options() end)
    text(p,"The music slider is applied while this game is open. Your previous WoW music volume is restored when you close it.",0,210,13,350)
    button(p,"Fit game to screen",0,282,338,function() FB.db.windowSize=1; self:Resize() end)
    button(p,"Animation: full / reduced",0,330,338,function() FB.db.reducedMotion=not FB.db.reducedMotion end)
    text(p,"Use + / − in the title bar to change window size. Drag the art border to move the game.",0,385,13,350)
end
function U:Options()
    self.sound:SetText(FB.db.sound and "Sound: on" or "Sound: off")
    self.music:SetText(FB.db.music and "Music: on" or "Music: off")
    if self.musicValue then self.musicValue:SetText(math.floor((FB.db.musicVolume or 0.8)*100+0.5).."%") end
end
function U:Panel(name)
    self.screen=name
    for key,panel in pairs(self.panels) do panel:SetShown(key==name) end
    local gameplay=name=="game" or name=="opponent" or name=="editor"
    self.menu:SetShown(not gameplay); self.gameLayer:SetShown(gameplay)
    self.remoteBoard:SetShown(name=="opponent")
    self.remoteLabel:SetShown(name=="opponent")
    self.panels.opponent:Hide()
    if name=="opponent" then
        FB.Animation.Frame(self.gameBackground,"versus-background",1)
        self:PlaceBoard(self.board,566.4,64,1.6); self:PlaceBoard(self.remoteBoard,48,64,1.6)
        self.hud:ClearAllPoints(); self.hud:SetPoint("TOPLEFT",self.gameLayer,"TOPLEFT",36,-17); self.hud:SetFont("Fonts\\FRIZQT__.TTF",14)
        self.penguin:Hide()
    else
        FB.Animation.Frame(self.gameBackground,"solo-background",1)
        self:PlaceBoard(self.board,name=="editor" and 60 or 304,70.4,1.6)
        self.hud:ClearAllPoints(); self.hud:SetPoint("TOPLEFT",self.gameLayer,"TOPLEFT",15,-150)
        self.hud:SetFont("Fonts\\ARIALN.TTF",22,"OUTLINE"); self.hud:SetJustifyH("CENTER"); self.hud:SetWidth(230)
        self.hud:SetShown(name~="editor"); self.penguin:SetShown(name~="editor")
    end
    if name=="opponent" then self.hud:Show() end
    self.editButton:SetShown(FB.game and FB.game.mode=="custom" and name=="game" or false)
    if not gameplay and FB.game and FB.game.mode~="versus" then FB.game.paused=true end
end
function U:BuildHelp()
    local p=self.panels.help
    text(p,"A LITTLE ICE BETWEEN ADVENTURES",0,0,14,360)
    FB.Animation.Image(p,"menu-logo",75,45,190,119)
    text(p,"Aim with your mouse and click to shoot. While the pointer is over the board, use Left / Right (or A / D) and Space / Up instead. P pauses solo play.",0,211,13,350)
    text(p,"Match 3 or more of the same color. Bubbles disconnected from the ceiling fall. The ceiling drops every 9 solo shots; after 10.5 seconds, the launcher fires automatically.",0,287,13,350)
    text(p,"In versus, falling bubbles attack your opponent. Clear your board or outlast them. You cannot pause a match; hiding the window keeps it running.",0,363,13,350,muted)
end
function U:BuildLobby()
    local p=self.panels.lobby
    text(p,"MULTIPLAYER",0,0,16,350)
    button(p,"Join community channel",0,32,205,function() FB.Community.Join() end)
    self.channelStatus=text(p,"",0,66,12,350,muted)
    button(p,"Find match / stop",0,115,165,function() FB.Net.SetQueue(not FB.Net.queue) end)
    button(p,"Announce queue",177,115,165,function()
        if not FB.Net.queue then FB.Net.SetQueue(true) end
        if FB.Net.queue then FB.Community.Manual("QUEUE",1) end
    end)
    self.target=input(p,6,158,206,"")
    button(p,"Challenge",223,156,120,function() FB.Net.Challenge(self.target:GetText()) end)
    self.lobbyNotice=text(p,"",0,199,13,350)
    self.accept=button(p,"Accept",0,260,105,function() FB.Net.Accept() end)
    button(p,"Leave / forfeit",118,260,130,function() FB.Net.Leave() end)
    button(p,"View match",255,260,90,function() self:Panel("opponent") end)
    self.peerText=text(p,"",0,307,12,350,muted)
end
function U:ShowLobby() self.frame:Show(); self:Panel("lobby"); self:RefreshLobby() end
function U:RefreshLobby()
    if not self.lobbyNotice then return end
    self.lobbyNotice:SetText(FB.Net.notice or "Queue to match another player, or enter Player-Realm to challenge a friend.")
    self.accept:SetEnabled(FB.Net.match and FB.Net.match.phase=="invite" or false)
    local labels={offline="Not joined",joining="Joining…",checking="Checking delivery…",ready="Addon channel delivery verified",manual="Addon channel blocked: use click-to-announce",unavailable="Channel unavailable: retry Join"}
    self.channelStatus:SetText("FrozenBubbleForever\n"..(labels[FB.Community.state] or FB.Community.state))
    local peers={}
    for name,peer in pairs(FB.Net.peers) do if peer.queued then peers[#peers+1]=name end end
    table.sort(peers)
    self.peerText:SetText("Queued players seen: "..#peers.."\n"..table.concat(peers,"\n",1,math.min(5,#peers)).."\n\nChannel reach depends on your server / ruleset. Both players need this addon.")
end
function U:BuildScores()
    local p=self.panels.scores
    text(p,"HIGHSCORES",0,0,16,350)
    self.scoreMode="campaign"; self.shared=false
    button(p,"Campaign / endless",0,34,160,function() self.scoreMode=self.scoreMode=="campaign" and "endless" or "campaign"; self:RefreshScores() end)
    button(p,"Personal / shared",174,34,168,function() self.shared=not self.shared; self:RefreshScores() end)
    button(p,"Refresh shared",0,72,160,function()
        FB.Net.RequestScores()
        if FB.Community.state=="manual" then FB.Community.Manual("SCOREQ") end
        self.shared=true; self:RefreshScores()
    end)
    button(p,"Share my best",174,72,168,function()
        local row=FB.Scores.Best(self.scoreMode)
        if not row then FB.Print("Finish a scored run first."); return end
        if FB.Community.state=="ready" then FB.Community.Broadcast("SCORE",row.mode,row.score,row.level,row.seconds)
        else FB.Community.Manual("SCORE",row.mode,row.score,row.level,row.seconds) end
    end)
    self.scoreText=text(p,"",0,121,13,350)
    text(p,"Shared scores are player-reported and cached locally. Campaign rankings count runs started at level 1. Custom levels and practice starts are unranked.",0,354,12,350,muted)
end
function U:ShowScores() self:Panel("scores"); self:RefreshScores() end
function U:RefreshScores()
    local rows=FB.Scores.Rows(self.shared,self.scoreMode)
    local lines={(self.shared and "Community" or "Personal").." · "..self.scoreMode,""}
    for i=1,math.min(8,#rows) do
        local row=rows[i]; lines[#lines+1]=i..". "..row.name.."\n    "..row.score.." pts  ·  Level "..row.level
    end
    if #rows==0 then lines[#lines+1]="No completed runs yet." end
    self.scoreText:SetText(table.concat(lines,"\n"))
end
function U:BuildMarket()
    local p=self.panels.market
    text(p,"LEVEL MARKETPLACE",0,0,16,350)
    text(p,"Free levels, shared directly between players.",0,27,12,350,muted)
    button(p,"Browse community",0,56,170,function()
        FB.Community.Browse(FB.Community.state~="ready"); self.marketRemote=true; self.marketPage=1; self:RefreshMarket()
    end)
    button(p,"My library",182,56,160,function() self.marketRemote=false; self.marketPage=1; self:RefreshMarket() end)
    self.marketRows={}
    for i=1,6 do
        local y=104+(i-1)*43
        local row={label=text(p,"",0,y,12,225)}
        row.button=button(p,"Play",245,y-3,95,function()
            if not row.key then return end
            if self.marketRemote then FB.Community.Request(row.key) else FB.PlayCustom(row.key) end
        end)
        self.marketRows[i]=row
    end
    button(p,"Previous",0,371,100,function() self.marketPage=math.max(1,(self.marketPage or 1)-1); self:RefreshMarket() end)
    button(p,"Next",112,371,100,function() self.marketPage=(self.marketPage or 1)+1; self:RefreshMarket() end)
    text(p,"Creators must be online for downloads. Published levels can be re-shared. Open the editor to import, export, or delete a saved level.",0,408,12,350,muted)
end
function U:ShowMarket() self:Panel("market"); self:RefreshMarket() end
function U:RefreshMarket()
    local source=self.marketRemote and FB.Community.catalog or FB.db.custom
    local keys={}; for key in pairs(source) do keys[#keys+1]=key end
    table.sort(keys,function(a,b) return source[a].title<source[b].title end)
    self.marketPage=FB.Clamp(self.marketPage or 1,1,math.max(1,math.ceil(#keys/6)))
    for i,row in ipairs(self.marketRows) do
        local key=keys[(self.marketPage-1)*6+i]; local item=key and source[key]
        row.key=key; row.button:SetShown(item~=nil)
        row.label:SetText(item and (item.title.."\n|cff8eacbe"..(item.peer or item.author).."|r") or (i==1 and "No levels found. Browse or create one." or ""))
        row.button:SetText(self.marketRemote and "Download" or "Play")
    end
end
function U:BuildEditor()
    local p=self.panels.editor
    text(p,"LEVEL EDITOR",0,0,16,350)
    text(p,"Click to paint. Right-click to erase. Mouse wheel changes color. Keep every bubble connected to the top, within the first 10 rows.",0,33,13,350)
    for i=1,8 do
        local color=i
        local b=button(p,tostring(i),(i-1)*43,112,38,function() self.editorColor=color end)
        local icon=b:CreateTexture(nil,"ARTWORK"); icon:SetTexture(FB.media.."bubble"..i..".tga"); icon:SetSize(18,18); icon:SetPoint("LEFT",3,0)
    end
    self.levelTitle=input(p,6,162,332,"My level"); self.levelTitle:SetMaxLetters(36)
    button(p,"Save",0,202,105,function() self:SaveEditor() end)
    button(p,"Test level",118,202,105,function() local id=self:SaveEditor(); if id then FB.PlayCustom(id) end end)
    button(p,"Publish",236,202,105,function()
        local id=self:SaveEditor(); if id then FB.Community.Publish(id,FB.Community.state~="ready") end
    end)
    text(p,"Level code (copy / paste)",0,253,12,350,muted)
    self.levelCode=input(p,6,280,332,""); self.levelCode:SetMaxLetters(98)
    button(p,"Export",0,320,105,function() self.levelCode:SetText(self.editGame:Pack()); self.levelCode:SetFocus(); self.levelCode:HighlightText() end)
    button(p,"Import",118,320,105,function()
        local data=self.levelCode:GetText(); local grid=FB.Community.Validate(data)
        if grid then self.editGame.grid=grid; self.editing=true else FB.Print("Invalid level code or unsupported layout.") end
    end)
    button(p,"Clear",236,320,105,function() self.editGame.grid={}; self.editing=true end)
    button(p,"Delete saved level",0,365,170,function()
        if self.editID then FB.db.custom[self.editID]=nil; self.editID=nil; FB.Print("Deleted from your library.") end
    end)
    self.editorStatus=text(p,"",0,410,12,350,muted)
end
function U:StartEditor(id)
    if not FB.CanStart() then return end
    if FB.game then FB.game.paused=true end
    self.editing=true; self.editID=id; self.editGame=E.New({},1,"custom")
    if id and FB.db.custom[id] then
        self.editGame.grid=E.Unpack(FB.db.custom[id].data)
        self.levelTitle:SetText(FB.db.custom[id].title)
    end
    self:Panel("editor")
    self.frame:Show()
end
function U:SaveEditor()
    if not self.editGame then return end
    local id,err=FB.Community.Save(self.levelTitle:GetText(),self.editGame:Pack())
    self.editorStatus:SetText(id and "Saved. Publish to offer this level to the community." or err)
    if id then self.editID=id end
    return id
end
function U:Cursor()
    local x,y=GetCursorPosition(); local scale=self.board:GetEffectiveScale()
    return x/scale-self.board:GetLeft(),self.board:GetTop()-y/scale
end
function U:Paint(which)
    local x,y=self:Cursor(); local best,dist
    for r=1,10 do for c=1,E.Columns(r) do
        local cx,cy=E.Position(r,c); local d=(cx-x)^2+(cy-y)^2
        if not dist or d<dist then best,dist=E.Key(r,c),d end
    end end
    if dist and dist<32^2 then
        if which=="RightButton" then self.editGame.grid[best]=nil else self.editGame.grid[best]=self.editorColor end
    end
end
function U:RenderBoard(board,game,remote)
    for key=1,104 do
        local color=game and game.grid[key]
        if color then local r,c=E.Cell(key); local x,y=E.Position(r,c,game.ceiling); place(board.bubbles[key],board,x,y,color)
            if game.status=="lost" and r<=(self.endAge or 0)*10 then FB.Animation.Frame(board.bubbles[key],"frozen",1) end
        else board.bubbles[key]:Hide() end
    end
    board.roof:ClearAllPoints(); board.roof:SetPoint("TOPLEFT",0,-(game and game.ceiling or 0))
    if game and game.ceiling>=51 then
        board.compressor:ClearAllPoints(); board.compressor:SetPoint("TOPLEFT",2,-game.ceiling+51); board.compressor:Show()
    else board.compressor:Hide() end
    for i,t in ipairs(board.fx) do
        local fx=game and game.effects and game.effects[i]
        if fx then
            place(t,board,fx.drawX or fx.x,fx.drawY or fx.y,fx.color,32,1)
        else t:Hide() end
    end
    board.projectile:Hide(); board.current:Hide(); board.next:Hide(); board.shooter:Hide()
    board.stick:Hide()
    for _,dot in ipairs(board.dots) do dot:Hide() end
    if not game or remote or self.editing or game.status~="playing" then return end
    if game.stick then
        local r,c=E.Cell(game.stick.key); local x,y=E.Position(r,c,game.ceiling)
        board.stick:ClearAllPoints(); board.stick:SetPoint("CENTER",board,"TOPLEFT",x,-y)
        FB.Animation.Frame(board.stick,"stick",math.floor(game.stick.age/0.04)+1)
    end
    if game.projectile then place(board.projectile,board,game.projectile.x,game.projectile.y,game.projectile.color)
    else place(board.current,board,128,E.LAUNCH_Y,game.current) end
    place(board.next,board,128,412,game.next,32)
    board.shooter:Show(); board.shooter:SetRotation(-game.angle)
    -- The original game aims with the rotating cannon, without a dotted guide.
end
function U:AnimateMenu(dt)
    if not self.menu:IsShown() then return end
    self.menuTime=(self.menuTime or 0)+dt
    local tick=math.floor(self.menuTime*25)
    if not FB.db.reducedMotion then
        -- Original logo rocking formula from menu() in bin/frozen-bubble.
        self.menuLogo:SetRotation(math.sin(tick/40)/20)
        for i,item in ipairs(self.menuHover) do
            local count=FB.MediaInfo[item.name].frames
            FB.Animation.Frame(item.texture,item.name,i==self.menuSelection and tick%count+1 or 1)
        end
    end
    for i,eye in ipairs(self.blinkEyes) do
        local phase=(self.menuTime+(i>2 and 2.3 or 0))%5.7
        eye:SetShown(not FB.db.reducedMotion and (phase<0.12 or phase>0.28 and phase<0.37))
    end
end
function U:Update(dt)
    if not self.frame or not self.frame:IsShown() then return end
    self:AnimateMenu(dt)
    local game=self.editing and self.editGame or FB.game
    self.endAge=game and game.status~="playing" and ((self.endAge or 0)+dt) or 0
    if self.penguin:IsShown() then FB.Animation.Penguin(self.penguin,game,"p1",FB.db.reducedMotion and 0 or dt) end
    if game and not self.editing and game.status=="playing" then
        local oldAngle=game.angle
        if self.keys.LEFT or self.keys.A then game.angle=FB.Clamp(game.angle-dt*1.5,-E.MAX_ANGLE,E.MAX_ANGLE)
        elseif self.keys.RIGHT or self.keys.D then game.angle=FB.Clamp(game.angle+dt*1.5,-E.MAX_ANGLE,E.MAX_ANGLE)
        elseif self.board:IsMouseOver() then
            local x,y=self:Cursor()
            if self.lastX~=x or self.lastY~=y then
                if y<E.LAUNCH_Y-10 then game.angle=FB.Clamp(math.atan2(x-128,E.LAUNCH_Y-y),-E.MAX_ANGLE,E.MAX_ANGLE) end
                self.lastX,self.lastY=x,y
            end
        end
        game.turning=game.angle<oldAngle and -1 or game.angle>oldAngle and 1 or 0
    end
    self:RenderBoard(self.board,game)
    self.overlayText:SetText(""); self.overlaySub:SetText("")
    local canAdvance=not self.editing and game and game.status=="won" and game.mode=="campaign" and FB.level<100
    self.nextButton:SetShown(canAdvance or false)
    local ended=not self.editing and game and game.status~="playing"
    self.result:SetShown(ended or false)
    self.retryButton:SetShown(ended and not canAdvance or false)
    self.pauseArt:Hide()
    if self.editing then
        self.hud:SetText("Editor  ·  Color "..self.editorColor)
        self.footer:SetText("Paint your layout, then Save, Test, or Publish.")
    elseif game then
        local label=game.mode=="campaign" and ("Level "..(FB.level or 1).." / 100") or game.mode
        self.hud:SetText(label.."\n"..((FB.run and FB.run.score or 0)+game.score).." points")
        self.footer:SetText(game.status=="playing" and ("Ceiling in "..(game.rootPeriod-game.shots%game.rootPeriod).." shots\nIncoming bubbles: "..game.pending) or "")
        if game.paused then
            FB.Animation.Frame(self.pauseArt,"pause",math.floor((GetTime()%1.4)*25)+1)
            self.overlaySub:SetText("Press P or click Pause to resume.")
        elseif game.status~="playing" then
            FB.Animation.Frame(self.resultArt,game.status=="won" and "win-panel" or "lose-panel",1)
            self.resultDetail:SetText(game.mode=="versus" and (FB.Net.notice or "") or
                (game.status=="won" and ("Level "..(FB.level or 1).." cleared") or "Try that one again!"))
        elseif game.idle>game.hurryWarn then self.overlaySub:SetText("HURRY! Auto-fire in "..math.ceil(game.hurryMax-game.idle)) end
    else self.hud:SetText("Ready when you are"); self.footer:SetText("Pick Play level to begin the original campaign.") end
    local match=FB.Net.match
    if self.screen=="opponent" then
        self:RenderBoard(self.remoteBoard,match and match.remote,true)
        self.remoteLabel:SetText(match and (match.peer.."\n"..(match.remote and match.remote.score or 0).." points") or "No active match")
    end
    self.refresh=(self.refresh or 0)+dt
    if self.refresh>=1 then
        self.refresh=0
        if self.screen=="lobby" then self:RefreshLobby()
        elseif self.screen=="scores" then self:RefreshScores()
        elseif self.screen=="market" then self:RefreshMarket() end
    end
end
