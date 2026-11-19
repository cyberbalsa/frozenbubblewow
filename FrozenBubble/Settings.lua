local _, FB = ...
local Options = {controls={}}
FB.Options = Options

local defaults = {
    minimap=true, flightPrompt=true, idlePrompt=true, idleSeconds=90, promptSeconds=30, craftingPrompt=true,
    sound=true, music=true, musicVolume=0.8, windowSize=1, reducedMotion=false,
    fadeOnBlur=true, colorblind=false, debug=true, community=false,
}

function Options.Set(key,value)
    if FB.db[key]==value then return end
    FB.db[key]=value
    if key=="minimap" and Options.icon then Options.icon:SetShown(value) end
    if key=="colorblind" then
        FB.UI:SelectEditorColor(FB.UI.editorColor)
        if FB.UI.screen=="scores" then FB.UI:RefreshScores() end
    end
    if key=="windowSize" then FB.UI:Resize() end
    if key=="music" or key=="musicVolume" then FB.Music() end
    if key=="sound" or key=="music" or key=="musicVolume" then FB.UI:Options() end
    if key=="flightPrompt" or key=="idlePrompt" or key=="idleSeconds" or key=="craftingPrompt" then
        FB.Invitations.SettingsChanged(key)
    end
    local setting=Options.controls[key]
    if setting and setting.NotifyUpdate then setting:NotifyUpdate() end
end

function Options.Open()
    if InCombatLockdown() then return end
    if Options.category then Settings.OpenToCategory(Options.category:GetID()) end
end

local function registerPage()
    if not Settings or not Settings.RegisterVerticalLayoutCategory then return end
    local category,layout=Settings.RegisterVerticalLayoutCategory("Frozen Bubble Forever")
    Options.category=category
    local function header(title)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(title))
    end
    local function setting(key,label)
        local default=defaults[key]
        local kind=type(default)=="boolean" and Settings.VarType.Boolean or Settings.VarType.Number
        local proxy=Settings.RegisterProxySetting(category,"FrozenBubbleForever_"..key,kind,label,default,
            function() return FB.db[key] end,function(value) Options.Set(key,value) end)
        Options.controls[key]=proxy
        return proxy
    end
    local function check(key,label,help)
        Settings.CreateCheckbox(category,setting(key,label),help)
    end
    local function slider(key,label,low,high,step,formatter)
        local range=Settings.CreateSliderOptions(low,high,step)
        range:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,formatter)
        Settings.CreateSlider(category,setting(key,label),range)
    end
    local function percent(value) return math.floor(value*100+0.5).."%" end
    header("Launcher and invitations")
    check("minimap","Show minimap button","Click to open or close the game. Right-click for settings. Drag to move it.")
    check("flightPrompt","Invite me on flight paths","Show a small invitation once per taxi ride.")
    check("idlePrompt","Invite me while standing idle","Show an invitation after staying in one place. Movement and manual activity restart the timer.")
    slider("idleSeconds","Idle time before invitation",60,120,5,function(value) return value.." seconds" end)
    check("craftingPrompt","Allow idle invitations during crafting","Let an unattended crafting queue count as idle time.")
    slider("promptSeconds","Invitation display time",10,60,5,function(value) return value.." seconds" end)
    header("Game window and audio")
    slider("windowSize","Game window size",0.55,1,0.05,percent)
    check("fadeOnBlur","Fade when the pointer leaves the game","Fade the window and pause solo play when it loses focus.")
    check("colorblind","Colorblind bubble symbols","Give each bubble color its own shape in all game modes and the editor.")
    check("reducedMotion","Reduce menu and penguin animation")
    check("sound","Play sound effects")
    check("music","Play game music")
    slider("musicVolume","Game music volume",0.1,1,0.05,percent)
    header("Community and diagnostics")
    check("community","Rejoin the community channel at login")
    check("debug","Save debug messages","View recent entries with /fb debug.")
    Settings.RegisterAddOnCategory(category)
end

local function positionIcon()
    local angle=FB.db.minimapAngle
    Options.icon:ClearAllPoints()
    Options.icon:SetPoint("CENTER",Minimap,"CENTER",math.cos(angle)*Minimap:GetWidth()/2,math.sin(angle)*Minimap:GetHeight()/2)
end

local function createIcon()
    if not Minimap then return end
    local button=CreateFrame("Button","FrozenBubbleMinimapButton",Minimap)
    Options.icon=button
    button:SetSize(32,32); button:SetFrameLevel(Minimap:GetFrameLevel()+5)
    button:RegisterForClicks("LeftButtonUp","RightButtonUp"); button:RegisterForDrag("LeftButton")
    local art=button:CreateTexture(nil,"ARTWORK"); art:SetSize(24,24); art:SetPoint("CENTER"); art:SetTexture(FB.media.."logo.tga")
    local mask=button:CreateMaskTexture()
    mask:SetAllPoints(art); mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    art:AddMaskTexture(mask)
    local border=button:CreateTexture(nil,"OVERLAY"); border:SetSize(54,54); border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnEnter",function()
        GameTooltip:SetOwner(button,"ANCHOR_LEFT")
        GameTooltip:AddLine("Frozen Bubble Forever")
        GameTooltip:AddLine("Click to play   ·   Right-click for settings",1,1,1)
        GameTooltip:AddLine("Drag to move",0.8,0.8,0.8); GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    button:SetScript("OnClick",function(_,which)
        if InCombatLockdown() then return end
        if which=="RightButton" then Options.Open() else FB.UI.frame:SetShown(not FB.UI.frame:IsShown()) end
    end)
    button:SetScript("OnDragStart",function()
        GameTooltip:Hide()
        button:SetScript("OnUpdate",function()
            local x,y=GetCursorPosition()
            local cx,cy=Minimap:GetCenter()
            if cx and cy then
                local scale=Minimap:GetEffectiveScale()
                FB.db.minimapAngle=math.atan2(y/scale-cy,x/scale-cx); positionIcon()
            end
        end)
    end)
    button:SetScript("OnDragStop",function() button:SetScript("OnUpdate",nil) end)
    positionIcon(); button:SetShown(FB.db.minimap)
end

function Options.Init()
    for key,default in pairs(defaults) do
        if type(FB.db[key])~=type(default) then FB.db[key]=default end
    end
    FB.db.idleSeconds=FB.Clamp(FB.db.idleSeconds,60,120)
    FB.db.minimapAngle=tonumber(FB.db.minimapAngle) or 2.35
    registerPage(); createIcon()
end
