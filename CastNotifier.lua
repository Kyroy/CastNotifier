-----------------------------------------------------------------------------------------------
-- Client Lua Script for CastNotifier
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Sound"
 
-----------------------------------------------------------------------------------------------
-- CastNotifier Module Definition
-----------------------------------------------------------------------------------------------
local CastNotifier = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
local kcrSelectedText = ApolloColor.new("UI_BtnTextHoloPressedFlyby")
local kcrNormalText = ApolloColor.new("UI_BtnTextHoloNormal")
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------

local sounds = {
	PlayUIWindowAuctionHouseOpen,
	PlayUIStoryPaneUrgent,
	PlayUICraftingSuccess,
	PlayUICraftingOverchargeWarning,
	PlayUIWindowPublicEventVoteOpen,
	PlayUIMissionUnlockSoldier,
	PlayUIQueuePopsPvP,
	PlayUIQueuePopsDungeon,
	PlayUIWindowPublicEventVoteVotingEnd
}

function CastNotifier:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	o.members = {} -- keep track of all the players and enemies
	o.spells = {}
	o.ids = 0
	o.settings = {
		version = {0,0,2},
		customeVolumeLevel = 1,
		useCustomVolume = false
	}
	
    return o
end

function CastNotifier:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- CastNotifier OnLoad
-----------------------------------------------------------------------------------------------
function CastNotifier:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("CastNotifier.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- CastNotifier OnDocLoaded
-----------------------------------------------------------------------------------------------
function CastNotifier:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "CastNotifierForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		self.wndPopup = Apollo.LoadForm(self.xmlDoc, "PopupForm", nil, self)
		if self.wndPopup == nil then
			Apollo.AddAddonErrorText(self, "Could not load the popup window for some reason.")
			return
		end
		
		self.wndOptions = Apollo.LoadForm(self.xmlDoc, "OptionForm", nil, self)
		if self.wndOptions == nil then
			Apollo.AddAddonErrorText(self, "Could not load the option  window for some reason.")
			return
		end
		
		-- item list
		self.wndItemList = self.wndMain:FindChild("ItemList")
	    self.wndMain:Show(false, true)
		self.wndPopup:Show(false, true)
		self.wndOptions:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterEventHandler("UnitEnteredCombat", "OnEnteredCombat", self)
		
		Apollo.RegisterSlashCommand("cn", "OnCastNotifierOn", self)

		self.timer = ApolloTimer.Create(0.100, true, "OnTimer", self)

		-- Do additional Addon initialization here
		if self.saveData then
			for k,v in pairs(self.saveData.settings) do
				self.settings[k] = v
			end
			for k,v in pairs(self.saveData.spells) do
				self.spells[k] = v
				self:AddItem(v)
			end
			self.wndOptions:FindChild("CustomVolumeCheckButton"):SetCheck(self.settings.useCustomVolume)
		end
	end
end

-----------------------------------------------------------------------------------------------
-- CastNotifier Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/cn"
function CastNotifier:OnCastNotifierOn()
	self.wndMain:Invoke() -- show the window
end

-- on timer
function CastNotifier:OnTimer()
	for id1, unit in pairs(self.members) do
		local castPercentage = unit:GetCastTotalPercent()
		if castPercentage and 0 < castPercentage and castPercentage < 100 then
			local spellName = unit:GetCastName()
			for id2, item in pairs(self.spells) do
				if spellName == item.strName and item.nPercentage <= castPercentage  then
					if not item.nextPlay or os.difftime(item.nextPlay, os.clock()) <= 0 then
						self:SetCustomVolumeLevels()
						Print("CastNotifier: " .. unit:GetName() .. " is casting " .. spellName  .. "(" .. castPercentage .. "%)")
						Sound.Play(Sound.PlayUIQueuePopsPvP)
						item.nextPlay = os.clock() + (unit:GetCastDuration())/1000.0 + 1.0
						self:RestoreVolumeLevels()
					end
					--[[
					PlayUIWindowAuctionHouseOpen
					PlayUIStoryPaneUrgent
					PlayUICraftingSuccess
					PlayUICraftingOverchargeWarning
					PlayUIWindowPublicEventVoteOpen
					PlayUIMissionUnlockSoldier!!!
					PlayUIQueuePopsPvP !
					PlayUIQueuePopsDungeon
					PlayUIWindowPublicEventVoteVotingEnd
					--
					PlayUILootSpellslingerEquipable
					PlayRingtoneSoldier
					PlayUIExplorerSognalDetection3
					PlayUIAlertPopUpRepIncrease
					PlayRingtoneExplorer
					--
					Sound.PlayUI60MessageAlertDigital
					Sound.PlayUI55ErrorVirtual
					Sound.PlayUIButtonHoloLarge
					Sound.PlayUIWIndowMetalClose
					Sound.PlayUIWindowMetalOpen
					Sound.PlayUIWindowAccordionClose
					Sound.PlayUIAlertPopUpMessageReceived
					Sound.PlayUIWindowHoloOpen
					--]]
					end
			end
		end
	end
end

function CastNotifier:OnEnteredCombat(unitChanged,bInCombat)
	if bInCombat then
		--Print("OnEnteredCombat(".. unitChanged:GetName() ..", true)")
		self.members[unitChanged:GetId()] = unitChanged
	else
		--Print("OnEnteredCombat(".. unitChanged:GetName() ..", false-)")
		self.members[unitChanged:GetId()] = nil
	end
end


-----------------------------------------------------------------------------------------------
-- CastNotifierForm Functions
-----------------------------------------------------------------------------------------------

function CastNotifier:OnPopupOK()
	local wndItemText = self.wndPopup:FindChild("Name")
	local wndItemPercentage = self.wndPopup:FindChild("Percentage")

	if wndItemText then
		local ind = self.ids + 1
		while self.spells[ind ] do
			ind = ind +1
		end
		self.ids = ind
			self.spells[self.ids] = {
			nId = self.ids,
			strName = wndItemText:GetText(),
			nPercentage = tonumber(wndItemPercentage:GetText()),
			nextPlay = 0
		}
		self:AddItem(self.spells[self.ids])
		wndItemText:SetText("")
	end

	self.wndPopup:Close() -- hide the window
end

-- when the Cancel button is clicked
function CastNotifier:OnPopupCancel()
	self.wndPopup:FindChild("Name"):SetText("")
	self.wndPopup:Close() -- hide the window
end



function CastNotifier:OnAddItem( wndHandler, wndControl, eMouseButton )
	self.wndPopup:Invoke()
end

function CastNotifier:OnOptions( wndHandler, wndControl, eMouseButton )
	self.wndOptions:Invoke()
end

-----------------------------------------------------------------------------------------------
-- ItemList Functions
-----------------------------------------------------------------------------------------------
-- add an item into the item list
function CastNotifier:AddItem(i)
	
	-- load the window item for the list item
	local wnd = Apollo.LoadForm(self.xmlDoc, "ListItem", self.wndItemList, self)
	i.wnd = wnd
	
	self:UpdateItem(i)
	self.wndItemList:ArrangeChildrenVert()
end

function CastNotifier:UpdateItem(i)
    -- fill in our data
	i.wnd:FindChild("SpellId"):SetText(i.nId)
    i.wnd:FindChild("Name"):SetText(i.strName)
    i.wnd:FindChild("Percentage"):SetText(tostring(i.nPercentage))
end

function CastNotifier:OnCancel( wndHandler, wndControl, eMouseButton )
	self.wndMain:Close()
end

-----------------------------------------------------------------------------------------------
-- CastNotifier Save/Restore
-----------------------------------------------------------------------------------------------
function CastNotifier:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then
        return nil
    end
	local tSave = {spells = self.spells,
		version = self.version,
		settings = self.settings
	}
	return tSave
end

function CastNotifier:OnRestore(eLevel, tData)
	if tData then
		-- check version compatibility
		--if tData and tData.version and tData.version[0] >= 0 and tData.version[1] >= 0 and tData.version[2] >= 2 then
			self.saveData = tData
		--end
	end
end

---------------------------------------------------------------------------------------------------
-- ListItem Functions
---------------------------------------------------------------------------------------------------

function CastNotifier:OnButtonItemDelete( wndHandler, wndControl, eMouseButton )
	local castId = tonumber(wndHandler:GetParent():FindChild("SpellId"):GetText())
	if castId then
		self.spells[castId] = nil
		wndHandler:GetParent():Destroy()
		self.wndItemList:ArrangeChildrenVert()
	end
end

-----------------------------------------------------------------------------------------------
-- CastNotifier Sound
-----------------------------------------------------------------------------------------------

function CastNotifier:SetCustomVolumeLevels()
	if self.settings.useCustomVolume then
		self.originalVolumeLevel = Apollo.GetConsoleVariable("sound.volumeMaster")
		self.originalVoiceVolumeLevel = Apollo.GetConsoleVariable("sound.volumeVoice")
		Apollo.SetConsoleVariable("sound.volumeMaster", self.settings.customeVolumeLevel)
		Apollo.SetConsoleVariable("sound.volumeVoice", self.settings.customeVolumeLevel)
	end
end

function CastNotifier:RestoreVolumeLevels()
	if self.settings.useCustomVolume then
		Apollo.SetConsoleVariable("sound.volumeMaster", self.originalVolumeLevel)
		Apollo.SetConsoleVariable("sound.volumeVoice", self.originalVoiceVolumeLevel)
	end
end

---------------------------------------------------------------------------------------------------
-- OptionForm Functions
---------------------------------------------------------------------------------------------------

function CastNotifier:OnCustomVolumeCheck( wndHandler, wndControl, eMouseButton )
	self.settings.useCustomVolume = true
end

function CastNotifier:OnCustomeVolumeUncheck( wndHandler, wndControl, eMouseButton )
	self.settings.useCustomVolume = false
end

function CastNotifier:OnOptionsClose( wndHandler, wndControl, eMouseButton )
	self.wndOptions:Close()
end

-----------------------------------------------------------------------------------------------
-- CastNotifier Instance
-----------------------------------------------------------------------------------------------
local CastNotifierInst = CastNotifier:new()
CastNotifierInst:Init()
