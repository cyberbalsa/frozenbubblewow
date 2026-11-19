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
    for _,module in ipairs({"Bootstrap","Debug","Levels","Engine","Chains","Scores","Network","Community","MediaInfo","Animation"}) do loadModule(module,fb,env) end
    fb.db={}; fb.Scores.Init(fb.db); fb.Debug.Init()
    fb.StartVersus=function(seed) fb.game=fb.Engine.New(nil,seed,"versus") end
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
    eq(#a.db.scores,30); eq(a.Scores.Best("campaign").score,40)
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
    methods.GetParent=function(f) return f.parent end; methods.IsForbidden=function() return false end
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
    loadModule("UI",fb,env); loadModule("Invitations",fb,env); loadModule("Settings",fb,env); loadModule("Main",fb,env)
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
