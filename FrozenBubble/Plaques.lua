-- Place the desktop score and clock lettering on the original 640 x 480 plaques.
local _,FB=...
local art=FB.HUDArt
local P={}; FB.Plaques=P

function P.Layout(center,prefix,value,draw)
    value=tostring(value or "")
    local width=prefix and art.labels[prefix].w or 0
    for i=1,#value do width=width+art.labels[value:sub(i,i)].w end
    local x=math.floor(center-width/2)
    if prefix then
        local g=art.labels[prefix]; draw(g,x); x=x+g.w
    end
    for i=1,#value do
        local g=art.labels[value:sub(i,i)]; draw(g,x); x=x+g.w
    end
end

local function caption(parent,center,y)
    local f=CreateFrame("Frame",nil,parent)
    f:SetScale(1.6); f:SetSize(1,1); f:SetPoint("TOPLEFT",parent,"TOPLEFT",center,-y)
    f:EnableMouse(false)
    local slots,used={},0
    local function draw(g,x)
        used=used+1
        local t=slots[used]
        if not t then
            t=f:CreateTexture(nil,"OVERLAY"); slots[used]=t
            t:SetTexture(FB.media.."hud-lettering.tga")
        end
        t:ClearAllPoints(); t:SetPoint("TOPLEFT",x,0); t:SetSize(g.w+1,g.h+1)
        t:SetTexCoord(0,(g.w+1)/art.width,g.y/art.height,(g.y+g.h+1)/art.height)
        t:Show()
    end
    function f:SetCaption(prefix,value)
        value=tostring(value or "")
        if self.fbPrefix==prefix and self.fbDigits==value then return end
        self.fbPrefix,self.fbDigits=prefix,value
        used=0; P.Layout(0,prefix,value,draw)
        for i=used+1,#slots do slots[i]:Hide() end
    end
    return f
end

function P.Build(ui)
    P.solo=caption(ui.gameLayer,74,103)
    P.left=caption(ui.gameLayer,160,11)
    P.right=caption(ui.gameLayer,480,11)
    P.clock=caption(ui.gameLayer,80,177)
    P.Clear()
end

function P.Clear()
    P.solo:Hide(); P.left:Hide(); P.right:Hide(); P.clock:Hide()
end

function P.Solo(game)
    if game.mode=="training" then return "Score: ",game.score end
    if game.mode=="random" then return "Random level" end
    if game.mode=="campaign" then return "Level ",FB.level end
    if game.customSet and game.customSet.builtin then return "Level ",game.customIndex end
end

function P.Draw(ui,game,wins)
    if wins then
        ui.hud:Hide(); ui.remoteLabel:Hide()
        P.right:SetCaption(nil,wins[1]); P.right:Show()
        P.left:SetCaption(nil,wins[2]); P.left:Show()
        return true
    end
    local prefix,value=P.Solo(game)
    if game.mode=="training" then
        local remaining=math.floor(game:TrainingTimeLeft())
        P.clock:SetCaption(nil,string.format("%d'%02d\"",math.floor(remaining/60),remaining%60))
        P.clock:Show()
    end
    if prefix then
        ui.hud:Hide(); P.solo:SetCaption(prefix,value); P.solo:Show()
        return true
    end
end
