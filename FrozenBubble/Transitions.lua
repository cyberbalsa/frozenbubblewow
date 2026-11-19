-- The opening blit in init_game reveals the new board over the previous screen.
local _,FB=...
local T={sprites={},patches={},localeCaptions={}}
FB.Transitions=T

local function choose(layout)
    local roll=math.random(8)
    if roll<=2 then return math.random(2)==1 and "horizontal" or "vertical" end
    if roll<=5 then
        local kind=math.random(3)
        if kind==1 then
            local mirror=math.random(4)
            return "plasma",mirror==2 or mirror==4,mirror>=3
        elseif kind==2 then return "points" end
        return layout..(math.random(2)==1 and "-light" or "-dark")
    end
    if roll==6 then return math.random(2)==1 and "circle-out" or "circle-in" end
    return roll==7 and "bars" or "squares"
end

local function maskFrame(mask,key,step,flipX,flipY,glyph)
    local spec=FB.RevealData[key]
    local page=math.floor(step/spec.capacity)+1
    local cell=step%spec.capacity
    local sheet=spec.sheets[page]
    if mask.fbKey~=key or mask.fbPage~=page then
        mask:SetTexture(FB.media.."Reveals\\"..key.."-"..page..".blp","CLAMP","CLAMP","NEAREST")
        mask.fbKey,mask.fbPage=key,page
    end
    local x,y=cell%spec.cols*spec.w,math.floor(cell/spec.cols)*spec.h
    local w,h=spec.w,spec.h
    if glyph and spec.w>1 then
        local border=glyph.x and 0 or 1
        x,y=x+(glyph.x or 0),y+glyph.y; w,h=glyph.w+border,glyph.h+border
    end
    local l,r=x/sheet[1],(x+w)/sheet[1]
    local t,b=y/sheet[2],(y+h)/sheet[2]
    if flipX then l,r=r,l end
    if flipY then t,b=b,t end
    mask:SetTexCoord(l,r,t,b)
end

local function build()
    local ui=FB.UI
    local frame=CreateFrame("Frame",nil,ui.frame)
    frame:SetScale(1.6); frame:SetSize(640,480); frame:SetPoint("TOPLEFT")
    frame:SetFrameLevel(ui.layers.chrome-1); frame:SetClipsChildren(true)
    frame:EnableMouse(true); frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseDown",T.Interrupt)
    frame:SetScript("OnKeyDown",function(f,key)
        local focus=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        local skip=not InCombatLockdown() and ui:HasFocus() and not focus
        f:SetPropagateKeyboardInput(not skip)
        if skip and (not key or key~=ui.keys.resultKey) then T.Interrupt() end
    end)
    frame:SetScript("OnKeyUp",function(_,key) if ui.keys.resultKey==key then ui.keys.resultKey=nil end end)
    FB.Controls.InstallAudioKeys(frame)
    T.frame=frame
    T.mask=frame:CreateMaskTexture(); T.mask:SetAllPoints(frame)
end

local function padded(v)
    local size=4
    while size<v do size=size*2 end
    return size
end

