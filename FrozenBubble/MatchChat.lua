local _,FB=...
local Chat={}
FB.MatchChat=Chat

local function valid(message)
    return type(message)=="string" and #message<=120 and message:find("%S") and not message:find("%c")
end

function Chat.Send(message)
    local m=FB.Net.match
    if not m or m.phase~="playing" or not valid(message) then return false end
    if m.arena then return FB.Arena.Fan("ACHAT",m.id,message) end
    return FB.Net.Whisper("CHAT",m.id,message)
end

function Chat.Receive(m,message,player)
    if m.phase~="playing" or not valid(message) then return end
    local recipient=player or m
    recipient.chatText=message:gsub("|","||")
    recipient.chatUntil=GetTime()+10
    FB.Sound("chatted")
end

function Chat.Build(ui,text)
    local hud=ui.toolbar
    local input=CreateFrame("EditBox",nil,hud)
    input:SetSize(219,37); input:SetScale(1.6); input:SetPoint("TOPLEFT",hud,"TOPLEFT",390,-442)
    FB.Animation.Image(input,"chat-input",0,0,nil,nil,"BACKGROUND")
    input:SetFont("Fonts\\ARIALN.TTF",14,"OUTLINE"); input:SetTextInsets(15,15,0,8)
    input:SetTextColor(1,1,1); input:SetMaxBytes(120); input:SetAutoFocus(false); input:Hide()

    local peer=CreateFrame("Frame",nil,hud)
    local art=FB.MediaInfo["chat-peer"]
    peer:SetScale(1.6); peer:SetSize(art.w,art.h); peer:SetPoint("TOPLEFT",hud,"TOPLEFT",70,-465)
    FB.Animation.Image(peer,"chat-peer",0,0,nil,nil,"BACKGROUND")
    local line=text(peer,"",3,2,12,art.w-6); line:SetJustifyH("CENTER"); line:SetWordWrap(false)
    peer:Hide()

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
        input:SetText(""); input:Show(); input:SetFocus()
    end
    function Chat.Refresh()
        local m=FB.Net.match
        if recipient and (m~=recipient or m.phase~="playing") then Chat.Close() end
        local visible=ui.screen=="opponent" and m and m.phase=="playing" and m.chatUntil and GetTime()<m.chatUntil
        peer:SetShown(visible or false)
        if visible then line:SetText(m.chatText) end
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
