-- Seats keep their original indices, including players who left an earlier round.
local _,FB=...
local R={}
FB.ArenaReplay=R

function R.Header(m)
    local seats={}
    for i,name in ipairs(m.names) do
        local v=m.players[name]
        seats[i]={name=name,label=v.label,wins=v.wins,left=v.left}
    end
    return {seats=seats,me=m.me,round=m.round,limit=m.limit,events={}}
end

function R.New(record,sound)
    local h=record.arena
    local right=FB.Engine.New(nil,record.seed,"versus",record.chains,sound)
    right.launchY=362
    local room={arena=true,names={},players={},phase="playing",seed=record.seed,chainReaction=record.chains,
        me=h.me,round=h.round,limit=h.limit,mask=0,leftMask=0}
    for i,seat in ipairs(h.seats) do
        room.names[i]=seat.name
        room.players[seat.name]={name=seat.name,label=seat.label,index=i,wins=seat.wins,left=seat.left,lost=seat.left,
            remoteSeq=0,remoteAttack=0,chainReaction=record.chains}
        if seat.left then room.leftMask=room.leftMask+2^(i-1) end
    end
    room.mask=room.leftMask
    FB.Arena.BuildBoards(room,right.sound)
    return {right=right,arena=room,eventIndex=1}
end

function R.Apply(play)
    local room,events=play.arena,play.record.arena.events
    local e=events[play.eventIndex]
    while e and e[1]==play.frame do
        local kind,index=e[2],e[3]
        local name=room.names[index]
        local v=room.players[name]
        if kind=="ATURN" or kind=="AFIRE" or kind=="ARISE" or kind=="ASTATE" then
            local fields=FB.Split("1|"..kind.."||"..e[4])
            if kind=="ATURN" then FB.PeerView.Turn(v,fields)
            elseif kind=="AFIRE" then FB.PeerView.Fire(v,fields,play.frame*0.02)
            elseif kind=="ARISE" then FB.PeerView.Rise(v,fields)
            else
                FB.PeerView.State(v,fields,play.right,play.frame*0.02)
                v.target=room.names[e[5]]
            end
        elseif kind=="chat" and v then FB.MatchChat.Display(v.remote,e[4])
        elseif kind=="localFire" then play.right:Shoot(tonumber(index))
        elseif kind=="target" then room.target=name
        elseif kind=="left" then
            v.left=true; room.leftMask=room.leftMask+2^(index-1)
        elseif kind=="loss" then FB.Arena.ApplyLoss(room,v,play.right.sound)
        elseif kind=="closed" then room.closed=index
        elseif kind=="winner" then FB.Arena.ApplyWinner(room,index,play.right) end
        play.eventIndex=play.eventIndex+1
        e=events[play.eventIndex]
    end
end
