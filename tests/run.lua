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
    assert(pop.vy<=-100 and pop.vy>=-300); assert(pop.vx>=-75 and pop.vx<=75)
    g:Update(0.02)
    assert(pop.drawY<pop.y); assert(fall.delay>0)
    eq(fall.drawY,fall.y)
    local stick=E.New({"1......."},1)
    stick.projectile={color=2}; stick.shots=1; stick:Attach(48,16)
    assert(stick.stick); eq(stick.lastPop,0)
    stick:Update(0.25); assert(stick.stick)
    stick:Update(0.04); eq(stick.stick,nil)
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
    for _,module in ipairs({"Bootstrap","Debug","Levels","Engine","Chains","Scores","PeerView","Network","Community","MediaInfo","Animation","Controls","MatchChat"}) do loadModule(module,fb,env) end
    fb.db={}; fb.Scores.Init(fb.db); fb.Debug.Init()
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
    g.turning=0; a.Animation.Penguin(texture,g,"p1",0)
    eq(texture.fbState,"left_from"); eq(texture.fbFrame,turnFrame)
    a.Animation.Penguin(texture,g,"p1",0.5)
    for i=1,210 do a.Animation.Penguin(texture,g,"p1",0.02) end
    eq(texture.fbState,"wait_to")
    g.turning=1; a.Animation.Penguin(texture,g,"p1",0.02)
    eq(texture.fbState,"right_to")
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
    eq(m.chatText,"Almost! ||cffff0000 || wow"); assert(m.chatUntil>clock)
    for _,sample in ipairs({{"WHISPER","Wrong-TestRealm",m.id,"bad"},{"CHANNEL",m.peer,m.id,"bad"},
        {"WHISPER",m.peer,"wrong","bad"},{"WHISPER",m.peer,m.id,string.rep("a",121)},
        {"WHISPER",m.peer,m.id,"bad\ntext"}}) do
        b.Net.Receive(b.PREFIX,"1|CHAT|"..sample[3].."|"..sample[4],sample[1],sample[2])
    end
    eq(m.chatText,"Almost! ||cffff0000 || wow")
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
    tick(21); assert(not next(h.Net.results) and not next(j.Net.results))
