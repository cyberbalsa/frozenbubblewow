local _,FB=...
local K={}
FB.Controls=K

-- Original order in the Keys menu. Numeric IDs also index the saved profile.
K.questions={"Player 1, turn left?","Player 1, turn right?","Player 1, fire?","Player 1, center?",
    "Player 2, turn left?","Player 2, turn right?","Player 2, fire?","Player 2, center?",
    "Toggle full window?","Chat (net game)?"}
K.defaults={"LEFT","RIGHT","UP","DOWN","X","V","C","D","F","ENTER"}
local aliases={"A","D","SPACE"}

function K.Valid(key)
    return type(key)=="string" and #key>0 and #key<=24 and key~="ESCAPE" and key~="UNKNOWN"
        and key~="PAUSE" and not key:find("[%s%c|]") and key==key:upper()
end

function K.Load(profile)
    local seen={}
    for i=1,#K.defaults do
        local key=type(profile)=="table" and profile[i]
        if not K.Valid(key) or seen[key] then profile=K.defaults; break end
        seen[key]=true
    end
    local keys,shared,solo={},{},{}
    for i=1,#K.defaults do
        local key=profile[i]
        keys[i]=key; shared[key]=i
        if i<=4 or i>=9 then solo[key]=i end
    end
    for i,key in ipairs(aliases) do
        if keys[i]==K.defaults[i] and not solo[key] then solo[key]=i end
    end
    K.keys,K.shared,K.solo=keys,shared,solo
    FB.db.bindings=keys
end

function K.Held(pressed,i)
    if pressed[K.keys[i]] then return true end
    local alias=aliases[i]
    return alias and K.solo[alias]==i and pressed[alias]
end

function K.Aim(game,left,right,center,step)
    local old=game.angle
    local angle=old+(right and step or 0)-(left and step or 0)
    if center then
        if math.abs(angle)<=step then angle=0
        else angle=angle+(angle>0 and -step or step) end
    end
    game.angle=FB.Clamp(angle,-FB.Engine.MAX_ANGLE,FB.Engine.MAX_ANGLE)
    game.turning=right and 1 or left and -1 or 0
    game.poseAngle=game.angle
end

function K.Build(ui,text,button)
    local panel=ui.panels.keys
    panel:ClearAllPoints(); panel:SetScale(1.6); panel:SetSize(341,280); panel:SetPoint("CENTER",ui.frame,"CENTER")
    FB.Animation.Image(panel,"panel",0,0,nil,nil,"BACKGROUND")
    text(panel,"Please enter new keys:",0,12,14,341):SetJustifyH("CENTER")
    local prompts,answers={},{}
    local status=text(panel,"",0,243,14,341); status:SetJustifyH("CENTER")
    local draft,held,step,finishAt
    for i,question in ipairs(K.questions) do
        local y=40+(i-1)*18+(i>4 and 9 or 0)+(i>8 and 9 or 0)
        prompts[i]=text(panel,question,0,y,14,217); prompts[i]:SetJustifyH("RIGHT")
        answers[i]=text(panel,"",227,y,14,100)
    end
    local function refresh()
        for i=1,#prompts do
            prompts[i]:SetShown(i<=step); answers[i]:SetShown(i<=step)
            answers[i]:SetText(draft[i] or "("..K.keys[i]..")")
        end
    end
    local function cancel()
        if not finishAt then FB.Sound("cancel") end
        ui:ShowMenu()
    end
    local back=button(panel,"Cancel",9,247,68,cancel)
    function K.Begin()
        draft,held,step,finishAt={},{},1,nil
        status:SetText(""); back:Show(); refresh()
    end
    function K.WaitForRelease(key) held[key]=true end
    panel:SetPropagateKeyboardInput(true)
    panel:SetScript("OnKeyDown",function(f,key)
        if InCombatLockdown() then return end
        local capture=not ui.inactive and ui:HasFocus() and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
        f:SetPropagateKeyboardInput(not capture)
        if not capture or held[key] then return end
        held[key]=true
        if key=="ESCAPE" then cancel(); return end
        if finishAt then return end
        if not K.Valid(key) then status:SetText("Choose another key."); return end
        for _,assigned in ipairs(draft) do
            if assigned==key then status:SetText("Key already used."); return end
        end
        draft[step]=key; step=step+1; FB.Sound("typewriter"); status:SetText("")
        if step>#K.defaults then
            K.Load(draft); finishAt=GetTime()+2; back:Hide()
            status:SetText("Thanks!"); FB.Sound("menu_selected")
        end
        refresh()
    end)
    panel:SetScript("OnKeyUp",function(_,key) if held then held[key]=nil end end)
    panel:SetScript("OnUpdate",function()
        if ui.inactive or not ui:HasFocus() then held={} end
        if finishAt and GetTime()>=finishAt then finishAt=nil; ui:ShowMenu() end
    end)
end
