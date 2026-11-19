-- Compare each displayed campaign frame with tools/demos/reference_campaign.pl.
return function(FB,eq)
    local expected=dofile("tests/reference_campaign.lua")
    for level,checksum in ipairs(expected) do
        local keys,actions,sounds={},{},{}
        local ticks=level==17 and 160 or level==1 and 1600 or 845
        local seed=level==17 and 4 or level*7
        local function action(tick,key,value)
            actions[tick]=actions[tick] or {}
            actions[tick][key]=value
        end
        if level==17 then
            action(1,"left",true); action(19,"left",false); action(19,"fire",true)
        else
            local turns={7,41,10,30,17,40,32,19}
            for shot=1,math.ceil(ticks/55) do
                local start=1+(shot-1)*55
                local direction=shot%2==1 and "right" or "left"
                local fire=start+1+turns[shot%#turns+1]
                action(start,"center",true); action(start+1,"center",false)
                action(start+1,direction,true); action(fire,direction,false); action(fire,"fire",true)
            end
        end
        local game=FB.Engine.New(FB.Levels[level],seed,"campaign",false,function(s) sounds[#sounds+1]=s end,true)
        local function input(g,t)
            FB.Controls.Aim(g,keys.left,keys.right,keys.center,0.03)
            if keys.fire and g:Shoot(nil,t) then keys.fire=false end
        end
        -- SDL reports sprite top-lefts. The addon simulates bubble centers.
        local function sprite(b)
            return table.concat({b.color,math.floor(b.x+174),math.floor(b.y+28)},",")
        end
        local hash=0
        for tick=1,ticks do
            for key,value in pairs(actions[tick] or {}) do keys[key]=value end
            game:Step(0.02,input)
            local cells={}
            for k=1,112 do cells[k]=0 end
            local drop=math.floor(game.ceiling/28)
            for k,color in pairs(game.grid) do
                if not (game.endCells and game.endCells[k]) then cells[k+8*drop]=color end
            end
            local falling={}
            for _,b in ipairs(game.effects) do
                if b.kind=="fall" then falling[#falling+1]=sprite(b) end
            end
            table.sort(falling)
            local lost=game.status=="lost"
            local row=table.concat({tick,game.status,table.concat(cells),drop,game.lockedShots%game.rootPeriod,
                game.projectile and sprite(game.projectile) or "-",table.concat(falling,";"),
                lost and 0 or game.current,lost and 0 or game.next,table.concat(sounds,",")},"|").."\n"
            for i=1,#row do hash=(hash*131+row:byte(i))%2147483647 end
            sounds={}
        end
        eq(hash,checksum,"campaign level "..level)
    end
    eq(#expected,100)
end
