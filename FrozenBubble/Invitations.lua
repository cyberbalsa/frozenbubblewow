local _, FB = ...
local I={nextCheck=0}
FB.Invitations=I

local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end

-- Units are yards for UnitPosition and normalized map coordinates for C_Map.
-- Retain only the last anchor in memory. Tiny successive steps accumulate.
local function position()
    if UnitPosition then
        local ok,x,y,z,map=pcall(UnitPosition,"player")
        if ok and readable(x) and readable(y) and readable(z) and readable(map)
            and type(x)=="number" and type(y)=="number" and map~=nil then
            return "world",map,x,y,z or 0,0.5
        end
    end
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local map=C_Map.GetBestMapForUnit("player")
        if readable(map) and map then
            local point=C_Map.GetPlayerMapPosition(map,"player")
            if readable(point) and point then
                local x,y=point:GetXY()
                if readable(x) and readable(y) and x and y then return "map",map,x,y,0,0.0001 end
            end
        end
    end
end

function I.Dismiss()
    I.reason=nil
    if I.popup then I.popup:Hide() end
end
function I.Activity()
    I.lastActivity=GetTime(); I.idleOffered=false
    if I.reason=="idle" then I.Dismiss() end
end

local function blocked()
    return InCombatLockdown() or FB.UI.frame:IsShown() or FB.Net.queue
        or FB.Net.match and FB.Net.match.phase~="done"
        or UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
        or SettingsPanel and SettingsPanel:IsShown()
        or GameMenuFrame and GameMenuFrame:IsShown()
        or CinematicFrame and CinematicFrame:IsShown()
        or MovieFrame and MovieFrame:IsShown()
end

local function onTaxi()
    local taxi=UnitOnTaxi and UnitOnTaxi("player")
    return readable(taxi) and taxi and true or false
end

local function accept()
    local reason=I.reason
    I.Dismiss()
    if not reason or blocked() or reason=="flight" and not onTaxi() then return end
    FB.UI.frame:Show()
    if FB.game and FB.game.status=="playing" and not FB.UI.editing then FB.UI:ShowGame()
    else FB.UI:ShowMenu() end
end

local function buildPopup()
    local frame=CreateFrame("Frame","FrozenBubblePlayInvitation",UIParent,"BackdropTemplate")
    frame:SetSize(236,84); frame:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-35,-205)
    frame:SetFrameStrata("DIALOG"); frame:SetClampedToScreen(true); frame:EnableMouse(true)
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=12})
    local label=frame:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOP",0,-10); label:SetText("Frozen Bubble Forever")
    local question=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); question:SetPoint("TOP",0,-30)
    for index,action in ipairs({{"Play",accept},{"Later",I.Dismiss}}) do
        local b=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
        b:SetSize(94,23); b:SetPoint("BOTTOMLEFT",19+(index-1)*103,9); b:SetText(action[1])
        b:SetScript("OnClick",action[2])
    end
    frame:Hide(); I.popup=frame; I.question=question
end

local function offer(reason)
    if not I.popup then buildPopup() end
    I.reason=reason; I.expires=GetTime()+FB.db.promptSeconds
    I.question:SetText(reason=="flight" and "Play while you’re on this flight?" or "Have time for a round?")
    I.popup:Show()
end

local function checkPosition()
    local kind,map,x,y,z,tolerance=position()
    local anchor=I.anchor
    if kind then
        if not anchor or kind~=anchor.kind or map~=anchor.map
            or (x-anchor.x)^2+(y-anchor.y)^2+(z-anchor.z)^2>tolerance^2 then
            I.anchor={kind=kind,map=map,x=x,y=y,z=z}
            I.Activity()
        end
    elseif anchor then
        I.anchor=nil; I.Activity()
    end
    local speed=GetUnitSpeed and GetUnitSpeed("player")
    if readable(speed) and speed and speed>0 then I.Activity() end
end

local function busyCasting(api)
    if not api then return false end
    local name,_,_,_,_,craft=api("player")
    if not readable(name) or not readable(craft) then return true end
    return name and (not craft or not FB.db.craftingPrompt)
end

function I.Update()
    if not I.inWorld or GetTime()<I.nextCheck then return end
    local now=GetTime(); I.nextCheck=now+1
    if not FB.db.flightPrompt and not FB.db.idlePrompt then return end
    if InCombatLockdown() then I.Dismiss(); I.Activity(); return end
    local taxi=onTaxi()
    if not taxi then
        if I.taxi and I.reason=="flight" then I.Dismiss() end
        I.flightOffered=false
    end
    I.taxi=taxi
    if blocked() then I.Dismiss(); I.Activity(); return end
    if I.reason and now>=I.expires then I.Dismiss() end
    if taxi then
        I.Activity(); I.anchor=nil
        if FB.db.flightPrompt and not I.flightOffered then I.flightOffered=true; offer("flight") end
        return
    end
    if not FB.db.idlePrompt then return end
    checkPosition()
    local x,y=GetCursorPosition()
    if not I.reason and I.cursorX and ((x-I.cursorX)^2+(y-I.cursorY)^2>16) then I.Activity() end
    I.cursorX,I.cursorY=x,y
    if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() or busyCasting(UnitCastingInfo) or busyCasting(UnitChannelInfo) then
        I.Activity(); return
    end
    if not I.idleOffered and now>=I.lastActivity+FB.db.idleSeconds then
        I.idleOffered=true; offer("idle")
    end
end

function I.SettingsChanged(key)
    if I.reason=="flight" and not FB.db.flightPrompt or I.reason=="idle" then I.Dismiss() end
    if key~="flightPrompt" then I.Activity() end
    I.nextCheck=0
end

function I.Init()
    local events=CreateFrame("Frame")
    local names={"PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED","PLAYER_STARTED_MOVING","PLAYER_STOPPED_MOVING","PLAYER_STARTED_TURNING",
        "GLOBAL_MOUSE_DOWN","PLAYER_TARGET_CHANGED","PLAYER_DEAD"}
    for _,event in ipairs(names) do events:RegisterEvent(event) end
    events:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_LEAVING_WORLD" then I.inWorld=false; I.Dismiss()
        elseif event=="PLAYER_ENTERING_WORLD" then I.inWorld=true; I.nextCheck=0; I.anchor=nil; I.Activity()
        elseif event=="GLOBAL_MOUSE_DOWN" then
            if not I.reason or not I.popup:IsMouseOver() then I.Activity() end
        else
            if event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_DEAD" then I.Dismiss() end
            I.Activity()
        end
    end)
    I.lastActivity=GetTime()
end
