local InterruptContainer = {}
InterruptContainer.__index = InterruptContainer

local is = Apollo.GetAddon("InterruptSync")
is.InterruptContainer = InterruptContainer

local g_GroupCount = 5
local g_HeaderPaddding = 15

function InterruptContainer:new(xmlDoc, rover, interruptbar, mainWindow)
	local self = setmetatable({}, InterruptContainer)
	
	self.itemList = mainWindow:FindChild("ItemList")
	self.mainWindow = mainWindow
	self.xmlDoc = xmlDoc
	self.rover = rover
	self.InterruptBar = interruptbar
	self.players = {}
	self.groupContainers = {}
	
	for i=1,g_GroupCount do
		local name = string.format("Group %d", i)
		self.groupContainers[i] = self:CreateGroupContainer(name)
		self.groupContainers[i]:Show(false, true)
	end
	
	if self.rover then
		self.rover:AddWatch("InterruptContainer.self", self)
	end
	
	return self
end

function InterruptContainer:CreateGroupContainer(name)
	local wndContainer = Apollo.LoadForm(self.xmlDoc, "GroupBarContainer", self.itemList, self)
	wndContainer:FindChild("GroupHeader"):FindChild("Text"):SetText(name)
	local tData = {
		name = name,
		type = "GroupBarContainer"
	}
	wndContainer:SetData(tData)
	return wndContainer
end

function InterruptContainer:CreateBar(playerName, interrupt)
	local container = self.itemList
	if interrupt.group and interrupt.group > 0 then
		container = self.groupContainers[interrupt.group]:FindChild("ItemList")
		self.groupContainers[interrupt.group]:Show(true, true)
	end
	local wndBar = self.InterruptBar:new(self.xmlDoc, playerName, interrupt, container)
	return wndBar
end

function InterruptContainer:HandleInterrupt(msg)
	local playerName = msg.playerName
	local interrupt = msg.interrupt
	local player = self.players[playerName]
	if player == nil then
		player = {}
		self.players[playerName] = player
	end
	local interruptBar = player[interrupt.name]
	if interruptBar == nil then
		--interruptBar = self.InterruptBar:new(self.xmlDoc, playerName, interrupt, self.itemList)
		interruptBar = self:CreateBar(playerName, interrupt)
		player[interrupt.name] = interruptBar
	end
	interruptBar:SetInterrupt(interrupt)
	self:UpdateGroupBarVisibility()
	self:ArrangeBars()
	self:ResizeWindow()
end

function InterruptContainer:HandleLas(msg)
	local playerName = msg.playerName
	local player = self.players[playerName]
	if player == nil then
		player = {}
		self.players[playerName] = player
	else
	-- on LAS update delete all bars of player
		for _, interruptBar in pairs(player) do
			interruptBar.wndInt:Destroy()
			self:ArrangeBars()
		end
	end
	-- Add the new bars
	for _, interrupt in pairs(msg.interrupts) do
		--local bar = self.InterruptBar:new(self.xmlDoc, playerName, interrupt, self.itemList)
		local bar = self:CreateBar(playerName, interrupt)
		player[interrupt.name] = bar
		bar:SetInterrupt(interrupt)
		self:UpdateGroupBarVisibility()
		self:ArrangeBars()
	end
	self:ResizeWindow()
end

function InterruptContainer:HandleGrouping(msg)
	--iterate through all the players
	Event_FireGenericEvent("SendVarToRover", "HandleGrouping_msg", msg)
	for playerName, player in pairs(msg.players) do
		for interruptName, interrupt in pairs(player) do
			local int = interrupt.interrupt
			local group = 0
			if int.group then
				group = int.group
			end
			self:UpdateBarGrouping(playerName, interruptName, group)
		end
	end
	
	self:UpdateGroupBarVisibility()
	self:ArrangeBars()
	self:ResizeWindow()
end

function InterruptContainer:UpdateBarGrouping(playerName, interruptName, grouping)
	local player = self.players[playerName]
	if player == nil then
		return
	end
	local bar = player[interruptName]
	if bar == nil then
		return
	end
	local interrupt = bar.interrupt
	interrupt.group = grouping
	bar.wndInt:Destroy()
	bar = nil
	bar = self:CreateBar(playerName, interrupt)
	player[interruptName] = bar
	bar:SetInterrupt(interrupt)
