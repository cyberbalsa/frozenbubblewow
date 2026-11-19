-- Recreates display_highscores from Frozen Bubble in its original 640x480 space.
local _,FB=...
local U,S,A=FB.UI,FB.Scores,FB.Animation
local pages={"campaign","training","endless"}
local locale=GetLocale and GetLocale()
local localeFont=(locale=="koKR" or locale=="zhCN" or locale=="zhTW") and STANDARD_TEXT_FONT
local book,bold=FB.media.."DejaVuSans.ttf",FB.media.."DejaVuSans-Bold.ttf"
local function duration(seconds)
    return string.format("%d'%02d\"",math.floor(seconds/60),seconds%60)
end
local function player(row,shared)
    if not shared and row.displayName then return row.displayName end
    return row.name:match("^[^-]+") or row.name
end
-- display_highscores uses SDLPango's white "sans 11" and "sans 11 bold"
-- with a one-pixel black shadow on its 640 x 480 surface.
local function lettering(label,highlighted)
    label:SetFont(localeFont or (highlighted and bold or book),11*96/72,"")
    label:SetShadowColor(0,0,0,1); label:SetShadowOffset(1,-1)
    if localeFont and highlighted then label:SetTextColor(1,0.82,0.25)
    else label:SetTextColor(1,1,1) end
end
local function caption(text,parent,value,x,y,width)
    local label=text(parent,value,x,y,14,width)
    lettering(label); label:SetJustifyH("CENTER")
    return label
end
local function share(mode)
    local row=S.Best(mode,FB.PlayerName())
    if not row then FB.Print("Finish a scored run on this character first."); return end
    if FB.Community.state=="ready" then FB.Community.Broadcast("SCORE",S.Fields(row))
    else FB.Community.Manual("SCORE",S.Fields(row)) end
end
local function scoreRow(parent,x,y,w,h)
    local frame=CreateFrame("Frame",nil,parent)
    frame:SetSize(w,h); frame:SetPoint("TOPLEFT",x,-y); frame:EnableMouse(true)
    frame:SetScript("OnEnter",function(f)
        if not f.entry or not GameTooltip then return end
        local row=f.entry
        GameTooltip:SetOwner(f,"ANCHOR_RIGHT")
        if row.displayName and not U.shared then
            GameTooltip:SetText(row.displayName); GameTooltip:AddLine(row.name)
        else GameTooltip:SetText(row.name) end
        if row.mode=="campaign" then
            GameTooltip:AddLine(row.completed and "Campaign cleared" or ("Level "..row.level))
            if row.elapsed then
                local ms=math.floor(row.elapsed*1000+0.5)
                GameTooltip:AddLine(string.format("%d:%02d.%03d",math.floor(ms/60000),math.floor(ms/1000)%60,ms%1000))
            else GameTooltip:AddLine(duration(row.seconds)) end
        end
        GameTooltip:AddLine(row.score.." points"); GameTooltip:Show()
    end)
    frame:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    return frame
end

function U:BuildScoreEntry(text,button,input)
    local shield=self.panels.scoreEntry
    shield:ClearAllPoints(); shield:SetAllPoints(self.frame)
    local panel=CreateFrame("Frame",nil,shield)
    panel:SetSize(341,280); panel:SetScale(1.6); panel:SetPoint("CENTER")
    A.Image(panel,"panel",0,0,nil,nil,"BACKGROUND")
    caption(text,panel,"Congratulations!",0,12,341)
    caption(text,panel,"You have a highscore!",0,30,341)
    caption(text,panel,"Your name?",0,76,217)
    local box=input(panel,222,70,108,"")
    box:SetFont(localeFont or book,11*96/72,""); box:SetTextColor(1,1,1)
    self.scoreName=box; box:SetMaxLetters(24); box:SetMaxBytes(96)
    local outro=caption(text,panel,"Great game!",0,245,341)
    self.scoreOutro=outro
    local function finish(save)
        if self.screen~="scoreEntry" or InCombatLockdown() or self.scoreOutro:IsShown() then return end
        local entry=self.namingScore
        if not entry then return end
        box:ClearFocus()
        local stored=S.Submit(entry,save and box:GetText() or "")
        if FB.game and FB.game.scoreEntry==entry then FB.game.scoreEntry=stored end
        if stored then
            box:EnableMouse(false); self.scoreSubmit:Hide(); self.scoreSkip:Hide()
            box:SetText(entry.displayName); outro:Show(); self.scoreOutroTime=0
            FB.Sound("menu_selected")
        else FB.Sound("cancel"); self:ShowScores(nil,true) end
    end
    self.scoreSubmit=button(panel,"Save name",50,196,115,function() finish(true) end)
    self.scoreSkip=button(panel,"Discard",176,196,115,function() finish(false) end)
    box:SetScript("OnEnterPressed",function() finish(true) end)
    box:SetScript("OnEscapePressed",function() finish(false) end)
    box:SetScript("OnTextChanged",function(_,typed) if typed then FB.Sound("typewriter") end end)
    shield:SetScript("OnHide",function() box:ClearFocus() end)
    shield:SetScript("OnUpdate",function(_,dt)
        if self.screen=="scoreEntry" and self.namingScore and outro:IsShown() and not self.inactive and not InCombatLockdown() then
            self.scoreOutroTime=self.scoreOutroTime+dt
            if self.scoreOutroTime>=2 then self:ShowScores(self.namingScore) end
        end
    end)
