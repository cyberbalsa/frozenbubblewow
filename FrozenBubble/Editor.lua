-- Ordered level-set drafts and import/export for the in-game editor.
local _,FB=...
local U,E=FB.UI,FB.Engine
function U:BuildEditorText(text,button,fill)
    local p=self.panels.editorText
    p:ClearAllPoints(); p:SetPoint("CENTER",self.frame,"CENTER"); p:SetSize(520,368)
    FB.Animation.Image(p,"panel",0,0,520,368,"BACKGROUND")
    self.codeHeading=text(p,"",24,22,18,470)
    local scroll=CreateFrame("ScrollFrame",nil,p)
    scroll:SetSize(464,211); scroll:SetPoint("TOPLEFT",28,-62); scroll:EnableMouseWheel(true)
    fill(scroll,0.08,0.05,0.05,0.9)
    local box=CreateFrame("EditBox",nil,scroll)
    box:SetMultiLine(true); box:SetAutoFocus(false); box:SetWidth(458); box:SetMaxBytes(65535)
    box:SetFont("Fonts\\ARIALN.TTF",16,""); box:SetTextColor(1,1,1); box:SetTextInsets(6,6,4,4)
    scroll:SetScrollChild(box); scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown",function() box:SetFocus() end)
    scroll:SetScript("OnMouseWheel",function(f,step)
        f:SetVerticalScroll(FB.Clamp(f:GetVerticalScroll()-step*38,0,f:GetVerticalScrollRange()))
    end)
    box:SetScript("OnCursorChanged",function(_,x,y,w,h)
        local offset=scroll:GetVerticalScroll()
        if -y<offset then scroll:SetVerticalScroll(-y)
        elseif -y+h>offset+scroll:GetHeight() then scroll:SetVerticalScroll(-y+h-scroll:GetHeight()) end
    end)
    local function back()
        box:ClearFocus()
        if self.importingRecording then FB.Recordings.Library() else self:Panel("editor") end
    end
    box:SetScript("OnEscapePressed",back)
    p:SetScript("OnHide",function() box:ClearFocus(); self.importingRecording=nil end)
    self.codeNotice=text(p,"",28,282,14,465)
    self.codeFormat=button(p,"WoW code",24,309,125,function()
        self.fileExport=not self.fileExport; self:FillEditorText()
    end)
    self.codeImport=button(p,"Import",24,309,125,function()
        if self.importingRecording then
            local record,err=FB.Recordings.Import(box:GetText())
            if record then FB.Recordings.Library() else self.codeNotice:SetText(err) end
        elseif self:ImportEditor(box:GetText()) then self:Panel("editor")
        else self.codeNotice:SetText("Invalid layout. Check the row widths and bubble colors.") end
    end)
    button(p,"Back",364,309,124,back)
    self.levelCode=box
end
function U:FillEditorText()
    local boards=self:EditorBoards()
    self.levelCode:SetText(self.fileExport and FB.Community.LevelText(boards) or FB.Community.Code(boards))
    self.codeHeading:SetText(self.fileExport and "Export Frozen Bubble level file" or "Export WoW level code")
    self.codeFormat:SetText(self.fileExport and "WoW code" or "Level file")
    self.levelCode:SetFocus(); self.levelCode:HighlightText()
end
function U:OpenEditorText(export)
    self.importingRecording=nil; self.levelCode:SetMaxBytes(65535)
    self:Panel("editorText")
    self.codeFormat:SetShown(export); self.codeImport:SetShown(not export)
    if export then
        self.fileExport=true; self.codeNotice:SetText("Copy the selected text."); self:FillEditorText()
    else
        self.codeHeading:SetText("Import boards")
        self.codeNotice:SetText("Paste a Frozen Bubble level file or a WoW code.")
        self.levelCode:SetText(""); self.levelCode:SetFocus()
    end