end)
test("unanswered direct challenge expires",function()
    local c=client("Cora"); c.Net.Challenge("Absent-TestRealm"); tick(22); eq(c.Net.match,nil)
end)
test("community verifies self-echo before advertising automatically",function()
    a.Community.Join(); tick(2); eq(a.Community.state,"ready")
    a.Community.Manual("CATALOG"); eq(a.lastManual,"FBF1|1|CATALOG")
end)
test("level validation rejects disconnected and bottom-row layouts",function()
    local g=E.New({},1); g.grid={[17]=1}; assert(not a.Community.Validate(g:Pack()))
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
test("community scores preserve clears across query and manual channel packets; alts keep their own names",function()
    local c=client("Ilse")
    local d=client("Jon")
    c.Community.Join(); d.Community.Join(); tick(2)
    local row=c.Scores.Record("campaign",20,100,1200,true)
    c.db.scores[#c.db.scores+1]={name="Alt-TestRealm",mode="campaign",score=100,level=100,seconds=40,completed=true}
    d.Net.RequestScores(); tick(3)
    local received=d.db.peers[c.PlayerName()..":campaign"]
    assert(received.completed); eq(received.seconds,1200)
    c.Community.Manual("SCORE",c.Scores.Fields(row))
    eq(c.lastManual,"FBF1|1|SCORE|campaign|20|100|1200|1")
    d.Community.Chat(c.lastManual,c.PlayerName(),d.Community.name)
    d.Scores.Receive(c.PlayerName(),{"1","SCORE","campaign","999","100","60"})
    eq(d.db.peers[c.PlayerName()..":campaign"],received)
    d.Scores.Receive("Alt-TestRealm",{"1","SCORE","campaign","8","2","9","1"})
    eq(d.db.peers["Alt-TestRealm:campaign"],nil)
    c.Scores.Receive("Alt-TestRealm",{"1","SCORE","campaign","6","100","55","1"})
    local all=c.Scores.Rows(true,"campaign"); eq(#all,2); eq(all[1].seconds,40)
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
    methods.CreateFontString=function(f) return frame(nil,nil,f) end; methods.CreateTexture=methods.CreateFontString
    methods.SetSize=function(f,w,h) f.width=w; f.height=h end
    methods.SetText=function(f,s) f.text=tostring(s) end
    methods.GetText=function(f) return f.text end
    methods.GetWidth=function(f) return f.width end; methods.GetHeight=function(f) return f.height end
    methods.GetFrameLevel=function() return 1 end
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
    loadModule("UI",fb,env); loadModule("Scoreboard",fb,env); loadModule("Invitations",fb,env); loadModule("Settings",fb,env); loadModule("LocalVersus",fb,env); loadModule("Main",fb,env)
    local eventFrame=frames[#frames]
    eventFrame.scripts.OnEvent(eventFrame,"ADDON_LOADED","FrozenBubble")
    local promptEvents=frames[#frames]
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
        down(ui.board,"J"); ui:Update(0.04); eq(fb.game.angle,-0.06); up(ui.board,"J")
        down(ui.board,"I"); ui:Update(0.04); eq(fb.game.angle,0); up(ui.board,"I")
        down(ui.board,"UP"); down(ui.board,"SPACE"); eq(fb.game.shots,0)
        down(ui.board,"K"); eq(fb.game.shots,1)
        ui:ShowMenu(); ui.menuHover[2].activate()
        assert(ui.chainControls.text:find("J / L",1,true)); ui.chainNo.scripts.OnClick()
        down(ui.board,"L"); down(ui.board,"S"); fb.LocalVersus.Update(0.02,ui.keys)
        eq(fb.game.angle,0.03); eq(fb.LocalVersus.match.left.angle,-0.03)
        down(ui.board,"T"); down(ui.board,"K"); eq(fb.LocalVersus.match.left.shots,1); eq(fb.game.shots,1)
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
        open(); chat.input:SetText("don't send"); chat.input.scripts.OnEscapePressed(); assert(not chat.input.shown)
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
        eq(dotAnchor[4],127+60*math.sin(math.pi/4)); eq(dotAnchor[5],-(365-60*math.cos(math.pi/4)))
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
    test("low graphics hides pop and stick effects but keeps falling chains and the ceiling warning",function()
        local ui=fb.UI
        local game=fb.Engine.New({"11......","22....."},3,"training",true)
        fb.game=game; game.shots=10; game.lockedShots=10; game.tick=20
        game.stick={age=0,key=1}
        game.effects={game:Effect(1,"pop"),game:Effect(2,"fall")}
        game.chains={{drawX=20,drawY=60,color=4}}
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
        down(ui.board,"C"); down(ui.board,"UP"); eq(m.left.shots,1); eq(m.right.shots,1)
        down(ui.board,"P"); eventFrame.scripts.OnUpdate(nil,0.2)
        eq(m.right.tick,4); eq(m.left.tick,4); assert(m.left.paused)
        up(ui.board,"P"); down(ui.board,"P")
        eventFrame.scripts.OnUpdate(nil,0.02); eq(m.right.tick,5); eq(m.left.tick,5)
        ui:ShowMenu(); eventFrame.scripts.OnUpdate(nil,0.2); eq(m.left.tick,5)
        ui:ShowGame(); eventFrame.scripts.OnUpdate(nil,0.02); eq(m.left.tick,6)
        eventFrame.scripts.OnEvent(nil,"PLAYER_REGEN_DISABLED")
        eventFrame.scripts.OnUpdate(nil,0.02); eq(m.left.tick,6); assert(m.right.paused)
        eventFrame.scripts.OnEvent(nil,"PLAYER_REGEN_ENABLED"); ui:ShowGame()
        ui.focusGrace=0; env.GetMouseFoci=function() return {} end
        ui:UpdateVisibility(0.02); clock=clock+1
        eventFrame.scripts.OnUpdate(nil,0.10); eq(m.left.tick,6); assert(m.right.paused)
        env.GetMouseFoci=function() return {ui.remoteBoard} end
        eventFrame.scripts.OnUpdate(nil,0.02); eq(m.left.tick,7); eq(m.right.tick,7)
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
        eq(ui.resultArt.fbAsset,"local-win-p2"); eq(ui.remoteLabel.text,"1"); eq(ui.retryButton.text,"Next round")
        ui.retryButton.scripts.OnClick(); m=fb.LocalVersus.match
        assert(m.right.chainReaction and m.left.chainReaction); eq(m.right.shots,0); eq(m.wins[2],1)
        m.left.status="lost"; fb.LocalVersus.Update(0.02,{}); eq(m.right.status,"won"); eq(m.wins[1],1)
        ui:Update(0); eq(ui.resultArt.fbAsset,"local-win-p1")
        fb.LocalVersus.Rematch(); m=fb.LocalVersus.match
        m.right.status="lost"; m.left.status="lost"; fb.LocalVersus.Update(0.04,{})
        eq(m.right.status,"draw"); eq(m.left.status,"draw"); eq(m.wins[1],1); eq(m.wins[2],1)
        eq(fb.db.wins,wins); eq(fb.db.losses,losses); eq(fb.Net.match,nil)
        fb.StartCampaign(1); eq(fb.LocalVersus.match,nil)
    end)
    test("solo menu launches timed training, records it once, and retries",function()
        fb.UI:Panel("solo"); eq(fb.UI.soloIndex,1)
        fb.UI:SelectSolo(4); fb.UI:Update(0.10)
        eq(fb.UI.soloEntries[4].glow.fbFrame,6)
        fb.UI.soloEntries[4].activate(); eq(fb.UI.screen,"chain"); fb.UI.chainNo.scripts.OnClick()
        eq(fb.game.mode,"training"); fb.UI:Update(0.02)
        eq(fb.UI.trainingTime.text,"2'00\""); assert(fb.UI.trainingClock.shown)
        fb.game.tick=6049; fb.game.score=14
        for _=1,3 do eventFrame.scripts.OnUpdate(eventFrame,0.02) end
        eq(fb.game.status,"finished"); eq(#fb.Scores.Rows(false,"training"),1)
        eq(fb.Scores.Best("training").score,14); assert(fb.UI.trainingResult.shown)
        fb.UI.retryButton.scripts.OnClick(); eq(fb.game.tick,0); eq(fb.game.status,"playing")
        fb.UI:Panel("solo"); fb.UI.soloEntries[3].activate(); eq(fb.UI.screen,"chain"); fb.UI.chainYes.scripts.OnClick(); eq(fb.game.mode,"random"); assert(fb.game.chainReaction)
        fb.UI.retryButton.scripts.OnClick(); assert(fb.game.chainReaction)
        fb.StartSolo("training",true); fb.game.tick=6049; fb.game.score=29
        eventFrame.scripts.OnUpdate(eventFrame,0.02); eq(fb.Scores.Best("training-chain").score,29)
        eq(fb.Scores.Best("training").score,14)
        fb.UI:Panel("solo"); fb.UI.soloEntries[2].activate(); eq(fb.UI.screen,"pick")
    end)
    test("campaign finish opens its own card with the right preview, time and colorblind artwork",function()
        local unlocked=fb.db.unlocked; fb.db.unlocked=100
        local run={score=50,seconds=321,eligible=true}
        fb.StartCampaign(100,run); fb.game.status="won"; fb.game.elapsed=4
        eventFrame.scripts.OnUpdate(eventFrame,0.02)
        assert(fb.game.scoreEntry.completed and fb.UI.resultScores.shown)
        fb.UI.resultScores.scripts.OnClick()
        eq(fb.UI.screen,"scores"); eq(fb.UI.scoreMode,"campaign"); eq(fb.UI.highlightScore,fb.game.scoreEntry)
        local card=fb.UI.scoreCards[1]
        eq(card.entry,fb.game.scoreEntry); eq(card.level.text,"won!"); eq(card.time.text,"5'25\"")
        eq(card.board.fbAsset,"score-boards"); eq(card.board.fbFrame,100)
        fb.Options.Set("colorblind",true); eq(card.board.fbAsset,"score-boards-symbol")
        fb.Options.Set("colorblind",false)
        for i=1,14 do fb.Scores.Record("campaign",1,i,90) end
        fb.UI:RefreshScores(); fb.UI.scoreNext.scripts.OnClick()
        eq(fb.UI.scorePage,2); eq(card.board.fbFrame,5)
        fb.UI.scorePrev.scripts.OnClick(); eq(card.board.fbFrame,100)
        fb.UI.scoreSource.scripts.OnClick(); eq(fb.UI.scoreNumber.text,"1 / 1")
        fb.UI.scoreSource.scripts.OnClick()
        fb.UI.scoreSelector.scripts.OnClick()
        eq(fb.UI.scoreMode,"training"); eq(fb.UI.scoreHeading.fbAsset,"scores-training")
        eq(fb.UI.scoreColumns[1].lines[1].entry.score,14)
        eq(fb.UI.scoreColumns[2].lines[1].entry.score,29)
        fb.Scores.Record("training",14,1,121); fb.UI:RefreshScores()
        eq(fb.UI.scoreColumns[1].lines[2].rank.text,"")
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
            eq(fb.UI.winnerName.text,result=="won" and fb.PlayerName() or "Bob-TestRealm")
            if result=="lost" then eq(fb.UI.board.current.fbAsset,"frozen"); assert(not fb.UI.board.nextRim.shown) end
            fb.UI.retryButton.scripts.OnClick(); eq(fb.UI.screen,"lobby"); eq(fb.Net.match,nil)
        end
        fb.UI.versusRules.scripts.OnClick(); eq(fb.Net.QueueCode(),2)
        fb.UI.versusRules.scripts.OnClick(); eq(fb.Net.QueueCode(),1)
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
