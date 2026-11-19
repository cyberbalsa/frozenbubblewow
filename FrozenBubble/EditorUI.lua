-- Native 640 x 480 editor controls from Games::FrozenBubble::LevelEditor.
local _,FB=...
local U,A,E=FB.UI,FB.Animation,FB.Engine
local function image(parent,name,x,y,w,h,layer)
    return A.Image(parent,"Editor\\"..name,x,y,w,h,layer)
end

-- Render the variable-width SDL bitmap font on signs. Player-supplied names
-- outside its uppercase alphabet use the client's font at the same position.
local function sign(parent,x,y,width,text)
    local f=CreateFrame("Frame",nil,parent)
    f:SetSize(width,38); f:SetPoint("TOPLEFT",x,-y); f:EnableMouse(false)
    local fallback=text(f,"",0,3,16,width); fallback:SetJustifyH("CENTER")
    local glyphs={}
    function f:GetText() return self.fbSignValue or "" end
    function f:SetText(value)
        self.fbSignValue=value or ""
        value=self.fbSignValue:upper()
        local length=0
        for n=1,#value do
            local c=value:byte(n); local glyph=FB.EditorGlyphs[c==32 and 33 or c]
            if not glyph then
                for _,t in ipairs(glyphs) do t:Hide() end
                fallback:SetText(value); fallback:Show(); return
            end
            length=length+glyph[4]
        end
        fallback:Hide()
        local scale=math.min(1,width/math.max(1,length+6))
        local pos=math.floor((width-length*scale)/2); local used=0
        for n=1,#value do
            local c=value:byte(n); local glyph=FB.EditorGlyphs[c==32 and 33 or c]
            if c~=32 then
                used=used+1
                local t=glyphs[used]
                if not t then t=f:CreateTexture(nil,"ARTWORK"); t:SetTexture(FB.media.."Editor\\font.tga"); glyphs[used]=t end
                t:ClearAllPoints(); t:SetPoint("TOPLEFT",pos-glyph[3]*scale,-(1-scale)*12)
                t:SetSize((glyph[2]-glyph[1])*scale,38*scale)
                t:SetTexCoord(glyph[1]/1024,glyph[2]/1024,1/64,39/64); t:Show()
            end
            pos=pos+glyph[4]*scale
        end
        for i=used+1,#glyphs do glyphs[i]:Hide() end
    end
    return f
end

local function hit(parent,x,y,w,h,fn)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(w,h); b:SetPoint("TOPLEFT",x,-y)
    local glow=image(b,"hover",0,0,w,h,"HIGHLIGHT")
    glow:SetTexCoord(0,math.min(w,218)/256,0,math.min(h,138)/256); glow:SetAlpha(68/255)
    b:SetScript("OnClick",function() if not InCombatLockdown() then fn() end end)
    return b
end

