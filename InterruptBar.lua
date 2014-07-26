local InterruptBar = {}
InterruptBar.__index = InterruptBar

local is = Apollo.GetAddon("InterruptSync")
is.InterruptBar = InterruptBar

function InterruptBar:new(xmlDoc, playerName, interrupt, itemList)
	local self = setmetatable({}, { __index = InterruptBar })
	self.interrupt = interrupt
	self.playerName = playerName
	
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

