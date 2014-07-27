local InterruptBar = {}
InterruptBar.__index = InterruptBar

local is = Apollo.GetAddon("InterruptSync")
is.InterruptBar = InterruptBar

local knXCursorOffset = 10
local knYCursorOffset = 25

function InterruptBar:new(xmlDoc, playerName, interrupt, itemList)
	local self = setmetatable({}, { __index = InterruptBar })
	self.interrupt = interrupt
	self.playerName = playerName
	self.xmlDoc = xmlDoc
	
	local data = {
		interrupt = interrupt,
		playerName = playerName
	}
	
	self.wndInt = Apollo.LoadForm(xmlDoc, "InterruptBar", itemList, self)
	
	self.wndInt:FindChild("Icon"):SetSprite(interrupt.icon)
    self.wndInt:FindChild("ProgressOverlay"):SetMax(interrupt.cooldown)
    self.wndInt:FindChild("Text"):SetText(string.format("%s - %s", playerName, interrupt.name))
    self.wndInt:SetData(data)

	if self.interrupt.ia > 1 then
		self.wndInt:FindChild("CCArmorContainer"):FindChild("CCArmorValue"):SetText(self.interrupt.ia)
		self.wndInt:FindChild("CCArmorContainer"):Show(true)
	end
	
	return self
end

function InterruptBar:SetInterrupt(interrupt)
    self.wndInt:FindChild("ProgressOverlay"):SetProgress(interrupt.cooldownRemaining)
    self.interrupt = interrupt
    
	self.wndInt:FindChild("Text"):SetText(string.format("%s - %s", self.playerName, interrupt.name))

    if interrupt.cooldownRemaining ~= 0 then
        self.wndInt:FindChild("Timer"):SetText(string.format("%.1fs", interrupt.cooldownRemaining))
    else
        self.wndInt:FindChild("Timer"):SetText(string.format("%.1fs", interrupt.cooldown))
    end
end

function InterruptBar:TriggerUpdate()
	if self.wndInt and self.interrupt then
		local overlay = self.wndInt:FindChild("ProgressOverlay")
		local timer = self.wndInt:FindChild("Timer")
		if overlay and timer then
			overlay:SetProgress(self.interrupt.cooldownRemaining)
			timer:SetText(string.format("%.1fs", self.interrupt.cooldownRemaining))
		end
	end
end

function InterruptBar:OnBarButtonClick(wndHandler, wndControl, eMouseButton)
	Event_FireGenericEvent("SendVarToRover", "OnBarButtonClick_wndHandler", wndHandler)
	Event_FireGenericEvent("SendVarToRover", "OnBarButtonClick_wndControl", wndControl)
	--get group leader status here
	local leader = GroupLib.AmILeader()
	-------
	leader = true
	-------
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and leader then
		Print("Button_InterruptBar")
		self:ShowContextMenu(wndHandler)
	end
end

function InterruptBar:ShowContextMenu(wndHandler)
	if self.wndContext and self.wndContext:IsValid() then
		self.wndContext:Destroy()
		self.wndContext = nil
	end

	self.wndContext = Apollo.LoadForm(self.xmlDoc, "ContextMenuForm", nil, self)
	self.wndContext:Invoke()
	
	local tCursor = Apollo.GetMouse()
	self.wndContext:Move(tCursor.x - knXCursorOffset, tCursor.y - knYCursorOffset, self.wndContext:GetWidth(), self.wndContext:GetHeight())
	
	local wndButtonList = self.wndContext:FindChild("ButtonList")
	self:BuildButton(wndButtonList, "Btn_Group1", "Group 1")
	self:BuildButton(wndButtonList, "Btn_Group2", "Group 2")
	self:BuildButton(wndButtonList, "Btn_Group3", "Group 3")
	self:BuildButton(wndButtonList, "Btn_Group4", "Group 4")
	self:BuildButton(wndButtonList, "Btn_Group5", "Group 5")
	self:BuildButton(wndButtonList, "Btn_Default", "Default")
	
	self:ResizeAndRedrawContextMenu()
