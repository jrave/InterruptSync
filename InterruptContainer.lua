local InterruptContainer = {}
InterruptContainer.__index = InterruptContainer

local is = Apollo.GetAddon("InterruptSync")
is.InterruptContainer = InterruptContainer

function InterruptContainer:new(xmlDoc, rover, interruptbar, mainWindow)
	local self = setmetatable({}, InterruptContainer)
	
	self.itemList = mainWindow:FindChild("ItemList")
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
	self.itemList:ArrangeChildrenVert()
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
			self.itemList:ArrangeChildrenVert()
		end
	end
	-- Add the new bars
	for _, interrupt in pairs(msg.interrupts) do
		local bar = self.InterruptBar:new(self.xmlDoc, playerName, interrupt, self.itemList)
		player[interrupt.name] = bar
		bar:SetInterrupt(interrupt)
		self.itemList:ArrangeChildrenVert()
	end
end

function InterruptContainer:HandleTimerUpdate(timerValue)
	for _, player in pairs(self.players) do
		for _, bar in pairs(player) do
			if bar.interrupt.cooldownRemaining > 0 then
				bar.interrupt.cooldownRemaining = bar.interrupt.cooldownRemaining - timerValue
				bar:TriggerUpdate()
				self.itemList:ArrangeChildrenVert()
			end
		end
	end
end

