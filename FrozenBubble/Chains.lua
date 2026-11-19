-- Return flights for the optional chain-reaction rules in Frozen Bubble.
local _,FB=...
local E=FB.Engine

-- Start at all occupied ceiling cells. Excluding a proposed match also tells
-- us which groups would lose their support if that return flight succeeds.
function E:RootDistances(excluded)
    local dist,queue={},{}
    for k=1,E.Columns(1,self.offset) do
        if self.grid[k] and not (excluded and excluded[k]) then
            queue[#queue+1]=k; dist[k]=0
        end
    end
    local i=1
    while queue[i] do
        local key=queue[i]
        for _,k in ipairs(E.Neighbors(key,self.offset)) do
            if self.grid[k] and not dist[k] and not (excluded and excluded[k]) then
                queue[#queue+1]=k; dist[k]=dist[key]+1
            end
        end
        i=i+1
    end
    return dist
end

-- Upstream tries left, right, upper left, lower left, upper right, lower right.
local function targetSlots(game,key)
    local r,c=E.Cell(key)
    local left=c-(E.Columns(r,game.offset)==8 and 1 or 0)
    local slots={}
    for _,p in ipairs({{r,c-1},{r,c+1},{r-1,left},{r+1,left},{r-1,left+1},{r+1,left+1}}) do
        if E.Valid(p[1],p[2],game.offset) and p[1]+game.ceiling/E.STEP<=12 then
            slots[#slots+1]=E.Key(p[1],p[2])
        end
    end
    return slots
end

function E:PlanChains(attached)
    local fallingByColor,anchors,order={},{},{}
    for index,key in ipairs(self.attachedOrder) do
        local color=self.grid[key]
        order[key]=index
        if not attached[key] then
            local list=fallingByColor[color] or {}
            list[#list+1]=key; fallingByColor[color]=list
        else anchors[#anchors+1]=key end
    end
    table.sort(anchors,function(a,b)
        if attached[a]==attached[b] then return order[a]<order[b] end
        return attached[a]<attached[b]
    end)
    local plans,reserved,protected={},{},{}
    local function reserve(chain)
        reserved[chain.target]=true
        for _,k in ipairs(chain.protected) do protected[k]=true end
    end
    for _,chain in ipairs(self.chains) do reserve(chain) end
    for _,key in ipairs(anchors) do
        local color=self.grid[key]
        local loose=fallingByColor[color]
        if loose and #loose>0 and not protected[key] and #self:Group(key,true)>=2 then
            for _,slot in ipairs(targetSlots(self,key)) do
                if not attached[slot] and not reserved[slot] then
                    -- A detached bubble can still occupy the destination in
                    -- the pre-drop grid. Only roof-connected neighbors count.
                    local group,removed={},{}
                    for _,n in ipairs(E.Neighbors(slot,self.offset)) do
                        if attached[n] and self.grid[n]==color and not removed[n] then
                            for _,k in ipairs(self:Group(n,true)) do
                                group[#group+1]=k; removed[k]=true
                            end
                        end
                    end
                    local remaining=self:RootDistances(removed)
                    local chain={target=slot,group=group,protected={}}
                    for _,k in ipairs(anchors) do
                        if not remaining[k] then chain.protected[#chain.protected+1]=k end
                    end
                    plans[table.remove(loose,1)]=chain
                    reserve(chain)
                    break
                end
            end
        end
    end
    -- Multiple simultaneous matches can jointly disconnect another target
    -- even when removing either match alone would leave it attached.
    for source=E.ROWS*8,1,-1 do
        local chain=plans[source]
        if chain then
            local removed={}
            for other,plan in pairs(plans) do
                if source~=other then for _,k in ipairs(plan.group) do removed[k]=true end end
            end
            local remaining=self:RootDistances(removed)
            local count=0
            for _,k in ipairs(chain.group) do if remaining[k] then count=count+1 end end
            if count<2 then plans[source]=nil end
        end
    end
    return plans
end

function E:MoveChains()
    if #self.chains==0 then return end
    local landed={}
    for _,chain in ipairs(self.chains) do
        if chain.wait>0 then chain.wait=chain.wait-1
        else
            -- Screen y=380 as a sprite top-left maps to board center y=356
            -- in split screen (board top 40), or 352 in solo (board top 44).
            local turnY=self.chainTurnY or self.launchY-10
            if chain.y>turnY or chain.speedX then
                local r,c=E.Cell(chain.target)
                local x,y=E.Position(r,c,self.ceiling,self.offset)
                local acceleration=1.5
                if not chain.speedX then
                    local turn=chain.speed/acceleration
                    local distance=chain.speed*(turn+1)/2
                    local ticks=turn+(math.sqrt(math.max(0,1+8*(chain.y-y+distance)/acceleration))-1)/2
                    chain.speedX=ticks>0 and (x-chain.x)/ticks or 0
                end
                chain.speed=chain.speed-acceleration
                chain.x=chain.x+chain.speedX
                if math.abs(chain.x-x)<math.abs(chain.speedX) then chain.x=x; chain.speedX=0 end
                chain.y=chain.y+chain.speed
                if chain.y<y then landed[#landed+1]=chain end
            else
                chain.y=chain.y+chain.speed; chain.speed=chain.speed+0.5
            end
        end
    end
    for _,chain in ipairs(landed) do
        -- Other simultaneous arrivals still reserve their groups while this one resolves.
        for i,active in ipairs(self.chains) do
            if active==chain then table.remove(self.chains,i); break end
        end
        local slot=chain.target
        if not self.grid[slot] then
            for _,neighbor in ipairs(E.Neighbors(slot,self.offset)) do
                if self.grid[neighbor] then
                    self.grid[slot]=chain.color; self.attachedOrder[#self.attachedOrder+1]=slot
                    self:Resolve(slot)
                    if self.lastPop==0 then self.stick={key=slot,ticks=0} end
                    self.changed=true
                    break
                end
            end
        end
    end
    if #landed>0 then self:CheckEnd() end
end
