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

		self.timer = ApolloTimer.Create(1.0, true, "OnTimer", self)
		
		self.playerLas = {}
		self.groupMembers = {}
		self.abTimer = nil
		
		self.intChannel = ICCommLib.JoinChannel("InterruptSync", "OnMessageInChannel", self)

		-- Do additional Addon initialization here
		Apollo.RegisterTimerHandler("InterruptSync_AbilityTimer", "OnAbilityTimer", self)
		
		Apollo.RegisterEventHandler("AbilityBookChange", "OnAbilityBookChange", self)
		Apollo.RegisterEventHandler("Group_Join", "OnGroupChange", self)
		Apollo.RegisterEventHandler("Group_Left", "OnGroupChange", self)
		
		-- Initial LAS read, future updates are handled through events
		self:UpdateCurrentGroup()
		-- Todo: Delay timer for LAS reading
		-- ToDo: Onlz do stuff on OnAbilitzBook change if in group
		self:ReadCurrentLas()
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
	local interrupts = {}
	local abilities = AbilityBook.GetAbilitiesList()
	for _, ability in pairs(abilities) do
	    if g_interrupts[ability.strName] and ability.bIsActive and self.playerLas[ability.nId] and ability.nCurrentTier ~= 0 then
	        local int = {}
			int.cd = ability.tTiers[ability.nCurrentTier].splObject:GetCooldownTime()
			int.name = ability.strName
			int.ia = g_interrupts[ability.strName][ability.nCurrentTier]
			
			Print(int.name)
			
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

-- on SlashCommand "/nsync"
function InterruptSync:OnInterruptSyncOn()
	self.wndMain:Invoke() -- show the window
	
	self:SendLasUpdate()
end

-- on timer
function InterruptSync:OnTimer()
	-- Do your timer-related stuff here.
end

function InterruptSync:OnAbilityBookChange()
	Print("OnAbilityBookChange()")
	if GroupLib.InGroup() then
		-- Creating Timer is a workaround as this event fires too early
		self.abTimer = Apollo.CreateTimer("InterruptSync_AbilityTimer", 0.1, false)
	end
end

function InterruptSync:OnAbilityTimer()
	Print("OnAbilityTimer()")
	self:ReadCurrentLas()
	self:SendLasUpdate()
	self.abTimer = nil
end

function InterruptSync:OnGroupChange()
	Print("OnGroupChange()")
	self:UpdateCurrentGroup()
	self:SendLasUpdate()
end

function InterruptSync:OnMessageInChannel(channel, msg)
	Print("OnMessageInChannel()")
	if self:IsInGroup(msg.pName) then
		Print("Sender is in group")
		self:UpdateUIWithMessage(msg)
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
