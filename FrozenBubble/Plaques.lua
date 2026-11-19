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

-- SDLPango shapes these standard ligatures before kerning. Split remaining
-- characters at UTF-8 boundaries so accented names can use the same atlas.
local function tokens(value,font)
    local result={}
    local i=1
    while i<=#value do
        local c=value:match("^ffi",i) or value:match("^ffl",i) or value:match("^f[fil]",i)
            or value:match("^.[\128-\191]*",i)
        if not font.glyphs[c] then return end
        result[#result+1]=c; i=i+#c
    end
    return result
end

function P.NameLayout(center,name,wins,size,limit,draw)
    local font=FB.NameArt[size]
    local letters=tokens(name,font)
    if not letters then return false end
    local score=wins~=nil and tokens(": "..wins,font) or {}
    local origin,edge
    local function layout(list,x,previous,paint)
        for _,c in ipairs(list) do
            local g=font.glyphs[c]
            local kern=font.kern[previous]
            x=x+(kern and kern[c] or 0)
            if paint and g.w then
                local left=x+g.dx
                local first,last=math.max(left,origin),math.min(left+g.w,edge)
                if first==left and last==left+g.w then draw(g,left,g.dy)
                elseif first<last then
                    draw({x=g.x+first-left,y=g.y,w=last-first,h=g.h,solid=g.solid,skip=first-left},first,g.dy)
                end
            end
            x=x+g.advance; previous=c
        end
        return x,previous
    end
    local function width()
        local x,last=layout(letters,0)
        return layout(score,x,last)
    end
    local w=width()
    if w>limit then
        repeat
            letters[#letters]="…"
            w=width()
            if w<=limit then break end
            letters[#letters]=nil
        until #letters==0
    end
    origin=math.floor(center-w/2); edge=origin+w
    local x,last=layout(letters,origin,nil,true)
    layout(score,x,last,true)
    return true
end

-- Only keep realm qualifiers when the two character names would collide.
function P.DuelNames(player,peer)
    local own,other=player:match("^[^-]+"),peer:match("^[^-]+")
    if own==other then return player,peer end
    return own,other
end

function P.Caption(parent,center,y,scale)
    local f=CreateFrame("Frame",nil,parent)
    f:SetScale(scale or 1.6); f:SetSize(1,1); f:SetPoint("TOPLEFT",parent,"TOPLEFT",center,-y)
    f:EnableMouse(false)
    local slots,used={},0
    local fallback
    local function glyph(asset,atlas,g,x,y,w,h,shadow)
        used=used+1
        local t=slots[used]
        if not t then t=f:CreateTexture(nil,"OVERLAY"); slots[used]=t end
        if t.fbAsset~=asset then t:SetTexture(FB.media..asset..".tga"); t.fbAsset=asset end
        local shade=shadow and 0 or 1
        t:SetVertexColor(shade,shade,shade); t:SetDrawLayer("OVERLAY",shadow and -1 or 0)
        t:ClearAllPoints(); t:SetPoint("TOPLEFT",x,-y); t:SetSize(w,h)
        local left=g.x or 0
        t:SetTexCoord(left/atlas.width,(left+w)/atlas.width,g.y/atlas.height,(g.y+h)/atlas.height)
        t:Show()
    end
    local function trim()
        for i=used+1,#slots do slots[i]:Hide() end
    end
    function f:SetCaption(prefix,value)
        value=tostring(value or "")
        if self.fbPrefix==prefix and self.fbDigits==value and not self.fbName then return end
        self.fbPrefix,self.fbDigits,self.fbName=prefix,value,nil
        if fallback then fallback:Hide() end
        used=0
        P.Layout(0,prefix,value,function(g,x) glyph("hud-lettering",art,g,x,0,g.w+1,g.h+1) end)
        trim()
    end
    function f:SetNameScore(name,wins,size,limit)
        if self.fbName==name and self.fbWins==wins and self.fbFace==size and self.fbLimit==limit then return end
        self.fbName,self.fbWins,self.fbFace,self.fbLimit=name,wins,size,limit
        used=0
        local native=P.NameLayout(0,name,wins,size,limit,function(g,x,y)
            glyph("name-lettering",FB.NameArt,g,x+1,y+1,g.w,g.h,true)
            glyph("name-lettering",FB.NameArt,g,x,y,g.w,g.h)
        end)
        trim()
        if native then
            if fallback then fallback:Hide() end
        else
            -- Let the client's locale font shape scripts outside the atlas.
            if not fallback then
                fallback=f:CreateFontString(nil,"OVERLAY","GameFontNormal")
                fallback:SetPoint("TOP",f,"TOPLEFT")
                fallback:SetTextColor(1,1,1); fallback:SetShadowColor(0,0,0,1)
                fallback:SetShadowOffset(1,-1); fallback:SetWordWrap(false)
            end
            fallback:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size*96/72)
            fallback:SetText(wins~=nil and name..": "..wins or name)
            local width=fallback:GetStringWidth() or 0
            fallback:SetScale(width>limit and limit/width or 1); fallback:Show()
        end
    end
    return f
end

function P.Build(ui)
    P.solo=P.Caption(ui.gameLayer,74,103)
    P.left=P.Caption(ui.gameLayer,160,11)
    P.right=P.Caption(ui.gameLayer,480,11)
    P.center=P.Caption(ui.gameLayer,320,12)
    P.clock=P.Caption(ui.gameLayer,80,177)
    P.Clear()
end

function P.Clear()
    P.solo:Hide(); P.left:Hide(); P.right:Hide(); P.clock:Hide(); P.center:Hide()
end

function P.Solo(game)
    if game.mode=="training" then return "Score: ",game.score end
    if game.mode=="random" then return "Random level" end
    if game.mode=="campaign" then return "Level ",FB.level end
    if game.customSet and game.customSet.builtin then return "Level ",game.customIndex end
end

function P.Duel(ui,player,peer,wins,losses)
    local own,other=P.DuelNames(player,peer)
    ui.hud:Hide(); ui.remoteLabel:Hide()
    P.right:SetNameScore(own,wins,14,216); P.right:Show()
    P.left:SetNameScore(other,losses,14,216); P.left:Show()
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