function U:BuildEditor(text,button,input,fill)
    local p=self.panels.editor
    p:ClearAllPoints(); p:SetScale(1.6); p:SetSize(640,480); p:SetPoint("TOPLEFT",self.frame,"TOPLEFT")
    p:EnableMouse(false); p:SetPropagateKeyboardInput(true)
    p:SetScript("OnKeyDown",function(panel,key) self:EditorKey(panel,key) end)
    p:SetScript("OnKeyUp",function(_,key) self.keys[key]=nil end)
    self.editorHeading=sign(p,133,421,100,text)
    self.levelTitle=sign(p,215,7,198,text)
    self.editorPalette={}
    for i=1,9 do
        local color=i%9
        local x,y=18+(i-1)%3*40,73+math.floor((i-1)/3)*40
        local b=hit(p,x-3,y-3,38,38,function() self:SelectEditorColor(color) end)
        local icon=b:CreateTexture(nil,"ARTWORK"); icon:SetSize(32,32); icon:SetPoint("TOPLEFT",3,-3)
        if color==0 then A.Frame(icon,"stick",7) end
        self.editorPalette[i]={icon=icon,button=b}
    end
    self.brushSample=p:CreateTexture(nil,"ARTWORK"); self.brushSample:SetSize(32,32); self.brushSample:SetPoint("TOPLEFT",302,-440)
    self.editorPreview=self.board:CreateTexture(nil,"OVERLAY",nil,4); self.editorPreview:Hide()
    self:SelectEditorColor(1)
    self.editorNav={}
    for i,command in ipairs({"prev","next","first","last"}) do
        local action=command
        self.editorNav[action]=hit(p,2,209+40*i,150,40,function() self:EditorAction(action) end)
    end
    for i,command in ipairs({"new","open","save","delete"}) do
        local action=command
        hit(p,488,30+40*i,150,40,function()
            if action=="save" then self:SaveEditor() else self:EditorDialog(action) end
        end)
    end
    for i,command in ipairs({"insert","append","remove"}) do
        local action=command
        hit(p,488,249+i*40,150,40,function() self:EditorAction(action) end)
    end
    hit(p,488,428,150,40,function() self:EditorDialog("help") end)
    hit(p,215,0,195,40,function() self:EditorDialog("rename") end)
    hit(p,122,408,120,54,function() self:EditorDialog("jump") end)
    hit(p,15,414,100,61,function() self:ExitEditor() end)
    button(p,"Tools",370,438,76,function() self:EditorDialog("tools") end)
    self.editorStatus=text(p,"",191,332,13,254); self.editorStatus:SetJustifyH("CENTER")
    self.editorStatus:SetFont("Fonts\\ARIALN.TTF",13,"OUTLINE")
    self:BuildEditorText(text,button,fill)

    -- The full-size shield keeps brush strokes and window shortcuts behind a
    -- dialog from seeing its clicks. The wood panel retains its native size.
    local shield=CreateFrame("Frame",nil,p); self.editorShield=shield
    shield:SetAllPoints(); shield:SetFrameLevel(self.layers.panel+5); shield:EnableMouse(true); shield:Hide()
    local d=CreateFrame("Frame",nil,shield); d:SetSize(341,280); d:SetPoint("CENTER")
    A.Image(d,"panel",0,0,341,280,"BACKGROUND")
    self.editorHelp=image(d,"help",0,0,nil,nil,"BORDER")
    self.dialogSign=sign(d,10,5,321,text)
    self.dialogMessage=text(d,"",23,69,16,295); self.dialogMessage:SetJustifyH("CENTER")
    self.dialogValue=input(d,41,115,259,""); self.dialogValue:SetMaxLetters(36)
    self.dialogValue:SetScript("OnEnterPressed",function() self:AcceptEditorDialog() end)
    self.dialogValue:SetScript("OnEscapePressed",function() self:CloseEditorDialog() end)
    self.editorOK=button(d,"OK",21,239,107,function() self:AcceptEditorDialog() end)
    self.editorBack=button(d,"Cancel",212,239,107,function() self:CloseEditorDialog() end)
    self.editorTools=CreateFrame("Frame",nil,d); self.editorTools:SetAllPoints()
    local options={
        {"Test board",function() self:TestEditor() end},
        {"Publish set",function() local id=self:SaveEditor(); if id then FB.Community.Publish(id,FB.Community.state~="ready") end end},
        {"Undo",function() self:UndoEditor() end},
        {"Clear board",function() if next(self.editGame.grid) then self:RememberEditor(); self.editGame.grid={} end end},
        {"Move left",function() self:EditorAction("left") end},{"Move right",function() self:EditorAction("right") end},
        {"Import",function() self:OpenEditorText(false) end},{"Export",function() self:OpenEditorText(true) end},
        {"Community levels",function() self:BrowseCommunity() end},
        {"Main menu",function() self:ExitEditor() end}
    }
    for i,option in ipairs(options) do
        local action=option[2]
        button(self.editorTools,option[1],18+(i-1)%2*155,47+math.floor((i-1)/2)*35,148,
            function() self:CloseEditorDialog(); action() end)
    end
    self:BuildEditorBrowser(d,text)

    local prompt=self.panels.editorPrompt
    text(prompt,"Save your changes before opening another set?",0,54,20,340)
    local function proceed(save)
        local t=self.pendingEditor
        if not t then return end
        self.pendingEditor=nil
        if save and not self:SaveEditor() then self:Panel("editor"); return end
        self:StartEditor(t.id,t.fresh,t.index,true,t.title)
    end
    button(prompt,"Save and open",0,150,150,function() proceed(true) end)
    button(prompt,"Discard edits",165,150,150,function() proceed(false) end)
    button(prompt,"Keep editing",75,206,165,function() self.pendingEditor=nil; self:Panel("editor") end)
end

function U:SelectEditorColor(color)
    self.editorColor=color
    for i=1,8 do FB.SetBubbleTexture(self.editorPalette[i].icon,i) end
    if color>0 then FB.SetBubbleTexture(self.brushSample,color) end
    self.brushSample:SetShown(color>0); self.editorDirty=true
end