local function sprite(asset,x,y,w,h,order,atlasX,atlasY,glyph,shadow)
    T.used=T.used+1
    local t=T.sprites[T.used]
    if not t then t=T.frame:CreateTexture(); T.sprites[T.used]=t end
    t:SetDrawLayer("ARTWORK",order or 0)
    t:ClearAllPoints(); t:SetPoint("TOPLEFT",x,-y); t:SetSize(w,h)
    local shade=shadow and 0 or 1
    t:SetVertexColor(shade,shade,shade)
    t.fbGlyph=glyph
    if glyph then
        local art=glyph.x and FB.NameArt or FB.HUDArt
        local left=glyph.x or 0
        t:SetTexture(FB.media..asset..".tga"); t.fbAsset=asset
        t:SetTexCoord(left/art.width,(left+w)/art.width,glyph.y/art.height,(glyph.y+h)/art.height); t:Show()
    elseif atlasX then
        t:SetTexture(FB.media..asset..".tga"); t.fbAsset=asset
        t:SetTexCoord(atlasX/1024,(atlasX+w)/1024,atlasY/1024,(atlasY+h)/1024); t:Show()
    elseif FB.MediaInfo[asset] then FB.Animation.Frame(t,asset,1)
    else
        t:SetTexture(FB.media..asset..".tga"); t.fbAsset=asset
        t:SetTexCoord(0,1,0,1); t:Show()
    end
    local key=T.suffix and (shadow and "name-shadow" or asset)..T.suffix
    if key and FB.RevealData[key] then
        if not t.fbLocalMask then t.fbLocalMask=T.frame:CreateMaskTexture() end
        t.fbLocalMask:SetAllPoints(t)
        t.fbMask=t.fbLocalMask; t.fbReveal=key
        if not t.fbCut then t.fbCut=T.frame:CreateMaskTexture() end
        t.fbCut:SetAllPoints(t)
        t.fbCut:SetTexture(FB.media.."Reveals\\"..asset.."-cut.blp","CLAMP","CLAMP","NEAREST")
        local spec=FB.RevealData[key]
        if glyph then
            local art=glyph.x and FB.NameArt or FB.HUDArt
            local left=glyph.x or 0
            t.fbCut:SetTexCoord(left/art.width,(left+w)/art.width,glyph.y/art.height,(glyph.y+h)/art.height)
        else t.fbCut:SetTexCoord(0,spec.w/padded(spec.w),0,spec.h/padded(spec.h)) end
        T.boxes[#T.boxes+1]={x=x,y=y,r=x+w,b=y+h,cut=t.fbCut,glyph=glyph}
    else t.fbMask=T.mask end
    t:AddMaskTexture(t.fbMask)
end

local function board(game,x,y,scale,dotX,dotY,nextY,rimX,rimY)
    local mini=scale==0.5
    local prefix=(mini and "mini-" or "")..(FB.db.colorblind and "bubble-symbol" or "bubble")
    for key,color in pairs(game.grid) do
        local r,c=FB.Engine.Cell(key)
        local cx,cy=FB.Engine.Position(r,c,game.ceiling,game.offset)
        sprite(prefix..color,x+(cx-16)*scale,y+(cy-16)*scale,32*scale,32*scale)
    end
    local px=x+112*scale
    sprite(prefix..game.next,px,nextY,32*scale,32*scale)
    local ball=T.sprites[T.used]
    local rim=mini and "mini-rim" or "next-rim"
    sprite(rim,px+rimX,nextY+rimY,FB.MediaInfo[rim].w,FB.MediaInfo[rim].h,1)
    if T.suffix then
        ball.fbRim=T.sprites[T.used].fbCut
        ball:AddMaskTexture(ball.fbRim)
    end
    for i=1,game.rootPeriod do sprite(i==1 and "progress-red" or "progress-green",dotX,dotY+8*(i-1),7,7) end
end

local function plaque(center,y,prefix,value)
    FB.Plaques.Layout(center,prefix,value,function(g,x)
        sprite("hud-lettering",x,y,g.w+1,g.h+1,1,nil,nil,g)
    end)
end

local function namePlaque(center,y,name,wins,size,limit)
    local function draw(g,x,dy)
        sprite("name-lettering",x+1,y+dy+1,g.w,g.h,1,nil,nil,g,true)
        sprite("name-lettering",x,y+dy,g.w,g.h,2,nil,nil,g)
    end
    if not FB.Plaques.NameLayout(center,name,wins,size,limit,draw) then
        -- FontStrings can shape the client's other scripts. WoW texture masks
        -- only accept textures, so fade these captions with the board wipe.
        T.localeCount=T.localeCount+1
        local f=T.localeCaptions[T.localeCount]
        if not f then
            f=FB.Plaques.Caption(T.frame,center,y,1); T.localeCaptions[T.localeCount]=f
        end
        f:ClearAllPoints(); f:SetPoint("TOPLEFT",T.frame,"TOPLEFT",center,-y)
        f:SetNameScore(name,wins,size,limit); f:Show()
    end
end

local function fill(layout)
    local g=FB.game
    sprite(layout.."-background",0,0,640,480,-8)
    if layout=="solo" then
        sprite("compressor",192,-7,252,51,-1)
        if g.mode=="training" then sprite("opening-training-clock",32,152,96,75,-1) end
        local prefix,value=FB.Plaques.Solo(g)
        if prefix then plaque(74,103,prefix,value) end
        board(g,190,44,1,447,28,440,-3,-3)
    elseif layout=="versus" then
        board(g,354,40,1,345,28,440,-4,-3)
        local other=FB.LocalVersus.match and FB.LocalVersus.match.left or (FB.Net.match and FB.Net.match.remote) or g
        board(other,30,40,1,287,28,440,-4,-3)
        if FB.LocalVersus.match then
            local wins=FB.LocalVersus.match.wins
            plaque(160,11,nil,wins[2]); plaque(480,11,nil,wins[1])
        elseif FB.Net.match then
            local m=FB.Net.match
            local own,peer=FB.Plaques.DuelNames(FB.PlayerName(),m.peer)
            namePlaque(160,11,peer,m.series and m.series.losses or 0,14,216)
            namePlaque(480,11,own,m.series and m.series.wins or 0,14,216)
        end
    else
        board(g,190,44,1,447,28,440,-4,-3)
        local m=FB.Net.match
        local me=m.players[m.me]
        namePlaque(320,12,me.label,me.wins,14,220)
        for i,v in ipairs(FB.Arena.Opponents(m)) do
            local right,bottom=i%2==0,i>2
            local x,y=right and 492 or 20,bottom and 247 or 19
            namePlaque(right and 553 or 83,bottom and 465 or 2,v.label,v.wins,8,132)
            if v.left then
                local asset="arena-left-rp"..i
                sprite(asset,x-1,y-2,FB.MediaInfo[asset].w,FB.MediaInfo[asset].h)
            else
                board(v.remote,x,y,0.5,right and 483 or 149,bottom and 258 or 28,bottom and 445 or 216,-2,-2)
            end
        end
    end
end

-- A bright background can appear many frames before a dark bubble. Cut the
-- opaque sprite silhouettes out of the backdrop before revealing either layer.
-- Only rectangles that cross a sprite need its cutout mask.
local function edges(values)
    local sorted={}
    for value in pairs(values) do sorted[#sorted+1]=value end
    table.sort(sorted)
    return sorted
end
local function brightnessBackdrop(layout)
    T.sprites[1]:Hide()
    local file=FB.media..layout.."-background.tga"
    local function patch(x,y,r,b,cuts)
        T.patchCount=T.patchCount+1
        local t=T.patches[T.patchCount]
        if not t then
            t=T.frame:CreateTexture(nil,"BACKGROUND"); t.fbCuts={}
            t:AddMaskTexture(T.mask); T.patches[T.patchCount]=t
        end
        t:SetTexture(file); t:SetTexCoord(x/1024,r/1024,y/512,b/512)
        t:ClearAllPoints(); t:SetPoint("TOPLEFT",x,-y); t:SetSize(r-x,b-y)
        for _,box in ipairs(cuts) do
            t.fbCuts[#t.fbCuts+1]=box.cut; t:AddMaskTexture(box.cut)
        end
        t:Show()
    end
    local ys={[0]=true,[480]=true}
    for _,box in ipairs(T.boxes) do ys[math.max(0,box.y)]=true; ys[math.min(480,box.b)]=true end
    local rows=edges(ys)
    for row=1,#rows-1 do
        local y,b=rows[row],rows[row+1]
        local xs,active={[0]=true,[640]=true},{}
        for _,box in ipairs(T.boxes) do
            if box.y<b and box.b>y then
                xs[box.x]=true; xs[box.r]=true; active[#active+1]=box
            end
        end
        local cols=edges(xs)
        for col=1,#cols-1 do
            local x,r=cols[col],cols[col+1]
            local cuts={}
            for _,box in ipairs(active) do
                if box.x<r and box.r>x then cuts[#cuts+1]=box end
            end
            if #cuts<=2 then patch(x,y,r,b,cuts)
            else
                -- The backdrop wipe uses one of WoW's three texture masks.
                -- Kerning can put several letters and shadows on the same tiny
                -- rectangle. Cut their opaque pixels directly into scanlines.
                local fixed={}
                for _,box in ipairs(cuts) do
                    if not (box.glyph and box.glyph.solid) then fixed[#fixed+1]=box end
                end
                for py=y,b-1 do
                    local start
                    for px=x,r do
                        local visible=px<r
                        if visible then
                            for _,box in ipairs(cuts) do
                                local g=box.glyph
                                if g and g.solid then
                                    local bits=g.solid[py-box.y+1]
                                    local col=px-box.x+(g.skip or 0)
                                    if math.floor(bits/2^col)%2==1 then visible=false; break end
                                end
                            end
                        end
                        if visible and not start then start=px
                        elseif not visible and start then patch(start,py,px,py+1,fixed); start=nil end
                    end
                end
            end
        end
    end
end

local function display(step)
    T.step=step
    for i=1,T.localeCount do T.localeCaptions[i]:SetAlpha(step/(FB.RevealData[T.effect].steps-1)) end
    maskFrame(T.mask,T.effect,step,T.flipX,T.flipY)
    if T.suffix then
        for i=1,T.used do
            local t=T.sprites[i]
            if t.fbReveal then maskFrame(t.fbLocalMask,t.fbReveal,step,nil,nil,t.fbGlyph) end
        end
    end
end

function T.Cancel()
    if not T.target then return end
    T.target,T.demo=nil,nil
    T.frame:EnableKeyboard(false); T.frame:Hide()
    for i=1,T.patchCount do
        local t=T.patches[i]
        for j=#t.fbCuts,1,-1 do t:RemoveMaskTexture(t.fbCuts[j]); t.fbCuts[j]=nil end
        t:Hide(); t:SetTexture(nil)
    end
    T.boxes=nil
    for i=1,T.localeCount do T.localeCaptions[i]:Hide() end
    for i=1,T.used do
        local t=T.sprites[i]
        if t.fbRim then t:RemoveMaskTexture(t.fbRim); t.fbRim=nil end
        if t.fbCut then t.fbCut:SetTexture(nil) end
        t:RemoveMaskTexture(t.fbMask); t.fbMask=nil; t.fbReveal=nil; t:Hide()
        if t.fbLocalMask and t.fbLocalMask.fbKey then
            t.fbLocalMask:SetTexture(nil); t.fbLocalMask.fbKey=nil
        end
    end
    T.mask:SetTexture(nil); T.mask.fbKey=nil
end
function T.Finish()
    local target,demo=T.target,T.demo
    if not target then return end
    T.Cancel()
    if demo then FB.Demos.Play(demo)
    else
        local resultKey=FB.UI.keys.resultKey
        FB.UI:Panel(target)
        FB.UI.keys.resultKey=resultKey
        FB.Music()
    end
end
function T.Interrupt()
    if T.demo then FB.UI:ShowMenu() else T.Finish() end
end
function T.Open(target,demo)
    T.Cancel()
    local ui=FB.UI
    if FB.db.boardTransitions==false or FB.db.reducedMotion or FB.db.graphicsLevel==1 or ui.inactive or InCombatLockdown() then
        if demo then FB.Demos.Play(demo) else ui:Panel(target) end
        return
    end
    if not T.frame then build() end
    local arena=FB.Net.match and FB.Net.match.arena
    local layout=arena and "arena" or target=="opponent" and "versus" or "solo"
    if demo then layout=FB.DemoData.scenes[demo].background:match("^(.-)%-background$") end
    T.effect,T.flipX,T.flipY=choose(layout)
    T.suffix=T.effect:match("(%-light)$") or T.effect:match("(%-dark)$")
    T.target,T.demo,T.used,T.age,T.patchCount=target,demo,0,0,0
    T.boxes={}; T.localeCount=0
    ui.editing=false; ui.keys={}; ui.menu:EnableKeyboard(false); ui.board:EnableKeyboard(false)
    for _,name in ipairs({"solo","chain","keys","scores"}) do ui.panels[name]:EnableKeyboard(false) end
    local focus=GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus and ui:OwnsFocus(focus) then focus:ClearFocus() end
    if demo then FB.Demos.Opening(demo,sprite) else fill(layout) end
    if T.suffix then brightnessBackdrop(layout) end
    display(0)
    T.frame:Show(); T.frame:EnableKeyboard(true); T.frame:SetPropagateKeyboardInput(true)
    FB.Music()
end
function T.Advance(dt)
    if not T.target then return dt end
    if T.demo then
        if FB.Net.match or FB.Net.queue or FB.UI.inactive or InCombatLockdown() then
            FB.UI:ShowMenu(); return dt
        end
    elseif not FB.game then T.Cancel(); return dt
    elseif FB.game.status~="playing" then T.Finish(); return dt end
    T.age=T.age+dt
    local spec=FB.RevealData[T.effect]
    local step=math.floor(T.age*50+1e-8)
    if step>=spec.steps then
        local remainder=math.max(0,T.age-spec.steps/50)
        T.Finish(); return remainder
    end
    if step~=T.step then display(step) end
    return 0
end
