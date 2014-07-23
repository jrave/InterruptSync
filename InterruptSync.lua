-----------------------------------------------------------------------------------------------
-- Client Lua Script for InterruptSync
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "ActionSetLib"
require "AbilityBook"
require "GameLib"
require "GroupLib"
require "ICCommLib"
 
-----------------------------------------------------------------------------------------------
-- InterruptSync Module Definition
-----------------------------------------------------------------------------------------------
local InterruptSync = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local g_interrupts = {
	-- Medic
	["Paralytic Surge"] = {1, 1, 1, 1, 2, 2, 2, 2, 2},
	-- Stalker
	["Stagger"] = {1, 1, 1, 1, 1, 1, 1, 1, 1},
	["False Retreat"] = {1, 1, 1, 1, 1, 1, 1, 1, 1},
	["Collapse"] = {1, 1, 1, 1, 1, 1, 1, 1, 1},
	-- Warrior
	["Kick"] = {1, 1, 1, 1, 1, 1, 1, 1, 2},
	["Flash Bang"] = {1, 1, 1, 1, 1, 1, 1, 1, 1},
	["Grapple"] = {1, 1, 1, 1, 1, 1, 1, 1, 1},
	-- Esper
	["Crush"] = {1, 1, 1, 1, 2, 2, 2, 2, 2},
	["Shockwave"] = {1, 1, 1, 1, 1, 1, 1, 1, 1},
	-- Spellslinger
	["Gate"] = {1, 1, 1, 1, 2, 2, 2, 2, 2},
	["Arcane Shock"] = {1, 1, 1, 1, 1, 1, 1, 1, 1},
	-- Engineer
	["Zap"] = {1, 1, 1, 1, 2, 2, 2, 2, 2},
	["Obstruct Vision"] = {1, 1, 1, 1, 1, 1, 1, 1, 1}
}

local g_MessageTypeLas = 1
local g_MessageTypeAbility = 2

local g_TextItemCount = 3
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function InterruptSync:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.tItems = {}

    return o
end