function U:BuildEditorBrowser(d,text)
    local b=CreateFrame("Frame",nil,d); b:SetSize(322,120); b:SetPoint("TOPLEFT",9,-77); self.editorBrowser=b
    image(b,"files",0,0); image(b,"scroll",217,0)
    b:EnableMouseWheel(true); b:SetScript("OnMouseWheel",function(_,delta) self:BrowseEditorSet(-delta) end)
    self.editorRows={}
    for i=1,4 do
        local line=i
        local row=hit(b,3,10+25*(i-1),212,23,function() self:BrowseEditorSet(self.fileOffset+line-self.fileIndex) end)
        local highlight=image(row,"selected",0,0,nil,nil,"BACKGROUND")
        local label=text(row,"",5,3,15,201)
        self.editorRows[i]={row=row,highlight=highlight,label=label}
    end
    for i,kind in ipairs({"up","down"}) do
        local step=i==1 and -1 or 1
        local arrow=hit(b,220,i==1 and 2 or 97,15,21,function() self:BrowseEditorSet(step) end)
        image(arrow,kind,0,0)
    end
    local preview=CreateFrame("Frame",nil,b); self.filePreview=preview
    preview:SetSize(84,117); preview:SetPoint("TOPLEFT",236,-2)
    local bg=A.Image(preview,"editor-background",0,0,84,117,"BACKGROUND")
    bg:SetTexCoord(148/1024,484/1024,0,468/512)
    self.fileBubbles={}
    for row=1,10 do for col=1,E.Columns(row) do
        local x,y=E.Position(row,col)
        local t=preview:CreateTexture(nil,"ARTWORK"); t:SetSize(8,8)
        t:SetPoint("CENTER",preview,"TOPLEFT",(190-148+x)/4,-(44+y)/4)
        self.fileBubbles[E.Key(row,col)]=t
    end end
end

