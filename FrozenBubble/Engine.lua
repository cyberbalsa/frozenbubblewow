-- Native Lua adaptation of Frozen Bubble mechanics. No WoW API dependencies.
local _, FB = ...
local E = {}
FB.Engine = E
E.__index = E
E.W, E.H, E.R, E.STEP, E.ROWS = 256, 400, 16, 28, 13
E.LAUNCH_Y, E.LIMIT = 362, 350
-- Upstream runs at 20 ms: 10 px/frame, gravity 0.5 px/frame/frame.
E.SPEED = 500
E.MAX_ANGLE = math.pi/2 - 0.1

function E.Columns(row,offset) return (row+(offset or 0)) % 2 == 1 and 8 or 7 end
function E.Position(row, col, ceiling, offset)
    return 16 + (col - 1) * 32 + (E.Columns(row,offset)==7 and 16 or 0),
        16 + (row - 1) * E.STEP + (ceiling or 0)
end
function E.Key(row, col) return (row - 1) * 8 + col end
function E.Cell(key) return math.floor((key - 1) / 8) + 1, (key - 1) % 8 + 1 end
function E.Valid(row, col, offset) return row >= 1 and row <= E.ROWS and col >= 1 and col <= E.Columns(row,offset) end
function E.Neighbors(key,offset)
    local r, c = E.Cell(key)
    local side = E.Columns(r,offset)==7 and 1 or -1
    local cells = {{r,c-1},{r,c+1},{r-1,c},{r-1,c+side},{r+1,c},{r+1,c+side}}
    local out = {}
    for _, p in ipairs(cells) do if E.Valid(p[1], p[2],offset) then out[#out+1] = E.Key(p[1],p[2]) end end
    return out
end
-- Perl's drand48 state is 48 bits. Multiplying two 24-bit halves keeps
-- every intermediate exact on WoW's double-precision Lua 5.1 runtime.
local half,range=16777216,281474976710656
local function desktopRoll(game)
    local stream=game.randomOwner or game
    local low=stream.rng%half
    local product=15525485*low+11
    local high=(15525485*math.floor(stream.rng/half)+1502*low+math.floor(product/half))%half
    stream.rng=high*half+product%half
    return stream.rng/range
end

function E:Random(n)
    if self.desktopRandom then return math.floor(desktopRoll(self)*n)+1 end
    self.rng = (self.rng * 16807) % 2147483647
    return self.rng % n + 1
end
function E:Color()
    if self.mode=="versus" then return self:Random(8) end
    local colors, found = {}, {}
    for key = 1, E.ROWS * 8 do
        local color = self.grid[key]
        if color then found[color] = true end
    end
    for color = 1, 8 do if found[color] then colors[#colors+1] = color end end
    if #colors == 0 then return self:Random(8) end
    if self.desktopRandom then
        local color
        repeat color=self:Random(8) until found[color]
        return color
    end
    return colors[self:Random(#colors)]
end
local function silent() end
function E.New(level, seed, mode, chainReaction, sound, desktopRandom)
    local self = setmetatable({grid={}, sound=sound or silent, rng=math.max(1, (seed or 1) % 2147483647), mode=mode or "campaign",
        score=0, shots=0, ceiling=0, status="playing", elapsed=0, idle=0, pending=0,
        attack=0, tick=0, deliveries={}, rising={}, attachedOrder={}, lockedShots=0, offset=0, effects={}, angle=0, accumulator=0}, E)
    self.desktopRandom=desktopRandom
    if desktopRandom then self.rng=((seed or 1)%4294967296)*65536+13070 end
    self.chains={}
    self.effectRng=self.rng
    self.chainReaction=chainReaction==true and (mode=="random" or mode=="training" or mode=="versus")
    self.launchY=mode=="versus" and 366 or E.LAUNCH_Y
    self.penaltyRules=mode=="versus" or mode=="training"
    self.hurryWarn = self.penaltyRules and 5 or 8
    self.hurryMax = self.penaltyRules and 7.5 or 10.5
    self.rootPeriod = self.penaltyRules and 12 or 9
    if level then
        for r, row in ipairs(level) do
            for c = 1, #row do
                local color = tonumber(row:sub(c,c))
                if color and color >= 1 and color <= 8 and E.Valid(r,c,self.offset) then self.grid[E.Key(r,c)] = color end
            end
        end
    else
        for r = 1, 5 do for c = 1, E.Columns(r) do self.grid[E.Key(r,c)] = self:Random(8) end end
    end
    for key=1,E.ROWS*8 do if self.grid[key] then self.attachedOrder[#self.attachedOrder+1]=key end end
    self.current, self.next = self:Color(), self:Color()
    return self
end
function E:Count()
    local n=0; for _ in pairs(self.grid) do n=n+1 end; return n
end
function E:Group(start, sameColor)
    local visited, queue = {[start]=true}, {start}
    local color = self.grid[start]
    local index=1
    while queue[index] do
        for _, key in ipairs(E.Neighbors(queue[index],self.offset)) do
            if not visited[key] and self.grid[key] and (not sameColor or self.grid[key] == color) then
                visited[key]=true; queue[#queue+1]=key
            end
        end
        index=index+1
    end
    return queue
end
-- Local games use the desktop stream. Earlier recordings and the online
-- protocol keep their original independent sequence for visual effects.
local function burst(game,x,y,color)
    if game.desktopRandom then
        if game.lowGraphics then return end
        local vx=3*desktopRoll(game)-1.5
        return {x=x,y=y,vx=vx,vy=-2-4*desktopRoll(game),color=color,kind="pop",wait=0}
    end
    game.effectRng=game.effectRng*16807%2147483647
    local vx=3*game.effectRng/2147483647-1.5
    game.effectRng=game.effectRng*16807%2147483647
    return {x=x,y=y,vx=vx,vy=-2-4*game.effectRng/2147483647,color=color,kind="pop",wait=0}
end
function E:Effect(key,kind)
    local row,col=E.Cell(key)
    local x,y=E.Position(row,col,self.ceiling,self.offset)
    if kind=="pop" then return burst(self,x,y,self.grid[key]) end
    return {x=x,y=y,vx=0,vy=0,color=self.grid[key],kind="fall",wait=0}
end
function E:Remove(key,kind)
    self.effects[#self.effects+1]=self:Effect(key,kind)
    self.grid[key]=nil
    for i,k in ipairs(self.attachedOrder) do if k==key then table.remove(self.attachedOrder,i); break end end
end
function E:Resolve(key)
    local group=self:Group(key,true)
    local popped, dropped=0,0
    self.sound(#group>=3 and "destroy_group" or "stick")
    self.boardChanged=true
    if #group >= 3 then
        -- destroy_bubbles ejects attached neighbors first and the shot last.
        local first=self.desktopRandom and 2 or 1
        for i=first,#group do self:Remove(group[i],"pop") end
        if first==2 then self:Remove(key,"pop") end
        popped=#group
        local attached=self:RootDistances()
        local falling={}
        for k=1,E.ROWS*8 do if self.grid[k] and not attached[k] then falling[#falling+1]=k end end
        local plans=self.chainReaction and #falling>0 and self:PlanChains(attached) or {}
        -- Original cascade order: bottom-to-top, right-to-left; five ticks per row,
        -- then one extra tick for each bubble on that row.
        table.sort(falling,function(a,b) return a>b end)
        local bottom=falling[1] and E.Cell(falling[1]) or 1
        local lastRow,shift=nil,0
        for _,k in ipairs(falling) do
            local row=E.Cell(k)
            if row~=lastRow then shift=0; lastRow=row end
            self:Remove(k,"fall"); dropped=dropped+1
            local delay=(bottom-row)*5+shift
            local chain=plans[k]
            if chain then
                -- The chain owns this sprite until its return flight lands.
                local fx=table.remove(self.effects)
                chain.x,chain.y,chain.color=fx.x,fx.y,fx.color
                chain.wait,chain.speed=delay,0
                self.chains[#self.chains+1]=chain
            else self.effects[#self.effects].wait=delay end
            shift=shift+1
        end
    end
    local penalty=math.max(0,popped+dropped-3)
    if self.mode=="training" then self.score=self.score+penalty
    else self.score=self.score+popped*10+dropped*20 end
    if self.mode=="versus" then
        self.attack=self.attack+penalty
        if self.onPenalty and penalty>0 then self.onPenalty(penalty) end
    end
    self.lastPop,self.lastDrop=popped,dropped
    return popped,dropped
end
function E:CheckEnd()
    if not next(self.grid) then
        if self.mode == "endless" then
            self.ceiling=0
            for r=1,5 do for c=1,E.Columns(r) do self.grid[E.Key(r,c)]=self:Random(8) end end
            self.score=self.score+500
        elseif not self.penaltyRules then self.status="won"; return end
    end
    for key in pairs(self.grid) do
        local r,c=E.Cell(key); local _,y=E.Position(r,c,self.ceiling,self.offset)
        if y+E.R >= E.LIMIT then self.status="lost"; return end
    end
end
function E:AddGarbage(count)
    if count<=0 then return end
    self.pending=self.pending+count
    local batch=self.deliveries[#self.deliveries]
    if batch and batch.tick==self.tick then batch.count=batch.count+count
    else self.deliveries[#self.deliveries+1]={tick=self.tick,count=count} end
end
function E:ApplyGarbage()
    local batch=self.deliveries[1]
    if not batch or self.tick<=batch.tick+20 then return end
    local bottom={1,1,1,1,1,1,1,1}
    for key in pairs(self.grid) do
        local row,col=E.Cell(key)
        bottom[col]=math.max(bottom[col],row)
    end
    while batch and self.tick>batch.tick+20 and #self.rising<7 do
        -- The default upstream rules draw among columns 0..6 (1..7 in Lua).
        local color,col=self:Random(8),self:Random(7)
        bottom[col]=bottom[col]+1
        local x,y=E.Position(13,col,0,self.offset)
        self.rising[#self.rising+1]={col=col,row=bottom[col],x=x,y=y,color=color}
        self.pending=self.pending-1
        batch.count=batch.count-1
        if batch.count==0 then table.remove(self.deliveries,1); batch=self.deliveries[1] end
    end
    table.sort(self.rising,function(a,b)
        if a.col==b.col then return a.row<b.row end
        return a.col<b.col
    end)
    for index,bubble in ipairs(self.rising) do
        bubble.y=bubble.y+index*7+self:Random(20)-1
    end
    self.sound("malus")
end
function E:MoveGarbage()
    for i=#self.rising,1,-1 do
        local bubble=self.rising[i]
        bubble.y=bubble.y-30
        if math.floor((bubble.y-E.R+E.STEP/2)/E.STEP)+1<=bubble.row then
            if bubble.row<=E.ROWS then
                local slot=E.Key(bubble.row,bubble.col)
                self.grid[slot]=bubble.color
                self.attachedOrder[#self.attachedOrder+1]=slot
            end
            if bubble.row>=13 then self.status="lost" end
            table.remove(self.rising,i)
            self.boardChanged=true
        end
    end
end
function E:AdvanceRoot()
    if not self.penaltyRules then
        self.ceiling=self.ceiling+E.STEP
    else
        -- Shift the grid indices while preserving every existing bubble's x coordinate.
        local shifted={}
        for key,color in pairs(self.grid) do shifted[key+8]=color end
        for _,chain in ipairs(self.chains) do
            chain.target=chain.target+8
            for i,key in ipairs(chain.protected) do chain.protected[i]=key+8 end
        end
        for i,key in ipairs(self.attachedOrder) do self.attachedOrder[i]=key+8 end
        if self.stick then self.stick.key=self.stick.key+8 end
        self.grid=shifted
        self.offset=1-self.offset
        for col=1,E.Columns(1,self.offset) do
            shifted[col]=self.nextRow and self.nextRow[col] or self:Random(8)
            self.attachedOrder[#self.attachedOrder+1]=col
        end
    end
    if self.penaltyRules then self.nextRow=nil end
    self.sound(self.penaltyRules and "newroot" or "newroot_solo")
end
function E:Attach(x,y,hit)
    local candidates={}
    if hit then candidates=E.Neighbors(hit,self.offset) else for c=1,E.Columns(1,self.offset) do candidates[#candidates+1]=E.Key(1,c) end end
    local row = math.max(1, math.floor((y-self.ceiling-16+14)/28)+1)
    local shift = E.Columns(row,self.offset)==7 and 16 or 0
    local col = math.floor((x-shift)/32)+1
    local snapped = E.Valid(row,col,self.offset) and E.Key(row,col)
    local best, distance
    for _, key in ipairs(candidates) do
        if not self.grid[key] then
            if key==snapped then best=key; break end
            local r,c=E.Cell(key); local cx,cy=E.Position(r,c,self.ceiling,self.offset)
            local d=(x-cx)^2+(y-cy)^2
            if not distance or d<distance then best,distance=key,d end
        end
    end
    if not best then self.status="lost"; self.projectile=nil; return end
    self.attachedOrder[#self.attachedOrder+1]=best
    self.lockedShots=self.lockedShots+1
    self.warningShot,self.warningTick=self.lockedShots,self.tick
    self.grid[best]=self.projectile.color
    self.projectile=nil
    self:Resolve(best)
    if self.lastPop==0 then self.stick={key=best,ticks=0} end
    local rootDue=self.shots%self.rootPeriod==0
    if self.desktopRandom and self.mode~="endless" then
        -- stick_bubble lowers the ceiling before verify_if_end judges the board.
        if rootDue then self:AdvanceRoot() end
        self:CheckEnd()
    else
        self:CheckEnd()
        if self.status=="playing" and rootDue then self:AdvanceRoot(); self:CheckEnd() end
    end
    if self.status=="playing" then
        if hit and self.penaltyRules and #self.chains==0 and self.status=="playing" then self:ApplyGarbage() end
    end
end
function E:CanShoot()
    return self.status=="playing" and not self.paused and not self.projectile and #self.chains==0 and #self.rising==0
end
function E:Shoot(angle,launchTick)
    if not self:CanShoot() then return false end
    self.angle=FB.Clamp(angle or self.angle,-E.MAX_ANGLE,E.MAX_ANGLE)
    self.projectile={x=128,y=self.launchY,vx=math.sin(self.angle)*E.SPEED,vy=-math.cos(self.angle)*E.SPEED,color=self.current}
    self.current=self.next
    self.next=self:Color()
    self.shots=self.shots+1; self.idle=0; self.hurryVisible=false
    self.sound("launch")
    if self.onShoot then self.onShoot(self,launchTick or self.tick,launchTick~=nil) end
    return true
end
function E:TrainingTimeLeft()
    -- The original shows 2:00 on the first frame and 0:00 for its final second.
    return math.max(0,120.99-self.tick*0.02)
end
-- At full graphics upstream ejects or freezes one attached bubble on every
-- even frame. Keep the final board intact for a late simultaneous-loss draw.
function E:StepEnding()
    if self.endingStatus~=self.status then
        if self.endingStatus then self.effects={} end
        self.endingStatus,self.endIndex,self.endCells,self.endTick=self.status,0,{},self.tick
        if self.projectile then
            local shot=self.projectile
            local fx=burst(self,shot.x,shot.y,shot.color)
            if fx then
                fx.frozen=self.status~="won"
                self.effects[#self.effects+1]=fx
            end
        end
        self.projectile,self.stick,self.chains,self.rising=nil,nil,{},{}
        -- cleanup_player_bubbles sorts bottom row first, right to left.
        self.endOrder={}
        for key in pairs(self.grid) do self.endOrder[#self.endOrder+1]=key end
        table.sort(self.endOrder,function(a,b) return a>b end)
    end
    self.endTick=self.endTick+1
    if self.endTick%2~=0 or self.endIndex>=#self.endOrder then return end
    local freeze=self.status=="lost" or self.status=="draw"
    if not freeze and not (self.status=="won" and self.mode=="versus") then return end
    self.endIndex=self.endIndex+1
    local key=self.endOrder[self.endIndex]
    self.endCells[key]=true
    if freeze and self.mode~="versus" and self.endIndex==#self.endOrder then self.sound("noh") end
    if not freeze and self.grid[key] then self.effects[#self.effects+1]=self:Effect(key,"pop") end
end
local function advanceGame(self,dt,input)
    if self.status~="playing" then
        if self.status=="won" or self.status=="lost" or self.status=="draw" then self:StepEnding() end
        return
    end
    self.tick=self.tick+1
    self.elapsed=self.elapsed+dt
    if self.mode=="training" then
        if self:TrainingTimeLeft()==0 then self.status="finished"; self.projectile=nil; return end
        if self.pending==0 and #self.rising==0 and self:Random(1500)==1 then self:AddGarbage(self:Random(6)) end
    end
    if #self.chains==0 then self.idle=self.idle+dt end
    -- The desktop warning blinks every 25 simulation ticks, starting one
    -- tick after the threshold. Do not derive its sound from UI refreshes.
    local late=math.floor((self.idle-self.hurryWarn)*50+0.5)
    local warning=self.timed~=false and late>0 and math.floor(late/25)%2==0
    if warning and not self.hurryVisible then self.sound("hurry") end
    self.hurryVisible=warning
    -- Network replays start at the last completed tick before the shot moves.
    if input then input(self,self.tick-1) end
    if #self.chains>0 then self:MoveChains(); return end
    if #self.rising>0 then self:MoveGarbage(); return end
    if not self.projectile and self.timed~=false and self.idle+1e-9>=self.hurryMax then self:Shoot(nil,self.tick-1) end
    if not self.projectile then return end
    local p=self.projectile
    local previousX,previousY=p.x,p.y
    p.x,p.y=p.x+p.vx*dt,p.y+p.vy*dt
    if p.x<E.R then p.x=2*E.R-p.x; p.vx=-p.vx; self.sound("rebound") end
    if p.x>E.W-E.R then p.x=2*(E.W-E.R)-p.x; p.vx=-p.vx; self.sound("rebound") end
    if self.desktopRandom and not self.nextRow then
        self.nextRow={}
        for i=1,8 do self.nextRow[i]=self:Random(8) end
    end
    if p.y<=E.R+self.ceiling then self:Attach(p.x,p.y); self:MoveChains(); return end
    local hit,nearest
    for key=1,E.ROWS*8 do
        if self.grid[key] then
            local r,c=E.Cell(key); local x,y=E.Position(r,c,self.ceiling,self.offset)
            local d=(p.x-x)^2+(p.y-y)^2
            if d<(32*0.82)^2 and (not nearest or d<nearest) then hit,nearest=key,d end
        end
    end
    if hit then
        self:Attach((previousX+p.x)/2,(previousY+p.y)/2,hit)
        self:MoveGarbage()
        self:MoveChains()
    end
end
function E:Step(dt,input)
    if self.paused then return end
    advanceGame(self,dt,input)
    -- update_game moves sprites after collisions and end-of-round actions, even
    -- on the tick they are created. Speeds here are pixels per desktop frame.
    local bottom=self.effectFloor or self.launchY+80
    for i=#self.effects,1,-1 do
        local fx=self.effects[i]
        if fx.wait>0 then fx.wait=fx.wait-1
        else
            fx.x,fx.y=fx.x+fx.vx,fx.y+fx.vy
            fx.vy=fx.vy+0.5
            if fx.y>bottom then table.remove(self.effects,i) end
        end
    end
    if self.recordTrack then FB.Recordings.EndTick(self) end
    if self.stick then
        self.stick.ticks=self.stick.ticks+1
        if self.stick.ticks>14 then self.stick=nil end
    end
end
function E:Update(dt,input,animate)
    if self.paused then return end
    self.accumulator=self.accumulator+math.min(dt,0.25)
    while self.accumulator+1e-9>=0.02 do
        self:Step(0.02,input)
        if animate then animate(self,0.02) end
        self.accumulator=self.accumulator-0.02
    end
end
function E:Pack()
    local out={}
    for r=1,E.ROWS do for c=1,E.Columns(r,self.offset) do out[#out+1]=tostring(self.grid[E.Key(r,c)] or 0) end end
    return table.concat(out)
end
function E.Unpack(data,offset)
    if type(data)~="string" or #data~=(offset==1 and 97 or 98) or data:find("[^0-8]") then return nil end
    local grid,index={},1
    for r=1,E.ROWS do for c=1,E.Columns(r,offset) do
        local color=tonumber(data:sub(index,index)); index=index+1
        if color>0 then grid[E.Key(r,c)]=color end
    end end
    return grid
end
