local _,FB=...
local Chat={}
FB.MatchChat=Chat

local function valid(message)
    return type(message)=="string" and #message<=120 and message:find("%S") and not message:find("%c")
end

function Chat.Send(message)
    local m=FB.Net.match
    if not m or m.phase~="playing" or not valid(message) then return false end
    if m.arena then
        local recipients=0
        for _,player in pairs(m.players) do
            if player.name~=m.me and not player.left then recipients=recipients+1 end
        end
        if not FB.Net.CanQueue(recipients) then return false end
        return FB.Arena.Fan("ACHAT",m.id,message)
    end
    return FB.Net.Whisper("CHAT",m.id,message)
end

function Chat.Display(board,message)
    if not board or not valid(message) then return end
    board.chatText=message:gsub("|","||")
    -- SDL counts down 500 times, once on erase and once on draw per 20 ms tick.
    board.chatFrames=250
    board.sound("chatted")
    return true
end
function Chat.Step(board)
    if board.chatFrames then
        board.chatFrames=board.chatFrames-1
        if board.chatFrames==0 then board.chatText,board.chatFrames=nil,nil end
    end
end
function Chat.Receive(m,message,player)
    if m.phase=="playing" and Chat.Display((player or m).remote,message) then
        FB.Recordings.OnlineEvent(m,"chat",player and player.index or 0,message)
    end
end

local locale=GetLocale and GetLocale()
local face=(locale=="koKR" or locale=="zhCN" or locale=="zhTW") and STANDARD_TEXT_FONT or FB.media.."DejaVuSans.ttf"
function Chat.Panel(parent,asset,x,y,scale)
    local panel=CreateFrame("Frame",nil,parent)
    local art=FB.MediaInfo[asset]
    panel:SetSize(art.w,art.h); panel:SetScale(scale); panel:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    FB.Animation.Image(panel,asset,0,0,nil,nil,"BACKGROUND")
    local line=panel:CreateFontString(nil,"OVERLAY")
    line:SetFont(face,32/3,""); line:SetPoint("TOPLEFT",3,-3); line:SetWidth(art.w-6)
    line:SetJustifyH("CENTER"); line:SetJustifyV("TOP"); line:SetWordWrap(false)
    line:SetTextColor(1,1,1); line:SetShadowColor(0,0,0,1); line:SetShadowOffset(1,-1)
    panel.line=line; panel:Hide()
    return panel
end
function Chat.Build(ui)
    local hud=ui.toolbar
    local input=CreateFrame("EditBox",nil,hud)
    input:SetSize(219,37); input:SetScale(1.6); input:SetPoint("TOPLEFT",hud,"TOPLEFT",390,-442)
    FB.Animation.Image(input,"chat-input",0,0,nil,nil,"BACKGROUND")
    input:SetFont(face,40/3,""); input:SetTextInsets(15,15,5,0); input:SetJustifyV("TOP")
    input:SetTextColor(0,0,0); input:SetShadowColor(1,1,1,1); input:SetShadowOffset(1,-1)
    input:SetMaxBytes(120); input:SetAutoFocus(false); input:Hide()
    local measure=input:CreateFontString(nil,"ARTWORK")
    measure:SetFont(face,40/3,""); measure:Hide()
    local previous=""
    input:SetScript("OnTextChanged",function(box,typed)
        local value=box:GetText()
        if typed then
            measure:SetText((value:gsub("|","||")))
            if measure:GetStringWidth()>=189 then
                local cursor=math.max(0,box:GetCursorPosition()-(#value-#previous))
                box:SetText(previous); box:SetCursorPosition(cursor); FB.Sound("stick"); return
            end
            FB.Sound("typewriter")
        end
        previous=value
    end)
    local peer=Chat.Panel(ui.gameLayer,"chat-peer",70,465,1.6)
    peer:SetFrameLevel(ui.layers.hud+1)

    function Chat.Position(arena)
        input:ClearAllPoints(); input:SetPoint("TOPLEFT",hud,"TOPLEFT",arena and 215 or 390,-442)
    end
    local recipient
    function Chat.Close()
        recipient=nil; input:ClearFocus(); input:Hide(); peer:Hide()
    end
    function Chat.Open()
        local m=FB.Net.match
        if not m or m.phase~="playing" or InCombatLockdown() or ui.screen~="opponent" then return end
        recipient=m; ui.keys={}; ui.board:EnableKeyboard(false)
        previous=""; input:SetText(""); input:Show(); input:SetFocus()
    end
    function Chat.Refresh(replay)
        local m=FB.Net.match
        if recipient and (m~=recipient or m.phase~="playing") then Chat.Close() end
        local board=replay and replay.left or ui.screen=="opponent" and m and m.remote
        local message=board and board.chatText
        peer:SetShown(not not message)
        if message then peer.line:SetText(message) end
    end
    local function closeInput()
        Chat.Close()
        if not InCombatLockdown() and not ui.inactive and ui.screen=="opponent" and ui.board:IsMouseOver() then
            ui.board:EnableKeyboard(true); ui.board:SetPropagateKeyboardInput(true)
        end
    end
    input:SetScript("OnEscapePressed",closeInput)
    input:SetScript("OnEnterPressed",function()
        local message=input:GetText()
        if recipient==FB.Net.match and valid(message) and not Chat.Send(message) then
            FB.Print("Chat is busy. Press Enter to retry."); return
        end
        closeInput()
    end)
    input:SetScript("OnEditFocusLost",function() recipient=nil; input:Hide() end)
    Chat.input=input
end
