local LibMapPins = LibMapPins
local COMPASS_PINS = COMPASS_PINS


-- locals
local function RefreshMapPins(pinName)
	LibMapPins:RefreshPins(pinName)
end

local function RefreshCompassPins(pinName)
	COMPASS_PINS:RefreshPins(pinName)
end


-- globals
function LostTreasure_GetPlayerPositionInfo()
	if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
		CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
	end
	local x, y = GetMapPlayerPosition("player")
	local zone, subZone = LibMapPins:GetZoneAndSubzone()
	return x, y, zone, subZone
end

function LostTreasure_IsMapPinEnabled(pinName)
	return LibMapPins:IsEnabled(pinName)
end

function LostTreasure_SetLayoutKey(pinType, key, data)
	local pinName = LostTreasure_GetPinNameFromPinType(pinType)
	LibMapPins:SetLayoutKey(pinName, key, data)
end

function LostTreasure_SetMapPinState(pinType, state)
	local pinName = LostTreasure_GetPinNameFromPinType(pinType)
	LibMapPins:SetEnabled(pinName, state)
end

function LostTreasure_CreateMapPin(pinName, pinData, x, y)
	LibMapPins:CreatePin(pinName, pinData, x, y)
end

function LostTreasure_CreateCompassPin(pinName, pinData, x, y, itemName)
	COMPASS_PINS.pinManager:CreatePin(pinName, pinData, x, y, itemName)
end

function LostTreasure_RefreshAllPinsFromPinType(pinTypeOrPinName, refreshOnlyMapPins)
	local pinName
	if type(pinTypeOrPinName) == "number" then
		pinName = LostTreasure_GetPinNameFromPinType(pinTypeOrPinName)
	elseif type(pinTypeOrPinName) == "string" then
		for _, pinData in ipairs(LOST_TREASURE_PIN_TYPE_DATA) do
			if pinData.pinName == pinTypeOrPinName then
				pinName = pinTypeOrPinName
				break
			end
		end
	end

	assert(pinName, "pinName is not existing")

	RefreshMapPins(pinName)
	if not refreshOnlyMapPins then
		RefreshCompassPins(pinName)
	end
end

function LostTreasure_RefreshCompassPinsFromPinType(pinType)
	local pinName = LostTreasure_GetPinNameFromPinType(pinType)
	RefreshCompassPins(pinName)
end

function LostTreasure_SetCompassPinTypeTexture(pinType, texturePath)
	local pinName = LostTreasure_GetPinNameFromPinType(pinType)
	COMPASS_PINS.pinLayouts[pinName].texture = texturePath
end

function LostTreasure_AddNewPins(pinName, pinType, mapCallback, mapLayout, pinTooltip, mapFilter, compassCallback, compassLayout, settings, settingsKey)
	LibMapPins:AddPinType(pinName, mapCallback, nil, mapLayout, pinTooltip)
	LibMapPins:AddPinFilter(pinName, mapFilter, nil, settings, settingsKey)

	COMPASS_PINS:AddCustomPin(pinName, compassCallback, compassLayout)
	zo_callLater(function() RefreshCompassPins(pinName) end, 100)
end

function LostTreasure_AddTooltip(text, itemName, color, itemStackCount, iconPath)
	if IsInGamepadPreferredMode() then
		local InformationTooltip = ZO_MapLocationTooltip_Gamepad
		local baseSection = InformationTooltip.tooltip
		InformationTooltip:LayoutIconStringLine(baseSection, nil, itemName, { widthPercent = 100, fontFace = "$(GAMEPAD_BOLD_FONT)", fontSize = "$(GP_34)", uppercase = true, fontColor = color })
		InformationTooltip:LayoutIconStringLine(baseSection, iconPath, text, { fontSize = 27, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_3 })
		if itemStackCount > 1 then
			InformationTooltip:LayoutStringLine(baseSection, string.format("%s: %d", GetString(SI_CRAFTING_QUANTITY_HEADER), itemStackCount))
		end
	else
		InformationTooltip:AddLine(itemName, "", color:UnpackRGB())
		-- don't use zo_iconTextFormat, because it will turns points into commas
		InformationTooltip:AddLine(string.format("%s %s", zo_iconFormat(iconPath, 32, 32), text), "", ZO_HIGHLIGHT_TEXT:UnpackRGB())
		if itemStackCount > 1 then
			InformationTooltip:AddLine(string.format("%s: %d", GetString(SI_CRAFTING_QUANTITY_HEADER), itemStackCount), "", ZO_HIGHLIGHT_TEXT:UnpackRGB())
		end
	end
end