end

function U:OpenRoundScores()
    if InCombatLockdown() then return end
    local game=FB.game
    if not game then return end
    local entry=game.mode=="campaign" and FB.FinishCampaignRun() or game.scoreEntry
    if not entry then
        self.scoreMode=game.mode=="training" and "training" or game.mode
        self.shared=false; self.scorePage=1; self:ShowScores(nil,true); return
    end
    self:ShowScores(entry)
end

function U:NameHighscore(entry)
    if InCombatLockdown() then return end
    if FB.game and FB.game.scoreEntry==entry then FB.game.offeredScore=true end
    self.namingScore=entry
    self.scoreMode=entry.mode=="training-chain" and "training" or entry.mode
    self.scorePage=1; self.shared=false
    self:Panel("scoreEntry"); self.result:Hide()
    self.scoreOutro:Hide(); self.scoreSubmit:Show(); self.scoreSkip:Show()
    self.scoreName:EnableMouse(true); self.scoreName:SetText(player(entry,false))
    self.scoreName:SetFocus(); self.scoreName:HighlightText()
    FB.Sound("applause")
end

function U:BuildScores(text,button,input)
    self:BuildScoreEntry(text,button,input)
    local p=self.panels.scores
    p:ClearAllPoints(); p:SetSize(640,480); p:SetScale(1.6); p:SetPoint("TOPLEFT",self.frame,"TOPLEFT")
    A.Image(p,"scores-background",0,0,640,480,"BACKGROUND")
    self.scoreHeading=A.Image(p,"scores-campaign",0,8)
    self.scoreMode,self.scorePage,self.shared="campaign",1,false
    self.scoreCards={}
    for i=1,10 do
        local x=90+(i-1)%5*98
        local y=68+math.floor((i-1)/5)*175
        local card=scoreRow(p,x-15,y-6,93,152)
        A.Image(card,"scores-frame",8,0,nil,nil,"BACKGROUND")
        card.board=A.Image(card,"score-boards",15,6)
        card.name=text(card,"",0,98,13,93); card.name:SetJustifyH("CENTER"); card.name:SetWordWrap(false)
        card.level=text(card,"",0,118,13,93); card.level:SetJustifyH("CENTER")
        card.time=text(card,"",0,138,13,93); card.time:SetJustifyH("CENTER")
        self.scoreCards[i]=card
    end
    self.scoreColumns={}
    for i=1,2 do
        local col=CreateFrame("Frame",nil,p)
        col:SetSize(320,398); col:SetPoint("TOPLEFT",(i-1)*320,-44)
        col.title=caption(text,col,"",0,6,320)
        local mode=i==1 and "training" or "training-chain"
        col.share=button(col,"Share best",251,0,67,function() share(mode) end)
        col.empty=text(col,"No scores yet",0,50,13,320); col.empty:SetJustifyH("CENTER")
        col.lines={}
        for j=1,20 do
            -- The upstream training table indents the second column by an extra 20 pixels.
            local line=scoreRow(col,i==1 and 80 or 100,36+(j-1)*18,204,18)
            line.rank=text(line,"",0,0,14,40); line.rank:SetJustifyH("RIGHT")
            line.name=text(line,"",40,0,14,164); line.name:SetWordWrap(false)
            col.lines[j]=line
        end
        self.scoreColumns[i]=col
    end
    self.scoreEmpty=text(p,"No campaign runs yet",60,177,17,520); self.scoreEmpty:SetJustifyH("CENTER")
    local function nextMode()
        local i=self.scoreMode=="campaign" and 1 or self.scoreMode=="training" and 2 or 3
        self.scoreMode=pages[i%#pages+1]; self.scorePage=1; self:RefreshScores()
    end
    self.scoreSelector=button(p,"Campaign",70,445,106,nextMode)
    button(p,"Back",8,445,58,function() self:ShowMenu() end)
    self.scoreSource=button(p,"Personal",181,445,100,function()
        self.shared=not self.shared; self.scorePage=1; self:RefreshScores()
    end)
    button(p,"Refresh shared",286,445,111,function()
        FB.Net.RequestScores()
        if FB.Community.state=="manual" then FB.Community.Manual("SCOREQ") end
        self.shared=true; self.scorePage=1; self:RefreshScores()
    end)
    self.shareBest=button(p,"Share my best",402,445,107,function() share(self.scoreMode) end)
    self.scorePrev=button(p,"<",517,445,29,function() self.scorePage=self.scorePage-1; self:RefreshScores() end)
    self.scoreNumber=text(p,"",547,451,13,51); self.scoreNumber:SetJustifyH("CENTER")
    self.scoreNext=button(p,">",600,445,29,function() self.scorePage=self.scorePage+1; self:RefreshScores() end)
    p:SetPropagateKeyboardInput(true)
    p:SetScript("OnKeyDown",function(panel,key)
        if InCombatLockdown() then return end
        local active=not self.inactive and self:HasFocus() and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
        local used=active and (key=="ESCAPE" or key=="ENTER" or key=="SPACE" or key=="LEFT" or key=="RIGHT")
        panel:SetPropagateKeyboardInput(not used)
        if not used then return end
        if key=="ESCAPE" then self:ShowMenu()
        elseif key=="LEFT" or key=="RIGHT" then
            self.scorePage=self.scorePage+(key=="LEFT" and -1 or 1); self:RefreshScores()
        else nextMode() end
    end)
end

function U:ShowScores(entry,skipPending)
    local pending=not skipPending and S.Pending(entry)
    if pending then self:NameHighscore(pending); return end
    self.namingScore=nil; self.highlightScore=entry
    if entry then
        self.scoreMode=entry.mode=="training-chain" and "training" or entry.mode
        self.shared=false
        for i,row in ipairs(S.Rows(false,entry.mode)) do
            if row==entry then
                self.scorePage=math.ceil(i/(entry.mode=="campaign" and 10 or 20))
                local game=FB.game
                if entry.mode=="endless" and game and game.scoreEntry==entry and self.scorePage==1 and not game.applauded then
                    FB.Sound("applause"); game.applauded=true
                end
                break
            end
        end
    end
    self:Panel("scores")
end

function U:RefreshScores()
    local mode=self.scoreMode
    local campaign,training=mode=="campaign",mode=="training"
    local rows=S.Rows(self.shared,mode)
    local chains=training and S.Rows(self.shared,"training-chain") or {}
    local perPage=campaign and 10 or 20
    local count=math.max(1,math.ceil(math.max(#rows,#chains)/perPage))
    self.scorePage=FB.Clamp(self.scorePage,1,count)
    local first=(self.scorePage-1)*perPage
    self.scoreSelector:SetText(S.Label(mode).." ›")
    self.scoreSource:SetText(self.shared and "Community" or "Personal")
    self.shareBest:SetShown(not training)
    self.scorePrev:SetEnabled(self.scorePage>1); self.scoreNext:SetEnabled(self.scorePage<count)
    self.scoreNumber:SetText(self.scorePage.." / "..count)
    local art=campaign and "scores-campaign" or training and "scores-training"
    if art then
        local t,info=self.scoreHeading,FB.MediaInfo[art]
        t:ClearAllPoints(); t:SetPoint("TOPLEFT",630-info.w,-8); t:SetSize(info.w,info.h); A.Frame(t,art,1)
    else self.scoreHeading:Hide() end
    self.scoreEmpty:SetShown(campaign and #rows==0)
    for i,card in ipairs(self.scoreCards) do
        local row=campaign and rows[first+i]
        card.entry=row; card:SetShown(row and true or false)
        if row then
            A.Frame(card.board,FB.db.colorblind and "score-boards-symbol" or "score-boards",row.level)
            card.name:SetText(player(row,self.shared))
            card.level:SetText(row.completed and "won!" or ("level "..row.level))
            card.time:SetText(duration(row.seconds))
            local highlighted=row==self.highlightScore and not self.shared
            lettering(card.name,highlighted); lettering(card.level,highlighted); lettering(card.time,highlighted)
        end
    end
    for i,col in ipairs(self.scoreColumns) do
        local visible=training or not campaign and i==1
        col:SetShown(visible)
        if visible then
            local entries=i==1 and rows or chains
            col:ClearAllPoints(); col:SetPoint("TOPLEFT",training and (i-1)*320 or 160,-44)
            col.title:SetText(training and (i==1 and "Regular" or "Chain-reaction enabled") or "Endless")
            col.share:SetShown(training); col.empty:SetShown(#entries==0)
            for j,line in ipairs(col.lines) do
                local idx=first+j
                local row=entries[idx]
                line.entry=row; line:SetShown(row~=nil)
                if row then
                    local prev=entries[idx-1]
                    line.rank:SetText((not prev or prev.score~=row.score) and (idx..". ") or "")
                    line.name:SetText(player(row,self.shared)..": "..row.score)
                    local highlighted=row==self.highlightScore and not self.shared
                    lettering(line.rank,highlighted); lettering(line.name,highlighted)
                end
            end
        end
    end
    self.scoreRevision=S.revision
end
