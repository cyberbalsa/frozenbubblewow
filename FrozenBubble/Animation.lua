-- Original frame sequences and menu coordinates ported from bin/frozen-bubble.
-- Upstream GPL-2.0-only; see AUTHORS.upstream and THIRD_PARTY.md.
local _, FB = ...
local A={}; FB.Animation=A
function A.Frame(texture,name,frame)
    local info=FB.MediaInfo[name]
    if not info then texture:Hide(); return end
    frame=math.max(1,math.min(info.frames,math.floor(frame or 1)))-1
    local x,y=(frame%info.columns)*info.w,math.floor(frame/info.columns)*info.h
    if texture.fbAsset~=name then texture:SetTexture(FB.media..name..".tga"); texture.fbAsset=name end
    texture:SetTexCoord(x/info.tw,(x+info.w)/info.tw,y/info.th,(y+info.h)/info.th)
    texture.fbFrame=frame+1
    texture:Show()
end
function A.Image(parent,name,x,y,width,height,layer)
    local info=FB.MediaInfo[name]
    local t=parent:CreateTexture(nil,layer or "ARTWORK")
    t:SetSize(width or info.w,height or info.h); t:SetPoint("TOPLEFT",x,-y)
    A.Frame(t,name,1); return t
end
-- Exact frame ranges and transition graph from init_game()/update_game() upstream.
local sequences={
    normal={"anime-shooter",20,20,1}, action={"anime-shooter",21,50,1,"normal"},
    left_to={"anime-shooter",19,2,-1,"left"}, left={"anime-shooter",1,1,1},
    left_from={"anime-shooter",2,19,1,"normal"},
    right_to={"anime-shooter",51,70,1,"right"}, right={"anime-shooter",71,71,1},
    right_from={"anime-shooter",71,51,-1,"normal"},
    wait_to={"wait",1,74,1,"wait"}, wait={"wait",75,97,1,"wait"},
    win={"win",1,68,1,"win"}, lose_to={"loose",1,64,1,"lose"}, lose={"loose",65,158,1,"lose"},
}
local function pose(t,name)
    t.fbState=name
    t.fbIndex=sequences[name][2]
end

local function penguinInput(t,game)
    local direction=game.turning==-1 and "left" or game.turning==1 and "right"
    local fired=game.shots~=t.fbShots
    t.fbShots=game.shots
    t.fbIdleTicks=(direction or game.turning==2 or fired) and 0 or t.fbIdleTicks+1
    if fired then
        pose(t,"action")
    elseif game.turning==2 then
        -- SDL handles left then right, restarting right_to on every tick.
        pose(t,"right_to")
    elseif direction then
        if t.fbState==direction.."_from" then pose(t,direction)
        elseif t.fbState~=direction and t.fbState~=direction.."_to" then pose(t,direction.."_to") end
    elseif t.fbState=="left_to" or t.fbState=="right_to" then
        -- update_game reverses the zero-based animation index as length-index.
        local towards=sequences[t.fbState]
        local progress=(t.fbIndex-towards[2])*towards[4]
        pose(t,t.fbState=="left_to" and "left_from" or "right_from")
        local back=sequences[t.fbState]
        local length=math.abs(back[3]-back[2])+1
        t.fbIndex=back[2]+((length-progress)%length)*back[4]
    elseif t.fbState=="left" or t.fbState=="right" then
        pose(t,t.fbState.."_from")
    elseif t.fbIdleTicks>200 and t.fbState~="wait" and t.fbState~="wait_to" then
        pose(t,"wait_to")
    end
end

function A.Penguin(texture,game,player,dt)
    if texture.fbGame~=game or not texture.fbState then
        texture.fbGame=game
        texture.fbTime,texture.fbShots,texture.fbIdleTicks=0,0,0
        pose(texture,"normal")
    end
    if game then
        if game.status=="won" and texture.fbState~="win" then pose(texture,"win")
        elseif (game.status=="lost" or game.status=="draw") and texture.fbState~="lose" and texture.fbState~="lose_to" then
            pose(texture,"lose_to")
        end
    end
    if game and not game.paused then
        texture.fbTime=texture.fbTime+dt
        while texture.fbTime+1e-9>=0.02 do
            texture.fbTime=texture.fbTime-0.02
            if game.status=="playing" then penguinInput(texture,game) end
            local seq=sequences[texture.fbState]
            if seq[5] then
                texture.fbIndex=texture.fbIndex+seq[4]
                if (texture.fbIndex-seq[3])*seq[4]>0 then pose(texture,seq[5]) end
            end
        end
    end
    A.Frame(texture,sequences[texture.fbState][1].."-"..(player or "p1"),texture.fbIndex)
end
