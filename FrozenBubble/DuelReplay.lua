-- A duel records what reached this client. A FIRE and a correcting STATE may
-- arrive between the same two simulation ticks, in either order.
local _,FB=...
local D={}
FB.DuelReplay=D

function D.Packet(match,fields)
    if match.recording then FB.Recordings.OnlineEvent(match,fields[2],table.concat(fields,"|",4)) end
end

function D.Result(m,correction)
    local rec=m.recording
    if not rec then return end
    -- END can correct a forfeit to a draw even after the next round starts.
    local events=rec.duel.events
    events[#events+1]={rec.frames,"result",m.result,correction}
    rec.frames=math.max(1,rec.frames)
    rec.duel.result=m.result
    local c=FB.Recordings.capture
    if c and c.online==m then c.hasInput=true end
end

function D.New(record,sound)
    local right=FB.Engine.New(nil,record.seed,"versus",record.chains,sound)
    local left=FB.PeerView.NewDuelBoard(record.seed,record.chains,sound)
    local duel={remote=left,chainReaction=record.chains,phase="playing",remoteSeq=0,remoteAttack=0}
    return {right=right,left=left,duel=duel,eventIndex=1,wins=record.wins and {record.wins[1],record.wins[2]}}
end

function D.Apply(play)
    local events=play.record.duel.events
    local event=events[play.eventIndex]
    while event and event[1]==play.frame do
        local kind,value=event[2],event[3]
        if kind=="localFire" then play.right:Shoot(tonumber(value))
        elseif kind=="chat" then FB.MatchChat.Display(play.left,event[4])
        elseif kind=="result" then
            play.duel.phase="done"
            play.right.status=value
            play.left.status=value=="won" and "lost" or value=="lost" and "won" or value
            if value=="aborted" then play.right.projectile=nil end
            if not event[4] then play.right.sound(value=="aborted" and "cancel" or "lose") end
            if play.wins then
                play.wins[1]=play.record.wins[1]+(value=="won" and 1 or 0)
                play.wins[2]=play.record.wins[2]+(value=="lost" and 1 or 0)
            end
        else
            local fields=FB.Split("1|"..kind.."||"..value)
            local t=play.frame*0.02
            if kind=="TURN" then FB.PeerView.Turn(play.duel,fields)
            elseif kind=="FIRE" then FB.PeerView.Fire(play.duel,fields,t)
            elseif kind=="STATE" then FB.PeerView.State(play.duel,fields,play.right,t) end
        end
        play.eventIndex=play.eventIndex+1
        event=events[play.eventIndex]
    end
end