function U:BrowseEditorSet(delta)
    local files=self.editorFiles
    self.fileIndex=math.max(1,math.min(#files,self.fileIndex+delta))
    self.fileOffset=math.max(0,self.fileIndex-4,math.min(self.fileOffset,self.fileIndex-1))
    local selected=files[self.fileIndex]
    for i,r in ipairs(self.editorRows) do
        local file=files[self.fileOffset+i]
        r.row:SetShown(file~=nil); r.label:SetText(file and file.title or "")
        r.highlight:SetShown(file and file==selected or false)
    end
    self.filePreview:SetShown(selected~=nil); self.editorOK:SetEnabled(selected~=nil)
    local grid=selected and E.Unpack(selected.boards[1])
    for key,t in pairs(self.fileBubbles) do
        if grid and grid[key] then FB.SetBubbleTexture(t,grid[key]); t:Show() else t:Hide() end
    end
    self.dialogMessage:SetText(not selected and "No saved sets to delete." or "")
end

local titles={help="HELP - KEY SHORTCUTS", tools="EDITOR TOOLS", jump="JUMP TO LEVEL", rename="LEVELSET NAME",
    new="NEW LEVELSET",open="OPEN LEVELSET",delete="DELETE LEVELSET",confirm="DELETE LEVELSET?",quit="SAVE CHANGES?"}
function U:EditorDialog(kind)
    self.editorDialog=kind; self.stroke=nil; self.editorPreview:Hide()
    self.dialogValue:ClearFocus()
    self.editorShield:Show(); self.editorHelp:SetShown(kind=="help"); self.editorTools:SetShown(kind=="tools")
    self.dialogSign:SetText(titles[kind]); self.dialogMessage:SetText("")
    local entry=kind=="new" or kind=="rename" or kind=="jump"
    local browser=kind=="open" or kind=="delete"
    self.dialogValue:SetShown(entry); self.editorBrowser:SetShown(browser)
    self.editorOK:ClearAllPoints(); self.editorOK:SetPoint("TOPLEFT",kind=="help" and 212 or 21,-239)
    self.editorOK:SetEnabled(true); self.editorOK:SetShown(kind~="tools")
    self.editorOK:SetText(kind=="confirm" and "Delete" or kind=="quit" and "Save and exit" or "OK")
    self.editorBack:SetText(kind=="quit" and "Keep draft & exit" or kind=="tools" and "Back" or "Cancel")
    self.editorBack:SetShown(kind~="help")
    self.editorBack:SetScript("OnClick",function()
        if InCombatLockdown() then return end
        self:CloseEditorDialog()
        if kind=="quit" then self:StoreEditorDraft(); self:ShowMenu() end
    end)
    if entry then
        self.dialogValue:SetText(kind=="jump" and tostring(self.editIndex) or kind=="rename" and self.levelTitle:GetText() or "")
        self.dialogValue:SetFocus(); self.dialogValue:HighlightText()
        if kind=="jump" then self.dialogMessage:SetText("Choose a board from 1 to "..#self.editBoards..".") end
    elseif browser then
        local files={}
        if kind=="open" then files[1]={id="default-levelset",title="default-levelset",boards=self:DefaultEditorBoards()} end
        for id,item in pairs(FB.db.custom) do files[#files+1]={id=id,title=item.title,boards=FB.Community.Boards(item)} end
        table.sort(files,function(a,b)
            if a.title==b.title then return a.id<b.id end
            return a.title<b.title
        end)
        self.editorFiles,self.fileIndex,self.fileOffset=files,1,0
        self:BrowseEditorSet(0)
    elseif kind=="confirm" then self.dialogMessage:SetText(self.deleteFile.title)
    elseif kind=="quit" then self.dialogMessage:SetText("Save this set to your library? Escape keeps the editor open.") end
end
function U:CloseEditorDialog()
    self.editorDialog=nil; self.dialogValue:ClearFocus(); self.editorShield:Hide()
end
function U:ExitEditor()
    if self:EditorModified() then self:EditorDialog("quit")
    else self:StoreEditorDraft(); self:ShowMenu() end
end
function U:AcceptEditorDialog()
    if InCombatLockdown() then return end
    local kind=self.editorDialog
    local value=self.dialogValue:GetText()
    if kind=="jump" then
        local n=FB.Integer(value,1,#self.editBoards)
        if not n then self.dialogMessage:SetText("Enter a board number from 1 to "..#self.editBoards.."."); return end
        self:EditorBoards(); self:SelectEditorBoard(n)
    elseif kind=="new" or kind=="rename" then
        value=FB.Community.CleanTitle(value):match("^%s*(.-)%s*$")
        if value=="" then self.dialogMessage:SetText("Enter a name for this set."); return end
        if kind=="rename" then self.levelTitle:SetText(value)
        else self:CloseEditorDialog(); self:StartEditor(nil,true,nil,false,value); return end
    elseif kind=="open" or kind=="delete" then
        local file=self.editorFiles[self.fileIndex]
        if not file then return end
        if kind=="delete" then self.deleteFile=file; self:EditorDialog("confirm"); return end
        self:CloseEditorDialog(); self:StartEditor(file.id,false,1); return
    elseif kind=="confirm" then
        FB.db.custom[self.deleteFile.id]=nil
        if self.editID==self.deleteFile.id then self.editID=nil; self:StoreEditorDraft() end
        self.editorStatus:SetText("Deleted from your library."); self.deleteFile=nil
    elseif kind=="quit" then
        if not self:SaveEditor() then self:CloseEditorDialog(); return end
        self:ShowMenu()
    end
    self:CloseEditorDialog()
end

local nav={LEFT="prev",H="prev",P="prev",RIGHT="next",L="next",N="next",UP="first",DOWN="last",
    A="append",I="insert",D="remove",["["]="left",["]"]="right",LEFTBRACKET="left",RIGHTBRACKET="right"}
function U:EditorKey(panel,key)
    if InCombatLockdown() then return end
    local active=self.screen=="editor" and not self.inactive and self:HasFocus() and
        not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
    local kind=self.editorDialog
    local color=FB.Integer(key,0,8)
    local used
    if kind then used=key=="ESCAPE" or key=="ENTER" or key=="NUMPADENTER" or
        (kind=="open" or kind=="delete") and (key=="UP" or key=="DOWN")
    else used=color or nav[key] or key=="F" or key=="Q" or key=="ESCAPE" or key=="S" or key=="O" or key=="F1" or key=="J" or
        key=="Z" and IsControlKeyDown and IsControlKeyDown() end
    panel:SetPropagateKeyboardInput(not (active and used))
    if not active or not used or self.keys[key] then return end
    self.keys[key]=true
    if kind then
        if key=="ESCAPE" then self:CloseEditorDialog()
        elseif key=="UP" or key=="DOWN" then self:BrowseEditorSet(key=="UP" and -1 or 1)
        else self:AcceptEditorDialog() end
    elseif color then self:SelectEditorColor(color)
    elseif nav[key] then self:EditorAction(nav[key])
    elseif key=="S" then self:SaveEditor()
    elseif key=="F" then self:ToggleFullWindow()
    elseif key=="Z" then self:UndoEditor()
    elseif key=="Q" or key=="ESCAPE" then self:ExitEditor()
    else self:EditorDialog(key=="F1" and "help" or key=="J" and "jump" or "open") end
end