end
local blankBoard=FB.Community.blankBoard
local originals
function U:DefaultEditorBoards()
    if not originals then
        originals={}
        for i,rows in ipairs(FB.Levels) do
            local data=table.concat(rows):gsub("%.","0")
            originals[i]=data..string.rep("0",98-#data)
        end
    end
    return originals
end
function U:EditorBoards()
    self.editBoards[self.editIndex]=self.editGame:Pack()
    return self.editBoards
end
function U:SelectEditorBoard(index)
    self.editIndex=index
    self.editGame.grid=E.Unpack(self.editBoards[index])
    self.editorHeading:SetText(index.."/"..#self.editBoards)
    self.editorNav.prev:SetEnabled(index>1); self.editorNav.first:SetEnabled(index>1)
    self.editorNav.next:SetEnabled(index<#self.editBoards); self.editorNav.last:SetEnabled(index<#self.editBoards)
    self.levelCode:SetText(""); self.stroke=nil; self.editorDirty=true
end
function U:StoreEditorDraft()
    if self.editGame then
        FB.db.editorDraft={boards={unpack(self:EditorBoards())},index=self.editIndex,title=self.levelTitle:GetText(),id=self.editID}
    end
end
function U:StartEditor(id,fresh,index,confirmed,title,reload)
    if not FB.CanStart() then return end
    local draft=not self.editGame and FB.db.editorDraft
    if type(draft)=="table" and type(draft.boards)=="table" and #draft.boards>=1 and #draft.boards<=FB.Community.maxBoards then
        local valid=true
        for _,data in ipairs(draft.boards) do if not E.Unpack(data) then valid=false; break end end
        if valid then
            self.editGame=E.New({},1,"custom"); self.editID=draft.id; self.editBoards={unpack(draft.boards)}
            self.editorHistory={}; self.levelTitle:SetText(draft.title or "My set")
            self:SelectEditorBoard(FB.Integer(draft.index,1,#self.editBoards) or 1)
        end
    end
    local replace=fresh or reload or id and self.editID~=id
    if FB.game then FB.game.paused=true end
    if replace and self.editGame and not confirmed and self:EditorModified() then
        self:Panel("editor"); self.frame:Show()
        self.pendingEditor={id=id,fresh=fresh,index=index,title=title,reload=reload}
        self:EditorDialog("saveChanges"); return
    end
    if not self.editGame or replace then
        if not fresh and not id then id="default-levelset" end
        local stock=id=="default-levelset"
        local item=id and FB.db.custom[id]
        self.editGame=E.New({},1,"custom"); self.editorHistory={}; self.editID=(stock or item) and id
        self.editBoards=stock and {unpack(self:DefaultEditorBoards())} or item and {unpack(FB.Community.Boards(item))} or {blankBoard}
        self.levelTitle:SetText(stock and "default-levelset" or item and item.title or title or "My set")
        self:SelectEditorBoard(FB.Integer(index,1,#self.editBoards) or 1)
        self.editorStatus:SetText("")
    elseif index and index~=self.editIndex and self.editBoards[index] then
        self:EditorBoards(); self:SelectEditorBoard(index)
    end
    self:Panel("editor"); self.frame:Show()
end
function U:FinishEditorSwitch(save)
    local target=self.pendingEditor
    self:CloseEditorDialog()
    if not target then return end
    if save then
        local id=self:SaveEditor()
        if not id then return end
        if target.reload and target.id~="default-levelset" and not FB.db.custom[target.id] then target.id=id end
    end
    self:StartEditor(target.id,target.fresh,target.index,true,target.title,target.reload)
end
function U:EditorModified()
    local item=self.editID and FB.db.custom[self.editID]
    local boards=self:EditorBoards()
    if self.editID=="default-levelset" then
        return self.levelTitle:GetText()~="default-levelset" or table.concat(boards)~=table.concat(self:DefaultEditorBoards())
    end
    if not item then return #boards>1 or boards[1]~=blankBoard or self.levelTitle:GetText()~="My set" end
    return item.title~=self.levelTitle:GetText() or FB.Community.Code(boards)~=FB.Community.Code(FB.Community.Boards(item))
end
function U:RememberEditor()
    local history=self.editorHistory
    history[#history+1]={boards={unpack(self:EditorBoards())},index=self.editIndex}
    if #history>32 then table.remove(history,1) end
    self.editorDirty=true; self.editorStatus:SetText("")
end
function U:UndoEditor()
    local previous=table.remove(self.editorHistory)
    if previous then self.editBoards=previous.boards; self:SelectEditorBoard(previous.index) end
end
function U:EditorAction(action)
    local boards=self:EditorBoards()
    local i,n=self.editIndex,#boards
    if action=="prev" then i=math.max(1,i-1)
    elseif action=="next" then i=math.min(n,i+1)
    elseif action=="first" then i=1
    elseif action=="last" then i=n
    elseif action=="insert" or action=="append" then
        if n>=FB.Community.maxBoards then self.editorStatus:SetText("This set already has 100 boards."); return end
        self:RememberEditor()
        if action=="append" then i=i+1 end
        table.insert(boards,i,blankBoard)
    elseif action=="left" or action=="right" then
        local target=i+(action=="left" and -1 or 1)
        if target<1 or target>n then return end
        self:RememberEditor(); boards[i],boards[target]=boards[target],boards[i]; i=target
    elseif action=="remove" then
        self:RememberEditor(); table.remove(boards,i)
        if #boards==0 then boards[1]=blankBoard end
        i=math.min(i,#boards)
    else return end
    self:SelectEditorBoard(i)
end
function U:ImportEditor(code)
    local boards=FB.Community.Decode(code)
    if not boards then self.editorStatus:SetText("Invalid code. Use colors 1–8 and 0 for empty spaces in the WoW code."); return end
    self:RememberEditor()
    if #boards==1 then self.editBoards[self.editIndex]=boards[1]; self:SelectEditorBoard(self.editIndex)
    else self.editBoards=boards; self:SelectEditorBoard(1) end
    self.levelCode:ClearFocus(); return true
end
function U:TestEditor()
    local data=self.editGame:Pack()
    if not FB.Community.Validate(data) then
        self.editorStatus:SetText("Add at least one bubble within the ten editable rows."); return
    end
    FB.StartCustomBoard({boards={data},title=self.levelTitle:GetText(),draftIndex=self.editIndex},1)
end
function U:SaveEditor()
    local id,err=FB.Community.SaveSet(self.levelTitle:GetText(),self:EditorBoards(),nil,self.editID)
    if id then
        local item=FB.db.custom[id]
        self.editID=id; self.levelTitle:SetText(item.title); self:StoreEditorDraft()
        self.editorStatus:SetText(item.emptyBoard and ("Draft saved. Board "..item.emptyBoard.." is empty.") or "Saved to your library.")
    else self.editorStatus:SetText(err) end
    return id
end
