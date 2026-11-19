-- Title-screen playback of the four original record_protocol:0 games.
local _, FB = ...
local D={idle=0, textures={}, groups={}}
FB.Demos=D
local data=FB.DemoData
local digits={}
local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for i=1,#alphabet do digits[alphabet:byte(i)]=i-1 end

local function texture(slot)
    local t=D.textures[slot]
    if t then return t end
    if slot<1500 then
        t=D.panel:CreateTexture(nil,slot<=300 and "BACKGROUND" or "BORDER",nil,1)
    else
        -- The desktop blits moving sprites in order. WoW sublevels run from -8 to 7.
        local order=slot-1500
        local group=math.floor(order/16)
        if not D.groups[group] then
            local f=CreateFrame("Frame",nil,D.panel)
            f:SetAllPoints(); f:SetFrameLevel(D.panel:GetFrameLevel()+group+1)
            D.groups[group]=f
        end
        t=D.groups[group]:CreateTexture(nil,"ARTWORK",nil,order%16-8)
    end
    D.textures[slot]=t
    return t
end

local function draw(slot,id,x,y)
    local t=texture(slot)
    if id==0 then t:Hide(); return end
    local spec=data.sprites[id]
    local kind=spec[1]
    if kind=="cannon" then
        local mini,angle,radius=spec[2],spec[3],spec[4]
        if FB.db.graphicsLevel==1 then
            local radians=(angle+100)*math.pi/200
            local dy=mini>0 and (y==200 and 3 or 2) or 1
            x=math.floor(x-1+radius*math.cos(radians)); y=math.floor(y-dy-radius*math.sin(radians))
            FB.Animation.Frame(t,"aim-dot",1); t:SetSize(2,2)
        else
            x=x+spec[5]; y=y+spec[6]
            if mini==0 then
                local info=FB.MediaInfo["cannon-angles"]
                FB.Animation.Frame(t,"cannon-angles",angle+101); t:SetSize(info.w,info.h)
            else spec=data.sprites[mini]; kind=spec[1] end
        end
    end
    if kind=="bubble" then
        FB.SetBubbleTexture(t,spec[2]); t:SetSize(32,32)
    elseif kind=="media" then
        local name,index,role=spec[2],spec[3],spec[4]
        if (role=="penguin" and FB.db.graphicsLevel<3) or (role=="effect" and FB.db.graphicsLevel==1) then t:Hide(); return end
        FB.Animation.Frame(t,name,index)
        local info=FB.MediaInfo[name]; t:SetSize(info.w,info.h)
    elseif kind=="atlas" then
        local role=spec[7]
        if (role=="penguin" and FB.db.graphicsLevel<3) or (role=="effect" and FB.db.graphicsLevel==1) then t:Hide(); return end
        if FB.db.colorblind and spec[8]>0 then spec=data.sprites[spec[8]] end
        local name="demo-art-"..spec[2]
        if t.fbAsset~=name then t:SetTexture(FB.media..name..".tga"); t.fbAsset=name end
        local l,top,w,h=spec[3],spec[4],spec[5],spec[6]
        t:SetTexCoord(l/1024,(l+w)/1024,top/1024,(top+h)/1024)
        t:SetSize(w,h)
    end
    t:ClearAllPoints(); t:SetPoint("TOPLEFT",D.panel,"TOPLEFT",x,-y); t:Show()
end

local function cover()
    D.wipeStep=(D.wipeStep or 0)+1
    if D.wipeStep>35 then FB.UI:ShowMenu(); return end
    local u=(D.wipeStep-0.5)/64
    D.wipe:SetTexCoord(u,u,0,480/512); D.wipe:Show()
end

local function dismiss()
    if D.wipeStep then FB.UI:ShowMenu() else cover() end
end

local function step()
    if D.wipeStep then cover(); return end
    local row=D.scene.frames[D.frame+1]
    if not row then cover(); return end
    D.frame=D.frame+1
    for i=1,#row,8 do
        local a,b,c,d,e,f,g,h=row:byte(i,i+7)
        local slot,id=digits[a]*64+digits[b],digits[c]*64+digits[d]
        if slot==0 then FB.Sound(data.sounds[id])
        else draw(slot,id,digits[e]*64+digits[f]-512,digits[g]*64+digits[h]-512) end
    end
end

function D.Close()
    D.idle=0
    if D.scene then
        D.scene=nil; D.wipeStep=nil; D.wipe:Hide(); D.panel:EnableKeyboard(false); D.panel:Hide()
        for _,t in pairs(D.textures) do t:Hide() end
    end
