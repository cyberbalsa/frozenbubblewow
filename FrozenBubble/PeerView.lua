-- The other player's board replays launches through the same 20 ms engine.
-- Received snapshots are authoritative. Cumulative attack totals apply once to the receiving board.
local _,FB=...
local E=FB.Engine
local V={}
FB.PeerView=V

function V.NewDuelBoard(seed,chains,sound,safePenalties)
    local view=E.New(nil,seed,"versus",chains,sound)
    view.safePenalties=safePenalties==true
    -- Only the peer who owns this board can trigger its automatic shot.
    view.hurryMax=math.huge; view.timed=false
    return view
end

-- Four printable characters hold a rising bubble's column, row, color and y.
local digits="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
function V.PackRising(game)
    local out={}
    for _,b in ipairs(game.rising) do
        local n=(((b.col-1)*32+b.row)*8+b.color-1)*512+math.floor(b.y)
        local word=""
        for _=1,4 do
            local i=n%64+1
            word=digits:sub(i,i)..word; n=math.floor(n/64)
        end
        out[#out+1]=word
    end
    return table.concat(out)
end
function V.UnpackRising(data,offset,safePenalties)
    if #data>28 or #data%4~=0 then return end
    local rising={}
    for start=1,#data,4 do
        local n=0
        for pos=start,start+3 do
            local i=digits:find(data:sub(pos,pos),1,true)
            if not i then return end
            n=n*64+i-1
        end
        local y=n%512; n=math.floor(n/512)
        local color=n%8+1; n=math.floor(n/8)
        local row=n%32; local col=math.floor(n/32)+1
        if col>8 or row<2 or row>E.ROWS+7 then return end
        if col==8 and (not safePenalties or row>=E.ROWS or not E.Valid(row,col,offset)) then return end
        rising[#rising+1]={row=row,col=col,color=color,x=E.Position(13,col,0,offset),y=y}
    end
    return rising
end

local function setGrid(view,grid,offset)
    local order,seen={},{}
    local shift=offset~=view.offset and 8 or 0
    for _,old in ipairs(view.attachedOrder) do
        local key=old+shift
        if grid[key] and grid[key]==view.grid[old] and not seen[key] then
            order[#order+1]=key; seen[key]=true
        end
    end
    for key=1,E.ROWS*8 do
        if grid[key] and not seen[key] then order[#order+1]=key end
    end
    view.grid,view.offset,view.attachedOrder=grid,offset,order
end

function V.Turn(m,p)
    local seq=FB.Integer(p[4],1,10000000)
    local angle=FB.Integer(p[5],-1471,1471)
    local keys,lean=FB.Integer(p[6],0,7),FB.Integer(p[7],-1,2)
    local view=m.remote
    if #p~=7 or not seq or not angle or not keys or not lean or seq<=(view.turnSeq or 0) then return end
    -- A priority FIRE or STATE may have overtaken this turn. Keep its angle
    -- while accepting the latest held keys, which those packets do not carry.
    if seq>m.remoteSeq then view.angle=FB.Clamp(angle/1000,-E.MAX_ANGLE,E.MAX_ANGLE) end
    view.turnSeq,view.remoteKeys,view.turning,view.turnTicks=seq,keys,lean,110
    return true
end

function V.Fire(m,p,receivedAt)
    local seq=FB.Integer(p[4],1,10000000)
    local tick=FB.Integer(p[5],0,100000000)
    local shots=FB.Integer(p[6],1,1000000)
    local angle=tonumber(p[7])
    local color,current,nextColor=FB.Integer(p[8],1,8),FB.Integer(p[9],1,8),FB.Integer(p[10],1,8)
    local rng=FB.Integer(p[11],1,2147483646)
    local offset=p[12] and #p[12]==97 and 1 or 0
    local grid=E.Unpack(p[12],offset)
    if #p~=12 or not seq or seq<=m.remoteSeq or not tick or not shots or shots<=(m.remoteFire or 0)
        or shots<=(m.remoteLocked or 0) or not angle or angle~=angle or math.abs(angle)>E.MAX_ANGLE+1e-10
        or not color or not current or not nextColor or not rng or not grid then return end
    local view=m.remote
    m.remoteSeq,m.remoteFire,m.lastSeen=seq,shots,receivedAt or GetTime()
    setGrid(view,grid,offset)
    view.tick,view.elapsed,view.accumulator=tick,tick*0.02,0
    view.status,view.projectile,view.rising,view.chains="playing",nil,{},{}
    view.shots,view.lockedShots=shots-1,shots-1
    view.incomingRise=nil
    view.current,view.next=color,current
    local facing=view.angle
    view:Shoot(angle)
    if seq<(view.turnSeq or 0) then view.angle=facing end
    view.next,view.rng=nextColor,rng
    return true
end

local function applyRise(view)
    local volley=view.incomingRise
    if not volley or view.tick<view.riseTick or view.projectile then return end
    view.incomingRise=nil
    if view.status~="playing" or view.offset~=volley.offset or view.lockedShots~=view.riseShot then return end
    view.rising,view.pending=volley.bubbles,volley.pending
    -- The owner moves its volley on the contact tick. Catch up late packets
    -- without advancing the shot clock or the player's other animations.
    for _=1,math.min(16,view.tick-view.riseTick+1) do
        if #view.rising==0 then break end
        view:MoveGarbage()
    end
end

function V.Rise(m,p)
    local view=m.remote
    local seq=FB.Integer(p[4],1,10000000)
    local tick=FB.Integer(p[5],1,100000000)
    local shots=FB.Integer(p[6],1,1000000)
    local offset=FB.Integer(p[7],0,1)
    local pending=FB.Integer(p[8],0,10000000)
    if #p~=9 or not seq or seq<=m.remoteSeq or not tick or not shots or shots~=view.shots
        or view.riseShot==shots or not offset or not pending then return end
    local bubbles=V.UnpackRising(p[9],offset,view.safePenalties)
    if not bubbles or #bubbles==0 then return end
    local _,start=E.Position(13,1,0)
    local seen={}
    for i,b in ipairs(bubbles) do
        local slot=E.Key(b.row,b.col)
        if seen[slot] or b.y<start+i*7 or b.y>=start+i*7+20 then return end
        seen[slot]=true
    end
    local expected=view.offset
    if view.projectile and shots%view.rootPeriod==0 then expected=1-expected end
    if offset~=expected then return end
    m.remoteSeq=seq
    view.riseShot,view.riseTick=shots,tick
    view.incomingRise={offset=offset,pending=pending,bubbles=bubbles}
    applyRise(view)
    return true
end

-- The desktop moves network penalty sprites 30 screen pixels per frame
-- even on a half-size board. Hold the last position until the bubble sticks.
function V.RisingY(view,b,mini)
    if view.riseShot~=view.shots or not view.riseTick then return b.y end
    local _,start=E.Position(13,b.col,0)
    local speed=mini and 60 or 30
    local _,destination=E.Position(b.row,b.col,0)
    local last=math.max(1,math.floor((start-destination-E.STEP/2)/speed)+1)
    local age=math.max(1,view.tick-view.riseTick+1)
    return start-speed*math.min(age,last)
end

function V.Sync(view,grid,offset,tick,shots,locked,rng,rising)
    view.status="playing"; view.endCells=nil; view.endingStatus=nil
    if tick then
        -- A batch of messages can arrive before the next render. Replay to the
        -- authoritative tick so snaps, clears and chain targets form in order.
        local steps=math.min(150,math.max(0,tick-view.tick))
        for _=1,steps do
            if not view.projectile and #view.chains==0 and #view.rising==0 then break end
            view:Update(0.02)
        end
        view.tick,view.elapsed,view.accumulator=tick,tick*0.02,0
        view.rng=rng; view.rising=rising
    end
    if tick or shots~=view.shots then
        view.incomingRise=nil
    elseif locked>=shots then
        -- Compact snapshots omit the lane list. Retain the flight of any
        -- bubble that the owner's corrected grid still shows as airborne.
        local flight=view.incomingRise and view.incomingRise.bubbles or view.rising
        for i=#flight,1,-1 do
            local b=flight[i]
            if grid[E.Key(b.row,b.col)] then table.remove(flight,i) end
        end
    end
    if shots>view.shots or locked>=shots then view.projectile=nil end
    local diverged=offset~=view.offset
    for k=1,E.ROWS*8 do
        if view.grid[k]~=grid[k] then diverged=true; break end
    end
    if diverged then
        setGrid(view,grid,offset)
        -- A missed launch or a correction can invalidate a predicted return.
        for i=#view.chains,1,-1 do
            local chain=view.chains[i]
            local supported=false
            for _,n in ipairs(E.Neighbors(chain.target,offset)) do
                if grid[n]==chain.color then supported=true; break end
            end
            if grid[chain.target] or not supported then table.remove(view.chains,i) end
        end
    end
end

function V.State(m,p,recipient,receivedAt)
    local seq=FB.Integer(p[4],1,10000000)
    local shots=FB.Integer(p[5],0,1000000)
    local score=FB.Integer(p[6],0,100000000)
    local ceiling=FB.Integer(p[7],0,40000)
    local attack=FB.Integer(p[8],0,10000000)
    local offset=p[9] and #p[9]==97 and 1 or 0
    local grid=FB.Engine.Unpack(p[9],offset)
    if not seq or seq<=m.remoteSeq or not shots or not score or not ceiling or not attack or not grid then return end
    local locked=FB.Integer(p[10],math.max(0,shots-1),shots)
    local pending=FB.Integer(p[11],0,10000000) or 0
    local angle=FB.Integer(p[12],-1471,1471)
    local current,nextColor=FB.Integer(p[13],1,8),FB.Integer(p[14],1,8)
    if p[10] and (not locked or not angle or not current or not nextColor
        or not FB.Integer(p[11],0,10000000)) then return end
    local tick=FB.Integer(p[15],0,100000000)
    local rng=FB.Integer(p[16],1,2147483646)
    local rising=p[17] and V.UnpackRising(p[17],offset,m.remote.safePenalties)
    local idle=FB.Integer(p[18],0,10000)
    if p[15] and (not tick or not rng or not rising or not idle or #p~=18) then return end
    if shots<(m.remoteShots or 0) or attack<m.remoteAttack then return end
    if locked then
        local resolved=locked-(m.remoteLocked or 0)
        if resolved<0 then return end
        if m.chainReaction then
            -- Return flights can score several times after the same shot attached.
            local base=resolved>0 and m.remoteAttack or (m.chainBase or 0)
            local budget=resolved>0 and resolved*(FB.Engine.ROWS*8+8) or (m.chainBudget or 0)
            if attack-base>budget then return end
            m.chainBase,m.chainBudget=base,budget
        elseif attack-m.remoteAttack>96*resolved then return end
    else
        -- Older peers report launched shots even if the projectile is still in flight.
        local base=shots==(m.remoteShots or 0) and (m.legacyAttackBase or 0) or m.remoteAttack
        local limit=shots==(m.remoteShots or 0) and (m.legacyAttackLimit or 0) or 12*(shots-(m.remoteShots or 0))
        if attack-base>limit then return end
        m.legacyAttackBase,m.legacyAttackLimit=base,limit
        locked=shots
    end
    m.remoteLocked=locked
    m.remoteSeq=seq; m.remoteShots=shots; m.lastSeen=receivedAt
    if recipient.status=="playing" then recipient:AddGarbage(attack-m.remoteAttack) end
    m.remoteAttack=attack
    local remote=m.remote
    V.Sync(remote,grid,offset,tick,shots,locked,rng,rising)
    if idle then remote.idle,remote.timed=idle*0.02,true end
    remote.ceiling=ceiling/100
    remote.score,remote.shots,remote.lockedShots=score,shots,locked
    local aim=(angle or 0)/1000
    if seq>(remote.turnSeq or 0) then
        if remote.remoteKeys==nil then
            remote.turning=aim<remote.angle and -1 or aim>remote.angle and 1 or 0
            remote.turnTicks=8
        end
        remote.angle=FB.Clamp(aim,-E.MAX_ANGLE,E.MAX_ANGLE)
    end
    remote.current,remote.next=current,nextColor
    remote.pending,remote.mode,remote.rootPeriod=pending,"versus",12
    return true
end

local function stepTurn(view)
    if not view.turnTicks or view.turnTicks<=0 then return end
    view.turnTicks=view.turnTicks-1
    if view.turnTicks==0 then
        view.remoteKeys,view.turning=nil,0
    elseif view.remoteKeys and view.remoteKeys~=0 then
        local keys=view.remoteKeys
        FB.Controls.Aim(view,keys%2==1,math.floor(keys/2)%2==1,keys>=4,0.03)
    end
end
-- Advance both duel boards on the same fixed tick. Packet corrections may
-- replace the remote engine's tick, but do not move the local match clock.
local function peerTick(view)
    applyRise(view)
    FB.MatchChat.Step(view)
end
function V.StepDuel(m,lowGraphics)
    local view=m.remote
    view.lowGraphics=lowGraphics
    view:Step(0.02,stepTurn)
    peerTick(view)
    if m.phase=="playing" then view.status="playing" end
end

function V.Update(m,dt)
    local view=m.remote
    if not view then return end
    view.lowGraphics=FB.game and FB.game.lowGraphics
    view:Update(dt,stepTurn,peerTick)
    if m.phase=="playing" then view.status="playing" end
end
