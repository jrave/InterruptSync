local InterruptContainer = {}
InterruptContainer.__index = InterruptContainer

local is = Apollo.GetAddon("InterruptSync")
is.InterruptContainer = InterruptContainer

function InterruptContainer:new(xmlDoc, interruptbar, mainWindow)
	local self = setmetatable({}, InterruptContainer)
	
	self.itemList = mainWindow:FindChild("ItemList")
	self.xmlDoc = xmlDoc
	self.InterruptBar = interruptbar
	self.players = {}
	self.players.interrupts = {}
	return self
end

function InterruptContainer:HandleInterrupt(playerName, interrupt)
	local player = self.players[playerName]
	if player == nil then
		player = {}
		self.players[playerName] = player
	end
	local interruptBar = player[interrupt.name]
	if interruptBar == nil then
		interruptBar = self.InterruptBar:new(self.xmlDoc, interrupt, self.itemList)
		player[interrupt.name] = interruptBar
	end
	interruptBar:SetInterrupt(interrupt)
	self.itemList:ArrangeChildrenVert()
end

