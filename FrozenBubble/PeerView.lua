-- The other player's board replays launches through the same 20 ms engine.
-- Received snapshots are authoritative. Only Network applies their attack totals.
local _,FB=...
local E=FB.Engine
local V={}
FB.PeerView=V

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
function V.UnpackRising(data,offset)
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
        if col>7 or row<2 or row>E.ROWS+7 then return end
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

function V.Fire(m,p)
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
    m.remoteSeq,m.remoteFire,m.lastSeen=seq,shots,GetTime()
    setGrid(view,grid,offset)
    view.tick,view.elapsed,view.accumulator=tick,tick*0.02,0
    view.status,view.projectile,view.rising,view.chains="playing",nil,{},{}
    view.shots,view.lockedShots=shots-1,shots-1
    view.current,view.next=color,current
    view:Shoot(angle)
    view.next,view.rng=nextColor,rng
    FB.Sound("launch")
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

function V.Update(m,dt)
    local view=m.remote
    if not view then return end
    if view.turnUntil and GetTime()>view.turnUntil then view.turning=0 end
    view:Update(dt)
    if m.phase=="playing" then view.status="playing" end
    FB.BoardSounds(view)
end