end

local function build()
    local ui=FB.UI
    local panel=CreateFrame("Frame",nil,ui.frame)
    D.panel=panel
    panel:SetSize(640,480); panel:SetScale(1.6); panel:SetPoint("TOPLEFT")
    panel:SetFrameLevel(ui.layers.menu); panel:SetClipsChildren(true); panel:EnableMouse(true)
    panel:SetScript("OnMouseDown",function() if not InCombatLockdown() then dismiss() end end)
    panel:SetScript("OnKeyDown",function(f)
        if InCombatLockdown() then return end
        local active=ui:HasFocus() and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
        f:SetPropagateKeyboardInput(not active)
        if active then dismiss() end
    end)
    FB.Controls.InstallAudioKeys(panel)
    D.background=panel:CreateTexture(nil,"BACKGROUND",nil,-1)
    D.background:SetAllPoints()
    local coverLayer=CreateFrame("Frame",nil,panel)
    coverLayer:SetAllPoints(); coverLayer:SetFrameLevel(ui.layers.chrome-1)
    D.wipe=coverLayer:CreateTexture(nil,"OVERLAY")
    D.wipe:SetTexture(FB.media.."demo-wipe.tga"); D.wipe:SetAllPoints(); D.wipe:Hide()
end

-- The first trace contains the SDL background patches and the attached
-- sprites separately. The opening effect runs before the moving sprites.
function D.Opening(index,sprite)
    local scene=data.scenes[index]
    sprite(scene.background,0,0,640,480,-8)
    local row=scene.frames[1]
    for i=1,#row,8 do
        local a,b,c,d,e,f,g,h=row:byte(i,i+7)
        local slot,id=digits[a]*64+digits[b],digits[c]*64+digits[d]
        if slot>0 and slot<1500 and id>0 then
            local spec=data.sprites[id]
            local x,y=digits[e]*64+digits[f]-512,digits[g]*64+digits[h]-512
            local order=slot<=300 and -2 or 0
            if spec[1]=="bubble" then
                sprite((FB.db.colorblind and "bubble-symbol" or "bubble")..spec[2],x,y,32,32,order)
            elseif spec[1]=="media" then
                local info=FB.MediaInfo[spec[2]]
                sprite(spec[2],x,y,info.w,info.h,order)
            elseif spec[1]=="atlas" then
                if FB.db.colorblind and spec[8]>0 then spec=data.sprites[spec[8]] end
                sprite("demo-art-"..spec[2],x,y,spec[5],spec[6],order,spec[3],spec[4])
            end
        end
    end
end

function D.Start(index)
    FB.Transitions.Open("demo",index)
end
function D.Play(index)
    if not D.panel then build() end
    local ui=FB.UI
    D.scene=data.scenes[index]; D.frame=0; D.elapsed=0
    ui.menu:EnableKeyboard(false); ui.menu:Hide(); ui.screen="demo"
    if D.scene.background=="arena-background" then
        D.background:SetTexture(FB.media.."arena-background.tga"); D.background.fbAsset="arena-background"
        D.background:SetTexCoord(0,640/1024,0,480/512)
    else FB.Animation.Frame(D.background,D.scene.background,1) end
    D.panel:Show(); D.panel:EnableKeyboard(true); D.panel:SetPropagateKeyboardInput(true)
    step(); FB.Music()
end

function D.Update(dt)
    local ui=FB.UI
    if ui.screen~="menu" and ui.screen~="demo" then return end
    if FB.db.titleDemos==false or FB.db.reducedMotion or FB.Net.match or FB.Net.queue or InCombatLockdown() then
        D.idle=0
        if D.scene then ui:ShowMenu() end
        return
    end
    if ui.inactive or not ui:HasFocus() or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) then
        D.idle=0; return
    end
    if not D.scene then
        local x,y=GetCursorPosition()
        if D.mouseX~=x or D.mouseY~=y then D.idle=0; D.mouseX,D.mouseY=x,y end
        D.idle=D.idle+math.min(dt,0.25)
        if D.idle>=20-1e-9 then D.Start(math.random(#data.scenes)) end
    else
        D.elapsed=D.elapsed+math.min(dt,0.25)
        while D.scene and D.elapsed+1e-9>=0.02 do
            D.elapsed=D.elapsed-0.02; step()
        end
    end
end
