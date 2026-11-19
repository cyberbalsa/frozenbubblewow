local _, FB = ...
local L = {}
FB.LocalVersus = L

function L.New(seed,chains,wins,sound,desktopRandom)
    local right=FB.Engine.New(nil,seed,"versus",chains,sound,desktopRandom)
    local left=FB.Engine.New(nil,seed,"versus",chains,sound,desktopRandom)
    -- Both launchers draw from the same random stream after the shared opening.
    if desktopRandom then left.randomOwner=right
    else left.Random=function(_,n) return right:Random(n) end end
    return {right=right,left=left,wins=wins or {0,0},elapsed=0}
end

function L.Start(chains, previous)
    if not FB.CanStart() then return end
    FB.LeaveBoard()
    local seed=FB.GameSeed()
    local m=L.New(seed,chains,previous and previous.wins,FB.Sound,true)
    m.right.lowGraphics=FB.db.graphicsLevel==1; m.left.lowGraphics=m.right.lowGraphics
    m.right.timed=FB.db.shotClock~=false; m.left.timed=m.right.timed
    local function playerInput(game,first,launchTick)
        local keys,binding=m.keys,FB.Controls.keys
        FB.Controls.Aim(game,keys[binding[first]],keys[binding[first+1]],keys[binding[first+3]],0.03)
        FB.Controls.Fire(game,keys,first+2,launchTick)
    end
    m.rightInput=function(game,tick) playerInput(game,1,tick) end
    m.leftInput=function(game,tick) playerInput(game,5,tick) end
    L.match=m
    FB.Recordings.Begin(seed,m.right,m)
    FB.game=m.right; FB.run=nil
    FB.UI.keys={}; FB.UI.focusPausedGame=nil
    FB.Transitions.Open("opponent"); FB.UI.frame:Show(); FB.Music()
end

function L.Rematch()
    local m=L.match
    if m and m.finished then L.Start(m.right.chainReaction,m) end
end

-- A replay advances both engines on the same random stream and delivers
-- both attacks only after the second board has finished its tick.
function L.Step(m,rightInput,leftInput)
    local right,left=m.right,m.left
    local rightAttack,leftAttack=right.attack,left.attack
    right:Step(0.02,rightInput); left:Step(0.02,leftInput)
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
            m.finished=true; right.sound("lose")
        else
            left:AddGarbage(right.attack-rightAttack)
            right:AddGarbage(left.attack-leftAttack)
        end
    end
end

function L.Update(dt,keys)
    local m=L.match
    local right,left=m.right,m.left
    m.keys=keys
    left.paused=right.paused
    if right.paused then return end
    m.elapsed=m.elapsed+math.min(dt,0.25)
    while m.elapsed+1e-9>=0.02 do
        m.elapsed=m.elapsed-0.02
        L.Step(m,m.rightInput,m.leftInput)
        FB.UI.AnimatePlayerTick(right,0.02); FB.UI.AnimatePlayerTick(left,0.02)
    end
end
