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
function A.Penguin(texture,game,player,dt)
    player=player or "p1"
    if texture.fbGame~=game then
        texture.fbGame=game; texture.fbState="normal"; texture.fbIndex=20; texture.fbTime=0; texture.fbShots=0; texture.fbIdle=0
    end
    local function state(name)
        if texture.fbState~=name then texture.fbState=name; texture.fbIndex=sequences[name][2]; texture.fbTime=0 end
    end
    if not texture.fbState then state("normal") end
    if game then
        if game.status=="won" then state("win")
        elseif game.status=="lost" then
            if texture.fbState~="lose" and texture.fbState~="lose_to" then state("lose_to") end
        elseif not game.paused then
            local direction=game.turning and (game.turning<0 and "left" or game.turning>0 and "right")
            if game.shots~=texture.fbShots then
                state("action"); texture.fbIndex=21; texture.fbTime=0
                texture.fbShots=game.shots; texture.fbIdle=0
            elseif direction then
                texture.fbIdle=0
                if texture.fbState==direction.."_from" then state(direction)
                elseif texture.fbState~=direction then state(direction.."_to") end
            else
                texture.fbIdle=(texture.fbIdle or 0)+dt
                local previous=texture.fbState
                if previous=="left_to" or previous=="right_to" then
                    -- Continue the return motion from the pose reached before release.
                    local frame=texture.fbIndex
                    state(previous=="left_to" and "left_from" or "right_from")
                    texture.fbIndex=frame
                elseif previous=="left" or previous=="right" then state(previous.."_from")
                elseif texture.fbIdle>4 and previous~="wait" and previous~="wait_to" then state("wait_to") end
            end
        end
    end
    texture.fbTime=(texture.fbTime or 0)+(game and game.paused and 0 or dt)
    while texture.fbTime>=0.02 do
        texture.fbTime=texture.fbTime-0.02
        local seq=sequences[texture.fbState]
        if seq[5] then
            texture.fbIndex=texture.fbIndex+seq[4]
            if seq[4]>0 and texture.fbIndex>seq[3] or seq[4]<0 and texture.fbIndex<seq[3] then
                texture.fbState=seq[5]; texture.fbIndex=sequences[seq[5]][2]
            end
        end
    end
    local seq=sequences[texture.fbState]
    A.Frame(texture,seq[1].."-"..player,texture.fbIndex)
end
