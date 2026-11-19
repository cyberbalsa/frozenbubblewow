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
    t:SetSize(size or 32,size or 32); FB.SetBubbleTexture(t,color)
    t:SetAlpha(alpha or 1); t:Show()
end
local function makeBoard(parent,x,y)
    local b=CreateFrame("Frame",nil,parent)
    b:SetSize(256,400); b:SetPoint("TOPLEFT",x,-y)
    -- The original background already contains the playfield. Do not cover it.
    b.bubbles={}; b.fx={}; b.boardOverlays={}
    for key=1,104 do b.bubbles[key]=bubble(b) end
    for i=1,100 do b.fx[i]=bubble(b); b.fx[i]:Hide() end
    b.rising={}; b.penalties={}
    for i=1,7 do b.rising[i]=bubble(b); b.rising[i]:Hide() end
    b.limit=b:CreateTexture(nil,"OVERLAY"); b.limit:SetColorTexture(1,0.3,0.4,0)
    b.limit:SetSize(256,1); b.limit:SetPoint("TOPLEFT",0,-E.LIMIT)
    b.roof=b:CreateTexture(nil,"OVERLAY"); b.roof:SetColorTexture(0.5,0.85,1,0); b.roof:SetSize(256,3)
    b.compressor=FB.Animation.Image(b,"compressor",2,0,252,51,"OVERLAY"); b.compressor:Hide()
    b.pistons={}
    b.projectile=bubble(b); b.current=bubble(b); b.next=bubble(b)
    b.shooter=b:CreateTexture(nil,"ARTWORK",nil,1); b.shooter:SetTexture(FB.media.."shooter.tga"); b.shooter:SetSize(128,128)
    b.shooter:SetPoint("CENTER",b,"TOPLEFT",128,-E.LAUNCH_Y)
    b.stick=FB.Animation.Image(b,"stick",0,0,32,32,"OVERLAY"); b.stick:Hide()
    b.nextRim=FB.Animation.Image(b,"next-rim",109,393,nil,nil,"OVERLAY")
    b.hurry=FB.Animation.Image(b,"hurry",10,221,nil,nil,"OVERLAY")
    b.progress={}
    for i=1,12 do
        b.progress[i]=FB.Animation.Image(b,"progress-green",257,-16+(i-1)*(FB.MediaInfo["progress-green"].h+1))
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
        if FB.Invitations then FB.Invitations.Dismiss() end
        self.focusGrace=GetTime()+1.5; self.alpha=1; f:SetAlpha(1); self:Resize(); FB.Music()
    end)
    UISpecialFrames[#UISpecialFrames+1]="FrozenBubbleWindow"
    self.gameLayer=CreateFrame("Frame",nil,f); self.gameLayer:SetAllPoints(); self.gameLayer:SetClipsChildren(true)
    self.gameLayer:SetFrameLevel(self.layers.game)
    self.gameBackground=A.Image(self.gameLayer,"solo-background",0,0,1024,768,"BACKGROUND")
    self.board=makeBoard(self.gameLayer,0,0)
    self.board:SetFrameLevel(self.layers.board)
    self.board:EnableMouse(true); self.board:EnableMouseWheel(true)
    self.board:SetScript("OnEnter",function(b) if not InCombatLockdown() then b:EnableKeyboard(true); b:SetPropagateKeyboardInput(true) end end)
    self.board:SetScript("OnLeave",function(b) b:EnableKeyboard(false); self.keys={}; self.stroke=nil end)
    self.board:SetScript("OnMouseDown",function(_,which)
        if InCombatLockdown() then return end
        if self.editing and (which=="LeftButton" or which=="RightButton") then
            self.levelTitle:ClearFocus(); self.levelCode:ClearFocus()
            self.stroke={button=which}; self:Paint(which)
        elseif not self.editing and which=="LeftButton" then FB.Fire() end
    end)
    self.board:SetScript("OnMouseUp",function() self.stroke=nil end)
    self.board:SetScript("OnMouseWheel",function(_,delta)
        if self.editing then self:SelectEditorColor((self.editorColor-1+delta)%8+1)
        elseif FB.game then FB.game.angle=FB.Clamp(FB.game.angle+delta*0.045,-E.MAX_ANGLE,E.MAX_ANGLE) end
    end)
    self.board:SetScript("OnKeyDown",function(b,key)
        if self.editing then
            if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then b:SetPropagateKeyboardInput(true); return end
            local color=tonumber(key)
            local used=color and color>=1 and color<=8
            b:SetPropagateKeyboardInput(not used)
            if used and not InCombatLockdown() then self:SelectEditorColor(color) end
            return
        end
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
    self.resultBadge=A.Image(self.result,"net-lose-remote",318.4,118.4,64,49.6,"OVERLAY"); self.resultBadge:Hide()
    self.winnerName=text(self.result,"",177.6,176,20,316.8); self.winnerName:SetJustifyH("CENTER"); self.winnerName:Hide()
    self.resultDetail=text(self.result,"",0,250,18,526.4,{0.2,0.1,0.2}); self.resultDetail:SetJustifyH("CENTER")
    self.trainingResult=text(self.result,"",32,58,23,462); self.trainingResult:SetJustifyH("CENTER")
    self.nextButton=button(self.result,"Next level",116,284,294,function() FB.NextLevel() end); self.nextButton:Hide()
    self.retryButton=button(self.result,"Try again",116,284,294,function()
        if FB.game and FB.game.mode=="campaign" then FB.StartCampaign(FB.level)
        elseif FB.game and (FB.game.mode=="training" or FB.game.mode=="random" or FB.game.mode=="endless") then FB.StartSolo(FB.game.mode,FB.game.chainReaction)
        elseif FB.game and FB.game.mode=="versus" then FB.Net.Leave(); self:ShowLobby()
        else self:ShowMenu() end
    end)
    self.result:Hide()
    self.hud=text(self.gameLayer,"",30,113,23,245,{1,0.93,0.58})
    self.footer=text(self.gameLayer,"",20,235,14,225,{0.16,0.1,0.22})
    self.penguin=A.Image(self.gameLayer,"anime-shooter-p1",646.4,672,128,96)
    self.remotePenguin=A.Image(self.gameLayer,"anime-shooter-p2",-8,672,128,96); self.remotePenguin:Hide()
    self.trainingClock=A.Image(self.gameLayer,"training-clock",51.2,243.2,153.6,120)
    self.trainingTime=text(self.gameLayer,"",51.2,283.2,23,153.6); self.trainingTime:SetJustifyH("CENTER")
    self.panels={}
    for _,name in ipairs({"help","lobby","scores","market","editor","opponent","solo","chain","pick","settings"}) do
        local p=CreateFrame("Frame",nil,f); p:SetSize(370,470); p:SetPoint("TOPLEFT",555,-146)
        p:SetFrameLevel(self.layers.panel); p:EnableMouse(true); p:Hide(); self.panels[name]=p
        if name~="opponent" and name~="solo" and name~="chain" and name~="editor" then
            local bg=A.Image(p,"panel",-20,-24,410,514,"BACKGROUND")
            bg:SetVertexColor(0.6,0.65,0.75)
            button(p,"Back",266,-20,84,function() self:ShowMenu() end)
        end
    end
    self:BuildHelp(); self:BuildLobby(); self:BuildScores(); self:BuildMarket(); self:BuildEditor()
    self:BuildSolo(); self:BuildSettings()
    self.remoteBoard=makeBoard(self.gameLayer,0,0); self.remoteBoard:Hide()
    self.remoteBoard:SetFrameLevel(self.layers.board)
    self.remoteLabel=text(self.gameLayer,"",128,12,16,250); self.remoteLabel:SetJustifyH("CENTER")
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
    self.menuControl=button(self.toolbar,"Menu",16,728,90,function() self:ShowMenu() end)
    self.pauseControl=button(self.toolbar,"Pause",115,728,90,function() FB.TogglePause() end)
    self.editButton=button(self.toolbar,"Edit level",16,687,110,function() self:StartEditor(self.playingCustomID) end)
    self.editButton:Hide()
    local chrome=CreateFrame("Frame",nil,f); chrome:SetAllPoints(); chrome:SetFrameLevel(self.layers.chrome)
    button(chrome,"X",976,4,30,function() f:Hide() end)
    button(chrome,"−",900,4,28,function() FB.Options.Set("windowSize",math.max(0.55,(FB.db.windowSize or 1)-0.1)) end)
    button(chrome,"+",932,4,28,function() FB.Options.Set("windowSize",math.min(1,(FB.db.windowSize or 1)+0.1)) end)
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
    self.panels.solo:EnableKeyboard(not blocked and self.screen=="solo")
    self.panels.chain:EnableKeyboard(not blocked and self.screen=="chain")
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
    local inactive=combat or (FB.db.fadeOnBlur~=false and not focused and GetTime()-(self.outsideSince or GetTime())>=0.6)
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
        FB.Music()
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
    local versus=self.screen=="opponent"
    board.hurry:ClearAllPoints(); board.hurry:SetPoint("TOPLEFT",10,versus and -225 or -221)
    local progressX=versus and board==self.board and -9 or 257
    for i,dot in ipairs(board.progress) do
        dot:ClearAllPoints(); dot:SetPoint("TOPLEFT",progressX,(versus and 12 or 16)-(i-1)*(FB.MediaInfo["progress-green"].h+1))
    end
end
function U:ShowMenu()
    self.editing=false; self.stroke=nil
    self.focusPausedGame=nil
    self.keys={}; self.board:EnableKeyboard(false)
    if FB.game and FB.game.mode~="versus" then FB.game.paused=true end
    for _,panel in pairs(self.panels) do panel:Hide() end
    self.panels.solo:EnableKeyboard(false)
    self.panels.chain:EnableKeyboard(false)
    self.menu:Show(); self.gameLayer:Hide(); self.screen="menu"; FB.Music()
end
function U:ShowGame()
    if not FB.game then self:Panel("solo"); return end
    if FB.game.mode~="versus" and not InCombatLockdown() then FB.game.paused=false end
    self:Panel(FB.game.mode=="versus" and "opponent" or "game"); FB.Music()
end
function U:BuildSolo()
    local p=self.panels.solo
    p:ClearAllPoints(); p:SetScale(1.6); p:SetSize(341,280); p:SetPoint("CENTER",self.frame,"CENTER")
    FB.Animation.Image(p,"solo-panel",0,0,nil,nil,"BACKGROUND")
    local title=text(p,"Start 1-player game menu",0,16,14,341); title:SetJustifyH("CENTER")
    self.soloEntries={}
    local actions={
        {"play_all_levels",function() FB.StartCampaign(1) end},
        {"pick_start_level",function() self:Panel("pick") end},
        {"play_random_levels",function() self:ChooseChainRules("random") end},
        {"multiplayer_training",function() self:ChooseChainRules("training") end},
    }
    for index,choice in ipairs(actions) do
        local row=CreateFrame("Button",nil,p)
        row:SetSize(298,37); row:SetPoint("TOPLEFT",21,-90-(index-1)*41)
        local base=FB.Animation.Image(row,"solo-off",0,0,nil,nil,"BACKGROUND")
        local effect="glow-"..choice[1]
        local glow=FB.Animation.Image(row,effect,0,0); glow:Hide()
        FB.Animation.Image(row,"solo-"..choice[1],0,0,nil,nil,"OVERLAY")
        local activate=function()
            if not InCombatLockdown() then FB.Sound("menu_selected"); choice[2]() end
        end
        self.soloEntries[index]={base=base,glow=glow,effect=effect,activate=activate}
        row:SetScript("OnEnter",function() self:SelectSolo(index) end)
        row:SetScript("OnClick",activate)
    end
    button(p,"Continue",20,284,100,function() FB.ContinueCampaign() end)
    button(p,"Endless",120,284,100,function() FB.StartSolo("endless") end)
    button(p,"Back",220,284,100,function() self:ShowMenu() end)
    p:SetPropagateKeyboardInput(true)
    p:SetScript("OnKeyDown",function(panel,key)
        if InCombatLockdown() then return end
        local active=not self.inactive and self:HasFocus() and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
        local used=active and (key=="UP" or key=="DOWN" or key=="ENTER" or key=="NUMPADENTER" or key=="ESCAPE")
        panel:SetPropagateKeyboardInput(not used)
        if used then
            if key=="ESCAPE" then self:ShowMenu()
            elseif key=="UP" then self:SelectSolo((self.soloIndex-2)%4+1)
            elseif key=="DOWN" then self:SelectSolo(self.soloIndex%4+1)
            else self.soloEntries[self.soloIndex].activate() end
        end
    end)
    local prompt=self.panels.chain
    prompt:ClearAllPoints(); prompt:SetScale(1.6); prompt:SetSize(341,280); prompt:SetPoint("CENTER",self.frame,"CENTER")
    FB.Animation.Image(prompt,"panel",0,0,nil,nil,"BACKGROUND")
    self.chainTitle=text(prompt,"",0,12,14,341); self.chainTitle:SetJustifyH("CENTER")
    text(prompt,"Enable chain-reaction?",0,66,14,341):SetJustifyH("CENTER")
    self.chainYes=button(prompt,"Yes (Y)",56,114,105,function() FB.StartSolo(self.chainMode,true) end)
    self.chainNo=button(prompt,"No (N)",180,114,105,function() FB.StartSolo(self.chainMode,false) end)
    button(prompt,"Back",118,218,105,function() self:Panel("solo") end)
    prompt:SetPropagateKeyboardInput(true)
    prompt:SetScript("OnKeyDown",function(panel,key)
        if InCombatLockdown() then return end
        local active=not self.inactive and self:HasFocus() and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
        local used=active and (key=="Y" or key=="N" or key=="ESCAPE")
        panel:SetPropagateKeyboardInput(not used)
        if used then
            if key=="ESCAPE" then self:Panel("solo")
            else FB.StartSolo(self.chainMode,key=="Y") end
        end
    end)
    local pick=self.panels.pick
    text(pick,"Pick a starting level",0,24,22,340)
    text(pick,"Start at an unlocked level (practice)",0,94,14,340)
    self.level=input(pick,0,139,90,"1"); self.level:SetNumeric(true); self.level:SetMaxLetters(3)
    button(pick,"Play level",100,137,220,function() FB.StartCampaign(tonumber(self.level:GetText()) or 1) end)
end
function U:ChooseChainRules(mode)
    self.chainMode=mode
    self.chainTitle:SetText(mode=="training" and "Multiplayer training" or "Random level")
    self:Panel("chain")
end
function U:SelectSolo(index,silent)
    self.soloIndex=index; self.soloTime=0
    for i,row in ipairs(self.soloEntries) do
        FB.Animation.Frame(row.base,i==index and "solo-over" or "solo-off",1)
        row.glow:SetShown(i==index and not FB.db.reducedMotion)
    end
    if not silent then FB.Sound("menu_change") end
end
function U:BuildSettings()
    local p=self.panels.settings
    text(p,"SOUND & DISPLAY",0,0,24,350)
    self.sound=button(p,"Sound: on",0,60,160,function() FB.Options.Set("sound",not FB.db.sound) end)
    self.music=button(p,"Music: on",178,60,160,function() FB.Options.Set("music",not FB.db.music) end)
    text(p,"Game music volume",0,117,15,350)
    self.musicValue=text(p,"",0,155,16,110)
    button(p,"Quieter",110,150,105,function() FB.Options.Set("musicVolume",math.max(0.1,(FB.db.musicVolume or 0.8)-0.1)) end)
    button(p,"Louder",230,150,105,function() FB.Options.Set("musicVolume",math.min(1,(FB.db.musicVolume or 0.8)+0.1)) end)
    text(p,"The music slider is applied while this game is open. Your previous WoW music volume is restored when you close it.",0,210,13,350)
    button(p,"Fit game to screen",0,282,338,function() FB.Options.Set("windowSize",1) end)
    button(p,"Animation: full / reduced",0,330,338,function() FB.Options.Set("reducedMotion",not FB.db.reducedMotion) end)
    button(p,"WoW AddOns settings",0,382,338,function() FB.Options.Open() end)
end
function U:Options()
    self.sound:SetText(FB.db.sound and "Sound: on" or "Sound: off")
    self.music:SetText(FB.db.music and "Music: on" or "Music: off")
    if self.musicValue then self.musicValue:SetText(math.floor((FB.db.musicVolume or 0.8)*100+0.5).."%") end
end
function U:Panel(name)
    if name=="editor" and not self.editGame then self:StartEditor(); return end
    self.screen=name; self.stroke=nil; self.editing=name=="editor"
    self.editorSockets:SetShown(self.editing); self.editorDirty=true
    self.panels.solo:EnableKeyboard(name=="solo" and not self.combatInput)
    self.panels.chain:EnableKeyboard(name=="chain" and not self.combatInput)
    if name=="solo" then self:SelectSolo(1,true) end
    for key,panel in pairs(self.panels) do panel:SetShown(key==name) end
    local gameplay=name=="game" or name=="opponent" or name=="editor"
    self.menu:SetShown(not gameplay); self.gameLayer:SetShown(gameplay)
    self.remoteBoard:SetShown(name=="opponent")
    self.remoteLabel:SetShown(name=="opponent")
    self.remotePenguin:SetShown(name=="opponent")
    self.footer:SetShown(name~="opponent" and name~="editor")
    self.pauseControl:SetShown(name~="opponent" and name~="editor")
    self.result:ClearAllPoints(); self.result:SetPoint("TOPLEFT",name=="opponent" and 244.8 or 238.4,-304)
    self.menuControl:ClearAllPoints()
    self.menuControl:SetPoint("TOPLEFT",name=="opponent" and 467 or 16,-728)
    self.penguin:ClearAllPoints()
    self.panels.opponent:Hide()
    if name=="opponent" then
        FB.Animation.Frame(self.gameBackground,"versus-background",1)
        self:PlaceBoard(self.board,566.4,64,1.6); self:PlaceBoard(self.remoteBoard,48,64,1.6)
        self.hud:ClearAllPoints(); self.hud:SetPoint("TOPLEFT",self.gameLayer,"TOPLEFT",640,-12); self.hud:SetWidth(240); self.hud:SetJustifyH("CENTER")
        self.penguin:SetPoint("TOPLEFT",902.4,-672); self.penguin:Show()
    else
        self.penguin:SetPoint("TOPLEFT",646.4,-672)
        FB.Animation.Frame(self.gameBackground,name=="editor" and "editor-background" or "solo-background",1)
        self:PlaceBoard(self.board,304,70.4,1.6)
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
    text(p,"In versus, large clears send bubbles to the other board. Keep yours above the danger line to win. You cannot pause a match; hiding the window keeps it running.",0,363,13,350,muted)
end
function U:BuildLobby()
    local p=self.panels.lobby
    text(p,"MULTIPLAYER",0,0,16,350)
    button(p,"Join community channel",0,32,180,function() FB.Community.Join() end)
    self.versusRules=button(p,"Chain reactions off",188,32,154,function()
        if FB.Net.queue or FB.Net.match then return end
        FB.db.versusChains=not FB.db.versusChains; self:RefreshLobby()
    end)
    self.channelStatus=text(p,"",0,66,12,350,muted)
    button(p,"Find match / stop",0,115,165,function() FB.Net.SetQueue(not FB.Net.queue) end)
    button(p,"Announce queue",177,115,165,function()
        if not FB.Net.queue then FB.Net.SetQueue(true) end
        if FB.Net.queue then FB.Community.Manual("QUEUE",FB.Net.QueueCode()) end
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
    local chains=FB.db.versusChains
    if FB.Net.match then chains=FB.Net.match.chainReaction end
    self.versusRules:SetText(chains and "Chain reactions on" or "Chain reactions off")
    self.versusRules:SetEnabled(not FB.Net.queue and not FB.Net.match)
    self.accept:SetEnabled(FB.Net.match and FB.Net.match.phase=="invite" or false)
    local labels={offline="Not joined",joining="Joining…",checking="Checking delivery…",ready="Addon channel delivery verified",manual="Addon channel blocked: use click-to-announce",unavailable="Channel unavailable: retry Join"}
    self.channelStatus:SetText("FrozenBubbleForever\n"..(labels[FB.Community.state] or FB.Community.state))
    local peers={}
    for name,peer in pairs(FB.Net.peers) do if peer.queued then peers[#peers+1]=name..(peer.chainReaction and " (chain)" or "") end end
    table.sort(peers)
    self.peerText:SetText("Queued players seen: "..#peers.."\n"..table.concat(peers,"\n",1,math.min(5,#peers)).."\n\nChannel reach depends on your server / ruleset. Both players need this addon.")
end
function U:BuildScores()
    local p=self.panels.scores
    text(p,"HIGHSCORES",0,0,16,350)
    self.scoreMode="campaign"; self.shared=false
    self.scoreIndex=1
    self.scoreSelector=button(p,"Campaign",0,34,160,function()
        self.scoreIndex=self.scoreIndex%#FB.Scores.modes+1
        self.scoreMode=FB.Scores.modes[self.scoreIndex]
        self.scoreSelector:SetText(FB.Scores.Label(self.scoreMode))
        self:RefreshScores()
    end)
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
    local lines={(self.shared and "Community" or "Personal").." · "..FB.Scores.Label(self.scoreMode),""}
    for i=1,math.min(8,#rows) do
        local row=rows[i]; lines[#lines+1]=i..". "..row.name.."\n    "..row.score.." pts"..(row.mode=="campaign" and ("  ·  Level "..row.level) or "")
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
        local row={label=text(p,"",0,y,12,196)}
        row.edit=button(p,"Edit",200,y-3,64,function() if row.key then self:StartEditor(row.key) end end)
        row.button=button(p,"Play",268,y-3,72,function()
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
        row.key=key; row.button:SetShown(item~=nil); row.edit:SetShown(item~=nil and not self.marketRemote)
        row.label:SetText(item and (item.title.."\n|cff8eacbe"..(item.peer or item.author).."|r") or (i==1 and "No levels found. Browse or create one." or ""))
        row.button:SetText(self.marketRemote and "Download" or "Play")
    end
end
function U:BuildEditor()
    local p=self.panels.editor
    p:ClearAllPoints(); p:SetScale(1.6); p:SetSize(640,480); p:SetPoint("TOPLEFT",self.frame,"TOPLEFT")
    p:EnableMouse(false)
    local title=text(p,"Level editor",217,9,15,192); title:SetJustifyH("CENTER")
    self.editorPalette={}
    for i=1,8 do
        local color=i
        local tile=CreateFrame("Button",nil,p); tile:SetSize(29,29)
        tile:SetPoint("TOPLEFT",12+((i-1)%4)*32,-62-math.floor((i-1)/4)*36)
        local icon=tile:CreateTexture(nil,"ARTWORK"); icon:SetAllPoints()
        local ring=tile:CreateTexture(nil,"OVERLAY"); ring:SetSize(42,42); ring:SetPoint("CENTER")
        ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); ring:SetBlendMode("ADD")
        self.editorPalette[i]={icon=icon,ring=ring}
        tile:SetScript("OnClick",function() self:SelectEditorColor(color) end)
    end
    self:SelectEditorColor(1)
    text(p,"Bubble color",12,42,12,130)
    button(p,"Undo",10,146,61,function() self:UndoEditor() end)
    button(p,"Clear",77,146,64,function()
        if next(self.editGame.grid) then self:RememberEditor(); self.editGame.grid={} end
    end)
    text(p,"Drag to paint.\nRight-drag to erase.\n\nWheel or 1–8 changes color.",13,227,13,125)
    text(p,"Level name",493,43,12,135)
    self.levelTitle=input(p,493,61,135,"My level"); self.levelTitle:SetMaxLetters(36)
    button(p,"Save",493,94,135,function() self:SaveEditor() end)
    button(p,"Test level",493,127,135,function() self:TestEditor() end)
    button(p,"Publish",493,160,135,function()
        local id=self:SaveEditor(); if id then FB.Community.Publish(id,FB.Community.state~="ready") end
    end)
    button(p,"New level",493,193,135,function() self:StartEditor(nil,true) end)
    text(p,"Level code",493,266,12,136)
    self.levelCode=input(p,493,282,135,""); self.levelCode:SetMaxLetters(98)
    button(p,"Export",493,314,65,function() self.levelCode:SetText(self.editGame:Pack()); self.levelCode:SetFocus(); self.levelCode:HighlightText() end)
    button(p,"Import",563,314,65,function()
        local grid=FB.Community.Validate(self.levelCode:GetText())
        if grid then
            self:RememberEditor(); self.editGame.grid=grid; self.levelCode:ClearFocus()
        else self.editorStatus:SetText("Invalid code. Use ten rows connected to the ceiling.") end
    end)
    button(p,"Delete saved level",493,365,135,function()
        if self.editID then
            FB.db.custom[self.editID]=nil; self.editID=nil; self.editorStatus:SetText("Deleted from your library. Draft kept open.")
        end
    end)
    self.editorStatus=text(p,"",191,334,12,252); self.editorStatus:SetJustifyH("CENTER")
    self.editorStatus:SetFont("Fonts\\ARIALN.TTF",12,"OUTLINE")
    self.editorSockets=CreateFrame("Frame",nil,self.board); self.editorSockets:SetAllPoints()
    self.editorSockets:SetFrameLevel(self.board:GetFrameLevel()); self.editorSockets:EnableMouse(false)
    self.emptyCells={}
    for r=1,10 do for c=1,E.Columns(r) do
        local key=E.Key(r,c); local x,y=E.Position(r,c)
        local socket=self.editorSockets:CreateTexture(nil,"BACKGROUND")
        socket:SetTexture(FB.media.."bubble2.tga"); socket:SetSize(29,29)
        socket:SetPoint("CENTER",self.board,"TOPLEFT",x,-y); socket:SetAlpha(0.23)
        self.emptyCells[key]=socket
    end end
    self.editorPreview=bubble(self.editorSockets); self.editorPreview:SetDrawLayer("OVERLAY")
    self.editorPreview:Hide(); self.editorSockets:Hide()
end
function U:SelectEditorColor(color)
    self.editorColor=color
    for i,tile in ipairs(self.editorPalette) do
        FB.SetBubbleTexture(tile.icon,i); tile.ring:SetShown(i==color)
    end
    self.editorDirty=true
end
function U:StartEditor(id,fresh)
    if not FB.CanStart() then return end
    if FB.game then FB.game.paused=true end
    if not self.editGame or fresh or id and self.editID~=id then
        self.editID=id; self.editGame=E.New({},1,"custom"); self.editorHistory={}
        local item=id and FB.db.custom[id]
        if item then self.editGame.grid=E.Unpack(item.data) end
        self.levelTitle:SetText(item and item.title or "My level"); self.levelCode:SetText("")
        self.editorStatus:SetText("Connect the bubbles to the ceiling.")
    end
    self:Panel("editor"); self.frame:Show()
end
function U:RememberEditor()
    local history=self.editorHistory
    history[#history+1]=self.editGame:Pack()
    if #history>32 then table.remove(history,1) end
    self.editorDirty=true; self.editorStatus:SetText("")
end
function U:UndoEditor()
    local previous=table.remove(self.editorHistory)
    if previous then self.editGame.grid=E.Unpack(previous); self.editorDirty=true end
end
function U:TestEditor()
    local data=self.editGame:Pack()
    if not FB.Community.Validate(data) then
        self.editorStatus:SetText("Connect at least one bubble to the ceiling, and attach every group."); return
    end
    FB.StartCustom(data)
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
local function editorCell(x,y)
    if x<0 or x>=256 or y<0 or y>=284 then return end
    local row=math.floor((y-16)/E.STEP)+1
    local best,distance
    for r=math.max(1,row),math.min(10,row+1) do
        local first=E.Position(r,1)
        local c=FB.Clamp(math.floor((x-first)/32+0.5)+1,1,E.Columns(r))
        local cx,cy=E.Position(r,c); local d=(cx-x)^2+(cy-y)^2
        if d<=19^2 and (not distance or d<distance) then best,distance=E.Key(r,c),d end
    end
    return best
end
function U:Paint(which,x,y)
    if not x then x,y=self:Cursor() end
    local stroke=self.stroke or {}
    local fromX,fromY=stroke.x or x,stroke.y or y
    local steps=math.max(1,math.ceil(math.max(math.abs(x-fromX),math.abs(y-fromY))/8))
    local color
    if which=="LeftButton" then color=self.editorColor elseif which~="RightButton" then return end
    for i=1,steps do
        local key=editorCell(fromX+(x-fromX)*i/steps,fromY+(y-fromY)*i/steps)
        if key and self.editGame.grid[key]~=color then
            if not stroke.remembered then self:RememberEditor(); stroke.remembered=true end
            self.editGame.grid[key]=color; self.editorDirty=true
        end
    end
    stroke.x,stroke.y=x,y
end
function U:UpdateEditor()
    local key
    if self.board:IsMouseOver() and not self.inactive and not InCombatLockdown() then
        local x,y=self:Cursor()
        key=editorCell(x,y)
        if self.stroke then
            if IsMouseButtonDown and not IsMouseButtonDown(self.stroke.button) then self.stroke=nil
            else self:Paint(self.stroke.button,x,y) end
        end
    else self.stroke=nil end
    if self.editorDirty then
        self:RenderBoard(self.board,self.editGame)
        for slot,texture in pairs(self.emptyCells) do texture:SetShown(not self.editGame.grid[slot]) end
        self.editorDirty=false
    end
    if key then
        local r,c=E.Cell(key); local x,y=E.Position(r,c)
        place(self.editorPreview,self.board,x,y,self.editorColor,32,0.5)
    else self.editorPreview:Hide() end
end
function U:RenderBoard(board,game,remote)
    local phase=game and game.rootPeriod and game.lockedShots%game.rootPeriod or 0
    local sweep
    if game and (not game.status or game.status=="playing") and game.rootPeriod and phase>=game.rootPeriod-2 then
        sweep=math.floor((game.elapsed or 0)*50)%(phase==game.rootPeriod-1 and 31 or 61)
    end
    local ended=game and game.endCells
    local winner=game and game.status=="won"
    local overlays=0
    for key=1,104 do
        local color=game and game.grid[key]
        if winner and ended and ended[key] then color=nil end
        if color then local r,c=E.Cell(key); local x,y=E.Position(r,c,game.ceiling,game.offset); place(board.bubbles[key],board,x,y,color)
            local effect=ended and ended[key] and "frozen" or sweep==c-1 and "prelight"
            if effect then
                overlays=overlays+1
                local overlay=board.boardOverlays[overlays] or board:CreateTexture(nil,"ARTWORK",nil,1)
                board.boardOverlays[overlays]=overlay
                local info=FB.MediaInfo[effect]
                overlay:ClearAllPoints(); overlay:SetPoint("CENTER",board,"TOPLEFT",x,-y-(effect=="frozen" and 7 or 0))
                overlay:SetSize(info.w,info.h); FB.Animation.Frame(overlay,effect,1)
            end
        else board.bubbles[key]:Hide() end
    end
    for i=overlays+1,#board.boardOverlays do board.boardOverlays[i]:Hide() end
    board.roof:ClearAllPoints(); board.roof:SetPoint("TOPLEFT",0,-(game and game.ceiling or 0))
    local pistonCount=0
    if game and not remote and not self.editing and game.mode~="versus" then
        local info=FB.MediaInfo.compressor
        local roof=44+game.ceiling
        local height=math.min(info.h,roof)
        board.compressor:ClearAllPoints(); board.compressor:SetPoint("TOPLEFT",(256-info.w)/2,height-game.ceiling)
        board.compressor:SetHeight(height)
        board.compressor:SetTexCoord(0,info.w/info.tw,(info.h-height)/info.th,info.h/info.th)
        board.compressor:Show()
        -- Upstream blits whole 28px shaft sections up from inside the two heads.
        local shaft=FB.MediaInfo["compressor-ext"]
        local bottom=roof-info.h+3
        while bottom>0 do
            pistonCount=pistonCount+1
            local t=board.pistons[pistonCount] or FB.Animation.Image(board,"compressor-ext",0,0,nil,nil,"OVERLAY")
            board.pistons[pistonCount]=t
            local visible=math.min(shaft.h,bottom)
            t:ClearAllPoints(); t:SetPoint("TOPLEFT",(256-shaft.w)/2,44-bottom+visible)
            t:SetHeight(visible); t:SetTexCoord(0,shaft.w/shaft.tw,(shaft.h-visible)/shaft.th,shaft.h/shaft.th)
            t:Show(); bottom=bottom-shaft.h
        end
    else board.compressor:Hide() end
    for i=pistonCount+1,#board.pistons do board.pistons[i]:Hide() end
    for i,texture in ipairs(board.rising) do
        local bubble=game and game.rising and game.rising[i]
        if bubble then place(texture,board,bubble.x,bubble.y,bubble.color) else texture:Hide() end
    end
    local pending=game and (game.mode=="versus" or game.mode=="training") and game.pending or 0
    local height,used=0,0
    while pending>0 and height<350 do
        local grouped=pending>=7
        local asset=grouped and "penalty-seven" or "penalty-one"
        local info=FB.MediaInfo[asset]
        used=used+1
        local marker=board.penalties[used] or board:CreateTexture(nil,"ARTWORK")
        board.penalties[used]=marker
        marker:ClearAllPoints(); marker:SetPoint("BOTTOM",board,"TOPLEFT",remote and 278 or -23,-362+height)
        marker:SetSize(info.w,info.h); FB.Animation.Frame(marker,asset,1)
        height=height+info.h-1; pending=pending-(grouped and 7 or 1)
    end
    for i=used+1,#board.penalties do board.penalties[i]:Hide() end
    local chains=game and game.chains
    local chainCount=chains and #chains or 0
    for i,t in ipairs(board.fx) do
        local fx=(chains and chains[i]) or (game and game.effects and game.effects[i-chainCount])
        if fx then
            place(t,board,fx.drawX or fx.x,fx.drawY or fx.y,fx.color,32,1)
        else t:Hide() end
    end
    board.projectile:Hide(); board.current:Hide(); board.next:Hide(); board.shooter:Hide()
    board.stick:Hide()
    board.nextRim:Hide(); board.hurry:Hide()
    for i,dot in ipairs(board.progress) do
        if game and game.rootPeriod and i<=game.rootPeriod and not self.editing then
            FB.Animation.Frame(dot,i==phase+1 and "progress-red" or "progress-green",1)
        else dot:Hide() end
    end
    if not game or self.editing or not game.current then return end
    if game.stick then
        local r,c=E.Cell(game.stick.key); local x,y=E.Position(r,c,game.ceiling,game.offset)
        board.stick:ClearAllPoints(); board.stick:SetPoint("CENTER",board,"TOPLEFT",x,-y)
        FB.Animation.Frame(board.stick,"stick",math.floor(game.stick.age/0.04)+1)
    end
    if game.projectile then place(board.projectile,board,game.projectile.x,game.projectile.y,game.projectile.color)
    end
    local versus=game.mode=="versus"
    local launchY=versus and 366 or E.LAUNCH_Y
    board.shooter:ClearAllPoints(); board.shooter:SetPoint("CENTER",board,"TOPLEFT",128,-launchY)
    local nextY=versus and 416 or 412
    if game.status=="lost" or game.status=="draw" then
        local info=FB.MediaInfo.frozen
        for i,t in ipairs({board.current,board.next}) do
            t:ClearAllPoints(); t:SetPoint("CENTER",board,"TOPLEFT",128,-(i==1 and launchY+7 or nextY+8))
            t:SetSize(info.w,info.h); FB.Animation.Frame(t,"frozen",1)
        end
    else
        place(board.current,board,128,launchY,game.current)
        place(board.next,board,128,nextY,game.next)
        board.nextRim:ClearAllPoints(); board.nextRim:SetPoint("TOPLEFT",versus and 108 or 109,versus and -397 or -393)
        board.nextRim:Show()
    end
    local warning=game.status=="playing" and (not remote or game.timed) and game.idle and game.hurryWarn and game.idle>game.hurryWarn and math.floor((game.idle-game.hurryWarn)*2)%2==0
    if warning and not board.wasWarning then FB.Sound("hurry") end
    board.wasWarning=warning
    if warning then FB.Animation.Frame(board.hurry,remote and "hurry-remote" or "hurry",1) end
    board.hurry:SetShown(warning or false)
    board.shooter:Show(); board.shooter:SetRotation(-game.angle)
    -- The original game aims with the rotating cannon, without a dotted guide.
end
function U:AnimateMenu(dt)
    if not self.menu:IsShown() then return end
    if self.screen=="solo" and not FB.db.reducedMotion then
        self.soloTime=self.soloTime+dt
        local row=self.soloEntries[self.soloIndex]
        FB.Animation.Frame(row.glow,row.effect,math.floor(self.soloTime*50)%70+1)
    end
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
    if game and not self.editing and not game.paused and game.status=="playing" then
        local oldAngle=game.angle
        if self.keys.LEFT or self.keys.A then game.angle=FB.Clamp(game.angle-dt*1.5,-E.MAX_ANGLE,E.MAX_ANGLE)
        elseif self.keys.RIGHT or self.keys.D then game.angle=FB.Clamp(game.angle+dt*1.5,-E.MAX_ANGLE,E.MAX_ANGLE)
        elseif self.board:IsMouseOver() then
            local x,y=self:Cursor()
            if self.lastX~=x or self.lastY~=y then
                if y<game.launchY-10 then game.angle=FB.Clamp(math.atan2(x-128,game.launchY-y),-E.MAX_ANGLE,E.MAX_ANGLE) end
                self.lastX,self.lastY=x,y
            end
        end
        game.turning=game.angle<oldAngle and -1 or game.angle>oldAngle and 1 or 0
    end
    if self.penguin:IsShown() then FB.Animation.Penguin(self.penguin,game,"p1",FB.db.reducedMotion and 0 or dt) end
    if self.editing then self:UpdateEditor() else self:RenderBoard(self.board,game) end
    self.overlayText:SetText(""); self.overlaySub:SetText("")
    local canAdvance=not self.editing and game and game.status=="won" and game.mode=="campaign" and FB.level<100
    self.nextButton:SetShown(canAdvance or false)
    local ended=not self.editing and game and game.status~="playing"
    local match=FB.Net.match
    local versus=game and game.mode=="versus"
    local winner=ended and versus and (game.status=="won" and game or game.status=="lost" and match and match.remote)
    local ready=ended
    if ended and not FB.db.reducedMotion then
        if winner then ready=winner.endOrder and winner.endIndex>=#winner.endOrder and #winner.effects==0
        elseif game.status=="lost" or game.status=="draw" then ready=game.endOrder and game.endIndex>=#game.endOrder end
    end
    self.result:SetShown(ready or false)
    self.winnerName:SetShown(winner and true or false)
    self.resultBadge:SetShown(winner and true or false)
    if winner then
        self.winnerName:SetText(winner==game and FB.PlayerName() or match.peer)
        FB.Animation.Frame(self.resultBadge,winner==game and "net-lose-remote" or "net-lose-local",1)
    end
    local finished=ended and game.status=="finished"
    self.trainingResult:SetShown(finished or false); self.resultDetail:SetShown(not finished)
    if finished then self.trainingResult:SetText("Your score after two minutes\n\n"..game.score) end
    self.retryButton:SetText(versus and "Back to lobby" or "Try again")
    self.retryButton:SetShown(ended and not canAdvance or false)
    self.pauseArt:Hide()
    local training=game and game.mode=="training" and not self.editing
    self.trainingClock:SetShown(training or false); self.trainingTime:SetShown(training or false)
    if training then
        local seconds=math.floor(game:TrainingTimeLeft())
        self.trainingTime:SetText(string.format("%d'%02d\"",math.floor(seconds/60),seconds%60))
    end
    if self.editing then
        self.hud:SetText("Editor  ·  Color "..self.editorColor)
        self.footer:SetText("Paint your layout, then Save, Test, or Publish.")
    elseif game then
        local label=game.mode=="campaign" and ("Level "..(FB.level or 1).." / 100") or game.mode
        self.hud:SetText(game.mode=="versus" and (FB.PlayerName().."  ·  "..game.score) or
            (label.."\n"..((FB.run and FB.run.score or 0)+game.score).." points"))
        self.footer:SetShown(not training and game.mode~="versus")
        self.footer:SetText(game.status=="playing" and ((game.penaltyRules and "Next row in " or "Ceiling in ")..(game.rootPeriod-game.lockedShots%game.rootPeriod).." shots") or "")
        if game.paused then
            FB.Animation.Frame(self.pauseArt,"pause",math.floor((GetTime()%1.4)*25)+1)
            self.overlaySub:SetText("Press P or click Pause to resume.")
        elseif game.status~="playing" then
            local art=winner and (winner==game and "net-win-local" or "net-win-remote")
                or (finished or versus) and "panel" or game.status=="won" and "win-panel" or "lose-panel"
            self.resultArt:SetSize(art=="lose-panel" and 552 or 526.4,art=="lose-panel" and 198.4 or 254.4)
            FB.Animation.Frame(self.resultArt,art,1)
            self.resultDetail:SetText(training and ("Training score: "..game.score) or game.mode=="random" and game.status=="won" and "Random board cleared" or game.mode=="versus" and (FB.Net.notice or "") or
                (game.status=="won" and ("Level "..(FB.level or 1).." cleared") or "Try that one again!"))
        end
    else self.hud:SetText("Ready when you are"); self.footer:SetText("Pick Play level to begin the original campaign.") end
    if self.screen=="opponent" then
        local remote=match and match.remote
        if remote then
            FB.Animation.Penguin(self.remotePenguin,remote,"p2",FB.db.reducedMotion and 0 or dt)
        end
        self.remotePenguin:SetShown(remote~=nil)
        self:RenderBoard(self.remoteBoard,remote,true)
        self.remoteLabel:SetText(match and (match.peer.."  ·  "..(match.remote and match.remote.score or 0)) or "No active match")
    end
    self.refresh=(self.refresh or 0)+dt
    if self.refresh>=1 then
        self.refresh=0
        if self.screen=="lobby" then self:RefreshLobby()
        elseif self.screen=="scores" then self:RefreshScores()
        elseif self.screen=="market" then self:RefreshMarket() end
    end
end
