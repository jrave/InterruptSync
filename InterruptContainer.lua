local InterruptContainer = {}
InterruptContainer.__index = InterruptContainer

local is = Apollo.GetAddon("InterruptSync")
is.InterruptContainer = InterruptContainer

function InterruptContainer:new(xmlDoc, rover, interruptbar, mainWindow)
	local self = setmetatable({}, InterruptContainer)
	
	self.itemList = mainWindow:FindChild("ItemList")
	self.mainWindow = mainWindow
	self.xmlDoc = xmlDoc
	self.rover = rover
	self.InterruptBar = interruptbar
	self.players = {}
	
	if self.rover then
		self.rover:AddWatch("InterruptContainer.self", self)
	end
	
	return self
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
		interruptBar = self.InterruptBar:new(self.xmlDoc, playerName, interrupt, self.itemList)
		player[interrupt.name] = interruptBar
	end
	interruptBar:SetInterrupt(interrupt)
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
		local bar = self.InterruptBar:new(self.xmlDoc, playerName, interrupt, self.itemList)
		player[interrupt.name] = bar
		bar:SetInterrupt(interrupt)
		self:ArrangeBars()
	end
	self:ResizeWindow()
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
	if int1 and int2 then	
		return int1.playerName < int2.playerName
	else
		return 0
	end
end

function InterruptContainer:ArrangeBars()
	self.itemList:ArrangeChildrenVert(0, SortByName)
end

function InterruptContainer:ResizeWindow()
	local left, top, right, bottom = self.mainWindow:GetAnchorOffsets()
	local childrenCount = #self.itemList:GetChildren()
	local newHeight = 0
	if childrenCount > 0 then
		local child = self.itemList:GetChildren()[1]
		local childHeight = child:GetHeight()
		newHeight = top + (childrenCount * childHeight)
	end
	self.mainWindow:SetAnchorOffsets(left, top, right, newHeight)
end

