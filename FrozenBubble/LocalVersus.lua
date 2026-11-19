local _, FB = ...
local L = {}
FB.LocalVersus = L

function L.Start(chains, previous)
    if not FB.CanStart() then return end
    local seed=FB.GameSeed()
    local right=FB.Engine.New(nil,seed,"versus",chains)
    local left=FB.Engine.New(nil,seed,"versus",chains)
    -- Both launchers draw from the same random stream after the shared opening.
    left.Random=function(_,n) return right:Random(n) end
    left.timed=true
    L.match={right=right,left=left,wins=previous and previous.wins or {0,0},elapsed=0}
    FB.game=right; FB.run=nil
    FB.UI.keys={}; FB.UI.focusPausedGame=nil
    FB.UI.frame:Show(); FB.UI:Panel("opponent"); FB.Music()
end

function L.Rematch()
    local m=L.match
    if m and m.finished then L.Start(m.right.chainReaction,m) end
end

local function aim(game, left, right, center)
    local old=game.angle
    local angle=old+(right and 0.03 or 0)-(left and 0.03 or 0)
    if center then
        if math.abs(angle)<=0.03 then angle=0
        else angle=angle+(angle>0 and -0.03 or 0.03) end
    end
    game.angle=FB.Clamp(angle,-FB.Engine.MAX_ANGLE,FB.Engine.MAX_ANGLE)
    game.turning=game.angle<old and -1 or game.angle>old and 1 or 0
end

function L.Update(dt,keys)
    local m=L.match
    local right,left=m.right,m.left
    left.paused=right.paused
    if right.paused then return end
    m.elapsed=m.elapsed+math.min(dt,0.25)
    while m.elapsed+1e-9>=0.02 do
        m.elapsed=m.elapsed-0.02
        if not m.finished then
            aim(right,keys.LEFT,keys.RIGHT,keys.DOWN)
            aim(left,keys.X,keys.V,keys.D)
        end
        local rightAttack,leftAttack=right.attack,left.attack
        right:Update(0.02); left:Update(0.02)
        if not m.finished then
            if right.status=="lost" or left.status=="lost" then
                if right.status==left.status then
                    right.status,left.status="draw","draw"
                else
                    local p=right.status=="lost" and 2 or 1
                    m.wins[p]=m.wins[p]+1
                    local winner=p==1 and right or left
                    winner.status="won"
                end
                m.finished=true; FB.Sound("applause")
            else
                left:AddGarbage(right.attack-rightAttack)
                right:AddGarbage(left.attack-leftAttack)
            end
        end
        FB.BoardSounds(right); FB.BoardSounds(left)
    end
end