end

function InterruptBar:ResizeAndRedrawContextMenu()
	local wndButtonList = self.wndContext:FindChild("ButtonList")
	if next(wndButtonList:GetChildren()) == nil then
		self.wndContext:Destroy()
		self.wndContext= nil
		return
	end

	local nHeight = wndButtonList:ArrangeChildrenVert(0, function(a,b) return (a:GetData() < b:GetData()) end)
	local nLeft, nTop, nRight, nBottom = self.wndContext:GetAnchorOffsets()
	self.wndContext:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 20)
	
	self:CheckContextMenuBounds()
end

function InterruptBar:BuildButton(wndButtonList, eButtonType, strButtonText)
	local wndCurr = self:FactoryProduce(wndButtonList, "ContextButton", eButtonType)
	wndCurr:FindChild("ContextButtonText"):SetText(strButtonText)
	return wndCurr
end

function InterruptBar:FactoryProduce(wndParent, strFormName, tObject)
	local wndNew = wndParent:FindChildByUserData(tObject)
	if not wndNew then
		wndNew = Apollo.LoadForm(self.xmlDoc, strFormName, wndParent, self)
		wndNew:SetData(tObject)
	end
	return wndNew
end

function InterruptBar:CheckContextMenuBounds()
	local tMouse = Apollo.GetMouse()

	local nWidth =  self.wndContext:GetWidth()
	local nHeight = self.wndContext:GetHeight()

	local nMaxScreenWidth, nMaxScreenHeight = Apollo.GetScreenSize()
	local nNewX = nWidth + tMouse.x - knXCursorOffset
	local nNewY = nHeight + tMouse.y - knYCursorOffset

	local bSafeX = true
	local bSafeY = true

	if nNewX > nMaxScreenWidth then
		bSafeX = false
	end

	if nNewY > nMaxScreenHeight then
		bSafeY = false
	end

	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	if bSafeX == false then
		local nRightOffset = nNewX - nMaxScreenWidth
		nLeft = nLeft - nRightOffset
		nRight = nRight - nRightOffset
	end

	if bSafeY == false then
		nBottom = nTop + knYCursorOffset
		nTop = nBottom - nHeight
	end

	if bSafeX == false or bSafeY == false then
		self.wndContext:SetAnchorOffsets(nLeft, nTop, nRight, nBottom)
	end
end

function InterruptBar:OnContextMenuClosed(wndHandler, wndControl)
	Print("Closed")
	if self.wndContext and self.wndContext:IsValid() then
		local wndContext= self.wndContext
		self.wndContext= nil
		wndContext:Close()
		wndContext:Destroy()
	end
end

function InterruptBar:ProcessContextClick(eButtonType)
	if not self.wndContext or not self.wndContext:IsValid() then
		return
	end
	
	Event_FireGenericEvent("SendVarToRover", "ProcessContextClick_eButtonType", eButtonType)
	
	if eButtonType == "Btn_Group1" then
		self.interrupt.group = 1
	elseif eButtonType == "Btn_Group2" then
		self.interrupt.group = 2
	elseif eButtonType == "Btn_Group3" then
		self.interrupt.group = 3
	elseif eButtonType == "Btn_Group4" then
		self.interrupt.group = 4
	elseif eButtonType == "Btn_Group5" then
		self.interrupt.group = 5
	elseif eButtonType == "Btn_Default" then
		self.interrupt.group = 0
	end
	
	local msg = {
		playerName = self.playerName,
		interrupt = self.interrupt
	}
	
	Event_FireGenericEvent("InterruptSync_UpdateGrouping", msg)
end

function InterruptBar:OnContextButton(wndHandler, wndControl, eMouseButton)
	Print("Context Menu Button")
	self:ProcessContextClick(wndHandler:GetData())
	self:OnContextMenuClosed()
end
