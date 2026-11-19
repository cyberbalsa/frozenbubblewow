-- Versioned, bounded addon-message protocol. Peers are casual/trusted, not authoritative servers.
local _, FB = ...
local N={peers={},outbox={},results={},queue=false,serial=0,tokens=4,lastAdvert=-100,lastSend=0,lastScoreReply={}}
FB.Net=N
local function now() return GetTime() end
local function notify(text)
    N.notice=text
    if FB.Debug then FB.Debug.Log("NET",text) end
    if FB.UI then FB.UI:RefreshLobby() end
end
N.Notify=notify
local unpackFields=unpack or table.unpack
local function packet(kind,...) local a={"1",kind,...}; for i,v in ipairs(a) do a[i]=tostring(v) end; return table.concat(a,"|") end
function N.Send(kind, channel, target, ...)
    local message=packet(kind,...)
    if #message>240 or #N.outbox>=64 then return false end
    -- Coalesce snapshots and advertisements: a slow network must not build a stale backlog.
    if kind=="STATE" or kind=="ASTATE" or kind=="QUEUE" then
        for i=#N.outbox,1,-1 do
            local entry=N.outbox[i]
            if (kind=="STATE" and entry.kind=="FIRE" or kind=="ASTATE" and entry.kind=="AFIRE") and entry.target==target then break end
            if entry.kind==kind and entry.channel==channel and entry.target==target then entry.message=message; return true end
        end
    end
    N.outbox[#N.outbox+1]={kind=kind,message=message,channel=channel,target=target,expires=now()+10}
    return true
end
function N.Whisper(kind,...) if N.match then return N.Send(kind,"WHISPER",N.match.peer,...) end end
function N.Broadcast(kind,...)
    if FB.Community and FB.Community.joined then
        FB.Community.Broadcast(kind,...)
        return
    end
    if IsInGuild() then N.Send(kind,"GUILD",nil,...) end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then N.Send(kind,"INSTANCE_CHAT",nil,...)
    elseif IsInRaid() then N.Send(kind,"RAID",nil,...)
    elseif IsInGroup() then N.Send(kind,"PARTY",nil,...) end
end
function N.Available()
    if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return false,"Addon messaging is unavailable." end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return false,"Chat messaging is locked right now. Try again outside combat."
    end
    return true
end
function N.QueueCode()
    return FB.Series.Code(FB.db.versusChains,FB.db.versusLimit)
end
function N.SetQueue(enabled)
    local available,reason=N.Available()
    if enabled and not available then notify(reason); return end
    if enabled and N.match then notify("Finish or leave your current match first."); return end
    if enabled and not (FB.Community and FB.Community.joined) and not IsInGuild() and not IsInGroup() then
        notify("Join the FrozenBubbleForever channel first, or challenge a player by name."); return
    end
    if enabled and FB.game and FB.game.status=="playing" then FB.game.paused=true end
    N.queue=enabled; N.lastAdvert=now()
    N.Broadcast("QUEUE",enabled and N.QueueCode() or 0)
    notify(enabled and "Queued. If channel delivery is blocked, click Announce queue." or "Left the queue.")
end
function N.Challenge(peer, automatic)
    local available,reason=N.Available()
    if not available then notify(reason); return false end
    if N.match then notify("Finish or leave your current match first."); return false end
    if type(peer)~="string" or #peer<2 or #peer>100 or peer:find("[|%c%s]") then notify("Enter Player-Realm."); return false end
    peer=FB.PlayerName(peer)
    if peer==FB.PlayerName() then return false end
    N.serial=N.serial+1
    local seed=(time()+math.floor(now()*1000)+N.serial*7919)%2147483646+1
    local id=tostring(seed).."-"..N.serial
    N.match={id=id,peer=peer,seed=seed,host=true,phase="offer",since=now(),lastRetry=-100,lastSeen=now(),seq=0,remoteSeq=0,remoteAttack=0,automatic=automatic,limit=FB.db.versusLimit,chainReaction=FB.db.versusChains==true}
    N.queue=false
    if FB.game then FB.game.paused=true end
    N.Broadcast("QUEUE",0)
    notify("Challenging "..peer.."…")
    return true
end
function N.Accept()
    local m=N.match
    if not m or m.phase~="invite" then return end
    local available,reason=N.Available()
    if not available then notify(reason); return end
    m.phase="accept"; m.since=now(); m.lastRetry=-100
    N.queue=false; N.Broadcast("QUEUE",0)
    notify("Waiting for the match to start…")
end
function N.Leave()
    if N.match and N.match.arena then FB.Arena.Leave(); return end
    N.queue=false; N.Broadcast("QUEUE",0)
    local m=N.match
    if m then
        FB.Series.Leave(m)
        if m.phase=="playing" then N.Finish("lost","You forfeited.",true)
        elseif m.phase~="done" then N.Whisper("CANCEL",m.id); N.match=nil
        else N.match=nil end
    end
    notify("Left multiplayer.")
end
function N.WaitForStart(m)
    m.phase="barrier"; m.since=now(); m.lastRetry=now()
    N.Whisper("READY",m.id)
end
function N.Begin()
    local m=N.match
    if not m or m.phase=="playing" or m.phase=="done" then return end
    if InCombatLockdown() then N.Whisper("CANCEL",m.id); N.match=nil; return end
    m.phase="playing"; m.since=now(); m.lastSeen=now(); m.lastState=-100
    if m.capable and not m.series then
        m.round=1; m.series={id=m.id,wins=0,losses=0,limit=m.limit or 0}
    end
    m.remote=FB.Engine.New(nil,m.seed,"versus",m.chainReaction,FB.Sound)
    -- The spectator advances shots received from the other player.
    m.remote.hurryMax=math.huge; m.remote.timed=false
    FB.StartVersus(m.seed,m.chainReaction)
    FB.game.onShoot=N.Fire
    notify("Playing against "..m.peer)
end
function N.Finish(result,reason,send)
    local m=N.match
    if not m or m.phase=="done" then return end
    m.phase="done"; m.result=result; m.reason=reason; m.since=now(); m.lastRetry=-100
    m.sendResult=send
    if result=="won" or result=="lost" then
        local side=result=="won" and "wins" or "losses"
        if m.series then m.series[side]=m.series[side]+1 end
        m.wireResult=result
        N.results[m.peer..":"..m.id]=m
        if send then N.Whisper("END",m.id,result); m.lastRetry=now() end
    end
    if FB.game and FB.game.mode=="versus" then
        FB.game.status=result
        if result~="won" and result~="lost" and result~="draw" then FB.game.projectile=nil end
    end
    if m.remote then m.remote.status=result=="won" and "lost" or result=="lost" and "won" or result end
    if result=="won" then FB.db.wins=FB.db.wins+1
    elseif result=="lost" then FB.db.losses=FB.db.losses+1 end
    if result=="won" or result=="lost" or result=="draw" then FB.Sound("lose")
    elseif result=="aborted" then FB.Sound("cancel") end
    if FB.Series.Complete(m) then reason=reason.." Victory limit reached." end
    notify(reason)
end
function N.Fire(g)
    local m=N.match
    if not m or m.phase~="playing" then return end
    m.seq=m.seq+1
    local send=m.arena and FB.Arena.Fan or N.Whisper
    send(m.arena and "AFIRE" or "FIRE",m.id,m.seq,g.tick,g.shots,string.format("%.17g",g.angle),g.projectile.color,
        g.current,g.next,g.rng,g:Pack())
end
function N.State()
    local m,g=N.match,FB.game
    if not m or m.phase~="playing" or not g then return end
    if m.arena and now()-m.lastState<2 then return end
    m.seq=m.seq+1
    local fields={m.id,m.seq,g.shots,g.score,math.floor(g.ceiling*100+0.5),g.attack,g:Pack(),g.lockedShots,
        g.pending,math.floor(g.angle*1000+0.5),g.current,g.next}
    fields[13],fields[14]=g.tick,g.rng
    fields[15],fields[16]=FB.PeerView.PackRising(g),math.min(10000,math.floor(g.idle*50+0.5))
    if m.arena then FB.Arena.SendStates(m,fields)
    elseif not N.Whisper("STATE",unpackFields(fields)) then
        -- Preserve the authoritative scoreboard and board even at the packet size limit.
        N.Whisper("STATE",unpackFields(fields,1,12))
    end
    m.lastState=now()
end
function N.ApplyState(m,p)
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
    local rising=p[17] and FB.PeerView.UnpackRising(p[17],offset)
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
    m.remoteSeq=seq; m.remoteShots=shots; m.lastSeen=now()
    if FB.game.status=="playing" then FB.game:AddGarbage(attack-m.remoteAttack) end
    m.remoteAttack=attack
    local remote=m.remote
    FB.PeerView.Sync(remote,grid,offset,tick,shots,locked,rng,rising)
    if idle then remote.idle,remote.timed=idle*0.02,true end
    remote.ceiling=ceiling/100
    remote.score,remote.shots,remote.lockedShots=score,shots,locked
    local aim=(angle or 0)/1000
    remote.turning=aim<remote.angle and -1 or aim>remote.angle and 1 or 0
    remote.turnUntil=now()+0.15
    remote.angle,remote.current,remote.next=aim,current,nextColor
    remote.pending,remote.mode,remote.rootPeriod=pending,"versus",12
    m.remote=remote
end
function N.RequestScores()
    if N.lastScoreRequest and now()-N.lastScoreRequest<15 then return end
    N.lastScoreRequest=now(); N.Broadcast("SCOREQ")
end
function N.Receive(prefix,message,channel,sender)
    if issecretvalue and (issecretvalue(message) or issecretvalue(sender)) then return end
    if prefix~=FB.PREFIX or type(message)~="string" or #message>240 or type(sender)~="string" then return end
    if FB.Community and FB.Community.Receive(message,channel,sender) then return end
    sender=FB.PlayerName(sender)
    if sender==FB.PlayerName() then return end
    local p=FB.Split(message)
    if p[1]~="1" then return end
    local kind=p[2]
    if FB.Arena.Receive(kind,p,channel,sender) then return end
    if FB.Debug and kind~="STATE" and kind~="QUEUE" then FB.Debug.Log("RECV",kind,channel,sender) end
    if kind=="QUEUE" and (channel=="CHANNEL" or channel=="GUILD" or channel=="PARTY" or channel=="RAID" or channel=="INSTANCE_CHAT") then
        local limit,chains=FB.Series.Decode(p[3])
        if p[3]~="0" and not limit then return end
        local count=0; for _ in pairs(N.peers) do count=count+1 end
        if count>=100 and not N.peers[sender] then return end
        N.peers[sender]={seen=now(),queued=p[3]~="0",chainReaction=chains,limit=limit}
        if N.queue and tonumber(p[3])==N.QueueCode() and not N.match and FB.PlayerName()<sender then N.Challenge(sender,true) end
        if FB.UI then FB.UI:RefreshLobby() end
        return
    end
    if kind=="SCORE" and channel=="CHANNEL" then FB.Scores.Receive(sender,p); return end
    if kind=="SCOREQ" and (channel=="CHANNEL" or channel=="GUILD" or channel=="PARTY" or channel=="RAID" or channel=="INSTANCE_CHAT") then
        if now()-(N.lastScoreReply[sender] or -100)<30 then return end
        N.lastScoreReply[sender]=now()
        for _,mode in ipairs(FB.Scores.modes) do
            local row=FB.Scores.Best(mode,FB.PlayerName())
            if row then N.Send("SCORE","WHISPER",sender,FB.Scores.Fields(row)) end
        end
        return
    end
    if channel~="WHISPER" then return end
    if kind=="SCORE" then
        if N.lastScoreRequest and now()-N.lastScoreRequest<15 then FB.Scores.Receive(sender,p) end
        return
    end
    local m=N.match
    if m and m.arena then
        if kind=="OFFER" or kind=="CHAINOFFER" or kind=="LIMITOFFER" then N.Send("CANCEL","WHISPER",sender,p[3]) end
        if kind~="END" and kind~="ENDACK" then return end
    end
    if FB.Series.Receive(kind,p,sender) then return end
    if kind=="OFFER" or kind=="CHAINOFFER" or kind=="LIMITOFFER" then
        local seed=FB.Integer(p[4],1,2147483646)
        if not seed or not p[3] or #p[3]>32 or not p[3]:match("^%d+%-%d+$") or (p[5]~="0" and p[5]~="1") then return end
        if InCombatLockdown() then N.Send("CANCEL","WHISPER",sender,p[3]); return end
        local chains=kind=="CHAINOFFER"
        local limit=0
        if kind=="LIMITOFFER" then
            limit,chains=FB.Series.Decode(p[6])
            if not limit or limit==0 then return end
        end
        if p[5]=="1" and N.queue and FB.Series.Code(chains,limit)~=N.QueueCode() then
            N.Send("CANCEL","WHISPER",sender,p[3]); return
        end
        if m then
            if m.id==p[3] and m.peer==sender then
                if m.phase=="accept" then N.Whisper("ACCEPT",m.id,"R1") end
                return
            end
            -- Resolve simultaneous offers by canonical player name.
            if not (m.phase=="offer" and m.peer==sender and sender<FB.PlayerName()) then
                N.Send("CANCEL","WHISPER",sender,p[3]); return
            end
        end
        local auto=N.queue and p[5]=="1"
        N.match={id=p[3],peer=sender,seed=seed,chainReaction=chains,limit=limit,host=false,phase="invite",since=now(),lastSeen=now(),lastRetry=-100,seq=0,remoteSeq=0,remoteAttack=0}
        notify(sender.." challenges you "..(chains and "with chain reactions." or "under standard rules.")..(limit>0 and (" First to "..limit..".") or "").." Accept in Multiplayer.")
        if FB.UI then FB.UI:ShowLobby() end
        if auto then N.Accept() end
        return
    end
    if (kind=="ENDACK" or kind=="END") and p[3] then
        -- Keep result delivery alive when the player closes the result panel
        -- or has already started a different round.
        local finished=N.results[sender..":"..p[3]]
        if finished then
            if kind=="ENDACK" then finished.acked=true; return end
            if p[4]~="won" and p[4]~="lost" then return end
            N.Send("ENDACK","WHISPER",sender,finished.id)
            if finished.sendResult and finished.result==p[4] then
                local counter=finished.result=="won" and "wins" or "losses"
                FB.db[counter]=math.max(0,FB.db[counter]-1); finished.result="draw"
                if finished.series then finished.series[counter]=math.max(0,finished.series[counter]-1) end
                finished.peerReady=nil
                if m==finished then
                    FB.game.status="draw"; m.remote.status="draw"; notify("Draw — both players finished together.")
                end
            end
            return
        end
    end
    if not m or m.arena or sender~=m.peer or p[3]~=m.id then return end
    if kind=="CHAT" then
        FB.MatchChat.Receive(m,table.concat(p,"|",4))
    elseif kind=="ACCEPT" and m.host and m.phase=="offer" then
        m.capable=p[4]=="R1"
        if m.limit>0 and not m.capable then N.Whisper("CANCEL",m.id); N.match=nil; notify("This limit requires alpha 13 or later."); return end
        m.phase="start"; m.since=now(); m.lastRetry=-100
    elseif kind=="START" and not m.host and (m.phase=="accept" or m.phase=="barrier" or m.phase=="playing") then
        if m.phase=="accept" then
            m.capable=p[4]=="R1"
            if m.capable then N.WaitForStart(m)
            else N.Whisper("READY",m.id); N.Begin() end
        else N.Whisper("READY",m.id) end
    elseif kind=="READY" and m.host and not InCombatLockdown() then
        if m.phase=="start" or m.phase=="restart" then
            if not m.capable or N.Whisper("GO",m.id) then N.Begin() end
        elseif (m.phase=="playing" or m.phase=="done") and m.capable then N.Whisper("GO",m.id) end
    elseif kind=="GO" and not m.host and m.phase=="barrier" then N.Begin()
    elseif kind=="CANCEL" and m.phase~="done" then
        if m.phase=="playing" then N.Finish("aborted","Opponent left; match canceled.",false)
        else N.match=nil; notify("Challenge declined or canceled.") end
    elseif kind=="END" and (p[4]=="won" or p[4]=="lost") then
        if m.phase=="barrier" or m.host and (m.phase=="restart" or m.phase=="start") then N.Begin() end
        N.Whisper("ENDACK",m.id)
        if m.phase=="playing" then N.Finish(p[4]=="lost" and "won" or "lost",p[4]=="lost" and "Victory! Opponent lost or forfeited." or "Opponent cleared the board.",false)
        end
    elseif kind=="FIRE" and m.phase=="playing" then
        FB.PeerView.Fire(m,p)
    elseif kind=="STATE" and m.phase=="playing" then
        N.ApplyState(m,p)
    end
end
function N.Update(dt)
    local t=now()
    local fanout=N.match and N.match.arena and math.max(1,#N.match.names-1) or 1
    N.tokens=math.min(4*fanout,N.tokens+dt*3*fanout)
    if N.tokens>=1 and #N.outbox>0 then
        local entry=N.outbox[1]
        local available=N.Available()
        if entry.expires<t then table.remove(N.outbox,1)
        elseif available then
            local ok,result=pcall(C_ChatInfo.SendAddonMessage,FB.PREFIX,entry.message,entry.channel,entry.target)
            if FB.Debug and (entry.kind~="STATE" or not ok or result~=0) then FB.Debug.Log("SEND",entry.kind,entry.channel,entry.target,result) end
            N.tokens=N.tokens-1
            local results=Enum and Enum.SendAddonMessageResult
            local throttled=results and result==results.AddonMessageThrottle
            if not throttled then table.remove(N.outbox,1) end
            if not ok or (results and result~=results.Success and not throttled) then
                notify("Addon message failed ("..tostring(result).."). Check Community channel status.")
                if entry.channel=="CHANNEL" and FB.Community then FB.Community.Blocked() end
            end
        end
    end
    for name,peer in pairs(N.peers) do if t-peer.seen>25 then N.peers[name]=nil end end
    for name,seen in pairs(N.lastScoreReply) do if t-seen>60 then N.lastScoreReply[name]=nil end end
    if N.queue and t-N.lastAdvert>=8 then N.Broadcast("QUEUE",N.QueueCode()); N.lastAdvert=t end
    for key,finished in pairs(N.results) do
        if t-finished.since>=20 then N.results[key]=nil
        elseif finished.sendResult and not finished.acked and t-finished.lastRetry>=1 then
            N.Send("END","WHISPER",finished.peer,finished.id,finished.wireResult)
            finished.lastRetry=t
        end
    end
    local m=N.match
    FB.Arena.Expire(t)
    if not m then return end
    if m.arena then FB.Arena.Update(m,dt,t); return end
    if m.phase=="playing" then
        FB.PeerView.Update(m,dt)
        if t-m.lastSeen>25 then N.Finish("aborted","Connection timed out. No win or loss recorded.",false); return end
        if FB.game.status=="won" or FB.game.status=="lost" then
            N.Finish(FB.game.status,FB.game.status=="won" and "Board cleared — victory!" or "Your board is full.",true)
        elseif t-m.lastState>=1 then N.State() end
    elseif m.phase=="done" then
        FB.PeerView.Update(m,dt); FB.Series.Update(m,t)
    elseif t-m.since>20 then
        FB.Series.Leave(m); N.Whisper("CANCEL",m.id); N.match=nil; notify("Challenge expired. Queue again to retry.")
    elseif t-m.lastRetry>=2 then
        if m.phase=="barrier" then N.Whisper("READY",m.id)
        elseif m.phase=="restart" then N.Whisper("ROUNDSTART",m.parent,m.parentResult)
        elseif m.phase=="offer" and m.limit>0 then
            N.Whisper("LIMITOFFER",m.id,m.seed,m.automatic and 1 or 0,FB.Series.Code(m.chainReaction,m.limit))
        elseif m.phase=="offer" then N.Whisper(m.chainReaction and "CHAINOFFER" or "OFFER",m.id,m.seed,m.automatic and 1 or 0)
        elseif m.phase=="accept" then N.Whisper("ACCEPT",m.id,"R1")
        elseif m.phase=="start" then
            if m.capable then N.Whisper("START",m.id,"R1") else N.Whisper("START",m.id) end
        end
        m.lastRetry=t
    end
end