function InterruptSync:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- InterruptSync OnLoad
-----------------------------------------------------------------------------------------------
function InterruptSync:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("InterruptSync.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- InterruptSync OnDocLoaded
-----------------------------------------------------------------------------------------------
function InterruptSync:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "InterruptSyncForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		self.wndItemList = self.wndMain:FindChild("ItemList")
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("nsync", "OnInterruptSyncOn", self)

		self.timer = ApolloTimer.Create(0.1, true, "OnTimer", self)
		
		self.playerLas = {}
		self.playerInterruptAbilitites = {}
		self.groupMembers = {}
		
		-- Rover
		self.Rover = Apollo.GetAddon("Rover")
		if self.Rover then
			self.Rover:AddWatch("InterruptSync.self", self)
		end

		self.intChannel = ICCommLib.JoinChannel("InterruptSync", "OnMessageInChannel", self)

		-- Do additional Addon initialization here
		
		Apollo.RegisterEventHandler("AbilityBookChange", "Update", self)
		Apollo.RegisterEventHandler("Group_Add", "Update", self)
		Apollo.RegisterEventHandler("Group_Remove", "Update", self)
		Apollo.RegisterEventHandler("Group_Join", "Update", self)
		Apollo.RegisterEventHandler("Group_Left", "Update", self)
		
		-- Perform an update.
		self:Update()
	end
end

-----------------------------------------------------------------------------------------------
-- InterruptSync Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

function InterruptSync:DrawInterruptControl(wnd, controlName, interrupt)
	local wndItem = wnd:FindChild(controlName)
	if wndItem then
		wndItem:SetText(tostring(interrupt.ia))
		local tooltipText = string.format("%s - %f", interrupt.name, interrupt.cd)
		wndItem:SetTooltip(tooltipText)
	end
end

function InterruptSync:ResetInterruptControl(wnd, controlName)
	local wndItem = wnd:FindChild(controlName)
	if wndItem then
		wndItem:SetText("")
		wndItem:SetTooltip("")
	end
end

function InterruptSync:UpdateUIWithMessage(msg)
	Print("UpdateUIWithMessage()")
		
	local wnd = nil
	if self.tItems[msg.pName] then
		wnd = self.tItems[msg.pName]
	else
		wnd = Apollo.LoadForm(self.xmlDoc, "ListItem", self.wndItemList, self)
		self.tItems[msg.pName] = wnd
	end
	
	local wndItemPlayerText = wnd:FindChild("TextPlayerName")
	if wndItemPlayerText then
		wndItemPlayerText:SetText(msg.pName)
	end
		
	local i = 1
	for _, int in pairs(msg.interrupts) do
		local itemName = string.format("TextInt%s", i)
		self:DrawInterruptControl(wnd, itemName, int)
		i = i + 1
	end
	
	for j = i,g_TextItemCount do
		local itemName = string.format("TextInt%s", j)
		self:ResetInterruptControl(wnd, itemName)
	end
			
	wnd:SetData(msg)
	self.wndItemList:ArrangeChildrenVert()
end

function InterruptSync:UpdateCurrentGroup()
	Print("UpdateCurrentGroup()")
	self.groupMembers = {}
	if GroupLib.InGroup() then
		for i=1,GroupLib.GetMemberCount() do
			local member = GroupLib.GetGroupMember(i)
			if member then
				self.groupMembers[member.strCharacterName] = true
			end
		end
	end
end

function InterruptSync:IsInGroup(name)
	Print("IsInGroup()")
	if self.groupMembers[name] then
		return true
	end
	return false
end

function InterruptSync:ReadCurrentLas()
	Print("ReadCurrentLas()")
	-- reset playeLas
	self.playerLas = {}
	local currentAS = ActionSetLib.GetCurrentActionSet() or {}
	for _, nAbilityId in pairs(currentAS) do
		if nAbilityId ~= 0 then
			self.playerLas[nAbilityId] = true
		end
	end
end

function InterruptSync:GetActiveInterrupts()
	Print("GetActiveInterrupts()")
	self.playerInterruptAbilitites = {}
	local interrupts = {}
	local abilities = AbilityBook.GetAbilitiesList()
	for _, ability in pairs(abilities) do
	    if g_interrupts[ability.strName] and ability.bIsActive and self.playerLas[ability.nId] and ability.nCurrentTier ~= 0 then
	        local int = {}
			int.cd = ability.tTiers[ability.nCurrentTier].splObject:GetCooldownTime()
			int.name = ability.strName
			int.ia = g_interrupts[ability.strName][ability.nCurrentTier]
			
			Print(int.name)
			local ab = {
				obj = ability,
				onCooldown = false
			}
			table.insert(self.playerInterruptAbilitites, ab)
			
			table.insert(interrupts, int)
		end
	end
	return interrupts
end

function InterruptSync:SendLasUpdate()
	local player = GameLib.GetPlayerUnit()
	if player then
		local msg = {}	
		msg.pName = player:GetName()
		msg.interrupts = self:GetActiveInterrupts()
		msg.type = g_MessageTypeLas

		Print("Sending Message")
		self.intChannel:SendMessage(msg)
		self:OnMessageInChannel(nil, msg)
	end
end

function InterruptSync:SendAbilityUpdate(ability)

	if self.Rover then
		self.Rover:AddWatch("SendAbility", ability)
	end

	local player = GameLib.GetPlayerUnit()
	if player then
		local msg = {}
		msg.pName = player:GetName()
		msg.ability = ability
		msg.type = g_MessageTypeAbility
		
		Print("Sending Ability Message")
		self.intChannel:SendMessage(msg)
		self:OnMessageInChannel(nil, msg)
	end
end

-- on SlashCommand "/nsync"
function InterruptSync:OnInterruptSyncOn()
	self.wndMain:Invoke() -- show the window
	
	self:SendLasUpdate()
end

-- on timer
function InterruptSync:OnTimer()
	-- Do your timer-related stuff here.
	-- todo: minimize sent data by creating a smaller ab object with icon (id?), name, cooldown. we dont need the entire ab.obj thing.
	for _, ab in pairs(self.playerInterruptAbilitites) do
		local ability = ab.obj
		ab.remainingCd = ability.tTiers[ability.nCurrentTier].splObject:GetCooldownRemaining()
		if ab.remainingCd > 0 and not ab.onCooldown then
			Print(string.format("Interrupt fired: %s", ability.strName))
			ab.onCooldown = true
			self:SendAbilityUpdate(ab)
		elseif ab.remainingCd == 0 and ab.onCooldown then
			Print(string.format("Interrupt Reset: %s", ability.strName))
			ab.onCooldown  = false
			self:SendAbilityUpdate(ab)
		end
		
	end
end

function InterruptSync:Update()
	-- used because often when we want to update, the data hasn't been updated yet so we delay.
	self.updateTimer = ApolloTimer.Create(1, false, "OnUpdateTimer", self)
end

function InterruptSync:OnUpdateTimer()
	Print("OnUpdateTimer()")
	self:UpdateCurrentGroup()
	self:ReadCurrentLas()
	self:SendLasUpdate()
	
	self.updateTimer = nil
end

function InterruptSync:OnMessageInChannel(channel, msg)
	Print("OnMessageInChannel()")
	if self:IsInGroup(msg.pName) then
		Print("Sender is in group")
		if msg.type == g_MessageTypeLas then
			self:UpdateUIWithMessage(msg)
		elseif msg.type == g_MessageTypeAbility then
			Print("Ability recieved!")
		end
	end
end


-----------------------------------------------------------------------------------------------
-- InterruptSyncForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function InterruptSync:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function InterruptSync:OnCancel()
	self.wndMain:Close() -- hide the window
end

function InterruptSync:DestroyItemList()
	for _, wnd in pairs(self.tItems) do
		wnd:Destroy()
	end
	
	self.tItems = {}
end

-----------------------------------------------------------------------------------------------
-- InterruptSync Instance
-----------------------------------------------------------------------------------------------
local InterruptSyncInst = InterruptSync:new()
InterruptSyncInst:Init()
