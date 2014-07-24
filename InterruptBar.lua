local InterruptBar = {}
InterruptBar.__index = InterruptBar

local is = Apollo.GetAddon("InterruptSync")
is.InterruptBar = InterruptBar

function InterruptBar:new(xmlDoc, interrupt, itemList)
	local self = setmetatable({}, { __index = InterruptBar })
	self.interrupt = interrupt
	
	self.wndInt = Apollo.LoadForm(xmlDoc, "InterruptBar", itemList, self)
	
	self.wndInt:FindChild("Icon"):SetSprite(self:GetIcon())
    self.wndInt:FindChild("ProgressOverlay"):SetMax(interrupt.cooldown)
    --self.wndInt:FindChild("ProgressOverlay"):SetFullSprite(self:GetIcon())
    self.wndInt:FindChild("Text"):SetText(interrupt.name)
    self.wndInt:SetData(interrupt)
	
	return self
end

function InterruptBar:GetIcon()
	--ability = AbilityBook.GetAbilityInfo(self.interrupt.id)
	--return ability.tTiers[1].splObject:GetIcon()
	return self.interrupt.icon
end

function InterruptBar:SetInterrupt(interrupt)
    self.wndInt:FindChild("ProgressOverlay"):SetProgress(interrupt.cooldownRemaining)
    self.interrupt = interrupt
    
	self.wndInt:FindChild("Text"):SetText(interrupt.name)

    if interrupt.cooldownRemaining ~= 0 then
        self.wndInt:FindChild("Timer"):SetText(string.format("%.1fs", interrupt.cooldownRemaining))
    else
        self.wndInt:FindChild("Timer"):SetText("")
    end
end

function InterruptBar:TriggerUpdate()
	self.wndInt:FindChild("ProgressOverlay"):SetProgress(self.interrupt.cooldownRemaining)
	self.wndInt:FindChild("Timer"):SetText(string.format("%.1fs", self.interrupt.cooldownRemaining))
end

