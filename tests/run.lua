-- Run with Lua 5.1 (WoW's language baseline) or newer Lua.
local passed=0
local function test(name,fn)
    local ok,err=pcall(fn)
    if not ok then error("FAIL "..name..": "..tostring(err),0) end
    passed=passed+1; print("PASS "..name)
end
local function eq(a,b,msg) assert(a==b,(msg or "values differ")..": "..tostring(a).." ~= "..tostring(b)) end
local function loadModule(name,fb,env)
    local f
    if setfenv then f=assert(loadfile("FrozenBubble/"..name..".lua")); if env then setfenv(f,env) end
    else f=assert(loadfile("FrozenBubble/"..name..".lua","t",env or _G)) end
    f("FrozenBubble",fb)
end
local FB={}
loadModule("Bootstrap",FB); loadModule("Levels",FB); loadModule("Engine",FB); loadModule("Chains",FB)
local E=FB.Engine
loadModule("Controls",FB)
test("100 campaign boards match the desktop shot, piston, fall and freeze timelines",function()
    dofile("tests/campaign_trace.lua")(FB,eq)
end)
test("all 100 original levels have valid ten-row layouts",function()
    eq(#FB.Levels,100)
    for _,level in ipairs(FB.Levels) do
        eq(#level,10)
        for r,row in ipairs(level) do eq(#row,E.Columns(r)); assert(not row:find("[^1-8%.]")) end
        assert(E.New(level,1):Count()>0)
    end
end)
test("hex adjacency is symmetric and bounded",function()
    for r=1,E.ROWS do for c=1,E.Columns(r) do
        local key=E.Key(r,c)
        for _,n in ipairs(E.Neighbors(key)) do
            local nr,nc=E.Cell(n); assert(E.Valid(nr,nc))
            local back=false; for _,v in ipairs(E.Neighbors(n)) do if v==key then back=true end end
            assert(back)
        end
    end end
end)
test("three matching bubbles pop; disconnected clusters fall",function()
    local g=E.New({},1,"versus")
    g.grid={[1]=1,[2]=1,[3]=1,[9]=2,[17]=3}
    local popped,dropped=g:Resolve(1)
    eq(popped,3); eq(dropped,2); eq(g.score,70); eq(g.attack,2); eq(g:Count(),0)
end)
test("pairs do not pop or detach bubbles",function()
    local g=E.New({},1); g.grid={[1]=1,[2]=1,[9]=2}
    local p,d=g:Resolve(1); eq(p,0); eq(d,0); eq(g:Count(),3)
end)
test("versus attacks queue independently and rise up to seven at a time",function()
    local g=E.New({},1,"versus")
    g.grid={[1]=1,[2]=1,[3]=1,[9]=2,[17]=3}
    g:AddGarbage(10)
    g:Resolve(1); eq(g.pending,10); eq(g.attack,2)
    g:CheckEnd(); eq(g.status,"playing")
    for _=1,20 do g:Step(0.02) end
    g:ApplyGarbage(); eq(#g.rising,0)
    g:Step(0.02); g:ApplyGarbage()
    eq(g.pending,3); eq(#g.rising,7); eq(g:Count(),0); assert(not g:Shoot())
    local bubble=g.rising[1]; local y=bubble.y
    g:Step(0.02); eq(bubble.y,y-30)
    for _=1,20 do g:Step(0.02) end
    eq(#g.rising,0); eq(g:Count(),7); assert(g:Shoot())
end)
test("penalty bubbles start only after a bubble collision and after row insertion",function()
    local g=E.New({"111....."},2,"versus"); g:AddGarbage(1); g.tick=30; g.shots=11
    g.projectile={color=2}; g:Attach(220,16); eq(#g.rising,0)
    g.shots=12; g.projectile={color=3}; g:Attach(32,44,1)
    eq(g.offset,1); eq(#g.rising,1)
    local b=g.rising[1]
    eq(b.x,E.Position(13,b.col,0,1)); assert(not g.grid[E.Key(b.row,b.col)])
end)
test("wire board roundtrip and malformed data rejection",function()
    local g=E.New(FB.Levels[1],42); local packed=g:Pack(); eq(#packed,98)
    local other=E.New({},1); other.grid=E.Unpack(packed); eq(other:Pack(),packed)
    eq(E.Unpack(""),nil); eq(E.Unpack(string.rep("9",98)),nil)
    eq(E.Unpack(string.rep("0",99)),nil)
end)
local function finishShot(g,dt)
    local count=0
    while g.projectile and count<2000 do g:Update(dt); count=count+1 end
    assert(not g.projectile,"shot never resolved")
end
test("fixed-step physics resolves equally at 30 and 144 FPS",function()
    for _,angle in ipairs({-1.4,-0.7,0,0.45,1.4}) do
        local a,b=E.New(FB.Levels[1],123),E.New(FB.Levels[1],123)
        a:Shoot(angle); b:Shoot(angle); finishShot(a,1/30); finishShot(b,1/144)
        eq(a:Pack(),b:Pack()); eq(a.score,b.score); eq(a.next,b.next)
    end
end)
test("ceiling descends after nine shots and crossing danger line loses",function()
    local g=E.New(FB.Levels[1],123)
    g.shots=8; g:Shoot(0.5); finishShot(g,1/60); eq(g.shots,9); eq(g.ceiling,E.STEP)
    g.ceiling=400; g:CheckEnd(); eq(g.status,"lost")
end)
test("solo pause freezes physics and autofire",function()
    local g=E.New(FB.Levels[1],1); g.paused=true; g:Update(0.25)
    eq(g.elapsed,0); assert(not g:Shoot())
    g.paused=false; g.idle=10.49; g:Update(0.03); eq(g.shots,1)
end)
test("original bubble speed, ballistic clears, cascade delays, and sticking flash",function()
    local g=E.New({},1); g.grid={[1]=1,[2]=1,[3]=1,[9]=2,[17]=3}
    g:Shoot(0); eq(g.projectile.vy,-500)
    g.projectile=nil; g:Resolve(1)
    local pop,fall
    for _,fx in ipairs(g.effects) do
        if fx.kind=="pop" then pop=fx else fall=fx end
    end
    assert(pop.vy<=-2 and pop.vy>=-6); assert(pop.vx>=-1.5 and pop.vx<=1.5)
    local popY,fallY=pop.y,fall.y
    g:Update(0.02)
    assert(pop.y<popY); assert(fall.wait>0)
    eq(fall.y,fallY)
    local stick=E.New({"1......."},1)
    stick.projectile={color=2}; stick.shots=1; stick:Attach(48,16)
    assert(stick.stick); eq(stick.lastPop,0)
    stick:Update(0.25); assert(stick.stick)
    stick:Update(0.04); eq(stick.stick.ticks,14)
    stick:Update(0.02); eq(stick.stick,nil)
end)
test("a mid-frame collision gives bursts, falling bubbles and stick flashes the same age at every render rate",function()
    local function shoot(color)
        local g=E.New({"...11...","2......"},13)
        g.current=color; g:Shoot(0)
        return g
    end
    for _,color in ipairs({1,3}) do
        local desktop=shoot(color)
        for i=1,36 do desktop:Update(0.02) end
        for _,frames in ipairs({3,18,36,72,144}) do
            local g=shoot(color)
            for i=1,frames do g:Update(0.72/frames) end
            eq(g:Pack(),desktop:Pack()); eq(g.rng,desktop.rng)
            if color==1 then
                eq(#g.effects,4)
                for i,fx in ipairs(g.effects) do
                    eq(fx.x,desktop.effects[i].x); eq(fx.y,desktop.effects[i].y)
                    eq(fx.vy,desktop.effects[i].vy)
                end
                -- At tick 33 the row-two bubble disconnects. SDL moves it
                -- by 0, 0.5, 1 and 1.5 pixels on ticks 33 through 36.
                eq(g.effects[4].y,47)
            else eq(g.stick.ticks,4) end
        end
    end
end)
test("an airborne shot bursts at its current position when a versus board ends",function()
    for _,result in ipairs({"won","lost","draw"}) do
        local g=E.New({"1......."},29,"versus")
        g.current=3; g:Shoot(0.4); g:Update(0.08)
        local x,y=g.projectile.x,g.projectile.y
        local rng=g.rng
        g.status=result; g:Update(0.02)
        eq(g.projectile,nil); eq(g.rng,rng)
        local burst=g.effects[1]
        eq(burst.color,3); eq(burst.frozen,result~="won")
        eq(burst.x,x+burst.vx); eq(burst.y,y+(burst.vy-0.5))
        g.paused=true; local stopped=burst.y; g:Update(0.1); eq(burst.y,stopped)
    end
end)
test("63 upstream shot traces match the collision tick and snapped cell",function()
    local cases=dofile("tests/reference_shots.lua")
    eq(#cases,63)
    for _,case in ipairs(cases) do
        local level,angle,tick,key=case[1],case[2],case[3],case[4]
        local game=E.New(FB.Levels[level],1)
        local captured
        game.Resolve=function(_,slot) captured=slot end
        game:Shoot(angle)
        for step=1,tick-1 do game:Step(0.02); assert(game.projectile) end
        game:Step(0.02)
        eq(captured,key,"level "..level.." angle "..angle)
    end
end)
test("versus new rows alternate widths and retain original world coordinates",function()
    local game=E.New(nil,17,"versus")
    local original=game.grid[8]
    game:AdvanceRoot()
    eq(game.offset,1); eq(game.grid[16],original); eq(game.grid[8],nil)
    eq(E.Position(2,8,0,1),E.Position(1,8,0,0))
    eq(#game:Pack(),97); eq(E.Unpack(game:Pack(),1)[16],original)
    game:AdvanceRoot()
    eq(game.offset,0); eq(game.grid[24],original); eq(#game:Pack(),98)
end)
test("training uses solo ammunition, versus timing, and points for outgoing penalties",function()
    local g=E.New({"111.....","2......","3......."},7,"training")
    eq(g.rootPeriod,12); eq(g.hurryMax,7.5); eq(g.launchY,E.LAUNCH_Y)
    local p,d=g:Resolve(1)
    eq(p,3); eq(d,2); eq(g.score,2); eq(g.attack,0)
    g:CheckEnd(); eq(g.status,"playing")
    g.Random=function(_,limit) return limit==1500 and 1 or limit end
    g:Step(0.02); eq(g.pending,6)
    g:Step(0.02); eq(g.pending,6)
    g:AdvanceRoot(); eq(g.ceiling,0); eq(g.offset,1)
    g.tick=6049; g.paused=true; g:Step(0.02); eq(g.tick,6049)
    g.paused=false; g:Step(0.02); eq(g.status,"finished"); assert(not g:Shoot())
end)
test("return flights match the upstream arc and can start another chain",function()
    local layout={"111.2233","2..3..."}
    local g=E.New(layout,71,"random",true)
    local popped,dropped=g:Resolve(1)
    eq(popped,3); eq(dropped,1); eq(g.chains[1].target,4)
    g.paused=true; g:Update(0.02); eq(g.chains[1].speed,0)
    g.paused=false
    -- Coordinates from the original falling_bubble loop (20 ms, solo board origin 190,44).
    local reference={[36]={32,359},[37]={34.205642268,375.5},[50]={62.878991748,453.5},[70]={106.991837102,78.5}}
    for tick=1,144 do
        assert(not g:Shoot()); g:Update(0.02)
        if reference[tick] then
            local c=g.chains[1]
            assert(math.abs(c.x-reference[tick][1])<1e-6); eq(c.y,reference[tick][2])
        end
        if tick==72 then eq(g.chains[1].target,6); eq(g:Count(),2) end
    end
    eq(g.status,"won"); eq(g.score,130); eq(g.shots,0); eq(g.idle,0); eq(#g.chains,0)
    local standard=E.New(layout,71,"random",false)
    standard:Resolve(1); eq(#standard.chains,0); assert(standard:Shoot())
end)
test("two simultaneous chains reserve distinct groups and follow a new training row",function()
    local g=E.New({"22.11133","...2...","....3..."},17,"training",true)
    g:AddGarbage(3); g.tick=30
    g:Resolve(4); eq(#g.chains,2)
    local first,second=g.chains[1],g.chains[2]
    eq(first.color,3); eq(first.target,6); eq(second.color,2); eq(second.target,9)
    eq(first.wait,0); eq(second.wait,5)
    g:AdvanceRoot(); eq(first.target,14); eq(second.target,17); eq(g.offset,1)
    for _=1,200 do g:Update(0.02); if #g.chains==0 then break end end
    eq(#g.chains,0); eq(g.grid[9],nil); eq(g.grid[15],nil); eq(g.pending,3); assert(g:Shoot())
end)
test("different frame rates produce the same chain outcome",function()
    for _,step in ipairs({1/30,1/60,1/144}) do
        local g=E.New({"111.2233","2..3..."},9,"random",true); g:Resolve(1)
        for _=1,math.ceil(3/step) do g:Update(step) end
        eq(g.tick,144); eq(g.status,"won"); eq(g.score,130)
    end
end)
test("desktop training replay emits the recorded launches, rebounds and impacts on their ticks",function()
    -- First three shots from share/data/demo1.bz2. The opening colors and
    -- expected play_sound calls were captured from the desktop replay engine.
    local trace,tick={},0
    local g=E.New({"41375547","1353422","37742134","3587853","45546887"},1,"training",true,
        function(name) trace[#trace+1]=tick.." "..name end)
    local shots={[27]={4,-8*0.03},[74]={7,-13*0.03},[109]={3,-20*0.03}}
    for i=1,150 do
        tick=i
        if shots[i] then g.current=shots[i][1]; assert(g:Shoot(shots[i][2])) end
        g:Step(0.02)
    end
    eq(table.concat(trace,","),"27 launch,48 stick,74 launch,93 stick,109 launch,128 rebound,129 stick")
end)
test("each chain landing and hurry pulse survives batched simulation updates",function()
    for _,dt in ipairs({0.02,0.04,0.25}) do
        local g,trace
        trace={}
        local function sound(name) trace[#trace+1]=g.tick.." "..name end
        g=E.New({"22.11133","...2...","....3..."},17,"training",true,sound)
        g.tick=30; g:Resolve(4); g:AdvanceRoot()
        while g.tick<110 do g:Update(dt) end
        eq(table.concat(trace,","),"30 destroy_group,30 newroot,98 destroy_group,106 destroy_group")
        trace={}
        g=E.New(FB.Levels[1],10,"campaign",false,sound)
        while g.tick<550 do g:Update(dt) end
        eq(table.concat(trace,","),"401 hurry,450 hurry,500 hurry,525 launch,548 stick")
    end
end)
test("end of round freezes or ejects cells bottom first on even ticks and supports a late draw",function()
    local g=E.New({"313.....","12....."},9,"versus")
    g.status="won"; g:Update(0.02)
    eq(g.endIndex,0); g:Update(0.02); eq(g.endIndex,1); assert(g.endCells[10])
    eq(g.effects[1].color,2); eq(g.effects[1].kind,"pop")
    local original=g:Pack()
    for i=1,260 do g:Update(0.02) end
    eq(g.endIndex,5); eq(#g.effects,0); eq(g:Pack(),original)
    g.status="draw"; g:Update(0.04)
    eq(g.endIndex,1); assert(g.endCells[10] and not g.endCells[9]); eq(#g.effects,0)
    g:Update(0.04); assert(g.endCells[9])
end)
test("random play preserves board invariants across all levels",function()
    for i,level in ipairs(FB.Levels) do
        local g=E.New(level,999+i)
        for _=1,35 do
            if g.status~="playing" then break end
            g:Shoot((g:Random(281)-141)/100); finishShot(g,1/60)
            assert(E.Unpack(g:Pack()))
            for key,color in pairs(g.grid) do local r,c=E.Cell(key); assert(E.Valid(r,c)); assert(color>=1 and color<=8) end
        end
    end
end)

local clock=0
local clients,bus={},{}
local drops={}
local function client(name,fullUI)
    local fb={}; local env=setmetatable({},{__index=_G}); env._G=env
    env.unpack=table.unpack or unpack
    env.math=setmetatable({atan2=math.atan2 or function(y,x) return math.atan(y,x) end},{__index=math})
    env.GetTime=function() return clock end; env.time=function() return 1800000000 end; env.date=function() return "test-time" end
    env.GetNormalizedRealmName=function() return "TestRealm" end
    env.UnitFullName=function() return name,"TestRealm" end
    env.IsInGuild=function() return true end; env.IsInGroup=function() return false end; env.IsInRaid=function() return false end
    env.InCombatLockdown=function() return false end; env.LE_PARTY_CATEGORY_INSTANCE=2
    env.GetBuildInfo=function() return "1.60.1","test","",16001 end
    env.GetChannelName=function() return 5 end; env.JoinTemporaryChannel=function() end
    env.Enum={SendAddonMessageResult={Success=0,AddonMessageThrottle=3,InvalidChannel=7}}
    env.C_ChatInfo={RegisterAddonMessagePrefix=function() return 0 end,
        SendAddonMessage=function(prefix,message,channel,target)
            local kind=FB.Split(message)[2]
            if drops[kind] then drops[kind]=nil; return 0 end
            bus[#bus+1]={prefix=prefix,message=message,channel=channel,target=target,sender=name.."-TestRealm"}
            return 0
        end,
        SendChatMessage=function(message,_,_,_) fb.lastManual=message end}
    for _,module in ipairs({"Bootstrap","Debug","Levels","Engine","Chains","Scores","PeerView","Network","Series","Arena","Community","LobbyCommands","MediaInfo","HUDArt","NameArt","Plaques","EditorArt","Animation","Controls","MatchChat","Recordings","DuelReplay","ArenaReplay"}) do loadModule(module,fb,env) end
    fb.db={schema=1}; fb.Scores.Init(fb.db); fb.Debug.Init()
    fb.StartVersus=function(seed,chains) fb.game=fb.Engine.New(nil,seed,"versus",chains) end
    clients[name.."-TestRealm"]=fb
    if fullUI then return fb,env,loadModule end
    return fb,env
end
local function deliver()
    local pending=bus; bus={}
    for _,message in ipairs(pending) do
        for name,fb in pairs(clients) do
            if message.channel~="WHISPER" or name==message.target then
                fb.Net.Receive(message.prefix,message.message,message.channel,message.sender)
            end
        end
    end
end
local function tick(seconds)
    for _=1,math.floor(seconds*10) do
        clock=clock+0.1
        for _,fb in pairs(clients) do fb.Community.Update(); fb.Net.Update(0.1) end
        deliver()
    end
end
local a,b=client("Alice"),client("Bob")
test("original penguin frame sequences advance, transition, and loop at 50 FPS",function()
    local texture={SetTexture=function() end,SetTexCoord=function() end,Show=function() end}
    local g=E.New({},1); g.status="won"
    a.Animation.Penguin(texture,g,"p1",0.1)
    eq(texture.fbState,"win"); assert(texture.fbFrame>=5)
    local first=texture.fbFrame
    a.Animation.Penguin(texture,g,"p1",0.2); assert(texture.fbFrame~=first)
    a.Animation.Penguin(texture,g,"p1",2); assert(texture.fbFrame>=1 and texture.fbFrame<=68)
    g.status="lost"; a.Animation.Penguin(texture,g,"p1",1.5); eq(texture.fbState,"lose")
    assert(texture.fbFrame>=65 and texture.fbFrame<=158)
    g=E.New({},1); a.Animation.Penguin(texture,g,"p1",0)
    g.shots=1; a.Animation.Penguin(texture,g,"p1",0.1); eq(texture.fbState,"action")
    a.Animation.Penguin(texture,g,"p1",0.6); eq(texture.fbState,"normal")
    g.turning=-1; a.Animation.Penguin(texture,g,"p1",0.1)
    local turnFrame=texture.fbFrame
    g.turning=0; a.Animation.Penguin(texture,g,"p1",0.02)
    eq(texture.fbState,"left_from"); eq(texture.fbFrame,turnFrame+2)
    a.Animation.Penguin(texture,g,"p1",0.5)
    for i=1,210 do a.Animation.Penguin(texture,g,"p1",0.02) end
    eq(texture.fbState,"wait_to")
    g.turning=1; a.Animation.Penguin(texture,g,"p1",0.02)
    eq(texture.fbState,"right_to")
end)
test("shooter turn, release, fire and idle frames match the desktop input sequence",function()
    -- Frames sampled from the pinned Perl update_game input and advance blocks.
    local reference={[1]=18,[5]=14,[6]=16,[8]=18,[9]=1,[15]=1,[16]=3,
        [17]=52,[18]=53,[19]=22,[47]=50,[48]=20,[219]=20,[220]=2,[292]=74,
        [293]=75,[315]=97,[316]=75,[400]=90}
    for _,subframes in ipairs({1,2,4}) do
        local t={SetTexture=function() end,SetTexCoord=function() end,Show=function() end}
        local g=E.New({},5)
        for tick=1,400 do
            g.turning=(tick<=5 or tick>=9 and tick<=15) and -1 or (tick>=17 and tick<=19) and 1 or 0
            if tick==19 then g.shots=1 end
            for i=1,subframes do a.Animation.Penguin(t,g,"rp2",0.02/subframes) end
            if reference[tick] then
                eq(t.fbFrame,reference[tick],"penguin frame at tick "..tick)
                eq(t.fbAsset,tick<220 and "anime-shooter-rp2" or "wait-rp2")
            end
        end
    end
end)
test("remote aim follows held keys and the desktop penguin, recovers a dropped release and preserves shots",function()
    local sender=client("TurnSender")
    local n,controls=sender.Net,sender.Controls
    local g=E.New({},17,"versus")
    local m={id="51-1",seq=0,phase="playing",peer="TurnGuest-TestRealm"}
    sender.game,n.match=g,m
    local v={remote=sender.PeerView.NewDuelBoard(17),phase="playing",remoteSeq=0,remoteAttack=0}
    local peer=v.remote
    local texture={Show=function() end,SetTexture=function() end,SetTexCoord=function() end}
    local function sample(t)
        n.SendTurn(m,g,t)
        local entry=table.remove(n.outbox)
        assert(entry and entry.kind=="TURN")
        return FB.Split(entry.message)
    end
    local function advance(count)
        for _=1,count do
            sender.PeerView.StepDuel(v)
            sender.Animation.Penguin(texture,peer,"p2",0.02)
        end
    end
    n.SendTurn(m,g,0); eq(#n.outbox,0)
    controls.Aim(g,false,true,false,0.03)
    local start=sample(1)
    assert(sender.PeerView.Turn(v,start)); advance(50)
    eq(peer.angle,E.MAX_ANGLE); eq(texture.fbState,"right"); eq(texture.fbFrame,71)
    controls.Aim(g,true,true,false,0.03)
    assert(sender.PeerView.Turn(v,sample(2)))
    advance(20); eq(texture.fbFrame,52); eq(peer.angle,0.03)
    controls.Aim(g,false,false,true,0.03)
    assert(sender.PeerView.Turn(v,sample(3))); advance(20)
    eq(peer.angle,0); eq(peer.turning,0)
    g.angle,g.aimKeys,g.turning=-0.72,0,-1
    assert(sender.PeerView.Turn(v,sample(4))); advance(8)
    eq(peer.angle,-0.72); eq(texture.fbState,"left_to")
    g.turning=0; sample(4.2) -- lost in transit
    assert(sender.PeerView.Turn(v,sample(5.8))); advance(24)
    eq(texture.fbState,"normal"); eq(peer.angle,-0.72)
    n.SendTurn(m,g,8); eq(#n.outbox,0)
    assert(not sender.PeerView.Turn(v,start))
    local invalid=FB.Split("1|TURN|51-1|9999|1472|2|1")
    assert(not sender.PeerView.Turn(v,invalid)); eq(peer.angle,-0.72)
    controls.Aim(g,false,true,false,0.03)
    local held=sample(9)
    assert(sender.PeerView.Turn(v,held)); advance(120)
    eq(peer.turning,0); eq(peer.remoteKeys,nil)
    -- Fresh aim can overtake a launch in transit. The projectile keeps the
    -- angle at launch while the cannon keeps the newer angle.
    g.onShoot=n.Fire; assert(g:Shoot(0.15))
    local fire=FB.Split(table.remove(n.outbox).message)
    g.angle,g.aimKeys,g.turning=0.81,0,0
    assert(sender.PeerView.Turn(v,sample(10)))
    assert(sender.PeerView.Fire(v,fire)); eq(peer.angle,0.81)
    assert(math.abs(peer.projectile.vx-E.SPEED*math.sin(0.15))<1e-9)
    -- A correcting STATE gets queue priority. A slightly older turn still
    -- carries the held direction, and must preserve the corrected angle.
    controls.Aim(g,true,false,false,0.03); n.SendTurn(m,g,11)
    g.angle=0.5; n.State()
    eq(n.outbox[1].kind,"STATE"); eq(n.outbox[2].kind,"TURN")
    assert(sender.PeerView.State(v,FB.Split(n.outbox[1].message),g,11))
    assert(sender.PeerView.Turn(v,FB.Split(n.outbox[2].message)))
    eq(peer.angle,0.5); advance(1); eq(peer.angle,0.47)
    n.match=nil
end)
test("a peer replays the launch tick for between-frame clicks, keyboard fire and auto-fire",function()
    local sender=client("Launcher")
    local net=sender.Net
    for _,source in ipairs({"click","keyboard","clock"}) do
        local shot=E.New(FB.Levels[1],43,"versus")
        local peer={remote=E.New({},1,"versus"),remoteSeq=0}
        net.match={phase="playing",id="test",seq=0}
        net.Whisper=function(kind,...)
            local words={"1",kind,...}
            for i=1,#words do words[i]=tostring(words[i]) end
            sender.PeerView.Fire(peer,words)
        end
        shot.onShoot=net.Fire; shot.tick=27; shot.angle=0.41
        if source=="click" then shot:Shoot()
        elseif source=="clock" then shot.idle=shot.hurryMax-0.02 end
        shot:Update(0.12,function(g,launchTick)
            if source=="keyboard" and g.tick==28 then assert(g:Shoot(nil,launchTick)) end
        end)
        local view=peer.remote; eq(view.tick,27)
        sender.PeerView.Sync(view,shot.grid,shot.offset,shot.tick,shot.shots,shot.lockedShots,shot.rng,{})
        eq(view.projectile.x,shot.projectile.x); eq(view.projectile.y,shot.projectile.y)
        eq(view.current,shot.current); eq(view.next,shot.next)
    end
    net.match=nil
end)
test("queue handshake survives dropped offer, accept, start and ready",function()
    drops={OFFER=true,ACCEPT=true,START=true,READY=true}
    a.Net.SetQueue(true); b.Net.SetQueue(true); tick(18)
    eq(a.Net.match.phase,"playing"); eq(b.Net.match.phase,"playing")
    eq(a.Net.match.id,b.Net.match.id); eq(a.game:Pack(),b.game:Pack())
end)
test("cumulative attacks survive duplicates and lost snapshots",function()
    a.game.shots=3; a.game.lockedShots=2; a.game.attack=0; a.Net.State(); tick(1)
    a.game.lockedShots=3; a.game.attack=5; a.Net.State(); tick(1)
    eq(b.game.pending,5)
    a.Net.State(); tick(1); eq(b.game.pending,5)
    drops.STATE=true; a.game.shots=4; a.game.lockedShots=4; a.game.attack=8; a.Net.State(); tick(2)
    eq(b.game.pending,8)
end)
test("match chat travels only to the active opponent and preserves literal pipes",function()
    local m=b.Net.match
    local message="Almost! |cffff0000 | wow"
    assert(a.MatchChat.Send(message)); tick(1)
    eq(m.remote.chatText,"Almost! ||cffff0000 || wow"); assert(m.remote.chatFrames>0)
    for _,sample in ipairs({{"WHISPER","Wrong-TestRealm",m.id,"bad"},{"CHANNEL",m.peer,m.id,"bad"},
        {"WHISPER",m.peer,"wrong","bad"},{"WHISPER",m.peer,m.id,string.rep("a",121)},
        {"WHISPER",m.peer,m.id,"bad\ntext"}}) do
        b.Net.Receive(b.PREFIX,"1|CHAT|"..sample[3].."|"..sample[4],sample[1],sample[2])
    end
    eq(m.remote.chatText,"Almost! ||cffff0000 || wow")
    b.MatchChat.Receive(m,"second line"); eq(m.remote.chatFrames,250)
    for _=1,249 do b.PeerView.StepDuel(m) end
    eq(m.remote.chatFrames,1); eq(m.remote.chatText,"second line")
    b.PeerView.StepDuel(m); eq(m.remote.chatText,nil)
    assert(not a.MatchChat.Send("") and not a.MatchChat.Send(string.rep("a",121)))
end)
test("stale, foreign, invalid and excessive attack packets are ignored",function()
    local m=b.Net.match; local seq=m.remoteSeq; local pending=b.game.pending
    local packed=a.game:Pack()
    for _,message in ipairs({
        "1|STATE|wrong|999|9|1|0|99|"..packed,
        "1|STATE|"..m.id.."|999|4|1|0|99999|"..packed,
        "1|STATE|"..m.id.."|0|4|1|0|8|"..packed,
        "1|STATE|"..m.id.."|nan|4|1|0|8|"..packed,
        "1|STATE|"..m.id.."|999|4|1|0|8|bad"}) do
        b.Net.Receive(FB.PREFIX,message,"WHISPER","Alice-TestRealm")
    end
    b.Net.Receive(FB.PREFIX,"1|END|"..m.id.."|lost","WHISPER","Mallory-TestRealm")
    eq(m.remoteSeq,seq); eq(b.game.pending,pending); eq(m.phase,"playing")
end)
test("match result retry records one win and loss",function()
    drops.END=true
    a.game.status="lost"; tick(5)
    eq(a.db.losses,1); eq(b.db.wins,1)
    eq(a.Net.match.phase,"done"); eq(b.Net.match.phase,"done")
    tick(3); eq(a.db.losses,1); eq(b.db.wins,1)
end)
test("chain matchmaking separates rules, retries offers and replays a two-stage attack",function()
    local host,guest=client("Dora"),client("Enzo")
    host.db.versusChains=true
    host.Net.SetQueue(true); guest.Net.SetQueue(true); tick(10)
    assert(host.Net.queue and guest.Net.queue and not host.Net.match and not guest.Net.match)
    guest.Net.SetQueue(false); guest.db.versusChains=true
    drops={CHAINOFFER=true,READY=true}
    guest.Net.SetQueue(true); tick(12)
    eq(host.Net.match.phase,"playing"); eq(guest.Net.match.phase,"playing")
    assert(host.game.chainReaction and guest.game.chainReaction and guest.Net.match.remote.chainReaction)
    local board=host.Engine.New({"11..2233","2..3..."},9,"versus",true)
    board.onShoot=host.Net.Fire; host.game=board; board.current=1
    assert(board:Shoot(-0.50))
    local seenFlight,seenReturn,seenSecond,highest=nil,nil,nil,0
    for frame=1,245 do
        clock=clock+0.02
        board:Update(0.02)
        if board.changed then
            host.Net.State(); board.changed=false
            if board.attack==2 then drops.STATE=true end
        end
        host.Net.Update(0.02); guest.Net.Update(0.02); deliver()
        local view=guest.Net.match.remote
        if view.projectile and view.projectile.y<350 then seenFlight=true end
        if view.chains[1] and view.chains[1].target==4 then seenReturn=true end
        if view.chains[1] and view.chains[1].target==6 then seenSecond=true end
        highest=math.max(highest,guest.game.pending)
    end
    assert(seenFlight and seenReturn and seenSecond)
    eq(board.lockedShots,1); eq(board.score,130); eq(board.attack,2)
    eq(guest.game.pending,2); eq(highest,2); eq(guest.Net.match.remote:Pack(),board:Pack())
    host.Net.State(); tick(1); eq(guest.game.pending,2)
    host.Net.Leave(); guest.Net.Leave(); tick(1)
end)
test("manual chain challenge identifies rules and standard offers still use the old wire format",function()
    local host,guest=client("Faye"),client("Gray")
    host.db.versusChains=true
    host.Net.Challenge("Gray-TestRealm"); tick(2)
    eq(guest.Net.match.phase,"invite"); assert(guest.Net.notice:find("with chain reactions",1,true))
    guest.Net.Accept(); tick(4); assert(guest.game.chainReaction)
    host.Net.Finish("lost","Forfeited",true); tick(3)
    host.Net.Leave(); guest.Net.Leave()
    host.db.versusChains=false; host.Net.Challenge("Gray-TestRealm"); tick(2)
    eq(guest.Net.match.phase,"invite"); assert(not guest.Net.match.chainReaction)
    guest.Net.Accept(); tick(4); assert(not guest.game.chainReaction)
    local m=guest.Net.match; local packed=host.game:Pack()
    guest.Net.Receive(FB.PREFIX,"1|STATE|"..m.id.."|999|1|0|0|0|"..packed,"WHISPER","Faye-TestRealm")
    eq(m.remoteShots,1); eq(m.remote:Pack(),packed)
    host.Net.Leave(); guest.Net.Leave(); tick(1)
end)
test("victory limits match identical queues and both clients replay a fresh board after dropped readiness",function()
    local h,j=client("Arena"),client("Basin")
    h.db.versusChains,j.db.versusChains=true,true
    h.db.versusLimit,j.db.versusLimit=2,3
    h.Net.SetQueue(true); j.Net.SetQueue(true); tick(10)
    assert(h.Net.queue and j.Net.queue and not h.Net.match and not j.Net.match)
    j.Net.SetQueue(false); j.db.versusLimit=2; j.Net.SetQueue(true); tick(10)
    local first=h.Net.match
    assert(first.host and first.capable and j.Net.match.capable); eq(first.series.limit,2)
    eq(first.round,1); eq(j.Net.match.series.limit,2)
    local firstBoard=h.game:Pack()
    j.game.status="lost"; tick(4)
    eq(first.series.wins,1); eq(j.Net.match.series.losses,1)
    local ready=false
    j.UI={CanAutoRematch=function() return ready end,RefreshLobby=function() end}
    drops.AGAIN=true; drops.ROUNDSTART=true; drops.READY=true; drops.GO=true
    h.Series.Ready(); tick(5)
    eq(h.Net.match,first); assert(j.Net.match.peerReady and not j.Net.match.ready)
    ready=true; tick(10)
    local m=h.Net.match
    eq(m.phase,"playing"); eq(j.Net.match.phase,"playing"); eq(m.id,j.Net.match.id)
    assert(m.id~=first.id and h.game:Pack()~=firstBoard and h.game.chainReaction)
    eq(h.game:Pack(),j.game:Pack()); eq(m.round,2); eq(m.series.wins,1)
    h.Net.Receive(h.PREFIX,"1|END|"..first.id.."|lost","WHISPER",j.PlayerName())
    h.Net.Receive(h.PREFIX,"1|AGAIN|"..first.id.."|lost","WHISPER",j.PlayerName())
    eq(h.db.wins,1); eq(h.game.status,"playing")
    j.game.status="lost"; tick(4)
    eq(m.series.wins,2); eq(j.Net.match.series.losses,2)
    assert(h.Series.Complete(m) and not j.Series.CanContinue(j.Net.match))
    eq(h.Series.Caption(m),"Series won · 2–0")
    h.Series.Ready(); tick(3); eq(h.Net.match,m); eq(h.db.wins,2)
    h.Net.Leave(); tick(4); j.Net.Leave()
    for _,client in ipairs({h,j}) do
        local log=table.concat(client.Community.log,"\n")
        assert(log:find("*** Game finished, because victories limit of 2 was reached.",1,true))
        assert(log:find("*** Winner: Arena\n*** Scores: Arena: 2, Basin: 0",1,true))
        local _,count=log:gsub("Addicted for:",""); eq(count,1)
    end
end)
test("a draw gives neither player a round and a departure closes a pending rematch",function()
    local h,j=client("Cairn"),client("Dune")
    h.db.versusLimit=1; h.Net.Challenge(j.PlayerName()); tick(2); j.Net.Accept(); tick(4)
    h.Net.Finish("lost","finished",true); j.Net.Finish("lost","finished",true); tick(4)
    eq(h.Net.match.result,"draw"); eq(j.Net.match.result,"draw")
    eq(h.Net.match.series.losses,0); eq(j.Net.match.series.losses,0)
    assert(h.Series.CanContinue(h.Net.match) and not h.Series.Complete(h.Net.match))
    j.Series.Ready(); tick(2); assert(h.Net.match.peerReady)
    h.Net.Leave(); tick(3)
    assert(j.Net.match.departed and not j.Series.CanContinue(j.Net.match)); eq(j.db.wins,0); eq(h.db.losses,0)
end)
test("five-player arena joins, survives lost control packets, targets penalties and scores a series",function()
    local team={}
    for i,name in ipairs({"Orchid","Pine","Quartz","Rose","Sage"}) do team[i]=client(name) end
    local h=team[1]; h.db.versusLimit=2; h.db.versusChains=true; h.db.arenaContinue=false
    h.Arena.Host(); tick(2)
    local host=h.PlayerName(); local room=h.Net.match.room
    assert(team[2].Arena.rooms[host].chains); eq(team[2].Arena.rooms[host].limit,2)
    drops.AJOIN=true; drops.ASEATS=true
    for i=2,5 do team[i].Arena.Join(host) end
    tick(17)
    for _,fb in ipairs(team) do
        eq(#fb.Net.match.names,5); eq(fb.Net.match.phase,"room"); eq(fb.Net.match.room,room)
    end
    local extra=client("Juniper"); extra.Arena.Join(host); tick(2); eq(extra.Net.match,nil)
    drops.APREP=true; drops.APULSE=true; drops.AHOST=true; h.Arena.Start(); tick(15)
    for _,fb in ipairs(team) do
        eq(fb.Net.match.phase,"playing"); eq(fb.game:Pack(),h.game:Pack()); eq(fb.Net.match.round,1)
        assert(fb.game.chainReaction and fb.game.onPenalty)
    end
    local opponent=h.Arena.Opponents(h.Net.match)[1].name
    h.game.shots,h.game.lockedShots=1,1; h.game.onPenalty(5); tick(5)
    for i=2,5 do eq(team[i].game.pending,2) end
    h.Arena.Target(1); h.game.shots,h.game.lockedShots=2,2; h.game.onPenalty(6)
    drops.ASTATE=true; tick(9)
    for i=2,5 do
        local fb=team[i]; eq(fb.game.pending,fb.PlayerName()==opponent and 8 or 2)
        eq(fb.Net.match.players[host].target,opponent)
    end
    h.Arena.Target(0); assert(h.game:Shoot(0.34)); tick(1)
    for i=2,5 do assert(team[i].Net.match.players[host].remote.shots>=3) end
    local firstID=h.Net.match.id
    team[2].game.status="lost"; tick(5)
    for _,fb in ipairs(team) do eq(fb.Net.match.phase,"playing"); assert(fb.Net.match.players[team[2].PlayerName()].lost) end
    for i=3,5 do team[i].game.status="lost" end
    tick(8)
    for _,fb in ipairs(team) do
        local m=fb.Net.match
        eq(m.phase,"done"); eq(m.names[m.winner],host); eq(m.players[host].wins,1)
        fb.UI={CanAutoRematch=function() return true end,RefreshLobby=function() end}
    end
    team[3].Arena.Start(); tick(20)
    for _,fb in ipairs(team) do eq(fb.Net.match.round,2); eq(fb.Net.match.phase,"playing"); eq(fb.game:Pack(),h.game:Pack()) end
    local prior=h.Net.match.players[team[2].PlayerName()].remoteSeq
    h.Net.Receive(h.PREFIX,"1|AFIRE|"..firstID.."|8|1|1|0|1|1|1|1|"..h.game:Pack(),"WHISPER",team[2].PlayerName())
    eq(h.Net.match.players[team[2].PlayerName()].remoteSeq,prior)
    for i=2,5 do team[i].game.status="lost" end
    tick(10)
    for _,fb in ipairs(team) do
        assert(fb.Arena.Complete(fb.Net.match)); eq(fb.Net.match.players[host].wins,2)
        eq(fb.db.wins,fb==h and 2 or 0); eq(fb.db.losses,fb==h and 0 or 2)
    end
    team[4].Net.Leave(); tick(3)
    for _,fb in ipairs(team) do eq(fb.Net.match,nil) end
end)
test("room departures retain the other seats and all remaining players can draw and rematch",function()
    local h=client("Cedar"); local j=client("Birch-"..string.rep("T",64)); local k=client("Ash")
    local long=client("Oak-"..string.rep("R",65))
    local host=h.PlayerName()
    h.db.arenaTargeting=false; h.Arena.Host()
    for _,fb in ipairs({j,k,long}) do fb.Arena.Join(host) end
    tick(8); h.Arena.Start(); tick(9)
    eq(h.Net.match.phase,"playing"); eq(long.Net.match.phase,"playing")
    assert(not long.Net.match.targeting and long.Net.match.keepRoom); long.Arena.Target(1); eq(long.Net.match.target,nil)
    local gone=k.PlayerName(); k.Arena.Leave(); tick(7)
    for _,fb in ipairs({h,j,long}) do assert(fb.Net.match.players[gone].left); eq(fb.Net.match.phase,"playing") end
    eq(k.db.losses,1)
    h.game.status="lost"; j.game.status="lost"; long.game.status="lost"; tick(8)
    for _,fb in ipairs({h,j,long}) do
        local m=fb.Net.match; eq(m.winner,0); eq(m.phase,"done"); eq(fb.db.losses,0)
        fb.Arena.Start()
    end
    tick(12)
    for _,fb in ipairs({h,j,long}) do
        local m=fb.Net.match; eq(m.round,2); eq(m.phase,"playing"); assert(m.players[gone].left and m.players[gone].lost)
    end
    local room=h.Net.match
    -- A winner can leave before the host closes. Their victory still counts.
    h.game.status="lost"; j.game.status="lost"; tick(8)
    eq(room.names[room.winner],long.PlayerName())
    long.Arena.Leave(); tick(5); assert(room.players[long.PlayerName()].left)
    assert(room.mask~=room.finalMask)
    h.Arena.Leave(); tick(4); eq(j.Net.match,nil); eq(long.Net.match,nil)
    for _,fb in ipairs({h,j}) do
        local scores=table.concat(fb.Community.log,"\n"):match("%*%*%* Scores: ([^\n]+)")
        assert(scores:find("Oak: 1",1,true)==1 and scores:find("Ash: 0",1,true))
    end
end)
test("the host's final standings survive a lost result and close, with older guests still seeing their lobby",function()
    local h,j,k=client("Glacier"),client("Snowcap"),client("Drift")
    local host,guest,older=h.PlayerName(),j.PlayerName(),k.PlayerName()
    local legacySend=k.Net.Send
    k.Net.Send=function(kind,channel,to,...)
        local args={...}
        if kind=="AJOIN" then args[4]=nil end
        return legacySend(kind,channel,to,(unpack or table.unpack)(args))
    end
    h.db.versusLimit=1; h.Arena.Host(); j.Arena.Join(host); k.Arena.Join(host)
    tick(8); h.Arena.Start(); tick(10)
    local room=h.Net.match; assert(room.players[guest].canFinal and not room.players[older].canFinal)
    local send=h.Net.Send
    local lostClose,final,legacy
    h.Net.Send=function(kind,channel,to,...)
        local args={...}
        if kind=="AHOST" and to==guest and args[5]>=0 then return true end
        if kind=="ACLOSE" then
            if to==guest then
                eq(args[2],"final")
                if not lostClose then lostClose=true; return true end
                final=table.concat(args,"|")
            elseif to==older then legacy=#args==1 end
        end
        return send(kind,channel,to,...)
    end
    h.game.status="lost"; k.game.status="lost"; tick(8)
    eq(room.phase,"done"); eq(room.names[room.winner],guest); eq(j.Net.match.phase,"playing")
    -- Only the host of this room can close it, and its winner must agree with the loss mask.
    local forged="1|ACLOSE|"..room.room.."|final|1|0|1|0|Closed."
    j.Net.Receive(j.PREFIX,forged,"WHISPER",host); j.Net.Receive(j.PREFIX,forged,"WHISPER",older)
    eq(j.Net.match.phase,"playing")
    h.Arena.Leave(); tick(10); assert(lostClose and final and legacy)
    eq(j.Net.match,nil); eq(k.Net.match,nil); eq(j.db.wins,1); eq(h.db.losses,1)
    for _,side in ipairs({h,j,k}) do
        local log=table.concat(side.Community.log,"\n")
        assert(log:find("*** Winner: Snowcap",1,true))
        local rows=log:match("%*%*%* Scores: ([^\n]+)")
        assert(rows:find("Snowcap: 1, ",1,true)==1 and rows:find("Drift: 0",1,true) and rows:find("Glacier: 0",1,true))
    end
    local logSize=#j.Community.log
    j.Net.Receive(j.PREFIX,"1|ACLOSE|"..final,"WHISPER",host); eq(#j.Community.log,logSize); eq(j.db.wins,1)
    tick(41); eq(h.Arena.closedRooms[room.room],nil)
end)
test("remote rising penalties round-trip all seven lanes; malformed frames are ignored",function()
    for offset=0,1 do
        local g=E.New({},1,"versus"); g.offset=offset
        for col=1,7 do g.rising[col]={row=col+1,col=col,color=8-col,y=380+col} end
        local wire=a.PeerView.PackRising(g); eq(#wire,28)
        local restored=a.PeerView.UnpackRising(wire,offset)
        for i,b in ipairs(restored) do
            eq(b.col,i); eq(b.row,i+1); eq(b.color,8-i); eq(b.y,380+i); eq(b.x,E.Position(13,i,0,offset))
        end
    end
    for _,wire in ipairs({"abc", "----","0000", "0?00",string.rep("0",32)}) do
        assert(not a.PeerView.UnpackRising(wire,0))
    end
end)
test("spectators see the desktop penalty flight, freeze and snap on the board clock",function()
    local peer=a.PeerView
    local view=peer.NewDuelBoard(11,false)
    view.grid={[1]=1}; view.attachedOrder={1}; view.shots=1; view.lockedShots=1; view.tick=186
    local m={phase="playing",remote=view,remoteSeq=1}
    local owner=E.New({},11,"versus")
    owner.rising={{row=6,col=1,color=6,y=378}}
    local packet={"1","ARISE","round","2","186","1","0","3",peer.PackRising(owner)}
    local before=view:Pack()
    for index,invalid in pairs({[4]="1",[5]="-1",[6]="2",[7]="1",[8]="-1",[9]="...."}) do
        local valid=packet[index]; packet[index]=invalid
        assert(not peer.Rise(m,packet)); packet[index]=valid
    end
    eq(m.remoteSeq,1); eq(view:Pack(),before)
    assert(peer.Rise(m,packet)); assert(not peer.Rise(m,packet)); eq(view.pending,3)
    -- Desktop demo 4, rp3 at (20,247), frames 186 onward. At y=295
    -- the sprite waits above its final staggered socket until it sticks.
    for frame,y in ipairs({385,355,325,295,295,295}) do
        if frame>1 then peer.StepDuel(m) end
        local b=view.rising[1]; assert(b)
        eq(247+peer.RisingY(view,b,true)/2-8,y)
        if frame==1 then eq(peer.RisingY(view,b,false),322) end
    end
    peer.StepDuel(m); eq(#view.rising,0); eq(view.grid[E.Key(6,1)],6)
    -- A delayed launch after a newer snapshot must not add the bubble twice.
    assert(not peer.Rise(m,packet)); eq(view:Count(),2)
end)
test("queued board snapshots preserve the penalty launch between them",function()
    local c=client("VolleyQueue"); local net=c.Net
    for _,prefix in ipairs({"","A"}) do
        net.outbox={}
        for _,kind in ipairs({"STATE","RISE","STATE","STATE"}) do net.Send(prefix..kind,"WHISPER","Peer","round") end
        eq(#net.outbox,3); eq(net.outbox[1].kind,prefix.."STATE"); eq(net.outbox[2].kind,prefix.."RISE")
    end
    net.outbox={}
end)
test("lost end packets and a simultaneous loss settle after leaving the result screen",function()
    local h,j=client("Heidi"),client("June")
    h.Net.Challenge("June-TestRealm"); tick(2); j.Net.Accept(); tick(4)
    drops.END=true
    h.Net.Finish("lost","Round over",true); h.Net.Leave()
    j.Net.Finish("lost","Round over",true); j.Net.Leave()
    h.game=h.Engine.New({},1,"custom"); j.game=j.Engine.New({},1,"custom")
    tick(5)
    eq(h.db.losses,0); eq(j.db.losses,0); eq(h.db.wins,0); eq(j.db.wins,0)
    eq(h.game.status,"playing"); eq(j.game.status,"playing")
    for _,side in ipairs({h,j}) do
        local log=table.concat(side.Community.log,"\n")
        assert(log:find("*** A round was corrected to a draw.\n*** Draw game!\n*** Scores: June: 0, Heidi: 0",1,true))
        local _,count=log:gsub("Addicted for:",""); eq(count,1)
    end
    tick(21); assert(not next(h.Net.results) and not next(j.Net.results))
end)
test("unanswered direct challenge expires",function()
    local c=client("Cora"); c.Net.Challenge("Absent-TestRealm"); tick(22); eq(c.Net.match,nil)
end)
test("community verifies self-echo before advertising automatically",function()
    a.Community.Join(); tick(2); eq(a.Community.state,"ready")
    a.Community.Manual("CATALOG"); eq(a.lastManual,"FBF1|1|CATALOG")
end)
test("lobby chat uses the community channel and displays one escaped copy per echo",function()
    local host=client("Chatter"); local peer=client("Listener"); local c=host.Community
    assert(not c.Say("before joining")); c.Join(); peer.Community.Join(); tick(2)
    local message="Anyone for a round? |cffffffff"
    assert(c.Say(message)); tick(1)
    local expected="<"..host.PlayerName().."> Anyone for a round? ||cffffffff"
    eq(c.log[1],expected); eq(peer.Community.log[1],expected); eq(#c.log,1)
    peer.Net.Receive(peer.PREFIX,"1|LOBBY|wrong channel","GUILD",host.PlayerName())
    peer.Net.Receive(peer.PREFIX,"1|LOBBY|bad\nline","CHANNEL",host.PlayerName())
    eq(#peer.Community.log,1)
    c.Blocked(); assert(c.Say("meet | at 5")); eq(host.lastManual,"FBF1|1|LOBBY|meet | at 5")
    peer.Community.Chat(host.lastManual,host.PlayerName(),"General"); eq(#peer.Community.log,1)
    peer.Community.Chat(host.lastManual,host.PlayerName(),c.name)
    eq(peer.Community.log[2],"<"..host.PlayerName().."> meet || at 5")
    assert(not c.Say(string.rep("x",161))); assert(not c.Say("   "))
    for i=1,101 do c.Log(tostring(i)) end
    eq(#c.log,100); eq(c.log[1],"*** 2")
end)
test("the host can revise all four room rules immediately before starting",function()
    local host,first,second=client("RoomHost"),client("IceGuest"),client("SnowGuest")
    host.Arena.Host()
    first.Arena.Join(host.PlayerName()); second.Arena.Join(host.PlayerName()); tick(5)
    first.Arena.SetRule("versusLimit",100); eq(first.Net.match.limit,host.Net.match.limit)
    host.Arena.SetRule("versusChains",true); host.Arena.SetRule("versusLimit",12)
    host.Arena.SetRule("arenaContinue",false); host.Arena.SetRule("arenaTargeting",false)
    drops.ASEATS=true; host.Arena.Start(); tick(16)
    for _,peer in ipairs({host,first,second}) do
        local m=peer.Net.match
        eq(m.phase,"playing"); eq(m.limit,12); assert(m.chainReaction and peer.game.chainReaction)
        assert(not m.keepRoom and not m.targeting)
    end
    host.Arena.SetRule("versusLimit",1); eq(host.Net.match.limit,12)
    host.Arena.Leave(); tick(2)
end)
test("room chat and emotes reach only seated players, with names resolved against the right roster",function()
    local host,guest,third,outside=client("TalkHost"),client("SnowOne"),client("SnowTwo"),client("Outsider")
    for _,c in ipairs({host,guest,third,outside}) do c.Community.Join() end
    host.Arena.Host(); guest.Arena.Join(host.PlayerName()); third.Arena.Join(host.PlayerName()); tick(5)
    local m=guest.Net.match
    local nobody=#outside.Community.log
    assert(guest.LobbyCommands.Submit("/me waves | hello",m)); tick(2)
    for _,c in ipairs({host,guest,third}) do eq(c.Community.log[#c.Community.log],"[Room] * "..guest.PlayerName().." waves || hello") end
    eq(#outside.Community.log,nobody)
    local before=#guest.Community.log
    guest.Net.Receive(guest.PREFIX,"1|ARLINE|"..m.room.."|"..m.revision.."|1|foreign","WHISPER",outside.PlayerName())
    eq(#guest.Community.log,before)
    eq(guest.LobbyCommands.Complete("Sn",m),"Snow"); eq(guest.LobbyCommands.Complete("Tell Talk",m),"Tell "..host.PlayerName().." ")
    eq(guest.LobbyCommands.Complete("talkh",m),host.PlayerName()..": ")
    assert(not guest.LobbyCommands.Submit("/kick SnowTwo",m)); assert(not guest.LobbyCommands.Submit("/unknown",m))
    assert(guest.LobbyCommands.Submit("/list",m)); assert(guest.Community.log[#guest.Community.log]:find(third.PlayerName(),1,true))
    assert(guest.LobbyCommands.Submit("Public too",nil)); tick(2)
    eq(outside.Community.log[#outside.Community.log],"<"..guest.PlayerName().."> Public too")
    host.Arena.Leave(); tick(2)
    assert(not guest.LobbyCommands.Submit("old draft",m)); eq(#outside.Community.log,nobody+1)
end)
test("mixed-version rooms keep their seats and disable private chat",function()
    local host,guest=client("CrossHost"),client("CrossGuest")
    host.Arena.Host(); guest.Arena.Join(host.PlayerName()); tick(5)
    local m=host.Net.match
    assert(guest.Arena.CanChat(guest.Net.match))
    host.Net.Receive(host.PREFIX,"1|AJOIN|"..m.room.."|123-1","WHISPER","Older-TestRealm")
    tick(3)
    eq(#m.names,3); assert(not host.Arena.CanChat(m))
    assert(not guest.Arena.CanChat(guest.Net.match)); assert(not guest.LobbyCommands.Submit("team only",guest.Net.match))
    host.Net.Receive(host.PREFIX,"1|ALEAVE|"..m.room.."|123-1","WHISPER","Older-TestRealm")
    tick(3); assert(guest.Arena.CanChat(guest.Net.match)); host.Arena.Leave(); tick(2)
    guest.Arena.Join("Older-TestRealm")
    local join=guest.Net.match
    guest.Net.Receive(guest.PREFIX,"1|ASEATS|889-1|"..join.nonce.."|1|2|1|1|Older-TestRealm,"..guest.PlayerName().."|3","WHISPER","Older-TestRealm")
    eq(join.phase,"room"); assert(not guest.Arena.CanChat(join)); guest.Arena.Leave(); tick(2)
end)
test("a kicked seat is reclaimed after lost delivery and stale packets cannot close a fresh join",function()
    local host,guest,third=client("KickHost"),client("Floe"),client("Glacier")
    host.Arena.Host(); guest.Arena.Join(host.PlayerName()); third.Arena.Join(host.PlayerName()); tick(5)
    local room,join=host.Net.match,guest.Net.match
    assert(not host.LobbyCommands.Submit("/kick KickHost",room))
    drops.ACLOSE=true
    assert(host.LobbyCommands.Submit("/kick floe practice | run",room)); eq(#room.names,2)
    host.Net.Receive(host.PREFIX,"1|AJOIN|"..room.room.."|"..join.nonce,"WHISPER",guest.PlayerName())
    eq(#room.names,2); tick(8)
    eq(guest.Net.match,nil); eq(guest.Arena.hiddenRoom.id,room.room); assert(guest.Net.notice:find("practice | run",1,true))
    eq(#third.Net.match.names,2)
    guest.Arena.Join(host.PlayerName()); tick(5)
    local again=guest.Net.match; eq(again.phase,"room"); assert(again.nonce~=join.nonce)
    guest.Net.Receive(host.PREFIX,"1|ACLOSE|"..room.room.."|"..join.nonce.."|late","WHISPER",host.PlayerName())
    eq(guest.Net.match,again)
    assert(host.LobbyCommands.Submit("/autokick Floe members only",room)); tick(5); eq(guest.Net.match,nil)
    guest.Arena.Join(host.PlayerName()); tick(5); eq(guest.Net.match,nil); eq(#room.names,2)
    assert(host.LobbyCommands.Submit("/autokick",room)); assert(host.Community.log[#host.Community.log]:find(guest.PlayerName(),1,true))
    assert(host.LobbyCommands.Submit("/autokick Floe",room)); guest.Arena.Join(host.PlayerName()); tick(5)
    eq(#room.names,3); eq(guest.Net.match.phase,"room"); eq(guest.db.losses,0)
    host.Arena.Leave(); tick(2)
end)
test("the public player list discovers open lobbies through a correlated whisper reply",function()
    local caller,listener,absent=client("Lister"),client("SilentObserver"),client("AbsentObserver")
    for _,c in ipairs({caller,listener,absent}) do c.Community.Join() end
    tick(2)
    listener.UI={screen="lobby",RefreshLobby=function() end,frame={IsShown=function() return true end}}
    assert(caller.LobbyCommands.Submit("/list")); tick(5)
    local q=caller.Community.who
    assert(q.names[listener.PlayerName()]); eq(q.names[absent.PlayerName()],nil); eq(q.untilTime,nil)
    eq(caller.LobbyCommands.Complete("Silent"),listener.PlayerName()..": ")
    caller.Net.Receive(caller.PREFIX,"1|LHERE|"..q.nonce,"WHISPER",absent.PlayerName()); eq(q.count,2)
    caller.Community.Blocked(); assert(caller.LobbyCommands.Submit("/list"))
    listener.Community.Chat(caller.lastManual,caller.PlayerName(),caller.Community.name); tick(5)
    assert(caller.Community.who.names[listener.PlayerName()])
    listener.UI=nil
end)
test("level validation accepts original floating groups and rejects out-of-editor rows",function()
    local g=E.New({},1); g.grid={[17]=1}; assert(a.Community.Validate(g:Pack()))
    g.grid={[1]=1,[9]=2}; assert(a.Community.Validate(g:Pack()))
    g.grid[E.Key(11,1)]=3; assert(not a.Community.Validate(g:Pack()))
end)
test("P2P catalog and requested level download persist without execution",function()
    local g=E.New({},1); g.grid={[1]=1,[2]=2,[9]=3}
    local id=assert(a.Community.Save("Ice bridge",g:Pack()))
    a.Community.Publish(id,false); tick(2)
    local key="Alice-TestRealm:"..id
    assert(b.Community.catalog[key]); b.Community.Request(key); tick(3)
    eq(b.db.custom[id].data,g:Pack()); eq(b.db.custom[id].author,"Alice-TestRealm")
    assert(not b.db.custom[id].published)
end)
test("desktop level-file import preserves colors, row offsets, whitespace and board order",function()
    local c=a.Community
    local first=E.New({"12345678","8765432"},1):Pack()
    local second=E.New({"...8...."},1):Pack()
    local written=c.LevelText({first,second})
    assert(written:find("0   1   2   3   4   5   6   7\n  7   6   5   4   3   2   1",1,true))
    local read=c.Decode(written:gsub("\n","\r\n")); eq(#read,2); eq(read[1],first); eq(read[2],second)
    eq(c.Decode("0 1 2 3 4 5 6 7\n  7 6 5 4 3 2 1")[1],first)
    eq(c.Decode("0 1 2 3 4 5 6 8"),nil); eq(c.Decode("0 1 2 3 4 5 6 7\n0 1"),nil)
end)
test("ordered sets recover lost pages and commit only the requested complete set",function()
    local host,guest=client("Levels"),client("Reader")
    host.Community.Join(); guest.Community.Join(); tick(2)
    local boards={}
    for i=1,100 do
        local board=E.New({},1); board.grid[1]=i%8+1; board.grid[2]=math.floor(i/8)%8+1
        boards[i]=board:Pack()
    end
    local id=assert(host.Community.SaveSet("Long set",boards))
    local key=host.PlayerName()..":"..id
    host.Community.Publish(id,true); guest.Community.Chat(host.lastManual,host.PlayerName(),guest.Community.name)
    eq(guest.Community.catalog[key].count,100)
    drops.BOARDS=true; guest.Community.Request(key); tick(1)
    assert(not guest.db.custom[id])
    guest.Community.Receive("1|BOARDS|"..id.."|3|"..boards[3]..boards[4],"WHISPER",host.PlayerName())
    guest.Community.Receive("1|BOARDS|"..id.."|1|"..boards[1]..boards[2],"WHISPER","Other-TestRealm")
    eq(#guest.Community.pending[key].boards,0)
    drops.GETBOARDS=true
    for _=1,120 do
        tick(1)
        if guest.db.custom[id] then break end
    end
    assert(guest.db.custom[id]); eq(guest.Community.pending[key],nil)
    eq(guest.db.custom[id].author,host.PlayerName()); eq(guest.db.custom[id].published,false)
    for n,data in ipairs(guest.db.custom[id].boards) do eq(data,boards[n]) end
    eq(#guest.db.custom[id].boards,100)
    local imported=host.Community.Decode(host.Community.Code(boards))
    eq(table.concat(imported),table.concat(boards))
    local wrong="s123"; key=host.PlayerName()..":"..wrong
    guest.Community.Receive("1|LEVELSET|"..wrong.."|Fake|2","CHANNEL",host.PlayerName())
    guest.Community.Request(key)
    guest.Community.Receive("1|BOARDS|"..wrong.."|1|"..boards[1]..boards[2],"WHISPER",host.PlayerName())
    eq(guest.Community.pending[key],nil); eq(guest.db.custom[wrong],nil)
end)
test("named copies share by layout checksum and unfinished sets stay local",function()
    local host,guest=client("Painter"),client("Collector")
    host.Community.Join(); guest.Community.Join(); tick(2)
    local c=host.Community
    local one=E.New({"1......."},1):Pack()
    for _,boards in ipairs({{one},{one,one}}) do
        local first=assert(c.SaveSet("Ice",boards))
        local copy=assert(c.SaveSet("Snow",boards))
        assert(first~=copy); eq(host.db.custom[copy].id,first)
        local key=host.PlayerName()..":"..first
        assert(c.Publish(first)); tick(2)
        guest.Community.Request(key); tick(3); eq(guest.db.custom[first].title,"Ice")
        assert(c.Publish(copy)); tick(2)
        assert(not host.db.custom[first].published and host.db.custom[copy].published)
        eq(guest.Community.catalog[key].title,"Snow")
        guest.Community.Request(key); tick(3)
        eq(guest.db.custom[first].title,"Ice")
        local received
        for _,item in pairs(guest.db.custom) do if item.id==first and item.title=="Snow" then received=item end end
        assert(received); eq(received.author,host.PlayerName())
        eq(guest.Community.Code(guest.Community.Boards(received)),c.Code(boards))
        local draft=assert(c.SaveSet("Snow",{one,c.blankBoard},nil,copy))
        assert(not c.Publish(draft)); eq(host.db.custom[draft].emptyBoard,2)
        eq(host.db.custom[first].title,"Ice"); assert(not host.db.custom[first].published)
        assert(not guest.Community.SaveSet("Invalid transfer",{one,c.blankBoard},host.PlayerName()))
    end
end)
test("a full level library can finish an existing draft without consuming another slot",function()
    local host=client("Builder")
    local c=host.Community
    local draft
    for i=1,100 do draft=assert(c.SaveSet("Draft "..i,{c.blankBoard})) end
    assert(not c.SaveSet("Overflow",{c.blankBoard}))
    local invalid="9"..c.blankBoard:sub(2)
    assert(not c.SaveSet("Invalid",{invalid},nil,draft)); eq(host.db.custom[draft].title,"Draft 100")
    local id=assert(c.SaveSet("Ready",{E.New({"....2..."},1):Pack()},nil,draft))
    eq(host.db.custom[draft],nil); assert(not host.db.custom[id].emptyBoard); eq(host.db.custom[id].title,"Ready")
end)
test("unsolicited or corrupt level downloads cannot write the library",function()
    b.Community.Receive("1|LEVELDATA|12|"..string.rep("1",98),"WHISPER","Alice-TestRealm")
    eq(b.db.custom["12"],nil)
    local id="20"; local key="Alice-TestRealm:"..id
    b.Community.pending[key]={sent=clock,peer="Alice-TestRealm",id=id,title="bad"}
    b.Community.Receive("1|LEVELDATA|20|"..string.rep("1",98),"WHISPER","Alice-TestRealm")
    eq(b.db.custom[id],nil)
end)
test("score validation and bounded personal history",function()
    a.Scores.Receive("Bob-TestRealm",{"1","SCORE","campaign","nan","1","10"})
    eq(a.db.peers["Bob-TestRealm:campaign"],nil)
    a.Scores.Receive("Bob-TestRealm",{"1","SCORE","campaign","100","2","10"})
    eq(a.db.peers["Bob-TestRealm:campaign"].score,100)
    for i=1,40 do a.Scores.Record("campaign",i,1,i) end
    eq(#a.db.scores,30); eq(a.Scores.Best("campaign").score,1)
end)
test("existing campaign records rank by progress and then time; only confirmed clears outrank level 100",function()
    local c=client("Iona")
    local function old(points,level,seconds)
        return {name=c.PlayerName(),mode="campaign",score=points,level=level,seconds=seconds,date=1}
    end
    local early,slow,fast=old(900,12,10),old(40,100,600),old(30,100,400)
    c.db.scores={early,slow,fast}; c.Scores.Init(c.db)
    eq(c.Scores.Best("campaign"),fast); eq(c.Scores.Rows(false,"campaign")[2],slow)
    local clear=c.Scores.Record("campaign",5,100,1000,true)
    eq(c.Scores.Best("campaign"),clear); assert(not fast.completed)
    for i=1,40 do c.Scores.Record("campaign",i,5,10+i) end
    eq(#c.Scores.Rows(false,"campaign"),30); eq(c.Scores.Rows(false,"campaign")[4],early)
end)
test("score names use separate desktop cutoffs, survive reload, and stay private to the local table",function()
    local c=client("Peggy")
    local s=c.Scores
    for i=1,10 do s.Record("campaign",10,17,100+i/100) end
    local missed=s.Finish("campaign",9999,17,100.11)
    eq(s.Pending(),nil); eq(missed.seconds,100)
    local exact=s.Finish("campaign",0,17,100.10)
    eq(s.Pending(),exact); eq(#s.Rows(false,"campaign"),11)
    local accepted=s.Submit(exact,"  Pépin-Deux  "); eq(accepted,exact)
    eq(accepted.displayName,"Pépin-Deux"); eq(accepted.name,c.PlayerName()); eq(s.Submit(exact,"again"),nil)
    eq(s.Rows(false,"campaign")[12],missed)
    for i=1,20 do s.Record("training",50,1,120) end
    eq(s.Finish("training",49,1,120).score,49); eq(s.Pending(),nil)
    local chain=s.Finish("training-chain",1,1,120)
    local regular=s.Finish("training",50,1,121)
    s.Init(c.db); eq(s.Pending(),chain); eq(s.Best("training-chain"),nil)
    local alt=client("OtherPenguin"); alt.db=c.db
    eq(alt.Scores.Pending(chain),nil); eq(alt.Scores.Submit(chain,"Other"),nil)
    eq(s.Submit(regular,"  "),nil); eq(s.Pending(regular),nil)
    s.Submit(chain,"Snow|ball"); eq(s.Best("training-chain").displayName,"Snowball")
    c.Community.Join(); tick(2); c.Community.Manual("SCORE",s.Fields(chain))
    eq(c.lastManual,"FBF1|1|SCORE|training-chain|1|1|120|0")
end)
test("community scores preserve clears across query and manual channel packets; alts keep their own names",function()
    local c=client("Ilse")
    local d=client("Jon")
    c.Community.Join(); d.Community.Join(); tick(2)
    local row=c.Scores.Record("campaign",20,100,1200.78,true)
    c.db.scores[#c.db.scores+1]={name="Alt-TestRealm",mode="campaign",score=100,level=100,seconds=40,completed=true}
    d.Net.RequestScores(); tick(3)
    local received=d.db.peers[c.PlayerName()..":campaign"]
    assert(received.completed); eq(received.seconds,1200); eq(received.elapsed,1200.78)
    c.Community.Manual("SCORE",c.Scores.Fields(row))
    eq(c.lastManual,"FBF1|1|SCORE|campaign|20|100|1200|1|780")
    d.Community.Chat(c.lastManual,c.PlayerName(),d.Community.name)
    d.Scores.Receive(c.PlayerName(),{"1","SCORE","campaign","999","100","60"})
    eq(d.db.peers[c.PlayerName()..":campaign"],received)
    d.Scores.Receive("Alt-TestRealm",{"1","SCORE","campaign","8","2","9","1"})
    eq(d.db.peers["Alt-TestRealm:campaign"],nil)
    c.Scores.Receive("Alt-TestRealm",{"1","SCORE","campaign","6","100","55","1"})
    local all=c.Scores.Rows(true,"campaign"); eq(#all,2); eq(all[1].seconds,40)
end)
test("campaign rankings retain millisecond finishes through channel chat, queries and old peers",function()
    local host,viewer=client("Zinnia"),client("Amos")
    host.Community.Join(); viewer.Community.Join(); tick(2)
    local name=host.PlayerName()
    local function announce(rest) viewer.Community.Chat("FBF1|1|SCORE|campaign|100|35|60|0"..rest,name,viewer.Community.name) end
    local function remote() return viewer.db.peers[name..":campaign"] end
    local function firstRival()
        for _,row in ipairs(viewer.Scores.Rows(true,"campaign")) do
            if row.name==name or row.name==viewer.PlayerName() then return row.name end
        end
    end
    viewer.Scores.Record("campaign",100,35,60.65)
    announce(""); assert(remote() and not remote().elapsed)
    local r=host.Scores.Record("campaign",100,35,60.9)
    viewer.Net.RequestScores(); tick(3)
    eq(remote().elapsed,60.9); eq(firstRival(),viewer.PlayerName())
    announce(""); eq(remote().elapsed,60.9)
    host.Scores.Record("campaign",100,35,60.14)
    host.Community.Manual("SCORE",host.Scores.Fields(host.Scores.Best("campaign")))
    viewer.Community.Chat(host.lastManual,name,viewer.Community.name)
    eq(remote().elapsed,60.14); eq(firstRival(),name)
    for _,packet in ipairs({"|1190","|-1","|0.1","|NaN","|2e99","|700",""}) do announce(packet); eq(remote().elapsed,60.14) end
    local boundary=host.Scores.Record("campaign",100,36,61-1e-12)
    eq(boundary.seconds,61); eq(boundary.elapsed,61)
    local wire={host.Scores.Fields(boundary)}; eq(wire[4],61); eq(wire[6],0)
    eq(select("#",host.Scores.Fields({mode=r.mode,score=1,level=35,seconds=60})),5)
end)
test("debug history is bounded and contains useful session data",function()
    for i=1,600 do a.Debug.Log("TEST",i) end
    eq(#a.db.debugLog,500); assert(a.db.debugLog[500]:find("600",1,true))
end)

-- UI API smoke test: load exactly the TOC order with simulated WoW frames.
test("addon loads, every screen renders, editor erases, and debug slash works",function()
    local fb,env=client("UITester",true)
    local frames={}
    local methods={}
    local function frame(_,_,parent)
        local f={scripts={},shown=true,width=900,height=610,text="",parent=parent,hideCalls=0}
        setmetatable(f,{__index=function(_,key)
            if key:sub(1,2)=="fb" then return nil end
            return methods[key] or function() end
        end})
        frames[#frames+1]=f; return f
    end
    methods.SetScript=function(f,event,fn) f.scripts[event]=fn end
    methods.GetScript=function(f,event) return f.scripts[event] end
    methods.CreateFontString=function(f) return frame(nil,nil,f) end; methods.CreateTexture=methods.CreateFontString
    methods.SetSize=function(f,w,h) f.width=w; f.height=h end
    methods.SetTexCoord=function(f,...) f.fbCoords=table.concat({...},",") end
    methods.SetDrawLayer=function(f,layer,sub) f.fbLayer,f.fbSub=layer,sub end
    methods.SetFont=function(f,path,size) f.fbFont,f.fbFontSize=path,size end
    methods.SetText=function(f,s) f.text=tostring(s) end
    methods.GetText=function(f) return f.text end
    methods.GetWidth=function(f) return f.width end; methods.GetHeight=function(f) return f.height end
    methods.SetFrameLevel=function(f,level) f.fbZ=level end
    methods.GetFrameLevel=function(f) return f.fbZ or 1 end
    methods.SetShown=function(f,v) if not not v~=not not f.shown then if v then methods.Show(f) else methods.Hide(f) end end end
    methods.Show=function(f) f.shown=true end
    methods.Hide=function(f) f.hideCalls=f.hideCalls+1; f.shown=false; if f.scripts.OnHide then f.scripts.OnHide(f) end end
    methods.IsShown=function(f) return f.shown end; methods.IsMouseOver=function() return false end
    methods.GetEffectiveScale=function() return 1 end
    methods.GetLeft=function() return 0 end; methods.GetTop=function() return 400 end
    methods.GetParent=function(f) return rawget(f,"parent") end; methods.IsForbidden=function() return false end
    methods.CreateMaskTexture=methods.CreateTexture
    local notifications,opened={},nil
    env.Settings={
        VarType={Boolean="boolean",Number="number"},
        RegisterVerticalLayoutCategory=function(title)
            return {GetID=function() return title end},{AddInitializer=function() end}
        end,
        RegisterProxySetting=function(_,key,_,_,default,get,set)
            return {default=default,get=get,set=set,NotifyUpdate=function() notifications[key]=true end}
        end,
        CreateSliderOptions=function() return {SetLabelFormatter=function() end} end,
        CreateCheckbox=function() end,CreateSlider=function() end,RegisterAddOnCategory=function() end,
        OpenToCategory=function(id) opened=id end,
    }
    env.MinimalSliderWithSteppersMixin={Label={Right=1}}
    env.CreateSettingsListSectionHeaderInitializer=function(label) return label end
    env.Minimap=frame()
    env.UIParent=frame(); env.CreateFrame=frame; env.UISpecialFrames={}; env.SlashCmdList={}
    env.GetCursorPosition=function() return 16,384 end
    loadModule("LogoData",fb,env); loadModule("TitleLogo",fb,env)
    loadModule("DemoData",fb,env); loadModule("Demos",fb,env); loadModule("RevealData",fb,env); loadModule("Transitions",fb,env); loadModule("UI",fb,env); loadModule("Lobby",fb,env); loadModule("ArenaUI",fb,env); loadModule("Editor",fb,env); loadModule("EditorUI",fb,env); loadModule("Scoreboard",fb,env); loadModule("Invitations",fb,env); loadModule("Settings",fb,env); loadModule("LocalVersus",fb,env); loadModule("Main",fb,env)
    local eventFrame=frames[#frames]
    eventFrame.scripts.OnEvent(eventFrame,"ADDON_LOADED","FrozenBubble")
    local promptEvents=frames[#frames]
    -- Existing interaction tests enter the playable board immediately.
    assert(fb.Options.controls.boardTransitions.get()); fb.Options.Set("boardTransitions",false)
    test("native settings and minimap launcher share saved preferences",function()
        eq(fb.Options.category:GetID(),"Frozen Bubble Forever")
        local setting=fb.Options.controls.minimap
        assert(setting.get() and fb.Options.icon.shown)
        setting.set(false); assert(not fb.Options.icon.shown and not fb.db.minimap)
        setting.set(true); assert(fb.Options.icon.shown and notifications.FrozenBubbleForever_minimap)
        fb.Options.icon.scripts.OnClick(nil,"RightButton"); eq(opened,"Frozen Bubble Forever")
        fb.Options.icon.scripts.OnClick(nil,"LeftButton"); assert(fb.UI.frame.shown)
        fb.Options.icon.scripts.OnClick(nil,"LeftButton"); assert(not fb.UI.frame.shown)
        fb.Options.controls.musicVolume.set(0.65); eq(fb.db.musicVolume,0.65)
    end)
    test("personal recordings reproduce both shot phases, clock changes, sound and poses at 50 Hz",function()
        local rec=fb.Recordings
        local function compare(actual,replay)
            for _,key in ipairs({"tick","status","angle","turning","shots","lockedShots","current","next","rng","effectRng",
                "score","pending","idle","hurryVisible","ceiling","offset","attack","endIndex"}) do
                if key=="turning" then eq(actual.turning or 0,replay.turning or 0)
                else eq(actual[key],replay[key],key.." at "..actual.tick) end
            end
            eq(actual:Pack(),replay:Pack()); eq(#actual.effects,#replay.effects)
            eq(#actual.rising,#replay.rising); eq(#actual.chains,#replay.chains)
            eq(not not actual.projectile,not not replay.projectile)
            if actual.projectile then
                for _,k in ipairs({"x","y","vx","vy","color"}) do eq(actual.projectile[k],replay.projectile[k]) end
            end
        end
        for _,rules in ipairs({{1,"random"},{1,"endless"},{1,"training"},{1,"versus"},
            {2,"random"},{2,"endless"},{2,"training"},{2,"versus"}}) do
            local mode,desktop=rules[2],rules[1]==2
            local seed=34164
            local soundA,soundB={},{}
            local emit=function(cue) soundA[#soundA+1]=cue end
            local match=mode=="versus" and fb.LocalVersus.New(seed,true,{2,1},emit,desktop)
            local g=match and match.right or fb.Engine.New(nil,seed,mode,true,emit,desktop)
            local left=match and match.left
            g.timed=true
            rec.Begin(seed,g,match); local data=rec.capture.record
            local play=rec.NewPlayback(data,function(cue) soundB[#soundB+1]=cue end)
            for tick=1,1500 do
                local angle=math.sin(tick*0.017)*1.2
                if desktop and (tick==21 or tick==410) then
                    rec.Graphics(g,tick==21)
                    if left then rec.Graphics(left,tick==21) end
                end
                if tick==18 or tick==740 then
                    rec.Clock(g,tick~=18); g.timed=tick~=18; g.idle=0; g.hurryVisible=false
                end
                if tick%300==1 and tick<600 then g:Shoot(angle) end
                if left and tick%140==1 then left:Shoot(-angle) end
                local function input(game,launchTick)
                    game.angle=angle; game.turning=angle<0 and -1 or 1
                    if tick%85==3 and tick<600 then game:Shoot(nil,launchTick) end
                end
                local status=g.status
                if match then fb.LocalVersus.Step(match,input)
                else
                    g:Step(0.02,input)
                    if g.status=="lost" and status~=g.status then emit("lose") end
                end
                assert(rec.Step(play)); compare(g,play.right)
                if left then compare(left,play.left); eq(play.wins[1],match.wins[1]); eq(play.wins[2],match.wins[2]) end
                eq(table.concat(soundA,","),table.concat(soundB,",")); soundA={}; soundB={}
            end
            assert(not rec.Step(play)); assert(g.shots>2)
            rec.CloseRound()
        end
    end)
    test("marked recordings survive leaving a board and playback leaves the live game and scores alone",function()
        local r,ui=fb.Recordings,fb.UI
        fb.StartSolo("random",true)
        local live=fb.game; fb.Fire(); live:Update(0.12)
        env.SlashCmdList.FROZENBUBBLE("record")
        local item=fb.db.recordings[1]; eq(item.frames,6); assert(item.tracks[1].before[1])
        live:Update(0.08); eq(item.frames,10)
        fb.StartCampaign(1); local campaign,checkpoint=fb.game,fb.db.checkpoint
        local count=#fb.db.scores
        env.SlashCmdList.FROZENBUBBLE("replays"); eq(ui.screen,"recordings"); assert(ui.recordButtons[1].shown)
        ui.recordButtons[1].scripts.OnClick(); eq(ui.screen,"replay"); eq(r.playback.right.mode,"random")
        local viewer=r.playback
        eventFrame.scripts.OnUpdate(nil,0.06); eq(viewer.frame,3)
        ui.inactive=true; r.Update(0.12); eq(viewer.frame,3); ui.inactive=false
        eventFrame.scripts.OnUpdate(nil,0.2); eq(ui.screen,"recordings"); eq(r.playback,nil)
        eq(#fb.db.scores,count); eq(fb.game,campaign); eq(fb.game.tick,0); eq(fb.db.checkpoint,checkpoint)
        fb.ContinueCampaign(); assert(not campaign.paused); eq(r.capture,nil)
        fb.Options.controls.autoRecord.set(true)
        fb.LocalVersus.Start(true); live=fb.game; live:Shoot(0.3); fb.LocalVersus.Update(0.06,{})
        fb.StartCampaign(1); eq(fb.db.recordings[1].mode,"versus"); eq(#fb.db.recordings,2)
        env.SlashCmdList.FROZENBUBBLE("replay"); assert(ui.remoteBoard.shown and r.playback.left)
        ui:ShowMenu(); eq(r.playback,nil)
        fb.Options.controls.autoRecord.set(false)
    end)
    test("the Print Screen recording survives logout and replays the whole two-minute training result",function()
        local ui,r=fb.UI,fb.Recordings
        local oldFocus=env.GetMouseFoci
        env.GetMouseFoci=function() return {ui.board} end
        fb.Options.Set("shotClock",false); fb.StartSolo("training",true)
        ui.board.scripts.OnKeyDown(ui.board,"PRINTSCREEN"); ui.board.scripts.OnKeyUp(ui.board,"PRINTSCREEN")
        assert(r.capture.marked)
        fb.Fire()
        local game=fb.game
        game:Update(0.02)
        for i=2,6050 do game:Step(0.02) end
        eventFrame.scripts.OnUpdate(nil,0.02)
        eq(game.status,"finished"); local entry=game.scoreEntry
        assert(entry and fb.Scores.Pending(entry))
        eventFrame.scripts.OnEvent(nil,"PLAYER_LOGOUT"); eq(r.capture,nil)
        env.SlashCmdList.FROZENBUBBLE("replay"); local play=r.playback
        eq(play.record.mode,"training"); assert(ui.trainingClock.shown and fb.Plaques.clock.shown)
        eq(fb.Plaques.clock.fbDigits,"2'00\"")
        while play.frame<play.record.frames do r.Update(0.02) end
        r.Render(); assert(ui.trainingResult.shown and ui.result.shown); eq(ui.trainingScore.text,tostring(game.score)); eq(fb.Plaques.clock.fbDigits,"0'00\"")
        eq(play.right:Pack(),game:Pack()); eq(play.right.status,game.status); eq(play.right.tick,game.tick)
        eq(fb.Scores.Pending(entry),entry); eq(fb.game,game)
        ui.panels.replay.scripts.OnKeyDown(ui.panels.replay,"SPACE"); eq(ui.screen,"recordings")
        fb.Scores.Submit(entry,""); fb.Options.Set("shotClock",true); ui:ShowMenu(); env.GetMouseFoci=oldFocus
    end)
    test("duel playback reproduces accepted packets, penalties, both cannon shots and a corrected result without sending messages",function()
        local peer=client("ReplayGuest")
        local net,r,ui=fb.Net,fb.Recordings,fb.UI
        local oldFocus=env.GetMouseFoci
        env.GetMouseFoci=function() return {ui.board} end
        local seed,id=78113,"78113-55"
        local function start(side,other)
            side.Net.match={phase="start",id=id,peer=other.PlayerName(),seed=seed,seq=0,remoteSeq=0,remoteAttack=0,
                capable=true,limit=3,chainReaction=true,series={wins=1,losses=0,limit=3},round=2}
            side.Net.Begin()
        end
        start(fb,peer); start(peer,fb)
        local m=net.match
        local function sendFromPeer(kind)
            for i=#peer.Net.outbox,1,-1 do
                local item=peer.Net.outbox[i]
                if item.kind==kind then
                    table.remove(peer.Net.outbox,i)
                    net.Receive(fb.PREFIX,item.message,"WHISPER",peer.PlayerName())
                    return item.message
                end
            end
            error("Missing "..kind)
        end
        local function board(g)
            local fields={g:Pack(),g.tick,g.status,g.current,g.next,g.ceiling,g.angle,g.turning or 0,g.shots,g.lockedShots,
                g.score,g.pending,g.attack,g.rng,g.effectRng,#g.effects,#g.chains,#g.rising,g.endIndex or 0,g.chatText or "-",g.chatFrames or 0}
            if g.projectile then
                for _,k in ipairs({"color","x","y","vx","vy"}) do fields[#fields+1]=g.projectile[k] end
            end
            for _,effect in ipairs(g.effects) do fields[#fields+1]=effect.x; fields[#fields+1]=effect.y end
            return table.concat(fields,"|")
        end
        local observed={}
        local function snapshot()
            observed[m.recording.frames]={board(fb.game),board(m.remote)}
        end
        local function update(dt)
            clock=clock+dt; eventFrame.scripts.OnUpdate(nil,dt)
            peer.game:Update(dt)
            for _,item in ipairs(peer.Net.outbox) do
                if item.kind=="RISE" then sendFromPeer("RISE"); break end
            end
            snapshot()
        end
        assert(fb.game:Shoot(-0.31)); assert(fb.Net.outbox[#fb.Net.outbox].kind=="FIRE")
        peer.game:AddGarbage(3)
        assert(peer.game:Shoot(0.63))
        local fire=sendFromPeer("FIRE")
        peer.Net.State(); local state=sendFromPeer("STATE")
        local records=#m.recording.duel.events
        net.Receive(fb.PREFIX,state,"WHISPER",peer.PlayerName()); net.Receive(fb.PREFIX,fire,"WHISPER",peer.PlayerName())
        net.Receive(fb.PREFIX,fire,"WHISPER","Uninvited-TestRealm"); eq(#m.recording.duel.events,records)
        peer.Controls.Aim(peer.game,false,true,false,0.03)
        peer.Net.SendTurn(peer.Net.match,peer.game,clock); local turn=sendFromPeer("TURN")
        eq(m.remote.turning,1); eq(m.recording.duel.events[#m.recording.duel.events][2],"TURN")
        net.Receive(fb.PREFIX,turn,"WHISPER",peer.PlayerName())
        assert(peer.MatchChat.Send("nice | shot")); sendFromPeer("CHAT"); eq(m.remote.chatFrames,250)
        snapshot()
        for _=1,7 do update(0.006); update(0.094) end
        eq(m.remote.riseShot,1); eq(m.remote.pending,0)
        env.SlashCmdList.FROZENBUBBLE("record"); assert(r.capture.marked)
        -- Lose a FIRE in transit. The extended snapshot must restore the remote
        -- board and apply its cumulative attack exactly once in the replay.
        assert(peer.game:Shoot(-0.48)); table.remove(peer.Net.outbox)
        for _=1,5 do update(0.12) end
        peer.game.attack=4; peer.Net.State(); state=sendFromPeer("STATE")
        eq(fb.game.pending,4); net.Receive(fb.PREFIX,state,"WHISPER",peer.PlayerName()); eq(fb.game.pending,4); snapshot()
        local key=fb.Controls.keys[3]
        fb.Controls.PressFire(fb.game,ui.keys,3,key)
        for _=1,14 do update(0.06) end
        assert(fb.game.shots>=2); assert(m.fixedClock)
        local wins,losses=fb.db.wins,fb.db.losses
        net.Finish("lost","You forfeited.",true); snapshot(); update(0.06)
        net.Receive(fb.PREFIX,"1|END|"..id.."|lost","WHISPER",peer.PlayerName())
        eq(m.result,"draw"); snapshot(); update(0.08)
        local rec=m.recording
        net.Leave(); eq(r.capture,nil); eq(fb.db.recordings[1],rec)
        local queue=#net.outbox; local live=fb.game
        local play=r.NewPlayback(rec)
        for f=0,rec.frames do
            if f>0 then assert(r.Step(play)) end
            local seen=observed[f]
            if seen then
                eq(board(play.right),seen[1],"right at "..f)
                eq(board(play.left),seen[2],"peer at "..f)
            end
        end
        eq(play.wins[1],1); eq(play.wins[2],0); eq(play.left.status,"draw")
        eq(fb.db.wins,wins); eq(fb.db.losses,losses); eq(fb.game,live); eq(#net.outbox,queue)
        env.SlashCmdList.FROZENBUBBLE("replay"); eq(ui.screen,"replay"); eq(fb.Plaques.left.fbName,"ReplayGuest"); assert(fb.Plaques.left.shown)
        ui:ShowMenu()
        -- A result for a closed round can still be corrected while a new round runs.
        id="78113-56"; start(fb,peer)
        net.Finish("lost","You forfeited.",true); r.Mark()
        local archived=net.match.recording; net.Leave()
        id="78113-57"; start(fb,peer)
        net.Receive(fb.PREFIX,"1|END|78113-56|lost","WHISPER",peer.PlayerName())
        eq(fb.game.status,"playing"); eq(archived.duel.result,"draw")
        local sounds={}; local corrected=r.NewPlayback(archived,function(cue) sounds[#sounds+1]=cue end)
        while r.Step(corrected) do end
        eq(corrected.right.status,"draw"); eq(table.concat(sounds,","),"lose")
        net.Finish("aborted","Combat started.",false); r.Mark()
        local aborted=net.match.recording; net.Leave()
        sounds={}; local cancelled=r.NewPlayback(aborted,function(cue) sounds[#sounds+1]=cue end)
        while r.Step(cancelled) do end
        eq(cancelled.right.status,"aborted"); eq(cancelled.left.status,"aborted"); eq(table.concat(sounds,","),"cancel")
        ui:ShowMenu(); clients[peer.PlayerName()]=nil; env.GetMouseFoci=oldFocus
    end)
    test("the original training recording reproduces all 997 SDL frames in the local engine",function()
        local file=assert(io.open("tests/demo1.record","rb")); local source=file:read("*a"); file:close()
        local ui,r=fb.UI,fb.Recordings
        r.Library(); r.OpenImport(); ui.levelCode:SetText(source:gsub("\n","\r\n")); ui.codeImport.scripts.OnClick()
        eq(ui.screen,"recordings")
        local record=fb.db.recordings[1]
        eq(record.seed,120364); eq(record.frames,997); eq(record.mode,"training")
        local cues={}
        local play=r.NewPlayback(record,function(sound) cues[#cues+1]=sound end)
        local expected=dofile("tests/reference_training.lua"); local checksum=0
        for tick=1,record.frames do
            assert(r.Step(play))
            local g=play.right; local cells={}
            for i=1,104 do cells[i]=g.grid[i] or 0 end
            local shot=g.projectile; local flight=shot and string.format("%d,%d,%d",shot.color,math.floor(174+shot.x),math.floor(28+shot.y)) or "-"
            local row=table.concat({table.concat(cells),g.current,g.next,flight,table.concat(cues,",")},"|").."\n"
            for i=1,#row do checksum=(checksum*131+row:byte(i))%2147483647 end
            if expected[tick] then eq(checksum,expected[tick],"SDL state through tick "..tick) end
            cues={}
        end
        assert(not r.Step(play))
        -- Network recordings carry remote-player events. Never accept those as local games.
        for _,invalid in ipairs({source:gsub("players:p1","players:p1,rp1"),source:gsub("frame_action:17","frame_action:0"),
            source:gsub("srand:120364","srand:bad"),source:gsub("record_protocol:0","record_protocol:1"),"frame_action:1|p2|fire|1"}) do
            local count=#fb.db.recordings; assert(not r.Import(invalid)); eq(#fb.db.recordings,count)
        end
        local two="record_protocol:0\nplayers:p1,p2\ncurrent_level:\nsrand:7\nchainreaction:0\n"..
            "frame_action:1|p1|fire|1\nframe_action:1|p2|fire|1\nframe_action:12|p2|left|1"
        local split=r.NewPlayback(assert(r.Import(two)))
        for _=1,12 do assert(r.Step(split)) end
        eq(split.right.shots,1); eq(split.left.shots,1); eq(split.left.angle,-0.03)
        ui:ShowMenu()
    end)
    test("desktop board reveals hold local clocks, cover the previous panel, and respect input and motion settings",function()
        local ui,t=fb.UI,fb.Transitions
        local random=env.math.random
        local function pick(...)
            local rolls={...}
            env.math.random=function(n)
                local roll=table.remove(rolls,1)
                assert(roll and roll>=1 and roll<=n)
                return roll
            end
        end
        fb.Options.Set("boardTransitions",true)
        for _,case in ipairs({
            {"horizontal",1,1},{"vertical",2,2},{"bars",7},{"squares",8},
            {"circle-out",6,1},{"circle-in",6,2},{"plasma",3,1,4},{"points",4,2},
            {"solo-dark",5,3,2},{"solo-light",3,3,1}
        }) do
            ui:Panel("solo"); pick(env.unpack(case,2))
            fb.StartCampaign(1)
            eq(t.effect,case[1]); eq(t.step,0); eq(t.target,"game")
            assert(ui.panels.solo:IsShown() and t.frame:IsShown())
            local g=fb.game; fb.Fire(); eq(g.shots,0)
            eventFrame.scripts.OnUpdate(nil,0.10)
            eq(t.step,5); eq(g.tick,0); eq(g.elapsed,0)
            if t.effect=="plasma" then assert(t.flipX and t.flipY) end
            if t.suffix then
                assert(t.patchCount>1 and not t.sprites[1]:IsShown() and #t.boxes>1)
                eq(t.sprites[2].fbReveal,"compressor"..t.suffix)
                local digit=t.sprites[4]
                eq(digit.fbGlyph,fb.HUDArt.labels["1"]); eq(digit.fbReveal,"hud-lettering"..t.suffix)
                local spec=fb.RevealData[digit.fbReveal]
                local sheet=spec.sheets[1]; local left=t.step*spec.w
                eq(digit.fbLocalMask.fbCoords,table.concat({left/sheet[1],(left+digit.fbGlyph.w+1)/sheet[1],
                    digit.fbGlyph.y/sheet[2],(digit.fbGlyph.y+digit.fbGlyph.h+1)/sheet[2]},","))
                for i=1,t.patchCount do assert(#t.patches[i].fbCuts<=2) end
            end
            local steps=fb.RevealData[t.effect].steps
            for i=6,steps do eventFrame.scripts.OnUpdate(nil,0.02) end
            eq(t.target,nil); eq(ui.screen,"game"); eq(g.tick,0)
            assert(not t.frame:IsShown() and not ui.panels.solo:IsShown())
            eventFrame.scripts.OnUpdate(nil,0.02); eq(g.tick,1)
        end
        pick(7); fb.StartCampaign(1)
        t.frame.scripts.OnMouseDown(); eq(ui.screen,"game"); eq(t.target,nil); eq(fb.game.shots,0)
        pick(7); fb.StartCampaign(1); ui.frame:Hide()
        assert(not t.target and fb.game.paused)
        ui.frame:Show(); ui:ShowGame(); assert(not fb.game.paused and not t.target)
        pick(7); fb.StartSolo("training"); eq(t.sprites[3].fbAsset,"opening-training-clock")
        fb.Options.Set("reducedMotion",true)
        assert(not t.target); fb.StartCampaign(1); assert(not t.target)
        fb.Options.Set("reducedMotion",false); fb.Options.Set("graphicsLevel",1)
        fb.StartCampaign(1); assert(not t.target)
        fb.Options.Set("graphicsLevel",3); pick(7); fb.StartCampaign(1)
        eventFrame.scripts.OnEvent(nil,"PLAYER_REGEN_DISABLED")
        assert(not t.target and fb.game.paused)
        eventFrame.scripts.OnEvent(nil,"PLAYER_REGEN_ENABLED")
        pick(7); fb.StartCampaign(1); ui:ShowMenu(); assert(not t.target)
        env.math.random=random; fb.Options.Set("boardTransitions",false)
        ui.frame:Hide()
    end)
    test("all four recording openings use the captured board and can be dismissed from the title",function()
        local ui,t=fb.UI,fb.Transitions
        local random=env.math.random; env.math.random=function() return 8 end
        fb.Options.Set("boardTransitions",true); ui.frame:Show()
        for i,scene in ipairs(fb.DemoData.scenes) do
            ui:ShowMenu(); fb.Demos.Start(i)
            eq(t.demo,i); eq(t.sprites[1].fbAsset,scene.background)
            assert(t.used>30 and not fb.Demos.scene)
            eq(t.Advance(0.7),0); eq(fb.Demos.scene,scene); eq(fb.Demos.frame,1)
        end
        ui:ShowMenu(); fb.Demos.Start(4); t.frame.scripts.OnMouseDown()
        assert(not t.target and not fb.Demos.scene); eq(ui.screen,"menu")
        fb.Options.Set("boardTransitions",false); env.math.random=random; ui.frame:Hide()
    end)
    test("local and network rounds open on the right boards and keep online play running",function()
        local ui,t=fb.UI,fb.Transitions
        fb.Options.Set("boardTransitions",true)
        local random=env.math.random; env.math.random=function() return 7 end
        fb.LocalVersus.Start(false)
        eq(t.sprites[1].fbAsset,"versus-background")
        local m=fb.LocalVersus.match; eventFrame.scripts.OnUpdate(nil,0.1)
        eq(m.right.tick,0); eq(m.left.tick,0)
        t.Finish(); eventFrame.scripts.OnUpdate(nil,0.02); eq(m.right.tick,1); eq(m.left.tick,1)
        fb.LocalVersus.match=nil
        local remote=fb.Engine.New(nil,9,"versus")
        fb.Net.match={phase="playing",remote=remote,seq=0,lastState=env.GetTime(),peer="Peer-TestRealm",lastSeen=env.GetTime(),id="a"}
        fb.StartVersus(9,false); eq(t.target,"opponent")
        eventFrame.scripts.OnUpdate(nil,0.1); eq(fb.game.tick,5)
        t.Finish(); fb.Net.match=nil; ui:ShowMenu()
        fb.Options.Set("boardTransitions",false); env.math.random=random; ui.frame:Hide()
    end)
    test("main menu keyboard, 50 Hz cursors, blinks and scrolling credits follow focus",function()
        local ui=fb.UI
        ui.frame:Show(); ui:ShowMenu()
        local oldFoci=env.GetMouseFoci; env.GetMouseFoci=function() return {ui.menu} end
        ui.menuAccum=0; ui.bannerPos=708
        local key=ui.menu.scripts.OnKeyDown
        ui:SelectMain(1,true)
        ui:AnimateMenu(0.10)
        eq(ui.menuHover[1].texture.fbFrame,6); eq(ui.menuHover[2].texture.fbFrame,1)
        assert(ui.banners[1].texture.shown)
        key(ui.menu,"UP"); eq(ui.menuSelection,8); eq(ui.menuHover[8].label.fbAsset,"menu-highscores-over")
        ui.purpleBlink=-1; ui.menuHover[3].broken=5
        ui:AnimateMenu(0.02)
        assert(ui.blinkEyes[3].shown and ui.menuHover[3].masked)
        eq(ui.menuHover[1].texture.fbFrame,6); eq(ui.menuHover[8].texture.fbFrame,2)
        key(ui.menu,"ENTER"); eq(ui.screen,"scores")
        local tick=ui.menuTick; ui:AnimateMenu(0.20); eq(ui.menuTick,tick)
        env.GetMouseFoci=function() return {} end
        ui.panels.scores.scripts.OnKeyDown(ui.panels.scores,"ESCAPE"); eq(ui.screen,"scores")
        env.GetMouseFoci=function() return {ui.panels.scores} end
        ui.panels.scores.scripts.OnKeyDown(ui.panels.scores,"ENTER"); eq(ui.scoreMode,"training")
        ui.panels.scores.scripts.OnKeyDown(ui.panels.scores,"ESCAPE"); eq(ui.screen,"menu")
        fb.Options.Set("reducedMotion",true); ui:AnimateMenu(0.02)
        assert(not ui.creditStrip.shown and not ui.blinkEyes[3].shown and not ui.menuHover[3].masked)
        fb.Options.Set("reducedMotion",false)
        ui:SelectMain(1,true); ui.frame:Hide(); env.GetMouseFoci=oldFoci
    end)
    test("nine title effects cycle on left Ctrl+N and stop with focus or reduced graphics",function()
        local ui=fb.UI
        local oldFocus,oldControl,oldDate=env.GetMouseFoci,env.IsLeftControlKeyDown,env.date
        local oldEdit,oldCombat=env.GetCurrentKeyBoardFocus,env.InCombatLockdown
        env.date=function() return {month=12,day=25} end
        eq(fb.TitleLogo.Choose(),8)
        env.date=oldDate
        ui.frame:Show(); ui:ShowMenu()
        env.GetMouseFoci=function() return {ui.menu} end
        env.IsLeftControlKeyDown=function() return true end
        fb.Options.Set("graphicsLevel",3)
        local s,key=ui.titleLogo,ui.menu.scripts.OnKeyDown
        s.method=8; ui.inactive=false
        for i=0,8 do
            key(ui.menu,"N"); eq(s.active,i)
            ui:AnimateMenu(0.1)
            if i==0 or i==1 or i==3 or i==4 or i==6 then
                local t=s.tiles[1].t
                local coords=t.fbCoords
                ui:AnimateMenu(0.02); assert(coords~=t.fbCoords); assert(not s.base.shown)
            elseif i==2 then assert(s.glint.shown and s.glint.fbGlintPage>=1)
            elseif i==5 then
                eq(#s.points,200)
                for _,p in ipairs(s.points) do
                    eq(fb.LogoData.white[math.floor(p.y)+1]:byte(math.floor(p.x)+1),49)
                end
            elseif i==7 then
                s.interference=3; ui:AnimateMenu(0.02); assert(s.noise.shown)
                ui:AnimateMenu(0.04); assert(not s.noise.shown and s.stripes[1].shown)
            elseif i==8 then
                for _=1,100 do ui:AnimateMenu(0.20) end
                assert(next(s.snow.rows) and next(s.snow.lines),"snow should settle on the logo")
            end
        end
        local tick=s.tick; ui.inactive=true; ui:AnimateMenu(0.12); eq(s.tick,tick)
        key(ui.menu,"N"); eq(s.method,8); ui.inactive=false
        env.IsLeftControlKeyDown=function() return false end; key(ui.menu,"N"); eq(s.method,8)
        env.IsLeftControlKeyDown=function() return true end
        env.GetCurrentKeyBoardFocus=function() return ui.menu end; key(ui.menu,"N"); eq(s.method,8)
        env.GetCurrentKeyBoardFocus=oldEdit
        env.InCombatLockdown=function() return true end; key(ui.menu,"N"); eq(s.method,8)
        env.InCombatLockdown=oldCombat
        fb.Options.Set("graphicsLevel",2); eq(s.active,-1); assert(s.base.shown)
        for _,t in ipairs(s.pool) do assert(not t.shown) end
        ui:AnimateMenu(0.1); eq(s.tick,tick)
        fb.Options.Set("graphicsLevel",3); fb.Options.Set("reducedMotion",true); eq(s.active,-1)
        fb.Options.Set("reducedMotion",false)
        env.GetMouseFoci,env.IsLeftControlKeyDown=oldFocus,oldControl
        ui.frame:Hide()
    end)
    test("stationary crafting, coordinate changes, combat and taxi transitions govern invitations",function()
        local x,map,taxi,craft=10,1,false,true
        env.UnitPosition=function() return x,5,2,map end
        env.UnitOnTaxi=function() return taxi end
        env.UnitCastingInfo=function() if craft then return "Craft",nil,nil,nil,nil,true end end
        local invites=fb.Invitations
        local function poll(dt) clock=clock+dt; invites.Update() end
        promptEvents.scripts.OnEvent(nil,"PLAYER_ENTERING_WORLD")
        fb.Options.controls.idleSeconds.set(60); poll(1)
        poll(55); eq(invites.reason,nil)
        x=x+10; poll(1); poll(59); eq(invites.reason,nil)
        map=2; poll(1); poll(60); eq(invites.reason,"idle")
        local function click(caption)
            for _,f in ipairs(frames) do
                if f.parent==invites.popup and f.text==caption then f.scripts.OnClick(); return end
            end
            error("missing popup action "..caption)
        end
        click("Later"); poll(120); eq(invites.reason,nil)
        fb.Options.controls.craftingPrompt.set(false); poll(120); eq(invites.reason,nil)
        craft=false; poll(60); eq(invites.reason,"idle")
        env.InCombatLockdown=function() return true end
        promptEvents.scripts.OnEvent(nil,"PLAYER_REGEN_DISABLED"); eq(invites.reason,nil)
        env.InCombatLockdown=function() return false end
        taxi=true; poll(1); eq(invites.reason,"flight"); click("Later"); poll(60); eq(invites.reason,nil)
        taxi=false; poll(1); taxi=true; poll(1); eq(invites.reason,"flight")
        taxi=false; poll(1); eq(invites.reason,nil)
        fb.Options.controls.flightPrompt.set(false); taxi=true; poll(1); eq(invites.reason,nil)
        fb.Options.controls.flightPrompt.set(true); poll(1); eq(invites.reason,"flight")
        click("Play"); assert(fb.UI.frame.shown); eq(invites.reason,nil)
        fb.UI.frame:Hide(); taxi=false; poll(1)
        env.UnitPosition=function() return nil end
        env.C_Map={GetBestMapForUnit=function() return map end,GetPlayerMapPosition=function()
            return {GetXY=function() return x/100,0.5 end}
        end}
        poll(1); eq(invites.anchor.kind,"map")
        env.GetUnitSpeed=function() return 5 end
        poll(120); eq(invites.reason,nil)
        promptEvents.scripts.OnEvent(nil,"PLAYER_LEAVING_WORLD")
    end)
    env.SlashCmdList.FROZENBUBBLE(""); fb.StartCampaign(1)
    for _,name in ipairs({"help","lobby","scores","market","editor","opponent"}) do fb.UI:Panel(name); fb.UI:Update(1) end
    test("Keys captures ten distinct bindings, cancels atomically and restores a saved profile",function()
        local ui,k=fb.UI,fb.Controls
        local mouse,focus=env.GetMouseFoci,env.GetCurrentKeyBoardFocus
        local panel=ui.panels.keys
        env.GetMouseFoci=function() return {panel} end
        ui:ShowMenu(); ui:SelectMain(7,true); ui.menu.scripts.OnKeyDown(ui.menu,"ENTER")
        eq(ui.screen,"keys")
        local function press(key)
            panel.scripts.OnKeyDown(panel,key); panel.scripts.OnKeyUp(panel,key)
        end
        press("ENTER"); press("J"); press("ESCAPE")
        eq(ui.screen,"menu"); eq(k.keys[1],"LEFT")
        ui.menuHover[7].activate()
        env.GetCurrentKeyBoardFocus=function() return env.UIParent end
        press("Z"); env.GetCurrentKeyBoardFocus=focus
        panel.scripts.OnKeyDown(panel,"J"); panel.scripts.OnKeyDown(panel,"J")
        panel.scripts.OnKeyUp(panel,"J"); press("J")
        local wanted={"J","L","K","I","S","G","T","R","F1","H"}
        for n=2,10 do press(wanted[n]) end
        k.Load(fb.db.bindings); for n,key in ipairs(wanted) do eq(k.keys[n],key) end
        clock=clock+2; panel.scripts.OnUpdate(); eq(ui.screen,"menu")
        local down,up=ui.board.scripts.OnKeyDown,ui.board.scripts.OnKeyUp
        fb.StartCampaign(1); env.GetMouseFoci=function() return {ui.board} end
        down(ui.board,"J"); eventFrame.scripts.OnUpdate(nil,0.04); eq(fb.game.angle,-0.06); up(ui.board,"J")
        down(ui.board,"I"); eventFrame.scripts.OnUpdate(nil,0.04); eq(fb.game.angle,0); up(ui.board,"I")
        down(ui.board,"UP"); down(ui.board,"SPACE"); eq(fb.game.shots,0)
        down(ui.board,"K"); eventFrame.scripts.OnUpdate(nil,0.02); eq(fb.game.shots,1)
        ui:ShowMenu(); ui.menuHover[2].activate()
        assert(ui.chainControls.text:find("J / L",1,true)); ui.chainNo.scripts.OnClick()
        down(ui.board,"L"); down(ui.board,"S"); fb.LocalVersus.Update(0.02,ui.keys)
        eq(fb.game.angle,0.03); eq(fb.LocalVersus.match.left.angle,-0.03)
        down(ui.board,"T"); down(ui.board,"K"); fb.LocalVersus.Update(0.02,ui.keys); eq(fb.LocalVersus.match.left.shots,1); eq(fb.game.shots,1)
        local savedSize=fb.db.windowSize; fb.db.windowSize=0.65
        local anchor,scale={"TOPLEFT",env.UIParent,"TOPLEFT",11,-13},nil
        ui.frame.GetPoint=function() return env.unpack(anchor) end
        ui.frame.SetPoint=function(_,...) anchor={...} end
        ui.frame.SetScale=function(_,value) scale=value end
        down(ui.board,"F1"); assert(ui.fullWindow); eq(anchor[1],"CENTER")
        eq(scale,math.min(900/1024,610/768)); up(ui.board,"F1")
        down(ui.board,"F1"); assert(not ui.fullWindow); eq(anchor[1],"TOPLEFT"); eq(anchor[4],11); eq(anchor[5],-13)
        eq(scale,math.min(870/1024,580/768)*0.65)
        ui.frame.GetPoint,ui.frame.SetPoint,ui.frame.SetScale=nil,nil,nil; fb.db.windowSize=savedSize
        fb.StartCampaign(1); k.Load({"J","J"}); eq(k.keys[1],"LEFT"); eq(k.keys[8],"D")
        env.GetMouseFoci=mouse
    end)
    test("online chat opens from the board, cancels on Escape and closes with the match",function()
        local ui,chat=fb.UI,fb.MatchChat
        local oldMouse=env.GetMouseFoci
        fb.StartVersus(37); fb.Net.match={id="37-1",phase="playing",peer="Chat-TestRealm"}
        env.GetMouseFoci=function() return {ui.board} end
        local function open()
            ui.board.scripts.OnKeyDown(ui.board,"ENTER"); ui.board.scripts.OnKeyUp(ui.board,"ENTER"); assert(chat.input.shown)
        end
        open(); ui:Update(0)
        assert(not ui.penguin.shown and not ui.board.next.shown and not ui.board.nextRim.shown and ui.board.current.shown)
        local angle=fb.game.angle
        ui.board.scripts.OnMouseDown(ui.board,"LeftButton"); ui.board.scripts.OnMouseWheel(ui.board,1)
        eq(fb.game.shots,0); eq(fb.game.angle,angle)
        local measureWidth=methods.GetStringWidth
        methods.GetStringWidth=function(region) return #region:GetText()*10 end
        chat.input.GetCursorPosition=function(box) return #box:GetText() end
        chat.input:SetText("don't send"); chat.input.scripts.OnTextChanged(chat.input,true)
        chat.input:SetText(string.rep("W",19)); chat.input.scripts.OnTextChanged(chat.input,true)
        eq(chat.input:GetText(),"don't send")
        methods.GetStringWidth=measureWidth; chat.input.GetCursorPosition=nil
        chat.input.scripts.OnEscapePressed(); assert(not chat.input.shown)
        ui:Update(0); assert(ui.penguin.shown and ui.board.next.shown and ui.board.nextRim.shown)
        open(); chat.input:SetText("nice shot"); chat.input.scripts.OnEnterPressed()
        eq(fb.Net.outbox[#fb.Net.outbox].message,"1|CHAT|37-1|nice shot")
        open(); fb.Net.match=nil; chat.Refresh(); assert(not chat.input.shown)
        env.GetMouseFoci=oldMouse; fb.StartCampaign(1)
    end)
    test("original graphics controls select both cannon styles and preserve a shared round",function()
        local ui=fb.UI
        ui.frame:Show(); ui:ShowMenu(); eq(fb.db.graphicsLevel,3)
        local gfx=ui.menuHover[6]
        gfx.activate(); eq(fb.db.graphicsLevel,1); eq(ui.screen,"menu"); eq(gfx.texture.fbAsset,"hover-gfx-l3")
        assert(not ui.creditStrip.shown and not fb.db.reducedMotion)
        ui.menuHover[2].activate(); eq(ui.screen,"opponent")
        local m=fb.LocalVersus.match
        m.right.angle=math.pi/4
        local dotAnchor
        ui.board.shooter.SetPoint=function(_,...) dotAnchor={...} end
        ui:Update(0); eq(ui.board.shooter.fbAsset,"aim-dot"); eq(ui.board.shooter.width,2)
        eq(dotAnchor[4],169); eq(dotAnchor[5],-322)
        eq(ui.remoteBoard.shooter.fbAsset,"aim-dot"); assert(not ui.penguin.shown and not ui.remotePenguin.shown)
        fb.Options.controls.graphicsLevel.set(2)
        ui:Update(0); eq(ui.board.shooter.fbAsset,"cannon-angles"); eq(ui.board.shooter.fbFrame,51)
        eq(ui.remoteBoard.shooter.fbFrame,101); assert(not ui.penguin.shown and not ui.remotePenguin.shown)
        ui:ShowMenu(); eq(gfx.texture.fbAsset,"hover-gfx-l2"); ui:SelectMain(6,true); ui:AnimateMenu(0.08)
        assert(ui.creditStrip.shown and gfx.texture.fbFrame>1)
        gfx.activate(); eq(fb.db.graphicsLevel,3); eq(gfx.texture.fbAsset,"hover-gfx-l1")
        ui:ShowGame(); m.left.angle=-math.pi/4; ui:Update(0)
        eq(ui.remoteBoard.shooter.fbFrame,151); assert(ui.penguin.shown and ui.remotePenguin.shown)
        eq(fb.LocalVersus.match,m); eq(m.right.angle,math.pi/4)
        ui.board.shooter.SetPoint=nil
        fb.StartCampaign(1)
    end)
    test("full and miniature airborne bubbles draw on the desktop pixel grid",function()
        local ui=fb.UI
        local g=fb.Engine.New({"111....."},31); g:Shoot(0.47); g:Step(0.02)
        for i,board in ipairs({ui.board,ui.miniBoards[1]}) do
            local pixel=i; local seat=board.fbMiniSeat
            if i==2 then board.fbMiniSeat=1 end
            local x,y
            board.projectile.SetPoint=function(_,_,_,_,px,py) x,y=px,py end
            ui:RenderBoard(board,g)
            eq(x,math.floor(g.projectile.x/pixel)*pixel); eq(y,-math.floor(g.projectile.y/pixel)*pixel)
            board.projectile.SetPoint=nil; board.fbMiniSeat=seat
        end
    end)
    test("low graphics hides pop and stick effects but keeps falling chains and the ceiling warning",function()
        local ui=fb.UI
        local game=fb.Engine.New({"11......","22....."},3,"training",true)
        fb.game=game; game.shots=10; game.lockedShots=10; game.tick=20
        game.stick={ticks=0,key=1}
        game.effects={game:Effect(1,"pop"),game:Effect(2,"fall")}
        game.chains={{x=20,y=60,color=4}}
        fb.Options.Set("graphicsLevel",1)
        ui:RenderBoard(ui.board,game)
        assert(ui.board.fx[1].shown and not ui.board.fx[2].shown and ui.board.fx[3].shown)
        assert(not ui.board.stick.shown and ui.board.boardOverlays[1].shown)
        assert(not ui.board.boardOverlays[2] or not ui.board.boardOverlays[2].shown)
        game.chainReaction=false; ui:RenderBoard(ui.board,game); assert(not ui.board.fx[3].shown)
        fb.Options.Set("graphicsLevel",2); ui:RenderBoard(ui.board,game)
        assert(ui.board.stick.shown and ui.board.fx[2].shown and ui.board.boardOverlays[2].shown)
        fb.Options.Set("graphicsLevel",3); fb.StartCampaign(1)
    end)
    test("the shot clock aims, fires and moves the bubble on the same desktop tick at every render rate",function()
        local ui=fb.UI
        local oldFocus=env.GetMouseFoci; env.GetMouseFoci=function() return {ui.board} end
        for _,frames in ipairs({1,4,12,48}) do
            fb.StartCampaign(1)
            local game=fb.game
            game.idle=(525-6)/50
            ui.board.scripts.OnKeyDown(ui.board,"RIGHT")
            for _=1,frames do eventFrame.scripts.OnUpdate(nil,0.24/frames) end
            eq(game.tick,12); eq(game.shots,1)
            local shot=game.projectile
            assert(math.abs(shot.x-(128+70*math.sin(0.18)))<1e-8)
            assert(math.abs(shot.y-(game.launchY-70*math.cos(0.18)))<1e-8)
            eq(ui.penguin.fbShots,1); eq(ui.penguin.fbState,"right_to")
            ui.board.scripts.OnKeyUp(ui.board,"RIGHT")
        end
        -- A quick tap survives key release before the next tick. The next key
        -- press, held while the projectile is in flight, fires once on recovery.
        fb.StartCampaign(1)
        local game=fb.game
        ui.board.scripts.OnKeyDown(ui.board,"LEFT")
        ui.board.scripts.OnKeyDown(ui.board,"SPACE"); ui.board.scripts.OnKeyUp(ui.board,"SPACE")
        eventFrame.scripts.OnUpdate(nil,0.02); eq(game.shots,1); eq(game.angle,-0.03)
        assert(math.abs(game.projectile.x-(128-10*math.sin(0.03)))<1e-8)
        ui.board.scripts.OnKeyUp(ui.board,"LEFT"); ui.board.scripts.OnKeyDown(ui.board,"SPACE")
        for _=1,80 do eventFrame.scripts.OnUpdate(nil,0.02) end
        eq(game.shots,2)
        ui.board.scripts.OnKeyUp(ui.board,"SPACE")
        game:Shoot(0); ui.board.scripts.OnKeyDown(ui.board,"UP"); ui.board.scripts.OnKeyUp(ui.board,"UP")
        for _=1,80 do eventFrame.scripts.OnUpdate(nil,0.02) end
        eq(game.shots,3); env.GetMouseFoci=oldFocus
    end)
    test("local shot-clock preference applies to both launchers while training and online clocks keep their rules",function()
        local option=fb.Options.controls.shotClock; assert(option.get())
        fb.StartCampaign(1); fb.game.idle=8.2; fb.game.hurryVisible=true
        option.set(false); eq(fb.game.idle,0); eq(fb.game.hurryVisible,false)
        local function wait(game)
            for _=1,550 do game:Step(0.02) end
            eq(game.shots,0); eq(game.hurryVisible,false)
        end
        wait(fb.game); fb.StartCustomBoard({boards={fb.UI:DefaultEditorBoards()[1]},title="Custom"},1); wait(fb.game)
        fb.LocalVersus.Start(false); wait(fb.game); wait(fb.LocalVersus.match.left)
        option.set(true); eq(fb.game.idle,0); eq(fb.LocalVersus.match.left.timed,true)
        option.set(false); fb.StartSolo("training"); fb.game.tick=6049
        fb.game:Update(0.02); eq(fb.game.status,"finished")
        fb.StartVersus(178,false); option.set(true); option.set(false)
        fb.game.idle=7.48; fb.game:Step(0.02); eq(fb.game.shots,1)
        option.set(true); fb.StartCampaign(1)
    end)
    test("mouse aim keeps the penguin turning and a held direction works at the angle limit",function()
        local ui=fb.UI
        fb.StartCampaign(1)
        local cursor=ui.Cursor
        ui.board.IsMouseOver=function() return true end
        ui.Cursor=function() return 258,260 end
        ui.lastX,ui.lastY=nil,nil
        for i=1,48 do eventFrame.scripts.OnUpdate(nil,1/120) end
        assert(fb.game.angle>0.8); eq(ui.penguin.fbState,"right")
        eq(fb.game.shots,0)
        for i=1,130 do eventFrame.scripts.OnUpdate(nil,1/120) end
        eq(ui.penguin.fbState,"normal"); eq(fb.game.poseAngle,fb.game.angle)
        ui.board.IsMouseOver=nil; ui.Cursor=cursor
        fb.game.angle=fb.Engine.MAX_ANGLE; ui.keys.RIGHT=true
        for i=1,30 do eventFrame.scripts.OnUpdate(nil,0.02) end
        eq(fb.game.angle,fb.Engine.MAX_ANGLE); eq(ui.penguin.fbState,"right")
        ui.keys.RIGHT=nil; fb.StartCampaign(1)
    end)
    test("sticky frames hold twice and debris passes in front of the cannon at original sprite sizes",function()
        local ui,board=fb.UI,fb.UI.board
        local game=fb.Engine.New({"1......."},5,"versus")
        game.stick={key=1,ticks=0}
        for tick=1,14 do
            game:Update(0.02); ui:RenderBoard(board,game)
            eq(board.stick.fbFrame,math.ceil(tick/2)); assert(board.stick.shown)
        end
        game:Update(0.02); ui:RenderBoard(board,game); assert(not board.stick.shown)
        game.current=4; game:Shoot(0); game.status="lost"; game:Update(0.02)
        ui:RenderBoard(board,game)
        local sprite=board.fx[1]
        eq(sprite.fbLayer,"OVERLAY"); eq(sprite.fbSub,4)
        eq(sprite.fbAsset,"frozen"); eq(sprite.width,34); eq(sprite.height,48)
        -- A pooled sprite must return to the ordinary colored ball dimensions.
        local fresh=fb.Engine.New({"1......."},9)
        fresh.effects[1]=fresh:Effect(1,"fall"); ui:RenderBoard(board,fresh)
        eq(sprite.fbSub,3); eq(sprite.fbAsset,"bubble1"); eq(sprite.width,32); eq(sprite.height,32)
    end)
    test("two-player menu, simultaneous controls, chat focus and shared pause",function()
        local ui=fb.UI
        local oldMouse,oldKeyboard=env.GetMouseFoci,env.GetCurrentKeyBoardFocus
        env.GetMouseFoci=function() return {ui.remoteBoard} end
        ui:ShowMenu(); ui.menuHover[2].activate(); eq(ui.screen,"chain")
        ui:BackFromChain(); eq(ui.screen,"menu")
        ui.menuHover[2].activate(); ui.chainYes.scripts.OnClick()
        local m=fb.LocalVersus.match
        eq(m.right:Pack(),m.left:Pack()); eq(m.right.current,m.left.current); eq(m.right.next,m.left.next)
        assert(m.right.chainReaction and m.left.chainReaction and not fb.Net.match)
        eq(ui.screen,"opponent"); ui:UpdateVisibility(0.02)
        local down,up=ui.board.scripts.OnKeyDown,ui.board.scripts.OnKeyUp
        down(ui.board,"RIGHT"); down(ui.board,"X")
        eventFrame.scripts.OnUpdate(nil,0.04)
        eq(m.right.angle,0.06); eq(m.left.angle,-0.06)
        up(ui.board,"RIGHT"); up(ui.board,"X")
        down(ui.board,"DOWN"); down(ui.board,"D"); eventFrame.scripts.OnUpdate(nil,0.04)
        eq(m.right.angle,0); eq(m.left.angle,0)
        up(ui.board,"DOWN"); up(ui.board,"D")
        env.GetCurrentKeyBoardFocus=function() return env.UIParent end
        down(ui.board,"C"); down(ui.board,"UP"); eq(m.left.shots,0); eq(m.right.shots,0)
        env.GetCurrentKeyBoardFocus=oldKeyboard
        down(ui.board,"C"); down(ui.board,"UP"); eventFrame.scripts.OnUpdate(nil,0.02); eq(m.left.shots,1); eq(m.right.shots,1)
        down(ui.board,"P"); eventFrame.scripts.OnUpdate(nil,0.2)
        eq(m.right.tick,5); eq(m.left.tick,5); assert(m.left.paused)
        up(ui.board,"P"); down(ui.board,"P")
        eventFrame.scripts.OnUpdate(nil,0.02); eq(m.right.tick,6); eq(m.left.tick,6)
        ui:ShowMenu(); eventFrame.scripts.OnUpdate(nil,0.2); eq(m.left.tick,6)
        ui:ShowGame(); eventFrame.scripts.OnUpdate(nil,0.02); eq(m.left.tick,7)
        eventFrame.scripts.OnEvent(nil,"PLAYER_REGEN_DISABLED")
        eventFrame.scripts.OnUpdate(nil,0.02); eq(m.left.tick,7); assert(m.right.paused)
        eventFrame.scripts.OnEvent(nil,"PLAYER_REGEN_ENABLED"); ui:ShowGame()
        ui.focusGrace=0; env.GetMouseFoci=function() return {} end
        ui:UpdateVisibility(0.02); clock=clock+1
        eventFrame.scripts.OnUpdate(nil,0.10); eq(m.left.tick,7); assert(m.right.paused)
        env.GetMouseFoci=function() return {ui.remoteBoard} end
        eventFrame.scripts.OnUpdate(nil,0.02); eq(m.left.tick,8); eq(m.right.tick,8)
        env.GetMouseFoci=oldMouse
    end)
    test("local clears send penalties once and round wins stay on this keyboard",function()
        local ui=fb.UI
        local m=fb.LocalVersus.match
        local wins,losses=fb.db.wins,fb.db.losses
        local right=m.right
        right.grid={[1]=1,[2]=1,[3]=1,[4]=2}; right.attachedOrder={1,2,3,4}
        right.projectile={x=16,y=48,vx=0,vy=-500,color=1}
        -- A fourth matching bubble attaches underneath the top row.
        fb.LocalVersus.Update(0.04,{}); eq(right.attack,1); eq(m.left.pending,1)
        fb.LocalVersus.Update(0.06,{}); eq(m.left.pending,1)
        right.status="lost"; fb.LocalVersus.Update(0.02,{})
        eq(m.left.status,"won"); eq(m.wins[2],1)
        for i=1,40 do fb.LocalVersus.Update(0.20,{}) end
        ui:Update(0); assert(ui.result.shown and not ui.resultBadge.shown)
        eq(ui.resultArt.fbAsset,"local-win-p2"); eq(fb.Plaques.left.fbDigits,"1"); eq(ui.retryButton.text,"Next round")
        ui.retryButton.scripts.OnClick(); m=fb.LocalVersus.match
        assert(m.right.chainReaction and m.left.chainReaction); eq(m.right.shots,0); eq(m.wins[2],1)
        m.left.status="lost"; fb.LocalVersus.Update(0.02,{}); eq(m.right.status,"won"); eq(m.wins[1],1)
        for i=1,40 do fb.LocalVersus.Update(0.20,{}) end
        ui:Update(0); eq(ui.resultArt.fbAsset,"local-win-p1"); assert(ui.resultArt.shown)
        fb.LocalVersus.Rematch(); m=fb.LocalVersus.match
        m.right.status="lost"; m.left.status="lost"; fb.LocalVersus.Update(0.04,{})
        eq(m.right.status,"draw"); eq(m.left.status,"draw"); eq(m.wins[1],1); eq(m.wins[2],1)
        eq(fb.db.wins,wins); eq(fb.db.losses,losses); eq(fb.Net.match,nil)
        fb.StartCampaign(1); eq(fb.LocalVersus.match,nil)
    end)
    test("local results match the freeze and winner-sign frames captured in SDL",function()
        -- Seed 12345. In the desktop game keep the first attached bubble on
        -- one board, then call lose(p2) after the first displayed frame.
        for _,small in ipairs({"winner","loser"}) do
            local m=fb.LocalVersus.New(12345,false,nil,nil,true)
            fb.LocalVersus.Step(m)
            local board=small=="winner" and m.right or m.left
            board.grid={[1]=board.grid[1]}
            m.right.status,m.left.status,m.finished="won","lost",true
            local sign,freeze
            for tick=1,150 do
                fb.LocalVersus.Step(m)
                if not freeze and m.left.endIndex==#m.left.endOrder then freeze=tick end
                if not sign and fb.UI:ResultReady(m.right,m.left,m.right,true) then sign=tick end
            end
            eq(sign,small=="winner" and 50 or 126); eq(freeze,small=="winner" and 76 or 2)
        end
    end)
    test("shared-keyboard results time the winner sign and the next round independently",function()
        local ui,localGame=fb.UI,fb.LocalVersus
        local focus=env.GetMouseFoci
        env.GetMouseFoci=function() return {ui.board} end
        local down,up=ui.board.scripts.OnKeyDown,ui.board.scripts.OnKeyUp
        local function lose(left,largeLoser)
            localGame.Start(true)
            local m=localGame.match
            local winner,loser=m.right,m.left
            if not left then winner,loser=loser,winner end
            if largeLoser then winner.grid={[1]=1} else loser.grid={[1]=1} end
            localGame.Update(0.02,{})
            loser.status="lost"
            localGame.Update(0.02,{}); ui:Update(0)
            return m,winner,loser
        end
        local m,winner=lose(false,false)
        down(ui.board,"X"); eq(localGame.match,m)
        for i=1,4 do localGame.Update(0.02,{}); ui:Update(0) end
        assert(ui.retryButton.shown and ui.result.shown and not ui.resultArt.shown)
        assert(#winner.effects>0)
        down(ui.board,"X"); eq(localGame.match,m) -- a held key cannot accept twice
        up(ui.board,"X"); down(ui.board,"X")
        assert(m~=localGame.match); eq(localGame.match.frameParity,m.frameParity)
        local rec=fb.Recordings.capture.record
        eq(rec.openingParity,m.frameParity); eq(fb.Recordings.NewPlayback(rec).frameParity,m.frameParity)
        eq(localGame.match.wins[2],1); assert(localGame.match.right.chainReaction)
        down(ui.board,"X"); localGame.Update(0.08,ui.keys); eq(localGame.match.left.angle,0)
        up(ui.board,"X"); down(ui.board,"X"); localGame.Update(0.02,ui.keys)
        assert(localGame.match.left.angle<0); up(ui.board,"X")

        m,winner=lose(true,true)
        -- A packet of falling bubbles may still be on screen after the last burst.
        winner.effects={{kind="fall",x=16,y=16,vx=0,vy=0,wait=200,color=3}}
        for i=1,60 do
            localGame.Update(0.02,{}); ui:Update(0)
            if ui.resultArt.shown and ui.result.shown then break end
        end
        assert(ui.result.shown and ui.resultArt.shown and not ui.retryButton.shown)
        eq(ui.resultArt.fbAsset,"local-win-p1"); assert(#winner.effects>0)
        down(ui.board,"SPACE"); up(ui.board,"SPACE"); eq(localGame.match,m)
        env.GetMouseFoci=function() return {} end
        down(ui.board,"ESCAPE"); eq(localGame.match,m)
        env.GetMouseFoci=function() return {ui.board} end
        fb.Options.Set("boardTransitions",true)
        down(ui.board,"ESCAPE"); assert(localGame.match~=m)
        eq(localGame.match.wins[1],1); eq(fb.Transitions.target,"opponent")
        local cover=fb.Transitions.frame
        cover.scripts.OnKeyDown(cover,"ESCAPE"); eq(fb.Transitions.target,"opponent")
        fb.Transitions.Finish(); eq(ui.keys.resultKey,"ESCAPE")
        up(ui.board,"ESCAPE"); eq(ui.keys.resultKey,nil)
        fb.Options.Set("boardTransitions",false)
        fb.StartCampaign(1); env.GetMouseFoci=focus
    end)
    test("the solo freeze paints icicles from the bottom up and keeps debris above the sign",function()
        local ui=fb.UI
        fb.StartCampaign(1)
        local g=fb.game
        g.grid={[1]=2,[2]=3,[9]=1}; g.status="lost"
        for i=1,8 do g:Step(0.02) end
        g.effects={g:Effect(1,"fall")}
        ui:Update(0)
        assert(ui.resultArt.shown and ui.result.shown); eq(ui.resultArt.fbAsset,"lose-panel")
        assert(ui.board.fxLayer:GetFrameLevel()>ui.result:GetFrameLevel())
        assert(ui.board.fxLayer:GetFrameLevel()<ui.retryButton:GetFrameLevel())
        local overlays=ui.board.boardOverlays
        local positions={}
        for i=1,3 do
            overlays[i].SetPoint=function(_,_,_,_,x,y) positions[i]={x,y} end
        end
        ui:RenderBoard(ui.board,g)
        for i,key in ipairs({9,2,1}) do
            local r,c=fb.Engine.Cell(key); local x,y=fb.Engine.Position(r,c)
            eq(positions[i][1],x); eq(positions[i][2],-(y+7))
            overlays[i].SetPoint=nil
        end
        fb.StartCampaign(1); ui:Update(0)
        assert(ui.board.fxLayer:GetFrameLevel()<ui.result:GetFrameLevel())
    end)
    test("the original plaques follow the board, clock and saved game mode",function()
        local ui,p=fb.UI,fb.Plaques
        fb.StartCampaign(1); ui:Update(0)
        eq(p.solo.fbPrefix,"Level "); eq(p.solo.fbDigits,"1")
        assert(p.solo.shown and not ui.hud.shown and not p.left.shown)
        assert(ui.footer:GetText():find("0 points",1,true))
        local coords={}
        p.Layout(74,"Level ",17,function(_,x) coords[#coords+1]=x end)
        eq(table.concat(coords,","),"35,89,101")

        fb.StartSolo("training"); fb.game.score=12345; fb.game.tick=3050; ui:Update(0)
        eq(p.solo.fbPrefix,"Score: "); eq(p.solo.fbDigits,"12345")
        eq(p.clock.fbDigits,"0'59\""); assert(p.clock.shown)
        fb.StartSolo("random"); ui:Update(0); eq(p.solo.fbPrefix,"Random level"); assert(not p.clock.shown)
        fb.LocalVersus.Start(false)
        local m=fb.LocalVersus.match; m.wins={2,12}; ui:Update(0)
        eq(p.right.fbDigits,"2"); eq(p.left.fbDigits,"12")
        assert(p.right.shown and p.left.shown and not p.solo.shown and not ui.remoteLabel.shown)
        fb.StartCustom(ui:DefaultEditorBoards()[1]); ui:Update(0)
        assert(ui.hud.shown and not p.left.shown and not p.solo.shown)
        fb.StartCustomBoard({builtin=true,title="Campaign practice",boards=fb.Levels},17); ui:Update(0)
        eq(p.solo.fbDigits,"17"); assert(p.solo.shown)
        ui:Panel("editor"); assert(not p.solo.shown and not p.clock.shown)
        fb.StartCampaign(1)
    end)
    test("multiplayer score plaques keep kerning, Unicode names and round counts across board sizes",function()
        local p=fb.Plaques
        local own,peer=p.DuelNames("Mira-Dawn","Mira-Dusk")
        eq(own,"Mira-Dawn"); eq(peer,"Mira-Dusk")
        own,peer=p.DuelNames("Élodie-Dawn","Олег-Dusk")
        eq(own,"Élodie"); eq(peer,"Олег")
        for _,size in ipairs({8,14}) do
            local glyphs=fb.NameArt[size].glyphs
            local visible={}
            assert(p.NameLayout(80,"Teffi",27,size,132,function(g,x) visible[#visible+1]={g,x} end))
            eq(visible[3][1],glyphs.ffi)
            assert(p.NameLayout(80,string.rep("É",32).."Р",27,size,132,function(g,x)
                assert(x>=14 and x+g.w<=146)
            end))
            local ink={}
            p.NameLayout(80,string.rep("É",32),27,size,132,function(g) ink[#ink+1]=g end)
            eq(ink[#ink-3],glyphs["…"]); eq(ink[#ink-1],glyphs["2"]); eq(ink[#ink],glyphs["7"])
        end
        local function unexpected() error("Partial caption drawn before font fallback") end
        assert(not p.NameLayout(80,"雨",3,8,132,unexpected))
        local f=p.Caption(fb.UI.gameLayer,80,11,1)
        local from=#frames
        f:SetNameScore("雨",3,8,132)
        local localized=frames[#frames]; assert(#frames>from)
        eq(localized.text,"雨: 3"); assert(localized.shown)
        f:SetNameScore("Олег",12,8,132); assert(not localized.shown)
    end)
    test("solo menu launches timed training, records it once, and retries",function()
        fb.UI:Panel("solo"); eq(fb.UI.soloIndex,1)
        fb.UI:SelectSolo(4); fb.UI:Update(0.10)
        eq(fb.UI.soloEntries[4].glow.fbFrame,6)
        fb.UI.soloEntries[4].activate(); eq(fb.UI.screen,"chain"); fb.UI.chainNo.scripts.OnClick()
        eq(fb.game.mode,"training"); fb.UI:Update(0.02)
        eq(fb.Plaques.clock.fbDigits,"2'00\""); assert(fb.UI.trainingClock.shown)
        fb.game.tick=6049; fb.game.score=14
        for _=1,3 do eventFrame.scripts.OnUpdate(eventFrame,0.02) end
        eq(fb.game.status,"finished"); eq(#fb.Scores.Rows(false,"training"),0)
        assert(fb.UI.trainingResult.shown); fb.UI.resultScores.scripts.OnClick()
        eq(fb.UI.screen,"scoreEntry"); fb.UI.scoreName:SetText("Fast fins"); fb.UI.scoreName.scripts.OnEnterPressed()
        fb.UI.panels.scoreEntry.scripts.OnUpdate(nil,2)
        eq(fb.Scores.Best("training").score,14); eq(fb.UI.scoreColumns[1].lines[1].name.text,"Fast fins: 14")
        fb.UI:ShowGame()
        fb.UI.retryButton.scripts.OnClick(); eq(fb.game.tick,0); eq(fb.game.status,"playing")
        fb.UI:Panel("solo"); fb.UI.soloEntries[3].activate(); eq(fb.UI.screen,"chain"); fb.UI.chainYes.scripts.OnClick(); eq(fb.game.mode,"random"); assert(fb.game.chainReaction)
        fb.UI.retryButton.scripts.OnClick(); assert(fb.game.chainReaction)
        fb.StartSolo("training",true); fb.game.tick=6049; fb.game.score=29
        eventFrame.scripts.OnUpdate(eventFrame,0.02); fb.UI.resultScores.scripts.OnClick()
        fb.UI.scoreSubmit.scripts.OnClick(); fb.UI.panels.scoreEntry.scripts.OnUpdate(nil,2)
        eq(fb.Scores.Best("training-chain").score,29)
        eq(fb.Scores.Best("training").score,14)
        fb.UI:Panel("solo"); fb.UI.soloEntries[2].activate(); eq(fb.UI.screen,"pick")
    end)
    test("solo result keys wait for the original animations and training score card",function()
        local ui=fb.UI; local oldFocus=env.GetMouseFoci
        env.GetMouseFoci=function() return {ui.board} end
        local function press(key)
            ui.board.scripts.OnKeyDown(ui.board,key); ui.board.scripts.OnKeyUp(ui.board,key)
        end
        fb.StartCampaign(1); local game=fb.game
        game.status="won"; game.effects={{kind="pop",x=16,y=16,vx=0,vy=0,wait=0,color=1}}
        eventFrame.scripts.OnUpdate(nil,0.02); press("UP"); eq(fb.game,game)
        game.effects={}; press("UP"); eq(fb.level,2); eq(fb.game.shots,0)
        game=fb.game; game.status="lost"; eventFrame.scripts.OnUpdate(nil,0.02)
        press("RIGHT"); eq(fb.game,game)
        for i=1,100 do eventFrame.scripts.OnUpdate(nil,0.02) end
        press("RIGHT"); assert(fb.game~=game); eq(fb.level,2)
        fb.StartSolo("training"); fb.game.tick=6049; fb.game.score=12
        eventFrame.scripts.OnUpdate(nil,0.02); assert(ui.trainingResult.shown and not ui.resultArt.shown)
        eq(ui.trainingScore.text,"12"); press("SPACE"); eq(ui.screen,"game")
        clock=clock+1; press("ENTER"); eq(ui.screen,"scoreEntry"); eq(ui.namingScore,fb.game.scoreEntry)
        ui.scoreName.scripts.OnEscapePressed(); eq(ui.screen,"scores"); eq(fb.game.scoreEntry,nil)
        env.GetMouseFoci=oldFocus
    end)
    test("a campaign retries on the same clock, can finish from pause and never counts a board twice",function()
        local ui=fb.UI; local unlocked=fb.db.unlocked
        local mouse=env.GetMouseFoci; env.GetMouseFoci=function() return {ui.board} end
        fb.StartCampaign(1)
        local run=fb.run; clock=clock+12.25; fb.game.status="won"; fb.game.score=80
        eventFrame.scripts.OnUpdate(nil,0.02); ui.nextButton.scripts.OnClick()
        clock=clock+3.5; fb.game.status="lost"; fb.game.score=20
        eventFrame.scripts.OnUpdate(nil,0.02); eq(fb.db.checkpoint.level,2)
        eq(fb.db.checkpoint.seconds,15.75); eq(fb.Scores.Pending(),nil)
        ui.retryButton.scripts.OnClick(); eq(fb.run,run); eq(fb.level,2); assert(run.eligible)
        local current=fb.game; clock=clock+2.9; fb.game.score=15
        ui:ShowMenu(); fb.ContinueCampaign(); eq(fb.game,current)
        fb.TogglePause(); ui:UpdatePause(0); assert(ui.finishRunButton.shown)
        ui.finishRunButton.scripts.OnClick(); eq(ui.screen,"scoreEntry")
        local entry=ui.namingScore; eq(entry.level,2); eq(entry.seconds,18); eq(entry.score,115)
        assert(math.abs(entry.elapsed-18.65)<1e-8); eq(fb.db.checkpoint,nil); assert(run.closed)
        eq(fb.FinishCampaignRun(),entry); eq(#fb.db.pendingScores,1)
        ui:ShowMenu(); ui:ShowScores(); eq(ui.namingScore,entry)
        ui.scoreName:SetText(""); ui.scoreName.scripts.OnEnterPressed()
        eq(fb.game.scoreEntry,nil); eq(fb.Scores.Pending(),nil)
        fb.StartCampaign(1); fb.game.elapsed=0.4; fb.StartSolo("random")
        assert(not fb.db.checkpoint.eligible); fb.ContinueCampaign(); assert(not fb.run.eligible)
        fb.TogglePause(); ui:UpdatePause(0); assert(not ui.finishRunButton.shown)
        fb.db.unlocked=unlocked; env.GetMouseFoci=mouse
    end)
    test("campaign clock includes reveals, long frames and visible results and survives a checkpoint reload",function()
        local ui,trans=fb.UI,fb.Transitions
        local mouse,combat=env.GetMouseFoci,env.InCombatLockdown
        env.GetMouseFoci=function() return {ui.board} end
        local function elapsed(expected)
            assert(math.abs(fb.Scores.CampaignTime(fb.run)-expected)<0.00001)
        end
        fb.Options.Set("boardTransitions",true); fb.StartCampaign(1)
        local run=fb.run; eq(trans.target,"game")
        clock=clock+0.25; eventFrame.scripts.OnUpdate(nil,0.02); eq(fb.game.tick,0)
        clock=clock+0.5; trans.Finish()
        clock=clock+4; eventFrame.scripts.OnUpdate(nil,4); elapsed(4.75)
        assert(fb.game.elapsed<=0.25)
        fb.TogglePause(); clock=clock+180; elapsed(4.75); fb.TogglePause()
        clock=clock+0.25
        fb.game.grid={[1]=1,[9]=2,[E.Key(13,1)]=3}
        fb.game:CheckEnd(); eq(fb.game.status,"lost"); eventFrame.scripts.OnUpdate(nil,0); elapsed(5)
        clock=clock+2; ui.frame:Hide(); ui.frame.scripts.OnHide(ui.frame)
        clock=clock+60; elapsed(7)
        ui.frame:Show(); ui.frame.scripts.OnShow(ui.frame); ui:UpdateVisibility(0.02)
        assert(not fb.game.paused)
        clock=clock+0.2; eventFrame.scripts.OnUpdate(nil,0.2)
        eq(fb.game.endIndex,3); assert(ui.result.shown and ui.retryButton.shown)
        clock=clock+0.175; ui:ShowMenu(); clock=clock+10; elapsed(7.375)
        fb.ContinueCampaign(); eq(fb.run,run); eq(fb.level,1)
        clock=clock+0.125; trans.Finish(); fb.game.status="won"; eventFrame.scripts.OnUpdate(nil,0)
        clock=clock+0.75; eventFrame.scripts.OnEvent(nil,"PLAYER_LOGOUT")
        eq(fb.db.checkpoint.level,2); assert(fb.db.checkpoint.eligible); elapsed(8.25)
        fb.game,fb.run=nil,nil; clock=clock+3600; fb.ContinueCampaign()
        eq(fb.level,2); elapsed(8.25); trans.Finish()
        ui.focusGrace=0; ui.outsideSince=nil
        env.GetMouseFoci=function() return {} end; ui:UpdateVisibility(0.02)
        clock=clock+0.75; ui:UpdateVisibility(0.02); assert(fb.game.paused)
        clock=clock+45; elapsed(9)
        env.GetMouseFoci=function() return {ui.board} end; ui:UpdateVisibility(0.02); assert(not fb.game.paused)
        clock=clock+0.75; env.InCombatLockdown=function() return true end
        eventFrame.scripts.OnEvent(nil,"PLAYER_REGEN_DISABLED")
        clock=clock+60; elapsed(9.75)
        env.InCombatLockdown=combat; eventFrame.scripts.OnEvent(nil,"PLAYER_REGEN_ENABLED")
        fb.TogglePause(); clock=clock+0.125
        local entry=fb.FinishCampaignRun(); eq(entry.elapsed,9.875)
        clock=clock+500; eq(fb.FinishCampaignRun(),entry); elapsed(9.875)
        fb.Scores.Submit(entry,""); fb.Options.Set("boardTransitions",false); env.GetMouseFoci=mouse
    end)
    test("campaign finish opens its own card with the right preview, time and colorblind artwork",function()
        local unlocked=fb.db.unlocked; fb.db.unlocked=100
        local run={score=50,seconds=321,eligible=true}
        fb.StartCampaign(100,run); fb.game.status="won"; clock=clock+4
        local mouse=env.GetMouseFoci; env.GetMouseFoci=function() return {fb.UI.board} end
        eventFrame.scripts.OnUpdate(eventFrame,0.02); env.GetMouseFoci=mouse
        assert(fb.game.scoreEntry.completed); eq(fb.UI.screen,"scoreEntry")
        fb.UI.scoreName:SetText("Ice Queen"); fb.UI.scoreSubmit.scripts.OnClick()
        fb.UI.panels.scoreEntry.scripts.OnUpdate(nil,1); eq(fb.UI.screen,"scoreEntry")
        fb.UI.panels.scoreEntry.scripts.OnUpdate(nil,1)
        eq(fb.UI.screen,"scores"); eq(fb.UI.scoreMode,"campaign"); eq(fb.UI.highlightScore,fb.game.scoreEntry)
        local card=fb.UI.scoreCards[1]
        local heading,closeX
        fb.UI.scoreHeading.SetPoint=function(_,anchor,x,y) eq(anchor,"TOPLEFT"); eq(y,-8); heading=x end
        fb.UI.windowClose.SetPoint=function(_,anchor,x) eq(anchor,"TOPLEFT"); closeX=x end
        fb.UI:Panel("scores"); eq(heading,630-149); eq(closeX,88)
        fb.UI.scoreHeading.SetPoint=nil; fb.UI.windowClose.SetPoint=nil
        local lines={}
        local oldTip=env.GameTooltip
        env.GameTooltip={SetOwner=function() end,SetText=function() end,Show=function() end,
            AddLine=function(_,value) lines[#lines+1]=value end}
        card.scripts.OnEnter(card); eq(lines[3],"5:25.000"); env.GameTooltip=oldTip
        eq(card.entry,fb.game.scoreEntry); eq(card.name.text,"Ice Queen"); eq(card.level.text,"won!"); eq(card.time.text,"5'25\"")
        eq(card.board.fbAsset,"score-boards"); eq(card.board.fbFrame,100)
        for _,label in ipairs({card.name,card.time,card.level}) do eq(label.fbFont,fb.media.."DejaVuSans-Bold.ttf"); eq(label.fbFontSize,11*96/72) end
        fb.Options.Set("colorblind",true); eq(card.board.fbAsset,"score-boards-symbol")
        fb.Options.Set("colorblind",false)
        for i=1,14 do fb.Scores.Record("campaign",1,i,90) end
        fb.UI:RefreshScores(); fb.UI.scoreNext.scripts.OnClick()
        eq(fb.UI.scorePage,2); eq(card.board.fbFrame,5); eq(card.level.fbFont,fb.media.."DejaVuSans.ttf")
        fb.UI.scorePrev.scripts.OnClick(); eq(card.board.fbFrame,100)
        fb.UI.scoreSource.scripts.OnClick(); eq(fb.UI.scoreNumber.text,"1 / 1"); eq(card.name.text,"UITester")
        fb.UI.scoreSource.scripts.OnClick()
        fb.UI.scoreSelector.scripts.OnClick()
        eq(fb.UI.scoreMode,"training"); eq(fb.UI.scoreHeading.fbAsset,"scores-training")
        eq(fb.UI.scoreColumns[1].lines[1].entry.score,14)
        eq(fb.UI.scoreColumns[2].lines[1].entry.score,29)
        fb.Scores.Record("training",14,1,121); fb.UI:RefreshScores()
        eq(fb.UI.scoreColumns[1].lines[2].rank.text,"")
        local line=fb.UI.scoreColumns[2].lines[1]
        fb.UI:ShowScores(line.entry)
        eq(line.rank.fbFont,fb.media.."DejaVuSans-Bold.ttf"); eq(line.name.fbFont,line.rank.fbFont)
        eq(line.rank.text,"1. ")
        assert(not card.shown and not fb.UI.shareBest.shown)
        fb.db.unlocked=unlocked
    end)
    test("versus draws the penalty stack, rising bubbles and both shooter penguins",function()
        fb.StartVersus(123)
        fb.Net.match={peer="Bob",remote={grid={},offset=0,shots=0,score=0,lockedShots=0,ceiling=0,
            angle=0.5,current=2,next=4,mode="versus",pending=0,rootPeriod=12}}
        fb.game:AddGarbage(9); fb.UI:Update(0.02)
        local board=fb.UI.board
        eq(board.penalties[1].fbAsset,"penalty-seven"); eq(board.penalties[3].fbAsset,"penalty-one")
        assert(fb.UI.penguin.shown and fb.UI.remotePenguin.shown and fb.UI.remoteBoard.shooter.shown)
        fb.game.tick=21; fb.game:ApplyGarbage(); fb.UI:Update(0.02)
        assert(board.rising[7].shown); eq(board.penalties[1].fbAsset,"penalty-one"); assert(not board.penalties[3].shown)
        fb.Net.match=nil
    end)
    test("versus winner panel waits for the round animation and identifies the winning player",function()
        for _,result in ipairs({"lost","won"}) do
            fb.StartVersus(9,true)
            local other=fb.Engine.New({"11......"},9,"versus",true)
            fb.Net.match={id="7-1",peer="Bob-TestRealm",remote=other,phase="playing"}
            fb.Net.Finish(result,"Round finished",false)
            fb.game:Update(0.02); other:Update(0.02); fb.UI:Update(0.02)
            eq(fb.UI.result.shown,false)
            for _=1,250 do fb.game:Update(0.02); other:Update(0.02) end
            fb.UI:Update(0.02); assert(fb.UI.result.shown)
            eq(fb.UI.resultArt.fbAsset,result=="won" and "net-win-local" or "net-win-remote")
            eq(fb.UI.resultBadge.fbAsset,result=="won" and "net-lose-remote" or "net-lose-local")
            eq(fb.UI.winnerName.fbName,result=="won" and fb.PlayerName() or "Bob-TestRealm")
            if result=="lost" then eq(fb.UI.board.current.fbAsset,"frozen"); assert(not fb.UI.board.nextRim.shown) end
            fb.UI.retryButton.scripts.OnClick(); eq(fb.UI.screen,"lobby"); eq(fb.Net.match,nil)
        end
        fb.UI.panels.lobby.byID.chains.scripts.OnClick(); eq(fb.Net.QueueCode(),12)
        fb.UI.panels.lobby.byID.chains.scripts.OnClick(); eq(fb.Net.QueueCode(),11)
    end)
    test("editor paint follows the original ten staggered rectangular row bands",function()
        local painter={editGame={grid={}},editorColor=8}
        for y=-1,280 do
            local row=math.floor(y/28)
            for x=-1,256 do
                painter.stroke={remembered=true}
                fb.UI.Paint(painter,"LeftButton",x+0.5,y+0.5)
                local column=math.floor((x-row%2*16)/32)
                local expected
                if row>=0 and row<10 and column>=0 and column<8-row%2 then expected=row*8+column+1 end
                local key=next(painter.editGame.grid)
                eq(key,expected)
                if key then painter.editGame.grid[key]=nil end
            end
        end
    end)
    test("editor samples mouse-up and keeps a held brush across the board edge",function()
        local ui=fb.UI
        local cursor,down=ui.Cursor,env.IsMouseButtonDown
        local x,y,over,held=16,16,true,true
        ui.Cursor=function() return x,y end
        ui.board.IsMouseOver=function() return over end
        env.IsMouseButtonDown=function(button) return held and button=="LeftButton" end
        ui:StartEditor(nil,true,1,true); ui:SelectEditorColor(3)
        local board=ui.board
        board.scripts.OnMouseDown(board,"LeftButton")
        board.scripts.OnMouseDown(board,"RightButton"); board.scripts.OnMouseUp(board,"RightButton")
        eq(ui.stroke.button,"LeftButton")
        x=80; board.scripts.OnMouseUp(board,"LeftButton")
        eq(ui.editGame:Count(),3); eq(#ui.editorHistory,1); eq(ui.stroke,nil)
        ui:UndoEditor()
        x=80; board.scripts.OnMouseDown(board,"LeftButton")
        x,over=-10,false; board.scripts.OnLeave(board); ui:UpdateEditor()
        eq(ui.editGame:Count(),3)
        x,y,over=240,72,true; ui:UpdateEditor()
        x=208; board.scripts.OnMouseUp(board,"LeftButton")
        eq(ui.editGame:Count(),5); eq(#ui.editorHistory,1); eq(ui.stroke,nil)
        eq(ui.editGame.grid[fb.Engine.Key(3,8)],3); eq(ui.editGame.grid[fb.Engine.Key(3,7)],3)
        ui:UndoEditor(); eq(ui.editGame:Count(),0)
        -- A release elsewhere can arrive without a board mouse-up callback.
        board.scripts.OnMouseDown(board,"LeftButton")
        held=false; x=16; ui:UpdateEditor(); eq(ui.stroke,nil); eq(ui.editGame:Count(),1)
        ui:UndoEditor()
        board.scripts.OnMouseDown(board,"LeftButton")
        ui:EditorDialog("help"); x=240; board.scripts.OnMouseUp(board,"LeftButton")
        eq(ui.editGame:Count(),1); ui:CloseEditorDialog()
        ui.Cursor=cursor; ui.board.IsMouseOver=nil; env.IsMouseButtonDown=down
    end)
    test("editor opens a private campaign copy, previews the brush and browses saved sets",function()
        local ui=fb.UI
        local oldFocus=env.GetMouseFoci
        env.GetMouseFoci=function() return {ui.panels.editor} end
        ui.editGame=nil; fb.db.editorDraft=nil; ui:StartEditor()
        eq(#ui.editBoards,100); eq(ui.editID,"default-levelset")
        eq(ui.editGame:Pack(),ui:DefaultEditorBoards()[1]); assert(not ui:EditorModified())
        local function key(k)
            local panel=ui.panels.editor
            panel.scripts.OnKeyDown(panel,k); panel.scripts.OnKeyUp(panel,k)
        end
        key("J"); eq(ui.editorDialog,"jump"); ui.dialogValue:SetText("101"); ui:AcceptEditorDialog()
        eq(ui.editIndex,1); eq(ui.editorDialog,"jump")
        ui.dialogValue:SetText("33"); ui.dialogValue.scripts.OnEnterPressed(); eq(ui.editIndex,33)
        local original=ui:DefaultEditorBoards()[33]
        eq(ui.editGame:Pack(),original)
        key("0"); eq(ui.editorColor,0)
        ui.board.IsMouseOver=function() return true end
        local keyAt=next(ui.editGame.grid); local r,c=fb.Engine.Cell(keyAt)
        local mouse=ui.Cursor
        ui.Cursor=function() return fb.Engine.Position(r,c) end
        ui:UpdateEditor(); eq(ui.erasedPreview,keyAt)
        ui:Paint("LeftButton"); eq(ui.editGame.grid[keyAt],nil); assert(ui:EditorModified())
        key("2"); ui:UpdateEditor(); assert(ui.editorPreview.shown); eq(ui.editorPreview.fbAsset,"bubble2")
        eq(ui:DefaultEditorBoards()[33],original)
        ui:UndoEditor(); assert(not ui:EditorModified())
        ui.board.IsMouseOver=nil; ui.Cursor=mouse
        key("F1"); eq(ui.editorDialog,"help"); assert(ui.editorHelp.shown)
        local previous=ui.editGame:Pack(); ui:Paint("RightButton",16,16); eq(ui.editGame:Pack(),previous)
        key("ESCAPE"); eq(ui.editorDialog,nil)
        ui:EditorDialog("new"); ui.dialogValue:SetText("Ice cave"); ui:AcceptEditorDialog()
        eq(ui.levelTitle:GetText(),"Ice cave"); eq(#ui.editBoards,1)
        ui:Paint("LeftButton",34,93); local id=assert(ui:SaveEditor())
        ui:EditorDialog("open"); eq(#ui.editorFiles,2)
        key("DOWN"); eq(ui.editorFiles[ui.fileIndex].id,"default-levelset")
        ui:AcceptEditorDialog(); eq(ui.editID,"default-levelset")
        ui:EditorDialog("delete"); eq(ui.editorFiles[1].id,id); eq(#ui.editorFiles,1)
        ui:AcceptEditorDialog(); eq(ui.editorDialog,"confirm")
        ui.editorBack.scripts.OnClick(); assert(fb.db.custom[id])
        ui:EditorDialog("delete"); ui:AcceptEditorDialog(); ui:AcceptEditorDialog(); eq(fb.db.custom[id],nil)
        ui:EditorDialog("delete"); eq(ui.editorDialog,"empty"); assert(ui.emptyLibrary.shown)
        eq(ui.dialogSign:GetText(),"NO LEVELSET TO DELETE")
        assert(ui.editorOK.shown and not ui.editorBack.shown and not ui.editorBrowser.shown)
        ui.editorOK.scripts.OnClick(); eq(ui.editorDialog,nil)
        env.GetMouseFoci=oldFocus
    end)
    test("starting level browser previews the selected board and repeats arrow presses",function()
        local ui=fb.UI
        local panel=ui.panels.pick
        local oldFocus,oldLibrary=env.GetMouseFoci,fb.db.custom
        local oldColorblind=fb.db.colorblind
        env.GetMouseFoci=function() return {panel} end
        fb.db.custom={}; fb.db.colorblind=true
        local boards=ui:DefaultEditorBoards()
        local ids={}
        for i,title in ipairs({"Ice","Lake","Peak","River","Snow"}) do
            ids[i]=assert(fb.Community.SaveSet(title,{boards[i],boards[i+1],boards[i+2]}))
        end
        local function key(k)
            panel.scripts.OnKeyDown(panel,k); panel.scripts.OnKeyUp(panel,k)
        end
        ui:Panel("pick")
        eq(ui.pickCount,100); eq(ui.pickLevel,1)
        local ten=ui.pickArrows[10]
        ten.scripts.OnMouseDown(ten,"LeftButton"); eq(ui.pickLevel,11)
        panel.scripts.OnUpdate(panel,0.20); eq(ui.pickLevel,11)
        panel.scripts.OnUpdate(panel,0.21); eq(ui.pickLevel,21)
        ten.scripts.OnLeave(); panel.scripts.OnUpdate(panel,0.25); eq(ui.pickLevel,21)
        key("DOWN"); eq(ui.pickID,ids[1]); eq(ui.pickLevel,3)
        key("LEFT"); eq(ui.pickLevel,2)
        key("DOWN"); eq(ui.pickID,ids[2]); eq(ui.pickLevel,2)
        for i=3,5 do key("DOWN") end
        eq(ui.pickBrowser.offset,2); eq(ui.pickBrowser.rows[4].label:GetText(),"Snow")
        assert(ui.pickBrowser.rows[4].highlight.shown)
        local grid=fb.Engine.Unpack(boards[6])
        for cell,texture in pairs(ui.pickBrowser.bubbles) do
            eq(texture.shown,grid[cell]~=nil)
            if grid[cell] then eq(texture.fbAsset,"bubble-symbol"..grid[cell]) end
        end
        ui.level:SetText("3"); ui.level.scripts.OnTextChanged(ui.level,true)
        eq(ui.pickLevel,3); eq(ui.pickNumber:GetText(),"3")
        panel.scripts.OnKeyDown(panel,"LEFT"); eq(ui.pickLevel,2)
        env.GetMouseFoci=function() return {} end
        panel.scripts.OnUpdate(panel,0.25)
        env.GetMouseFoci=function() return {panel} end
        for _=1,3 do panel.scripts.OnUpdate(panel,0.2) end
        eq(ui.pickLevel,2)
        key("ESCAPE"); eq(ui.screen,"solo"); eq(ui.soloIndex,2)
        fb.db.custom=oldLibrary; fb.db.colorblind=oldColorblind; env.GetMouseFoci=oldFocus
    end)
    test("opening the current editor file can keep, discard or save a changed layout",function()
        local ui=fb.UI
        local oldLibrary=fb.db.custom; fb.db.custom={}
        ui:StartEditor(nil,true,nil,true,"Ice cave")
        ui:SelectEditorColor(1); ui:Paint("LeftButton",16,16)
        local original=assert(ui:SaveEditor())
        local function reopen(button)
            ui:EditorDialog("open"); eq(ui.editorFiles[ui.fileIndex].id,original)
            ui:AcceptEditorDialog(); eq(ui.screen,"editor"); eq(ui.editorDialog,"saveChanges")
            assert(ui.saveChanges.shown and ui.gameLayer.shown and ui.editorShield.shown)
            eq(ui.dialogSign:GetText(),"SAVE CHANGES?")
            button.scripts.OnClick()
            eq(ui.pendingEditor,nil); eq(ui.editorDialog,nil)
        end
        ui:SelectEditorColor(2); ui:Paint("LeftButton",16,16)
        reopen(ui.keepEditing); eq(ui.editGame.grid[1],2); assert(ui:EditorModified())
        reopen(ui.editorBack); eq(ui.editGame.grid[1],1); assert(not ui:EditorModified())
        ui:SelectEditorColor(3); ui:Paint("LeftButton",16,16)
        reopen(ui.editorOK); eq(ui.editGame.grid[1],3); assert(not ui:EditorModified())
        assert(ui.editID~=original and fb.db.custom[ui.editID] and not fb.db.custom[original])
        ui:StartEditor(nil,true,nil,true); fb.db.custom=oldLibrary
    end)
    test("editor saves, reopens and exchanges unfinished named sets in both file formats",function()
        local ui,c=fb.UI,fb.Community
        local library,draft=fb.db.custom,fb.db.editorDraft
        fb.db.custom={}
        ui:StartEditor(nil,true,1,true,"Cavern"); local cavern=assert(ui:SaveEditor())
        ui:StartEditor(nil,true,1,true,"Glacier"); local glacier=assert(ui:SaveEditor())
        assert(glacier~=cavern); eq(fb.db.custom[cavern].title,"Cavern")
        ui:SelectEditorColor(6); ui:Paint("LeftButton",16,16); local filled=ui.editGame:Pack()
        ui:EditorAction("append"); eq(ui:SaveEditor(),glacier)
        ui.editGame=nil; ui:StartEditor(); eq(ui.editIndex,2); eq(ui.editID,glacier)
        ui:EditorDialog("open"); eq(#ui.editorFiles,3); ui:CloseEditorDialog()
        ui.marketRemote=false; ui:ShowMarket()
        eq(ui.marketRows[2].key,glacier); assert(ui.marketRows[2].edit.shown and not ui.marketRows[2].button.shown)
        ui:Panel("pick"); eq(#ui.pickFiles,1)
        local game=fb.game; fb.PlayCustom(glacier); eq(fb.game,game)
        ui:StartEditor(glacier); ui:TestEditor(); eq(ui.screen,"editor")
        ui:EditorAction("first"); ui:TestEditor(); eq(fb.game.grid[1],6)
        ui.editButton.scripts.OnClick(); eq(ui.editIndex,1); eq(ui.editID,glacier)
        local boards={c.blankBoard,filled,c.blankBoard}
        for _,code in ipairs({c.LevelText(boards),c.Code(boards)}) do
            ui:OpenEditorText(false); ui.levelCode:SetText(code); ui.codeImport.scripts.OnClick()
            eq(ui.screen,"editor"); eq(table.concat(ui:EditorBoards()),table.concat(boards))
            ui:OpenEditorText(true); eq(ui.levelCode:GetText(),c.LevelText(boards))
            ui.codeFormat.scripts.OnClick(); eq(ui.levelCode:GetText(),c.Code(boards))
            ui:Panel("editor")
        end
        eq(ui:SaveEditor(),glacier); eq(fb.db.custom[glacier].emptyBoard,1)
        ui:Paint("LeftButton",16,16); ui:EditorAction("last"); ui:Paint("LeftButton",16,16)
        local ready=assert(ui:SaveEditor()); assert(not fb.db.custom[ready].emptyBoard)
        eq(fb.db.custom[glacier],nil); eq(fb.db.custom[cavern].emptyBoard,1)
        ui:Panel("pick"); eq(#ui.pickFiles,2); ui:PickSet(1); eq(ui.pickID,ready)
        ui.pickPlay.scripts.OnClick(); eq(fb.game.customSet.id,ready)
        ui:StartEditor(nil,true,nil,true); fb.db.custom=library; fb.db.editorDraft=draft
    end)
    test("edit, reorder, export and play a custom set through its final board",function()
        local ui=fb.UI
        ui:StartEditor(nil,true,nil,true); ui.levelTitle:SetText("Test set")
        ui:SelectEditorColor(1); ui:Paint("LeftButton",16,16)
        local first=ui.editGame:Pack()
        ui:EditorAction("append"); eq(ui.editIndex,2); eq(ui.editGame:Count(),0)
        ui:SelectEditorColor(2); ui:Paint("LeftButton",16,16); local second=ui.editGame:Pack()
        ui:EditorAction("insert"); eq(ui.editIndex,2); eq(#ui.editBoards,3)
        ui:SelectEditorColor(3); ui:Paint("LeftButton",16,16); local third=ui.editGame:Pack()
        ui:EditorAction("right"); eq(ui.editIndex,3); eq(ui.editGame.grid[1],3)
        ui:EditorAction("first"); eq(ui.editGame.grid[1],1)
        ui:EditorAction("remove"); eq(ui.editGame.grid[1],2); ui:UndoEditor(); eq(ui.editIndex,1)
        eq(fb.Community.Code(ui:EditorBoards()),"FBSET1:"..first..second..third)
        ui:OpenEditorText(true); eq(ui.screen,"editorText")
        eq(ui.levelCode:GetText(),fb.Community.LevelText({first,second,third}))
        ui.codeFormat.scripts.OnClick(); eq(ui.levelCode:GetText(),fb.Community.Code({first,second,third}))
        ui:OpenEditorText(false); ui.levelCode:SetText("not a level"); ui.codeImport.scripts.OnClick(); eq(ui.screen,"editorText")
        ui.levelCode:SetText(fb.Community.LevelText({first,second,third})); ui.codeImport.scripts.OnClick(); eq(ui.screen,"editor")
        ui:ImportEditor("FBSET1:"..first..string.rep("0",97).."8"); eq(#ui.editBoards,3)
        ui:StoreEditorDraft(); ui.editGame=nil; ui:StartEditor(); eq(#ui.editBoards,3)
        ui:StartEditor(nil,true); eq(ui.editorDialog,"saveChanges"); assert(ui.pendingEditor.fresh)
        ui:Panel("editor"); local id=assert(ui:SaveEditor())
        local cp,unlocked=fb.db.checkpoint,fb.db.unlocked
        fb.PlayCustom(id)
        for i=1,3 do
            eq(fb.game.grid[1],i); fb.game.status="won"; ui:Update(0.02)
            if i<3 then assert(ui.nextButton.shown); ui.nextButton.scripts.OnClick() end
        end
        assert(not ui.nextButton.shown); eq(ui.retryButton.text,"Replay set")
        ui.retryButton.scripts.OnClick(); eq(fb.game.grid[1],1)
        ui:Panel("pick"); ui:PickSet(1); eq(ui.pickID,id)
        ui.level:SetText("2"); ui.pickPlay.scripts.OnClick(); eq(fb.game.grid[1],2)
        fb.game.status="lost"; ui.retryButton.scripts.OnClick(); eq(fb.game.customIndex,2)
        ui.editButton.scripts.OnClick(); eq(ui.editIndex,2); eq(ui.editGame.grid[1],2)
        ui:Panel("pick"); ui.level:SetText("99"); ui.pickPlay.scripts.OnClick()
        eq(fb.game.customIndex,99); assert(fb.game.customSet.builtin and not ui.editButton.shown)
        fb.game.status="won"; eventFrame.scripts.OnUpdate(nil,0.02); ui.nextButton.scripts.OnClick()
        eq(fb.game.customIndex,100); eq(fb.db.checkpoint,cp); eq(fb.db.unlocked,unlocked)
        fb.db.custom[id]=nil; ui:StartEditor(nil,true,nil,true)
    end)
    test("five-player recording replays all seats, targeting, corrections, departures and the result",function()
        local ui,r=fb.UI,fb.Recordings
        local oldFocus=env.GetMouseFoci
        env.GetMouseFoci=function() return {ui.board} end
        local guests={client("ArenaCopper"),client("ArenaIron"),client("ArenaSilver"),(client("ArenaGold"))}
        local host=fb.PlayerName()
        local menus=fb.db.boardTransitions; fb.Options.Set("boardTransitions",false)
        ui:Panel("rooms"); fb.Arena.Host()
        for _,peer in ipairs(guests) do peer.Arena.Join(host) end
        tick(8); fb.Arena.Start()
        local m=fb.Net.match; local observed,guestObserved={},{}
        local departing=guests[4]
        local function board(g)
            local p=g.projectile
            return table.concat({g:Pack(),g.status,g.tick,g.rng,g.effectRng,g.shots,g.lockedShots,g.attack,
                g.pending,#g.chains,#g.rising,#g.effects,g.current,g.next,g.angle,p and p.x or "-",p and p.y or "-",
                g.chatText or "-",g.chatFrames or 0},"/")
        end
        local function state(room,game)
            local fields={room.phase,room.mask,room.leftMask,room.target or "-",room.winner or "-",board(game)}
            for _,v in ipairs(room.opponents) do
                fields[#fields+1]=table.concat({v.name,v.wins,v.left and 1 or 0,v.lost and 1 or 0,v.target or "-",board(v.remote)},"~")
            end
            return table.concat(fields,"|")
        end
        local function remember()
            if r.capture and r.capture.online==m then observed[r.capture.record.frames]=state(m,fb.game) end
            local c=departing.Recordings.capture
            if c and c.online then guestObserved[c.record.frames]=state(c.online,departing.game) end
        end
        local function run(steps)
            for i=1,steps do
                local dt=i%2==0 and 0.06 or 0.02
                clock=clock+dt; eventFrame.scripts.OnUpdate(nil,dt)
                for _,peer in ipairs(guests) do
                    local room=peer.Net.match
                    local active=room and (room.phase=="playing" or room.phase=="done")
                    if active then peer.game:Update(dt,nil,function() peer.Arena.StepBoards(room) end) end
                    peer.Net.Update(dt,active)
                end
                deliver(); remember()
            end
        end
        run(160); eq(m.phase,"playing"); assert(m.fixedClock); eq(#m.opponents,4)
        r.Mark(); departing.Recordings.Mark()
        local function shot(peer,angle) assert(peer.game:Shoot(angle)) end
        guests[1].game:AddGarbage(4)
        shot(fb,0.43); shot(guests[1],-0.26); shot(guests[2],0.36)
        assert(guests[1].MatchChat.Send("gg")); assert(guests[3].MatchChat.Send("watch | left"))
        guests[1].Controls.Aim(guests[1].game,true,false,false,0.03)
        fb.Arena.Target(3); remember(); run(45)
        local v=m.players[guests[1].PlayerName()]
        eq(v.remote.turning,-1)
        local receivedTurn=false
        for _,e in ipairs(r.capture.record.arena.events) do
            if e[2]=="ATURN" and e[3]==v.index then receivedTurn=true end
        end
        assert(receivedTurn); eq(v.remote.riseShot,1)
        guests[1].Controls.Aim(guests[1].game,false,false,false,0.03)
        assert(v.remote.shots>=1)
        guests[1].Arena.Target(1)
        shot(guests[1],0.71)
        -- Discard this client's copy of AFIRE. The next snapshot carries both
        -- the corrected board and the cumulative penalty for this receiver.
        local outbox=guests[1].Net.outbox
        for i=#outbox,1,-1 do
            if outbox[i].kind=="AFIRE" and outbox[i].target==host then table.remove(outbox,i) end
        end
        run(30)
        local sender=guests[1].Net.match
        sender.players[host].sent=5; sender.lastState=-100
        guests[1].Net.State()
        local packet
        for _,item in ipairs(outbox) do if item.kind=="ASTATE" and item.target==host then packet=item.message end end
        assert(packet); fb.Net.Receive(fb.PREFIX,packet,"WHISPER",v.name)
        local n=#r.capture.record.arena.events
        fb.Net.Receive(fb.PREFIX,packet,"WHISPER",v.name); eq(#r.capture.record.arena.events,n)
        eq(v.remoteAttack,5); eq(v.target,host); remember()
        fb.Arena.Target(0); remember(); guests[4].Arena.Leave(); run(92)
        assert(m.players[departing.PlayerName()].left)
        local other=departing.Recordings.NewPlayback(departing.db.recordings[1])
        eq(other.arena.me,departing.PlayerName()); eq(other.arena.opponents[1].name,host)
        for f=0,other.record.frames do
            if f>0 then assert(departing.Recordings.Step(other)) end
            if guestObserved[f] then eq(state(other.arena,other.right),guestObserved[f],"guest frame "..f) end
        end
        eq(other.arena.closed,"Left the room.")
        for i=1,3 do guests[i].game.status="lost" end
        run(185)
        eq(m.phase,"done"); eq(m.names[m.winner],host)
        local rec=r.capture.record; local wins,losses=fb.db.wins,fb.db.losses
        fb.Arena.Leave(); eq(r.capture,nil); eq(fb.db.recordings[1],rec); eq(fb.game,nil)
        local queue=#fb.Net.outbox
        local p=r.NewPlayback(rec)
        for frame=0,rec.frames do
            if frame>0 then assert(r.Step(p)) end
            if observed[frame] then eq(state(p.arena,p.right),observed[frame],"arena frame "..frame) end
        end
        eq(#fb.Net.outbox,queue); eq(fb.db.wins,wins); eq(fb.db.losses,losses); eq(fb.Net.match,nil)
        r.Play(1); local rendered=r.playback
        eq(ui.screen,"replay"); eq(ui.gameBackground.fbAsset,"arena-background")
        eq(#ui.roomOpponents,4); assert(ui.miniBoards[4]:IsShown())
        while r.Step(rendered) do end
        r.Render(); assert(ui.result:IsShown() and ui.roomBadges:IsShown()); eq(ui.winnerName.fbName,host)
        assert(not ui.retryButton:IsShown() and not ui.leaveSeries:IsShown())
        local seat
        for i,o in ipairs(rendered.arena.opponents) do if o.name==guests[4].PlayerName() then seat=i end end
        assert(ui.leftSigns[seat]:IsShown() and not ui.miniBoards[seat]:IsShown())
        ui:ShowMenu(); fb.Options.Set("boardTransitions",menus); env.GetMouseFoci=oldFocus
        for _,peer in ipairs(guests) do clients[peer.PlayerName()]=nil end
    end)
    test("an editor test and a saved copy of the campaign draw the original ammunition",function()
        local ui,oldSeed=fb.UI,fb.GameSeed
        fb.GameSeed=function() return 4 end
        local function verify()
            local game=fb.game
            eq(game.current,6); assert(game:Shoot(-18*0.03))
            for i=1,38 do game:Step(0.02) end
            eq(game.status,"won"); eq(game.lastPop,3); eq(game.lastDrop,7)
            ui:Update(0.02)
            assert(ui.result:IsShown() and ui.board.fx[1]:GetParent()==ui.board.fxLayer)
            assert(ui.result:GetFrameLevel()<ui.board.fxLayer:GetFrameLevel())
            assert(ui.board.fxLayer:GetFrameLevel()<ui.nextButton:GetFrameLevel())
        end
        ui:StartEditor("default-levelset",false,17,true); ui:TestEditor(); verify()
        fb.StartCustom(ui:DefaultEditorBoards()[17]); verify()
        fb.GameSeed=oldSeed; ui:ShowMenu()
    end)
    test("map lobby navigates with keys, retains chat drafts and joins the selected listing",function()
        local ui=fb.UI
        local focus=env.GetMouseFoci; local rooms=fb.Arena.rooms; fb.Arena.rooms={}
        local p=ui.panels.rooms
        env.GetMouseFoci=function() return {p} end
        ui:ShowLobby(); eq(ui.panels.lobby.map.fbAsset,"lobby-map"); assert(not ui.menu.shown)
        ui.panels.lobby.byID.rooms.scripts.OnClick()
        eq(ui.screen,"rooms"); eq(p.map.fbAsset,"lobby-map"); eq(p.highlight.fbAsset,"lobby-highlight")
        local function press(key) p.scripts.OnKeyDown(p,key); p.scripts.OnKeyUp(p,key) end
        eq(p.selected,"chat"); press("ENTER"); assert(p.input.shown)
        p.input:SetText("Keep this"); p.input.scripts.OnTextChanged(p.input)
        p.input.scripts.OnEscapePressed(); press("ENTER"); eq(p.input:GetText(),"Keep this")
        fb.Community.Join(); tick(2)
        p.input.scripts.OnEnterPressed(p.input); eq(p.input:GetText(),""); assert(p.input.shown)
        p.input:SetText("New draft"); p.input.scripts.OnArrowPressed(p.input,"UP"); eq(p.input:GetText(),"Keep this")
        p.input.scripts.OnArrowPressed(p.input,"DOWN"); eq(p.input:GetText(),"New draft")
        p.input.scripts.OnEscapePressed(); press("DOWN"); assert(p.selected~="chat")
        local scroll=0; p.log.ScrollUp=function() scroll=scroll+1 end
        press("PAGEUP"); eq(scroll,4); p.log.ScrollUp=nil
        for i=1,6 do fb.Arena.rooms["Host"..i.."-TestRealm"]={count=2,limit=5,id="111-"..i,seen=clock} end
        ui:RefreshLobby(); p.byID.more.scripts.OnClick()
        local id="Host6-TestRealm:111-6"
        assert(p.byID[id]); p.byID[id].scripts.OnEnter(); eq(p.selected,id)
        fb.Arena.rooms["Host6-TestRealm"]=nil; ui:RefreshLobby(); eq(p.selected,"chat")
        fb.Arena.rooms={}
        local host=client("Lodge"); host.Arena.Host(); tick(2); ui:RefreshLobby()
        local listing=p.byID[host.PlayerName()..":"..host.Net.match.room]
        listing.scripts.OnEnter(); press("ENTER"); tick(5)
        eq(fb.Net.match.peer,host.PlayerName()); eq(fb.Net.match.phase,"room")
        eq(p.byID.chains.available,false); eq(p.selected,"roomChat")
        press("ENTER"); eq(p.entryMode,"roomChat"); eq(p.input:GetText(),"")
        p.input:SetText("Private draft"); p.input.scripts.OnTextChanged(p.input); p.input.scripts.OnEscapePressed()
        p.byID.chat.scripts.OnClick(); eq(p.entryMode,"chat"); assert(p.input:GetText()~="Private draft")
        p.byID.roomChat.scripts.OnClick(); eq(p.input:GetText(),"Private draft")
        p.input:SetText("Lod"); p.input.GetCursorPosition=function() return 3 end
        p.input.scripts.OnTabPressed(p.input); eq(p.input:GetText(),host.PlayerName()..": "); p.input.GetCursorPosition=nil
        p.input:SetText("/me waits"); p.input.scripts.OnEnterPressed(p.input); tick(2)
        eq(host.Community.log[#host.Community.log],"[Room] * "..fb.PlayerName().." waits")
        fb.Arena.Leave(); tick(1); assert(not p.input.shown); eq(p.selected,"chat"); host.Arena.Leave(); tick(1)
        local oldLimit=fb.db.versusLimit
        p.byID.limit.scripts.OnEnter(); press("NUMPAD7"); eq(fb.db.versusLimit,7)
        press("LEFT"); eq(fb.db.versusLimit,6); press("9"); eq(fb.db.versusLimit,9)
        fb.Arena.SetRule("versusLimit",oldLimit)
        fb.Arena.rooms=rooms; p.page=1
        local rival=client("Duelist"); rival.db.versusLimit=12; rival.db.versusChains=true
        rival.Net.SetQueue(true); tick(2); ui:ShowLobby()
        local limit=fb.db.versusLimit
        ui.panels.lobby.byID[rival.PlayerName()..":"..rival.Net.QueueCode()].scripts.OnClick(); tick(3)
        eq(rival.Net.match.phase,"invite"); eq(rival.Net.match.limit,12); assert(rival.Net.match.chainReaction)
        eq(fb.db.versusLimit,limit); fb.Net.Leave(); tick(2); ui:ShowMenu(); env.GetMouseFoci=focus
    end)
    test("room controls render live miniature boards, targeting, chat, spectating and combat cancellation",function()
        local ui=fb.UI
        local oldMouse=env.GetMouseFoci
        env.GetMouseFoci=function() return {ui.board} end
        local guest1,guest2=client("Larch"),client("Maple")
        local guest3,guest4=client("Spruce"),client("Willow")
        fb.db.versusLimit=1
        ui:Panel("rooms"); ui.panels.rooms.byID.host.scripts.OnClick()
        local host=fb.PlayerName()
        for _,peer in ipairs({guest1,guest2,guest3,guest4}) do peer.Arena.Join(host) end
        tick(9)
        eq(#fb.Net.match.names,5)
        fb.Options.Set("boardTransitions",true)
        local random=env.math.random
        env.math.random=function(n) return n==8 and 4 or n==3 and 3 or 2 end
        ui.panels.rooms.byID.start.scripts.OnClick(); tick(9)
        local reveal=fb.Transitions
        eq(reveal.effect,"arena-dark"); eq(reveal.sprites[1].fbAsset,"arena-background")
        local mini=0
        for i=1,reveal.used do
            if reveal.sprites[i].fbAsset:find("^mini%-bubble") then mini=mini+1 end
        end
        eq(mini,4*(38+1))
        local faces,shadows=0,0
        for i=1,reveal.used do
            local sprite=reveal.sprites[i]
            if sprite.fbReveal=="name-lettering-dark" then faces=faces+1
            elseif sprite.fbReveal=="name-shadow-dark" then shadows=shadows+1 end
        end
        assert(faces>25); eq(shadows,faces)
        for i=1,reveal.patchCount do assert(#reveal.patches[i].fbCuts<=2) end
        fb.Options.Set("boardTransitions",false); env.math.random=random
        eq(ui.screen,"opponent"); local m=fb.Net.match
        ui:Update(0.02)
        eq(ui.gameBackground.fbAsset,"arena-background")
        eq(fb.Plaques.center.fbName,m.players[host].label); assert(fb.Plaques.center.shown and not ui.hud.shown)
        for i,v in ipairs(ui.roomOpponents) do
            eq(ui.miniLabels[i].fbName,v.label); eq(ui.miniLabels[i].fbWins,0); eq(ui.miniLabels[i].fbFace,8)
        end
        eq(#ui.roomOpponents,4); assert(ui.miniBoards[1].shown and ui.miniBoards[4].shown and not ui.remoteBoard.shown)
        eq(ui.roomOpponents[1].remote.effectFloor,918); eq(ui.roomOpponents[4].remote.effectFloor,462)
        eq(ui.roomOpponents[1].remote.chainTurnY,348); eq(ui.roomOpponents[4].remote.chainTurnY,352)
        eq(ui.miniBoards[1].shooter.fbAsset,"mini-cannon"); eq(ui.miniPenguins[1].fbAsset,"anime-shooter-rp1")
        -- The desktop uses a different cannon pedestal on the bottom row.
        for i,board in ipairs(ui.miniBoards) do
            local barrelX,barrelY,rimY
            board.shooter.SetPoint=function(_,_,_,_,x,y) barrelX,barrelY=x,y end
            board.nextRim.SetPoint=function(_,_,_,y) rimY=y end
            local opponent=m.opponents[i].remote
            opponent.angle=0
            ui:RenderBoard(board,opponent,true)
            local top=i<3 and 19 or 247
            eq(top-barrelY/2,i<3 and 177 or 406)
            eq(top-rimY/2,i<3 and 214 or 443)
            fb.Options.Set("graphicsLevel",1)
            for _,angle in ipairs({0,math.pi/4,-math.pi/4}) do
                opponent.angle=angle; ui:RenderBoard(board,opponent,true)
                eq(barrelX/2,math.floor(63+30*math.sin(angle)))
                eq(top-barrelY/2,math.floor((i<3 and 197 or 427)-30*math.cos(angle)))
            end
            fb.Options.Set("graphicsLevel",3)
            board.shooter.SetPoint=nil; board.nextRim.SetPoint=nil
        end
        -- Frame 186 of desktop demo 4 draws the first rp3 penalty at
        -- (20,385). The mini sprite covers 16 desktop pixels.
        local miniBoard,opponent=ui.miniBoards[3],m.opponents[3].remote
        local sprite=miniBoard.rising[1]
        local x,y
        sprite.SetPoint=function(_,_,_,_,cx,cy) x,y=cx,cy end
        opponent.rising={{col=1,row=6,x=16,y=348,color=6}}
        opponent.riseShot,opponent.riseTick=opponent.shots,opponent.tick
        for _,colorblind in ipairs({true,false}) do
            fb.Options.Set("colorblind",colorblind)
            ui:RenderBoard(miniBoard,opponent,true)
            eq(20+x/2-8,20); eq(247-y/2-8,385)
            assert(sprite.shown and miniBoard.fxLayer:GetFrameLevel()>ui.arenaHUD:GetFrameLevel())
            eq(sprite.fbAsset,colorblind and "mini-bubble-symbol6" or "mini-bubble6")
        end
        sprite.SetPoint=nil; opponent.rising={}; opponent.riseShot,opponent.riseTick=nil,nil
        eq(ui.miniBoards[1].bubbles[1].fbAsset,"mini-bubble"..fb.game.grid[1])
        ui.board.scripts.OnKeyDown(ui.board,"F2"); ui:Update(0.02)
        eq(m.target,ui.roomOpponents[2].name); assert(ui.attackIcons[2].shown)
        ui.board.scripts.OnKeyDown(ui.board,"F10"); eq(m.target,nil)
        assert(guest1.MatchChat.Send("watch the left wall")); tick(2); ui:Update(0.02)
        local index
        for i,opponent in ipairs(ui.roomOpponents) do if opponent.name==guest1.PlayerName() then index=i end end
        eq(ui.roomChats[index].line.text,"watch the left wall"); assert(ui.roomChats[index].shown)
        fb.game.status="lost"; tick(6); ui:Update(0.02)
        assert(m.players[host].lost and m.phase=="playing" and not ui.result.shown)
        guest4.Arena.Leave(); tick(5)
        local departed=ui.roomOpponents[4].name==guest4.PlayerName() and 4
        if not departed then for i,opponent in ipairs(ui.roomOpponents) do if opponent.left then departed=i end end end
        ui:Update(0.02); assert(ui.leftSigns[departed].shown and not ui.miniBoards[departed].shown)
        guest1.game.status="lost"; guest3.game.status="lost"; tick(10)
        eq(m.phase,"done"); eq(m.names[m.winner],guest2.PlayerName())
        for i=1,200 do fb.game:Update(0.02); fb.Net.Update(0.02) end
        ui:Update(0.02); assert(ui.result.shown); eq(ui.winnerName.fbName,guest2.PlayerName()); eq(ui.retryButton.text,"Back to lobby")
        ui.retryButton.scripts.OnClick(); tick(3)
        eq(fb.Net.match,nil); eq(guest2.Net.match,nil)
        fb.db.versusLimit=2
        ui:Panel("rooms"); ui.panels.rooms.byID.host.scripts.OnClick()
        guest1.Arena.Join(host); guest2.Arena.Join(host); tick(6); ui.panels.rooms.byID.start.scripts.OnClick(); tick(9)
        m=fb.Net.match
        local previousBoard=m.opponents[1].remote
        guest1.game.status="lost"; guest2.game.status="lost"; tick(8); eq(m.phase,"done")
        for _=1,220 do fb.game:Update(0.02); fb.Net.Update(0.02) end
        ui:Update(0.02); assert(ui:CanAutoRematch()); eq(ui.winnerName.fbName,host)
        guest1.Arena.Start(); guest2.Arena.Start()
        ui.board.scripts.OnKeyDown(ui.board,"SPACE")
        local sawSeating=false
        for _=1,90 do
            tick(0.1); ui:Update(0.02)
            if m.phase=="seating" then
                sawSeating=true
                eq(m.opponents[1].remote,previousBoard); eq(ui.winnerName.fbName,host)
                eq(ui.retryButton.text,"Starting round…"); assert(ui.result.shown)
            end
        end
        assert(sawSeating); eq(m.phase,"playing"); eq(m.round,2); assert(m.opponents[1].remote~=previousBoard)
        eq(ui.winnerName.shown and ui.result.shown,false)
        ui.board.scripts.OnKeyDown(ui.board,"SPACE"); eq(fb.game.shots,0)
        ui.board.scripts.OnKeyUp(ui.board,"SPACE")
        fb.Recordings.Mark()
        env.InCombatLockdown=function() return true end
        eventFrame.scripts.OnEvent(nil,"PLAYER_REGEN_DISABLED")
        env.InCombatLockdown=function() return false end; eventFrame.scripts.OnEvent(nil,"PLAYER_REGEN_ENABLED")
        tick(3); eq(fb.Net.match,nil); eq(guest1.Net.match,nil); eq(guest2.Net.match,nil)
        fb.Recordings.Play(1); local canceled=fb.Recordings.playback
        eq(#canceled.arena.names,3)
        fb.Recordings.Update(0.25); fb.Recordings.Render()
        assert(ui.result:IsShown()); eq(ui.resultDetail.text,"Combat started.")
        assert(not ui.leftSigns[3]:IsShown() and not ui.miniBoards[3]:IsShown() and not ui.roomBadges:IsShown())
        ui:ShowMenu(); env.GetMouseFoci=oldMouse; fb.StartCampaign(1)
    end)
    test("the original four demos play on the title screen and leave the paused game intact",function()
        local ui,demos=fb.UI,fb.Demos
        local oldMouse,oldCursor=env.GetMouseFoci,env.GetCursorPosition
        fb.StartCampaign(1); ui:ShowMenu()
        local game,layout,checkpoint,run=fb.game,fb.game:Pack(),fb.db.checkpoint,fb.run
        env.GetMouseFoci=function() return {ui.menu} end
        local x=0; env.GetCursorPosition=function() return x,0 end
        for i=1,79 do demos.Update(0.25) end
        eq(ui.screen,"menu")
        x=1; demos.Update(0.25); eq(ui.screen,"menu")
        for i=1,78 do demos.Update(0.25) end
        ui.menu.scripts.OnKeyDown(ui.menu,"Z"); eq(demos.idle,0)
        for i=1,80 do demos.Update(0.25) end
        eq(ui.screen,"demo"); assert(demos.scene and demos.panel.shown)
        demos.panel.scripts.OnMouseDown(); eq(demos.wipeStep,1)
        demos.panel.scripts.OnMouseDown(); eq(ui.screen,"menu")
        for index,count in ipairs({997,999,998,999}) do
            demos.Start(index); eq(demos.scene,fb.DemoData.scenes[index])
            eq(demos.frame,1); eq(#demos.scene.frames,count)
            eq(demos.background.fbAsset,({"solo-background","versus-background","arena-background","arena-background"})[index])
            assert(demos.textures[301].shown and demos.textures[1500].shown)
            for frame=2,count do demos.Update(0.02) end
            eq(demos.frame,count); assert(demos.scene)
            for i=1,35 do demos.Update(0.02); eq(demos.wipeStep,i) end
            demos.Update(0.02); eq(demos.scene,nil); eq(ui.screen,"menu")
        end
        demos.Start(4)
        local miniUV=demos.textures[341].fbCoords
        eq(demos.textures[301].fbAsset,"bubble8")
        fb.Options.Set("colorblind",true); eq(ui.screen,"menu"); demos.Start(4)
        eq(demos.textures[301].fbAsset,"bubble-symbol8"); assert(demos.textures[341].fbCoords~=miniUV)
        fb.Options.Set("graphicsLevel",1); demos.Start(4)
        eq(demos.textures[1501].fbAsset,"aim-dot"); eq(demos.textures[1504].fbAsset,"aim-dot")
        assert(not demos.textures[1502].shown and not demos.textures[1505].shown)
        fb.Options.Set("graphicsLevel",3); fb.Options.Set("colorblind",false)
        eq(fb.game,game); eq(game:Pack(),layout); eq(game.tick,0); assert(game.paused)
        eq(fb.db.checkpoint,checkpoint); eq(fb.run,run); eq(fb.Net.match,nil)
        demos.Start(1); demos.panel.scripts.OnKeyDown(demos.panel,"P"); eq(demos.wipeStep,1)
        demos.panel.scripts.OnKeyDown(demos.panel,"P"); eq(ui.screen,"menu")
        demos.Start(2); ui:ShowLobby(); eq(demos.scene,nil); eq(ui.screen,"lobby")
        ui:ShowMenu(); fb.Options.controls.titleDemos.set(false)
        for i=1,81 do demos.Update(0.25) end
        eq(ui.screen,"menu"); fb.Options.controls.titleDemos.set(true)
        demos.Start(3); env.GetMouseFoci=function() return {} end; demos.Update(0.10)
        eq(ui.screen,"demo"); eq(demos.frame,1)
        env.GetMouseFoci=function() return {demos.panel} end; demos.Update(0.02); eq(demos.frame,2)
        ui:SetCombatInput(true); eq(ui.screen,"menu"); eq(demos.scene,nil); ui:SetCombatInput(false)
        env.GetMouseFoci,env.GetCursorPosition=oldMouse,oldCursor
    end)
    test("series rematch controls use round victories and only auto-acknowledge a visible focused result",function()
        local ui=fb.UI
        local oldMouse=env.GetMouseFoci
        fb.StartVersus(51,true)
        local m={id="51-1",peer="Remote-TestRealm",host=true,phase="playing",capable=true,limit=5,
            round=4,seed=51,series={id="51-1",limit=5,wins=1,losses=2,startedAt=env.GetTime()-3723},remote=fb.Engine.New(nil,51,"versus",true)}
        fb.Net.match=m
        fb.game.grid={} -- The loser still has a full board to freeze.
        fb.Net.Finish("won","Round won",false)
        fb.game:Update(0.02); m.remote:Update(0.02)
        ui:Update(0.02); assert(not ui.result.shown)
        for _=1,200 do fb.game:Update(0.02); m.remote:Update(0.02) end
        ui:Update(0.02); assert(ui.result.shown and ui.leaveSeries.shown)
        eq(ui.retryButton.text,"Next round"); eq(fb.Plaques.right.fbName,"UITester"); eq(fb.Plaques.right.fbWins,2)
        eq(fb.Plaques.left.fbName,"Remote"); eq(fb.Plaques.left.fbWins,2); eq(ui.resultDetail.text,"Round 4 · First to 5")
        env.GetMouseFoci=function() return {} end
        assert(not ui:CanAutoRematch()); ui:ShowMenu(); assert(not ui:CanAutoRematch())
        ui:ShowGame(); env.GetMouseFoci=function() return {ui.board} end
        assert(ui:CanAutoRematch()); ui.retryButton.scripts.OnClick(); assert(m.ready)
        ui:Update(0.02); eq(ui.retryButton.text,"Waiting for opponent…")
        local messages={}
        local log=ui.panels.lobby.log
        local addMessage=log.AddMessage
        log.AddMessage=function(_,text) messages[#messages+1]=text end
        ui.leaveSeries.scripts.OnClick(); eq(fb.Net.match,nil); eq(ui.screen,"lobby")
        log.AddMessage=addMessage
        assert(table.concat(messages,"\n"):find("*** Addicted for: 1h 02m 03s\n*** Draw game!\n*** Scores: Remote: 2, UITester: 2",1,true))
        env.GetMouseFoci=oldMouse; fb.StartCampaign(1)
    end)
    test("online winner sign precedes rematch input and falling clusters cross the sign",function()
        local ui=fb.UI
        local oldMouse=env.GetMouseFoci; env.GetMouseFoci=function() return {ui.board} end
        fb.StartVersus(53,true)
        local g=fb.game
        local m={id="53-1",peer="Maple-TestRealm",host=true,phase="playing",capable=true,limit=5,
            round=1,seed=53,series={id="53-1",limit=5,wins=0,losses=0},remote=fb.Engine.New(nil,53,"versus",true)}
        fb.Net.match=m; g.grid={[1]=1}
        g.effects={{kind="fall",x=128,y=40,vx=0,vy=0,wait=500,color=1}}
        fb.Net.Finish("won","Round won",false)
        local sign,input
        for frame=1,150 do
            g:Step(0.02); m.remote:Step(0.02); ui:Update(0.02)
            if not sign and ui.result.shown then
                sign=frame; assert(not ui.retryButton.shown and not ui:CanAutoRematch())
                eq(ui.winnerName.fbName,fb.PlayerName()); eq(ui.board.fxLevel,ui.layers.panel+1)
                assert(m.remote.endIndex<#m.remote.endOrder)
                ui.board.scripts.OnKeyDown(ui.board,"Z"); assert(not m.ready)
            end
            if ui:CanAutoRematch() then input=frame; break end
        end
        assert(sign and input and sign<input); eq(input,76); eq(#g.effects,1); eq(g.effects[1].kind,"fall")
        ui.board.scripts.OnKeyDown(ui.board,"Z"); assert(not m.ready)
        ui.board.scripts.OnKeyUp(ui.board,"Z"); ui.board.scripts.OnKeyDown(ui.board,"Z"); assert(m.ready)
        ui.board.scripts.OnKeyDown(ui.board,"ESCAPE"); eq(fb.Net.match,nil); eq(ui.screen,"lobby")
        env.GetMouseFoci=oldMouse; fb.StartCampaign(1)
    end)
    test("draws show the full menu panel and low graphics preserves the winner backdrop",function()
        local ui=fb.UI
        local g=fb.Engine.New({"34"},55,"versus")
        local peer=fb.Engine.New({"1"},55,"versus"); local m={remote=peer}
        g.status="draw"; peer.status="draw"
        g:Step(0.02,nil,0); peer:Step(0.02,nil,0)
        local sign,advance=ui:OnlineResultTiming(g,m,nil)
        assert(sign and not advance); eq(ui.drawPanel:GetWidth(),341); eq(ui.drawPanel:GetHeight(),280)
        g:Step(0.02); peer:Step(0.02); g:Step(0.02); peer:Step(0.02)
        sign,advance=ui:OnlineResultTiming(g,m,nil); assert(sign and advance)
        g.status="won"; g.lowGraphics=true
        g:Step(0.02,nil,0); eq(g.endIndex,2); eq(next(g.endCells),nil); eq(#g.effects,0)
        g.lowGraphics=false; g.effects={{kind="pop",x=0,y=600,vx=0,vy=1,wait=0,color=3}}
        g:Step(0.02)
        sign,advance=ui:OnlineResultTiming(g,m,g); assert(sign and not advance)
        g:Step(0.02); sign,advance=ui:OnlineResultTiming(g,m,g); assert(sign and advance)
    end)
    test("editor strokes interpolate across cells, undo together, and survive testing",function()
        fb.UI:StartEditor(nil,true); fb.UI:SelectEditorColor(7)
        fb.UI.stroke={button="LeftButton"}
        fb.UI:Paint("LeftButton",16,16); fb.UI:Paint("LeftButton",144,16)
        fb.UI.stroke=nil
        for key=1,5 do eq(fb.UI.editGame.grid[key],7) end
        eq(#fb.UI.editorHistory,1)
        fb.UI:UndoEditor(); eq(fb.UI.editGame:Count(),0)
        fb.UI:Paint("LeftButton",-1,16); eq(fb.UI.editGame:Count(),0)
        fb.UI:Paint("LeftButton",16,16); fb.UI.levelTitle:SetText("Draft")
        fb.UI:TestEditor(); eq(fb.game.mode,"custom"); eq(fb.game.grid[1],7)
        eq(next(fb.db.custom),nil)
        fb.UI.editButton.scripts.OnClick(); eq(fb.UI.screen,"editor")
        eq(fb.UI.levelTitle:GetText(),"Draft"); eq(fb.UI.editGame.grid[1],7)
        fb.Options.controls.colorblind.set(true); fb.UI:Update(0.02)
        eq(fb.UI.board.bubbles[1].fbAsset,"bubble-symbol7"); eq(fb.UI.editorPalette[7].icon.fbAsset,"bubble-symbol7")
        fb.UI:TestEditor(); fb.UI:Update(0.02)
        eq(fb.UI.board.current.fbAsset,"bubble-symbol7"); eq(fb.UI.board.next.fbAsset,"bubble-symbol7")
        fb.Options.controls.colorblind.set(false); fb.UI:Update(0.02); eq(fb.UI.board.current.fbAsset,"bubble7")
        fb.UI:StartEditor(nil,true)
    end)
    fb.UI:StartEditor(); fb.UI:SelectEditorColor(1); fb.UI:Paint("LeftButton"); eq(fb.UI.editGame.grid[1],1)
    fb.UI:Paint("RightButton"); eq(fb.UI.editGame.grid[1],nil)
    env.SlashCmdList.FROZENBUBBLE("debug"); env.SlashCmdList.FROZENBUBBLE("debug off"); eq(fb.db.debug,false)
    fb.StartCampaign(1); fb.Fire(); eventFrame.scripts.OnUpdate(eventFrame,0.1)
    eventFrame.scripts.OnEvent(eventFrame,"PLAYER_REGEN_DISABLED"); assert(fb.game.paused)
    test("campaign Next level stays clickable across render frames and advances",function()
        fb.game.status="won"; fb.game.score=100
        eventFrame.scripts.OnUpdate(eventFrame,0.02)
        eq(fb.db.unlocked,2); eq(fb.run.score,100)
        local hides=fb.UI.nextButton.hideCalls
        for _=1,10 do fb.UI:Update(0.02) end
        eq(fb.UI.nextButton.hideCalls,hides,"button must not Hide during mouse-down/up")
        assert(fb.UI.nextButton.shown)
        fb.UI.nextButton.scripts.OnClick(fb.UI.nextButton)
        eq(fb.level,2); eq(fb.game.status,"playing"); eq(fb.run.score,100)
    end)
    test("piston shafts fill ceiling drops and retract on a fresh board",function()
        local board=fb.UI.board
        fb.game.ceiling=84; fb.UI:RenderBoard(board,fb.game)
        eq(#board.pistons,3); assert(board.pistons[1].shown and board.pistons[3].shown)
        fb.game.ceiling=0; fb.UI:RenderBoard(board,fb.game)
        assert(not board.pistons[1].shown); assert(board.compressor.shown)
    end)
    test("desktop audio keys preserve preferences and use addon-only effect levels",function()
        local ui,options=fb.UI,fb.Options
        local oldMouse,oldKeyboard,oldCombat=env.GetMouseFoci,env.GetCurrentKeyBoardFocus,env.InCombatLockdown
        local oldPlay,oldStop,oldGet,oldSet,oldFX=env.PlayMusic,env.StopMusic,env.GetCVar,env.SetCVar,env.PlaySoundFile
        local musicVolume,effectsVolume=fb.db.musicVolume,fb.db.effectsVolume
        local worldVolume,starts,stops,cues="0.37",0,0,{}
        env.GetCVar=function(key) eq(key,"Sound_MusicVolume"); return worldVolume end
        env.SetCVar=function(key,v) eq(key,"Sound_MusicVolume"); worldVolume=v end
        env.PlayMusic=function() starts=starts+1; return true end
        env.StopMusic=function() stops=stops+1 end
        env.PlaySoundFile=function(path,channel) eq(channel,"SFX"); cues[#cues+1]=path end
        env.GetMouseFoci=function() return {ui.frame} end
        local function press(frame,key)
            frame.scripts.OnKeyDown(frame,key); frame.scripts.OnKeyUp(frame,key)
        end
        fb.StartCampaign(1); ui.inactive=false; fb.StopGameMusic(); worldVolume="0.37"; fb.Music()
        options.Set("musicVolume",0.65); eq(worldVolume,0.65); local started=starts
        press(ui.board,"NUMPADPLUS"); eq(worldVolume,0.7); eq(fb.db.effectsVolume,0.7); eq(starts,started)
        fb.Sound("launch"); eq(cues[#cues],fb.media.."Effects\\7\\launch.ogg")
        ui.board.scripts.OnKeyDown(ui.board,"F12"); ui.board.scripts.OnKeyDown(ui.board,"F12")
        assert(not fb.db.audioEnabled and fb.db.music and fb.db.sound); eq(worldVolume,"0.37")
        ui.board.scripts.OnKeyUp(ui.board,"F12")
        local before=#cues; fb.Sound("hurry"); eq(#cues,before)
        press(ui.board,"F11"); press(ui.board,"NUMPADMINUS"); assert(fb.db.music); eq(fb.db.musicVolume,0.7)
        press(ui.board,"F12"); eq(worldVolume,0.7); eq(starts,started+1)
        press(ui.board,"F11"); assert(not fb.db.music and fb.db.sound); eq(worldVolume,"0.37")
        fb.Sound("stick"); eq(cues[#cues],fb.media.."Effects\\7\\stick.ogg")
        fb.TogglePause(); press(ui.pauseScreen,"F11"); assert(fb.game.paused and fb.db.music)
        fb.TogglePause(); eq(fb.game.shots,0)
        ui:ShowMenu(); ui:Panel("settings"); local panel=ui.panels.settings
        for i=1,11 do press(panel,"NUMPADMINUS") end
        eq(fb.db.musicVolume,0); eq(fb.db.effectsVolume,0); eq(worldVolume,0)
        before=#cues; fb.Sound("cancel"); eq(#cues,before)
        options.controls.effectsVolume.set(1)
        fb.Sound("stick"); eq(cues[#cues],fb.media.."stick.ogg"); eq(worldVolume,0)
        env.GetMouseFoci=function() return {} end
        press(panel,"F12"); assert(fb.db.audioEnabled)
        env.GetMouseFoci=function() return {ui.frame} end
        env.GetCurrentKeyBoardFocus=function() return ui.level end
        press(panel,"F12"); assert(fb.db.audioEnabled)
        env.GetCurrentKeyBoardFocus=oldKeyboard
        env.InCombatLockdown=function() return true end
        press(panel,"F12"); assert(fb.db.audioEnabled)
        env.InCombatLockdown=oldCombat
        fb.StartCampaign(1); local bindings={env.unpack(fb.Controls.keys)}; local custom={env.unpack(bindings)}
        custom[3]="F11"; fb.Controls.Load(custom)
        press(ui.board,"F11"); eventFrame.scripts.OnUpdate(nil,0.02)
        eq(fb.game.shots,1); assert(fb.db.music); fb.Controls.Load(bindings)
        fb.Options.Set("boardTransitions",true); fb.StartCampaign(1)
        local cover=fb.Transitions.frame
        press(cover,"F11"); eq(fb.Transitions.target,"game"); assert(not fb.db.music)
        fb.Transitions.Finish(); fb.Options.Set("boardTransitions",false)
        ui:ShowMenu(); fb.Demos.Start(1); press(fb.Demos.panel,"F11")
        assert(fb.Demos.scene and fb.db.music); ui:ShowMenu()
        local saved=fb.db.recordings; fb.db.recordings={}
        fb.StartSolo("random"); fb.Fire(); eventFrame.scripts.OnUpdate(nil,0.12)
        fb.Recordings.Mark(); fb.Recordings.Play(1)
        local replay=fb.Recordings.playback; assert(replay)
        press(ui.panels.replay,"NUMPADPLUS"); eq(fb.Recordings.playback,replay); eq(ui.screen,"replay")
        ui:ShowMenu(); fb.Recordings.CloseRound(); fb.db.recordings=saved
        options.Set("musicVolume",musicVolume); options.Set("effectsVolume",effectsVolume)
        fb.StopGameMusic()
        env.GetMouseFoci,env.GetCurrentKeyBoardFocus,env.InCombatLockdown=oldMouse,oldKeyboard,oldCombat
        env.PlayMusic,env.StopMusic,env.GetCVar,env.SetCVar,env.PlaySoundFile=oldPlay,oldStop,oldGet,oldSet,oldFX
    end)
    test("pause uses the desktop frame sequence, consumes resume input and holds the music stream",function()
        local ui=fb.UI
        local oldMouse,oldPlay,oldStop=env.GetMouseFoci,env.PlayMusic,env.StopMusic
        local oldGet,oldSet,oldSound=env.GetCVar,env.SetCVar,env.PlaySoundFile
        local tracks,cues,volume,stops={},{}, "0.37",0
        env.PlayMusic=function(path) tracks[#tracks+1]=path; return true end
        env.StopMusic=function() stops=stops+1 end
        env.PlaySoundFile=function(path,channel) eq(channel,"SFX"); cues[#cues+1]=path end
        env.GetCVar=function() return volume end; env.SetCVar=function(_,v) volume=v end
        env.GetMouseFoci=function() return {ui.pauseScreen} end
        ui.inactive=false; ui:ShowMenu(); fb.StartCampaign(1)
        eq(tracks[#tracks],fb.media.."frozen-mainzik-1p.ogg")
        local g=fb.game; local starts=#tracks
        ui.board.scripts.OnKeyDown(ui.board,"P"); eq(cues[#cues],fb.media.."pause.ogg")
        assert(ui.pauseScreen.shown and g.paused); eq(volume,0); eq(ui.pauseArt.fbFrame,1)
        ui.pauseScreen.scripts.OnKeyDown(ui.pauseScreen,"P"); assert(g.paused)
        ui.pauseScreen.scripts.OnKeyUp(ui.pauseScreen,"P")
        for _=1,34 do ui:Update(0.02) end
        eq(ui.pauseArt.fbFrame,35)
        ui:Update(0.02); eq(ui.pauseArt.fbFrame,12)
        for _=1,24 do ui:Update(0.02) end
        eq(ui.pauseArt.fbFrame,12)
        fb.Options.Set("reducedMotion",true); ui:Update(0.02); eq(ui.pauseArt.fbFrame,1)
        fb.Options.Set("reducedMotion",false)
        ui.pauseScreen.scripts.OnKeyDown(ui.pauseScreen,"SPACE")
        assert(not g.paused and not ui.pauseScreen.shown)
        ui.board.scripts.OnKeyDown(ui.board,"SPACE"); eq(g.shots,0)
        ui.board.scripts.OnKeyUp(ui.board,"SPACE"); eq(#tracks,starts); eq(stops,0); eq(volume,0.65)
        fb.StartSolo("training"); fb.game.tick=6049; fb.game.score=100
        eventFrame.scripts.OnUpdate(nil,0.02); ui:OpenRoundScores(); eq(ui.screen,"scoreEntry")
        eq(#tracks,starts); eq(volume,0.65)
        ui.scoreSkip.scripts.OnClick(); eq(ui.screen,"scores")
        ui:ShowMenu(); eq(tracks[#tracks],fb.media.."introzik.ogg")
        ui:StartEditor(nil,true); eq(tracks[#tracks],fb.media.."introzik.ogg")
        fb.LocalVersus.Start(false); eq(tracks[#tracks],fb.media.."frozen-mainzik-2p.ogg")
        fb.LocalVersus.match=nil; ui:ShowMenu()
        fb.Options.Set("boardTransitions",true)
        fb.Demos.Start(1); eq(tracks[#tracks],fb.media.."frozen-mainzik-1p.ogg")
        eq(fb.Transitions.demo,1); local demoStarts=#tracks
        fb.Transitions.Finish(); eq(#tracks,demoStarts)
        ui:ShowMenu(); fb.Demos.Start(4); eq(tracks[#tracks],fb.media.."frozen-mainzik-2p.ogg")
        fb.Transitions.Finish(); ui:ShowMenu(); fb.Options.Set("boardTransitions",false)
        fb.StartCampaign(1); fb.StopGameMusic(); eq(volume,"0.37")
        env.GetMouseFoci,env.PlayMusic,env.StopMusic=oldMouse,oldPlay,oldStop
        env.GetCVar,env.SetCVar,env.PlaySoundFile=oldGet,oldSet,oldSound
    end)
    test("fading and refocusing mute and unmute one music playback",function()
        local starts,stops,volume=0,0,"0.37"
        env.PlayMusic=function() starts=starts+1 end
        env.StopMusic=function() stops=stops+1 end
        env.GetCVar=function() return volume end; env.SetCVar=function(_,value) volume=value end
        fb.UI.inactive=false; fb.Music(); eq(starts,1); eq(volume,0.65)
        fb.UI.focusGrace=0; fb.UI.outsideSince=clock-1
        env.GetMouseFoci=function() return {} end
        fb.UI:UpdateVisibility(0.2); eq(volume,0); eq(stops,0)
        env.GetMouseFoci=function() return {fb.UI.board} end
        fb.UI:UpdateVisibility(0.2); eq(volume,0.65); eq(starts,1)
        fb.StopGameMusic(); eq(stops,1); eq(volume,"0.37")
    end)
    test("focus fades, pauses solo, restores owned pause, and combat makes transparent",function()
        local focused=false; env.GetMouseFoci=function() return focused and {fb.UI.board} or {} end
        fb.UI.focusGrace=0; fb.UI.outsideSince=nil; fb.game.paused=false
        fb.UI:UpdateVisibility(0.1); clock=clock+1; fb.UI:UpdateVisibility(0.2)
        eq(fb.UI.alpha,0.15); assert(fb.game.paused)
        focused=true; fb.UI:UpdateVisibility(0.2); eq(fb.UI.alpha,1); assert(not fb.game.paused)
        fb.game.paused=true; focused=false; fb.UI:UpdateVisibility(0.1); clock=clock+1; fb.UI:UpdateVisibility(0.2)
        focused=true; fb.UI:UpdateVisibility(0.2); assert(fb.game.paused,"manual pause must survive focus gain")
        env.InCombatLockdown=function() return true end
        fb.UI:UpdateVisibility(0.2); eq(fb.UI.alpha,0)
        env.InCombatLockdown=function() return false end
    end)
end)
print("\n"..passed.." tests passed")