end

function InterruptContainer:CreateGroupingMessage()
	msg = {}
	msg.players = self.players
	return msg
end

function InterruptContainer:HandleGroupingUpdate(msg)
	local playerName = msg.playerName
	local interrupt = msg.interrupt
	local player = self.players[playerName]
	if player == nil then
		return
	end
	local bar = player[interrupt.name]
	if bar == nil then
		return
	end
	bar.wndInt:Destroy()
	bar = nil
	bar = self:CreateBar(playerName, interrupt)
	player[interrupt.name] = bar
	bar:SetInterrupt(interrupt)
	
	self:UpdateGroupBarVisibility()
	
	self:ArrangeBars()
	self:ResizeWindow()
end

function InterruptContainer:UpdateGroupBarVisibility()
	for _, group in pairs(self.groupContainers) do
		local itemList = group:FindChild("ItemList")
		local childrenCount = #itemList:GetChildren()
		if childrenCount == 0 then
			group:Show(false, true)
		end
	end
end

function InterruptContainer:HandleTimerUpdate(timerValue)
	for _, player in pairs(self.players) do
		for _, bar in pairs(player) do
			if bar.interrupt.cooldownRemaining > 0 then
				bar.interrupt.cooldownRemaining = bar.interrupt.cooldownRemaining - timerValue
				bar:TriggerUpdate()
				self:ArrangeBars()
			end
		end
	end
end

function InterruptContainer:HandleGroupUpdate(group)
	for playerName, interrupts in pairs(self.players) do
		if not group[playerName] then
			for _, interrupt in pairs(interrupts) do
				interrupt.wndInt:Destroy()
				interrupt.wndInt = nil
				self:ArrangeBars()
			end
			self.players[playerName] = nil
		end
	end
	self:ResizeWindow()
end

local SortByName = function(item1, item2)
	local int1 = item1:GetData()
	local int2 = item2:GetData()
	if int1.type == "GroupBarContainer" and int2.type == "GroupBarContainer" then
		return int1.name < int2.name
	elseif int1.type == "GroupBarContainer" then
		return true
	elseif int2.type == "GroupBarContainer" then
		return false 
	end
	if int1 and int2 then	
		return int1.playerName < int2.playerName
	else
		return 0
	end
end

function InterruptContainer:ArrangeBarsInGroups()
	for _, group in pairs(self.groupContainers) do
		local itemList = group:FindChild("ItemList")
		itemList:ArrangeChildrenVert(0, SortByName)
	end
end

function InterruptContainer:ArrangeBars()
	self:ArrangeBarsInGroups()
	self.itemList:ArrangeChildrenVert(0, SortByName)
end

function InterruptContainer:ResizeGroupContainer()
	for _, group in pairs(self.groupContainers) do
		local left, top, right, bottom = group:GetAnchorOffsets()
		local itemList = group:FindChild("ItemList")
		local childrenCount = #itemList:GetChildren()
		local newHeight = 0 
		if childrenCount > 0 then
			newHeight = top
		end
						
		newHeight = newHeight + g_HeaderPaddding
		for _, child in pairs(itemList:GetChildren()) do		
			if child:IsVisible() then
				local childHeight = child:GetHeight()
				newHeight = newHeight + childHeight 
			end
		end
		group:SetAnchorOffsets(left, top, right, newHeight)
	end
end

function InterruptContainer:ResizeWindow()
	self:ResizeGroupContainer()

	local left, top, right, bottom = self.mainWindow:GetAnchorOffsets()
	local childrenCount = #self.itemList:GetChildren()
	local newHeight = 0
	if childrenCount > 0 then
		newHeight = top
	end
	
	for _, child in pairs(self.itemList:GetChildren()) do
		if child:IsVisible() then
			local childHeight = child:GetHeight()
			newHeight = newHeight + childHeight
		end
	end
	self.mainWindow:SetAnchorOffsets(left, top, right, newHeight)
end

