local LAM2 = LibAddonMenu2
local LMP = LibMapPins

local Addon = {
  Name = "LostTreasure",
  NameSpaced = "Lost Treasure",
  Author = "CrazyDutchGuy ",
  Version = "7.02",
  WebSite = "http://www.esoui.com/downloads/info561-LostTreasure.html",
}

LT = ZO_Object:Subclass()

LT.defaults = {
  showTreasure = true,
  showTreasureCompass = true,
  treasurePinTexture = 1,
  treasureMarkMapMenuOption = 2,

  showSurveys = true,
  showSurveysCompass = true,
  surveysPinTexture = 1,
  surveysMarkMapMenuOption = 2,
  showMiniTreasureMap = true,
  miniTreasureMap = {
    point = TOPLEFT,
    relativeTo = GuiRoot,
    relativePoint = TOPLEFT,
    offsetX = 100,
    offsetY = 100,
  },
  pinTextureSize = 32,
  apiVersion = GetAPIVersion(),
  markerDeletionDelay = 10,
  pinLevel = 10,
}

-- some strings
local MAP_PIN_TYPES = {
  treasure = Addon.Name.."MapTreasurePin",
  surveys = Addon.Name.."CompassSurveysPin",
}
local COMPASS_PIN_TYPES = {
  treasure = Addon.Name.."MapTreasurePin",
  surveys = Addon.Name.."CompassSurveysPin",
}

local lang = GetCVar("Language.2")

local markMapMenuOptions = {
  [1] = GetString(LTS_MARK_MAP_MENU_OPTION1),
  [2] = GetString(LTS_MARK_MAP_MENU_OPTION2),
  [3] = GetString(LTS_MARK_MAP_MENU_OPTION3),
}

local pinTexturesList = {
  [1] = [[X red]],
  [2] = [[X black]],
  [3] = [[Map black]],
  [4] = [[Map white]],
  [5] = [[Justice Stolen Map]],
  [6] = [[Scroll]],
  [7] = [[Delivery Box]],
}

local pinTextures = {
  [1] = [[LostTreasure/Icons/x_red.dds]],
  [2] = [[LostTreasure/Icons/x_black.dds]],
  [3] = [[LostTreasure/Icons/map_black.dds]],
  [4] = [[LostTreasure/Icons/map_white.dds]],
  [5] = [[esoui\art\icons\justice_stolen_map_001.dds]],
  [6] = [[esoui\art\icons\scroll_001.dds]],
  [7] = [[esoui\art\icons\delivery_box_001.dds]],
}

local pinLayout_Treasure = {
  level = 40,
}

local pinLayout_Surveys = {
  level = 40,
}

local compassLayout_Treasure = {
  maxDistance = 0.05,
  texture = "",
}

local compassLayout_Surveys = {
  maxDistance = 0.05,
  texture = "",
}

local LostTreasureTLW = nil
local currentTreasureMapItemID = nil

local INFORMATION_TOOLTIP = nil

local TREASURE_TEXT = {
  en = "treasure map",
  de = "schatzkarte",
  fr = "carte au trésor",
  ru = "карта сокровищ",
  jp = "宝箱の地図",
}
local SURVEYS_TEXT = {
  en = "survey:",
  de = "fundbericht",
  fr = "repérages",
  ru = "исследований:",
  jp = "調査:",
}

LT.dirtyPins = {}
LT.isUpdating = false
LT.listMarkOnUse = {}
LT.listMarkOnUse["treasure"] = {}
LT.listMarkOnUse["surveys"] = {}

-- Gamepad Switch -- Credits Daeymon ----
local function OnGamepadPreferredModeChanged()
  INFORMATION_TOOLTIP = InformationTooltip
  if IsInGamepadPreferredMode() then
    INFORMATION_TOOLTIP = ZO_MapLocationTooltip_Gamepad
  end
end

--Creates ToolTip from treasure info
local pinTooltipCreator = {
  creator = function(pin)
    local function getItemLinkFromItemId(itemId) 
      local name = GetItemLinkName(ZO_LinkHandler_CreateLink("Test Trash", nil, ITEM_LINK_TYPE,itemId, 0, 26, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 10000, 0))
      local link = ZO_LinkHandler_CreateLinkWithoutBrackets(zo_strformat("<<t:1>>",name), nil, ITEM_LINK_TYPE,itemId, 0, 26, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 10000, 0)

      return string.match(link,"|H0:item:%d+:%d:%d%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d+:%d").."|h|h"
    end

    local _, pinTag = pin:GetPinTypeAndTag()

    if IsInGamepadPreferredMode() then
      INFORMATION_TOOLTIP:LayoutIconStringLine(INFORMATION_TOOLTIP.tooltip, nil, zo_strformat(pinTag[LOST_TREASURE_INDEX.MAP_NAME]), INFORMATION_TOOLTIP.tooltip:GetStyle("mapTitle"))
      INFORMATION_TOOLTIP:LayoutIconStringLine(INFORMATION_TOOLTIP.tooltip, pinTextures[4], zo_strformat("<<1>>x<<2>>", string.format("%.2f",pinTag[LOST_TREASURE_INDEX.X]*100), string.format("%.2f",pinTag[LOST_TREASURE_INDEX.Y]*100)), {fontSize = 27, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_3})
    else
      local bag,_,_ = GetItemLinkStacks(getItemLinkFromItemId(pinTag[LOST_TREASURE_INDEX.ITEMID]))

      INFORMATION_TOOLTIP:AddLine(pinTag[LOST_TREASURE_INDEX.MAP_NAME].." ("..tostring(bag)..")", "", ZO_HIGHLIGHT_TEXT:UnpackRGB())--name color
      INFORMATION_TOOLTIP:AddLine(string.format("%.2f",pinTag[LOST_TREASURE_INDEX.X]*100).."x"..string.format("%.2f",pinTag[LOST_TREASURE_INDEX.Y]*100), "", ZO_HIGHLIGHT_TEXT:UnpackRGB())--name color
    end
  end,
  tooltip = 1, -- tooltip type is information
}

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- creates a pin for a specific point, in either/both player map and compass
-- thanks Garkin!
local function CreatePin(treasureType, pinData, map, compass)
  if map then
    LMP:CreatePin(MAP_PIN_TYPES[treasureType], pinData, pinData[LOST_TREASURE_INDEX.X], pinData[LOST_TREASURE_INDEX.Y])
  end
  if compass then
    COMPASS_PINS.pinManager:CreatePin(COMPASS_PIN_TYPES[treasureType], pinData, pinData[LOST_TREASURE_INDEX.X], pinData[LOST_TREASURE_INDEX.Y])
  end
end

local function CreatePins()
  local data = LOST_TREASURE_DATA[GetCurrentMapId()]

  if data then
    if LT.dirtyPins[1] then      
      for treasureType, keys in pairs(LT.dirtyPins[1]) do
        local treasureTypeData = data[treasureType]
        if treasureTypeData then
          for _, pinData in pairs(treasureTypeData) do			
            if LT.listMarkOnUse[treasureType][pinData[LOST_TREASURE_INDEX.ITEMID]] then
              CreatePin(treasureType, pinData, keys.map, keys.compass)
            end
          end
        end
      end
    end

    if LT.dirtyPins[2] then
      local treasures = nil
      local bagCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
      for slotIndex, itemData in pairs(bagCache) do
        if itemData.itemType == ITEMTYPE_TROPHY then
          treasures = treasures or {}
          treasures[GetItemId(itemData.bagId, itemData.slotIndex)] = true
        end
      end
      
	  if treasures then
        for treasureType, keys in pairs(LT.dirtyPins[2]) do
          local treasureTypeData = data[treasureType]
          if treasureTypeData then
            for _, pinData in pairs(treasureTypeData) do
              if treasures[pinData[LOST_TREASURE_INDEX.ITEMID]] then
                CreatePin(treasureType, pinData, keys.map, keys.compass)
              end
            end
          end
        end
      end
    end

    if LT.dirtyPins[3] then
      for treasureType, keys in pairs(LT.dirtyPins[3]) do
        local treasureTypeData = data[treasureType]
        if treasureTypeData then
          for _, pinData in pairs(treasureTypeData) do
            CreatePin(treasureType, pinData, keys.map, keys.compass)
          end
        end
      end
    end
  end

  LT.dirtyPins = {}
  LT.isUpdating = false
end

-- prepares the list of dirty pins and sends it to CreatePins()
-- thanks Garkin!
local function QueueCreatePins(treasureType, key)
  local shownMaps = LT.SavedVariables[treasureType.."MarkMapMenuOption"]
  LT.dirtyPins[shownMaps] = LT.dirtyPins[shownMaps] or {}
  LT.dirtyPins[shownMaps][treasureType] = LT.dirtyPins[shownMaps][treasureType] or {}
  LT.dirtyPins[shownMaps][treasureType][key] = true

  if not LT.isUpdating then
    LT.isUpdating = true
    if IsPlayerActivated() then
      if LMP.AUI.IsMinimapEnabled() then
        zo_callLater(CreatePins, 150)
      else
        CreatePins()
      end
    else
      EVENT_MANAGER:RegisterForEvent("LostTreasure_PinUpdate", EVENT_PLAYER_ACTIVATED,
        function(event)
          EVENT_MANAGER:UnregisterForEvent("LostTreasure_PinUpdate", event)
          CreatePins()
        end)
    end
  end
end

local function pinCreator(treasureType)
  if not LMP:IsEnabled(MAP_PIN_TYPES[treasureType]) or (GetMapType() > MAPTYPE_ZONE) then return end
  QueueCreatePins(treasureType, "map")
end

local function compassCallback(treasureType)
  if not LT.SavedVariables[zo_strformat("show<<C:1>>Compass", treasureType)] or (GetMapType() > MAPTYPE_ZONE) then return end
  QueueCreatePins(treasureType, "compass")
end

local function showMiniTreasureMap(texture)
  if LT.SavedVariables.showMiniTreasureMap then
    LostTreasureTLW:SetHidden( false )
    LostTreasureTLW.map:SetTexture(texture)
  end
end

function LT:hideMiniTreasureMap()
  LostTreasureTLW:SetHidden(true)
end

function  LT:refreshTreasurePins()
  LMP:RefreshPins(MAP_PIN_TYPES.treasure)
  COMPASS_PINS:RefreshPins(COMPASS_PIN_TYPES.treasure)
end

function  LT:refreshSurveyPins()
  LMP:RefreshPins(MAP_PIN_TYPES.surveys)
  COMPASS_PINS:RefreshPins(COMPASS_PIN_TYPES.surveys)
end

local function createMiniTreasureMap()
  LostTreasureTLW = WINDOW_MANAGER:CreateTopLevelWindow("LostTreasureMap")
  LostTreasureTLW:SetMouseEnabled(true)
  LostTreasureTLW:SetMovable( true )
  LostTreasureTLW:SetClampedToScreen(true)
  LostTreasureTLW:SetDimensions( 400 , 400 )
  LostTreasureTLW:SetAnchor(
    LT.SavedVariables.miniTreasureMap.point,
    GetControl(LT.SavedVariables.miniTreasureMap.relativeTo),
    LT.SavedVariables.miniTreasureMap.relativePoint,
    LT.SavedVariables.miniTreasureMap.offsetX,
    LT.SavedVariables.miniTreasureMap.offsetY
  )
  LostTreasureTLW:SetHidden( true )
  LostTreasureTLW:SetHandler("OnMoveStop", function(self,...)
      local _, point, relativeTo, relativePoint, offsetX, offsetY = self:GetAnchor()
      LT.SavedVariables.miniTreasureMap.point = point
      LT.SavedVariables.miniTreasureMap.relativeTo = relativeTo:GetName()
      LT.SavedVariables.miniTreasureMap.relativePoint = relativePoint
      LT.SavedVariables.miniTreasureMap.offsetX = offsetX
      LT.SavedVariables.miniTreasureMap.offsetY = offsetY
    end
  )

  LostTreasureTLW.map = WINDOW_MANAGER:CreateControl(nil,  LostTreasureTLW, CT_TEXTURE)
  LostTreasureTLW.map:SetAnchorFill(LostTreasureTLW)

  LostTreasureTLW.map.close = WINDOW_MANAGER:CreateControlFromVirtual(nil, LostTreasureTLW.map, "ZO_CloseButton")
  LostTreasureTLW.map.close:SetHandler("OnClicked", function(...) LT:hideMiniTreasureMap() end)
end

function LT:EVENT_SHOW_BOOK(eventCode, title, body, medium, showTitle, bookId)
  if LT.SavedVariables["surveysMarkMapMenuOption"] == 1 then
    for LTitemID, LTbookID in pairs(LOST_TREASURE_ITEMID_TO_BOOKID) do
      if bookId == LTbookID then
        LT.listMarkOnUse["surveys"][LTitemID] = LT.listMarkOnUse["surveys"][LTitemID] or {}
        return
      end
    end
  end
end

function LT:EVENT_SHOW_TREASURE_MAP(event, treasureMapIndex)
  local name, textureName  = GetTreasureMapInfo(treasureMapIndex)

  showMiniTreasureMap(textureName)

  local mapTextureName = string.match(textureName, "%w+/%w+/%w+/(.+)%.dds")
  for _, v in pairs(LOST_TREASURE_DATA) do
    if v["treasure"] ~= nil then
      for _, pinData in pairs(v["treasure"]) do
        if mapTextureName == pinData[LOST_TREASURE_INDEX.TEXTURE] then
          if LT.SavedVariables["treasureMarkMapMenuOption"] == 1 then
            LT.listMarkOnUse["treasure"][pinData[LOST_TREASURE_INDEX.ITEMID]] = LT.listMarkOnUse["treasure"][pinData[LOST_TREASURE_INDEX.ITEMID]] or {}
          end
          currentTreasureMapItemID = pinData[LOST_TREASURE_INDEX.ITEMID]
          return
        end
      end
    end
    if v["surveys"] ~= nil then
      for _, pinData in pairs(v["surveys"]) do
        if mapTextureName == pinData[LOST_TREASURE_INDEX.TEXTURE] then
          if LT.SavedVariables["surveysMarkMapMenuOption"] == 1 then
            LT.listMarkOnUse["surveys"][pinData[LOST_TREASURE_INDEX.ITEMID]] = LT.listMarkOnUse["surveys"][pinData[LOST_TREASURE_INDEX.ITEMID]] or {}
          end
          currentTreasureMapItemID = pinData[LOST_TREASURE_INDEX.ITEMID]
          return
        end
      end
    end
  end

  name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
  local myLink
  local bagCache = SHARED_INVENTORY:GetOrCreateBagCache(BAG_BACKPACK)
  for slot, itemData in pairs(bagCache) do
    if name == itemData.name then
      myLink = GetItemLink(BAG_BACKPACK, slot)
      break
    end
  end

  if myLink and #myLink > 0 then
    local itemID = select(4,ZO_LinkHandler_ParseLink(myLink))
    d("Unknown treasure map: "..name..", "..mapTextureName..", "..itemID)
  end
end

-- callback to check if an item was added to inventory; if it was a map, update its pins
-- thanks Garkin!
function LT:SlotAdded(bagId, slotIndex, slotData)
  if not ( bagId == BAG_BACKPACK and 
           slotData and 
           ( slotData.specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP or 
             slotData.specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT))
  then return end

  local itemID = select(4, ZO_LinkHandler_ParseLink(GetItemLink(BAG_BACKPACK, slotIndex)))
  slotData.itemID = tonumber(itemID)

  if slotData.specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP and LT.SavedVariables["treasureMarkMapMenuOption"] == 2 then
    LT:refreshTreasurePins()
  end

  if slotData.specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT and LT.SavedVariables["surveysMarkMapMenuOption"] == 2 then
    LT:refreshSurveyPins()
  end
end

function LT:SlotRemoved(bagId, slotIndex, slotData)
  if not ( bagId == BAG_BACKPACK and 
           slotData and 
           ( slotData.specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP or 
             slotData.specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT))
  then return end
  

  if (currentTreasureMapItemID and currentTreasureMapItemID == slotData.itemID) then
    zo_callLater(
      function() LT:hideMiniTreasureMap() end, LT.SavedVariables.markerDeletionDelay * 1000 )
  end

  if slotData.specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP and LT.SavedVariables["treasureMarkMapMenuOption"] <= 2 then
    if LT.SavedVariables["treasureMarkMapMenuOption"] == 1 then
      if LT.listMarkOnUse["treasure"][slotData.itemID] then
        LT.listMarkOnUse["treasure"][slotData.itemID] = nil
      end
    end

    zo_callLater(
      function() LT:refreshTreasurePins() end,
      LT.SavedVariables.markerDeletionDelay * 1000 )
  end
  
  if slotData.specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT and LT.SavedVariables["surveysMarkMapMenuOption"] <= 2 then
    if LT.SavedVariables["surveysMarkMapMenuOption"] == 1 then
      if LT.listMarkOnUse["surveys"][slotData.itemID] then
        LT.listMarkOnUse["surveys"][slotData.itemID] = nil
      end
    end

    zo_callLater(
      function() LT:refreshSurveyPins() end,
      LT.SavedVariables.markerDeletionDelay * 1000 )
  end
end


local function createLAM2Panel()
  local treasureMapIcon  
  
  local panelData = {
    type = "panel",
    name = Addon.NameSpaced,
    displayName = ZO_HIGHLIGHT_TEXT:Colorize(Addon.NameSpaced),
    author = "|cFFA500"..Addon.Author.."|r",
    version = Addon.Version,
    registerForRefresh = true,
    registerForDefaults = true,
    website = Addon.WebSite,
  }

  local optionsData = {
    [1] = {
      type = "checkbox",
      name = GetString(LTS_TREASURE_ON_MAP),
      tooltip = GetString(LTS_TREASURE_ON_MAP_TOOLTIP),
      getFunc = function()
        return LT.SavedVariables.showTreasure
      end,
      setFunc = function(value)
        LT.SavedVariables.showTreasure = value
        LMP:SetEnabled(MAP_PIN_TYPES.treasure, value)
      end,
    },
    [2] = {
      type = "checkbox",
      name = GetString(LTS_TREASURE_ON_COMPASS),
      tooltip = GetString(LTS_TREASURE_ON_COMPASS_TOOLTIP),
      getFunc = function()
        return LT.SavedVariables.showTreasureCompass
      end,
      setFunc = function(value)
        LT.SavedVariables.showTreasureCompass = value
        COMPASS_PINS:RefreshPins(COMPASS_PIN_TYPES.treasure)
      end,
    },
    [3] = {
      type = "dropdown",
      name = GetString(LTS_TREASURE_ICON),
      tooltip = GetString(LTS_TREASURE_ICON_TOOLTIP),
      choices = pinTexturesList,
      getFunc = function() return pinTexturesList[LT.SavedVariables.treasurePinTexture] end,
      setFunc = function(value)
        for i,v in pairs(pinTexturesList) do
          if v == value then
            LT.SavedVariables.treasurePinTexture = i
            treasureMapIcon:SetTexture(pinTextures[i])
            LMP:SetLayoutKey(MAP_PIN_TYPES.treasure, "texture", pinTextures[i])
            LMP:RefreshPins(MAP_PIN_TYPES.treasure)
            COMPASS_PINS.pinLayouts[COMPASS_PIN_TYPES.treasure].texture = pinTextures[i]
            COMPASS_PINS:RefreshPins(COMPASS_PIN_TYPES.treasure)
            break
          end
        end
      end,
      reference = "LT_TreasureMapOption",
      disabled = function() return not LT.SavedVariables.showTreasure and not LT.SavedVariables.showTreasureCompass end,
    },
    [4] = {
      type = "dropdown",
      name = GetString(LTS_TREASURE_MARK_WHICH),
      tooltip = GetString(LTS_TREASURE_MARK_WHICH_TOOLTIP),
      choices = markMapMenuOptions,
      getFunc = function()
        return markMapMenuOptions[LT.SavedVariables.treasureMarkMapMenuOption]
      end,
      setFunc = function(value)
        for i,v in pairs(markMapMenuOptions) do
          if v == value then
            LT.SavedVariables.treasureMarkMapMenuOption = i
            LMP:RefreshPins(MAP_PIN_TYPES.treasure)
            COMPASS_PINS:RefreshPins(COMPASS_PIN_TYPES.treasure)
          else
            if LT.dirtyPins[i] then LT.dirtyPins[i].treasure = nil end
          end
        end
      end,
      disabled = function() return not LT.SavedVariables.showTreasure and not LT.SavedVariables.showTreasureCompass end,
    },
    [5] = {
      type = "checkbox",
      name = GetString(LTS_SURVEYS_ON_MAP),
      tooltip = GetString(LTS_SURVEYS_ON_MAP_TOOLTIP),
      getFunc = function() return LT.SavedVariables.showSurveys end,
      setFunc = function(value)
        LT.SavedVariables.showSurveys = value
        LMP:SetEnabled(MAP_PIN_TYPES.surveys, value)
      end,
    },
    [6] = {
      type = "checkbox",
      name = GetString(LTS_SURVEYS_ON_COMPASS),
      tooltip = GetString(LTS_SURVEYS_ON_COMPASS_TOOLTIP),
      getFunc = function() return LT.SavedVariables.showSurveysCompass end,
      setFunc = function(value)
        LT.SavedVariables.showSurveysCompass = value
        COMPASS_PINS:RefreshPins(COMPASS_PIN_TYPES.surveys)
      end,
    },
    [7] = {
      type = "dropdown",
      name = GetString(LTS_SURVEYS_ICON),
      tooltip = GetString(LTS_SURVEYS_ICON_TOOLTIP),
      choices = pinTexturesList,
      getFunc = function() return pinTexturesList[LT.SavedVariables.surveysPinTexture] end,
      setFunc = function(value)
        for i,v in pairs(pinTexturesList) do
          if v == value then
            LT.SavedVariables.surveysPinTexture = i
            surveysMapIcon:SetTexture(pinTextures[i])
            LMP:SetLayoutKey(MAP_PIN_TYPES.surveys, "texture", pinTextures[i])
              LMP:RefreshPins(MAP_PIN_TYPES.surveys)
              COMPASS_PINS.pinLayouts[COMPASS_PIN_TYPES.surveys].texture = pinTextures[i]
              COMPASS_PINS:RefreshPins(COMPASS_PIN_TYPES.surveys)
              break
          end
        end
      end,
      reference = "LT_SurveysMapOption",
      disabled = function() return not LT.SavedVariables.showSurveys and not LT.SavedVariables.showSurveysCompass end,
    },
    [8] = {
      type = "dropdown",
      name = GetString(LTS_SURVEYS_MARK_WHICH),
      tooltip = GetString(LTS_SURVEYS_MARK_WHICH_TOOLTIP),
      choices = markMapMenuOptions,
      getFunc = function() return markMapMenuOptions[LT.SavedVariables.surveysMarkMapMenuOption] end,
      setFunc = function(value)
        for i,v in pairs(markMapMenuOptions) do
          if v == value then
            LT.SavedVariables.surveysMarkMapMenuOption = i
            LMP:RefreshPins(MAP_PIN_TYPES.surveys)
            COMPASS_PINS:RefreshPins(COMPASS_PIN_TYPES.surveys)
          else
            if LT.dirtyPins[i] then 
              LT.dirtyPins[i].surveys = nil 
            end
          end
        end
      end,
      disabled = function() return not LT.SavedVariables.showSurveys and not LT.SavedVariables.showSurveysCompass end,
    },
    [9] = {
      type = "slider",
      name = GetString(LTS_PIN_SIZE),
      tooltip = GetString(LTS_PIN_SIZE_TOOLTIP),
      min = 12,
      max = 48,
      step = 2,
      getFunc = function() return LT.SavedVariables.pinTextureSize end,
      setFunc = function(value)
        LT.SavedVariables.pinTextureSize = value
        LMP:SetLayoutKey(MAP_PIN_TYPES.treasure, "size", value)
        LMP:SetLayoutKey(MAP_PIN_TYPES.surveys, "size", value)
        LMP:RefreshPins(MAP_PIN_TYPES.treasure)
        LMP:RefreshPins(MAP_PIN_TYPES.surveys)
      end,
    },
    [10] = {
      type = "checkbox",
      name = GetString(LTS_SHOW_MINIMAP),
      tooltip = GetString(LTS_SHOW_MINIMAP_TOOLTIP),
      getFunc = function() return LT.SavedVariables.showMiniTreasureMap end,
      setFunc = function(value) LT.SavedVariables.showMiniTreasureMap = value end,
    },
    [11] = {
      type = "slider",
      name = GetString(LTS_MARKER_DELAY),
      tooltip = GetString(LTS_MARKER_DELAY_TOOLTIP),
      min = 0,
      max = 60,
      step = 1,
      getFunc = function() return LT.SavedVariables.markerDeletionDelay end,
      setFunc = function(value)  LT.SavedVariables.markerDeletionDelay = value end,
    },
    [12] = {
      type = "slider",
      name = GetString(LTS_PIN_LEVEL),
      tooltip = GetString(LTS_PIN_LEVEL_TOOLTIP),
      min = 0,
      max = 250,
      step = 10,
      getFunc = function() return LT.SavedVariables.pinLevel end,
      setFunc = function(value)
        LT.SavedVariables.pinLevel = value
        LMP:SetLayoutKey(MAP_PIN_TYPES.treasure, "level", value)
        LMP:SetLayoutKey(MAP_PIN_TYPES.surveys, "level", value)
        LMP:RefreshPins(MAP_PIN_TYPES.treasure)
        LMP:RefreshPins(MAP_PIN_TYPES.surveys)
      end,
    }
  }

  local myPanel = LAM2:RegisterAddonPanel(Addon.Name.."LAM2Options", panelData)
  LAM2:RegisterOptionControls(Addon.Name.."LAM2Options", optionsData)

  local SetupLAMMapIcon = function(control)
    if control ~= myPanel then return end
    if not treasureMapIcon then
      treasureMapIcon = WINDOW_MANAGER:CreateControl(nil, LT_TreasureMapOption, CT_TEXTURE)
      treasureMapIcon:SetAnchor(RIGHT, LT_TreasureMapOption.dropdown:GetControl(), LEFT, -10, 0)
      treasureMapIcon:SetTexture(pinTextures[LT.SavedVariables.treasurePinTexture])
      treasureMapIcon:SetDimensions(32, 32)
    end
    if not surveysMapIcon then
      surveysMapIcon = WINDOW_MANAGER:CreateControl(nil, LT_SurveysMapOption, CT_TEXTURE)
      surveysMapIcon:SetAnchor(RIGHT, LT_SurveysMapOption.dropdown:GetControl(), LEFT, -10, 0)
      surveysMapIcon:SetTexture(pinTextures[LT.SavedVariables.surveysPinTexture])
      surveysMapIcon:SetDimensions(32, 32)
    end
    CALLBACK_MANAGER:UnregisterCallback("LAM-PanelControlsCreated", SetupLAMMapIcon)
  end
  CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", SetupLAMMapIcon)
end

function LT:EVENT_ADD_ON_LOADED(event, name)
  if name ~= Addon.Name then return end
  LT.SavedVariables = ZO_SavedVars:New("LOST_TREASURE_SV", 3, nil, LT.defaults)

  lang = GetCVar("Language.2")
  if lang == "de" then
    LOST_TREASURE_INDEX.MAP_NAME = LOST_TREASURE_INDEX.MAP_NAME_DE
  elseif lang == "fr" then
    LOST_TREASURE_INDEX.MAP_NAME = LOST_TREASURE_INDEX.MAP_NAME_FR
  elseif lang == "jp" then
    LOST_TREASURE_INDEX.MAP_NAME = LOST_TREASURE_INDEX.MAP_NAME_JP
  elseif lang == "ru" then
    LOST_TREASURE_INDEX.MAP_NAME = LOST_TREASURE_INDEX.MAP_NAME_RU
  elseif lang == "pl" then
    LOST_TREASURE_INDEX.MAP_NAME = LOST_TREASURE_INDEX.MAP_NAME_EN
  elseif lang == "br" then
    LOST_TREASURE_INDEX.MAP_NAME = LOST_TREASURE_INDEX.MAP_NAME_EN
  else
    lang = "en"
    LOST_TREASURE_INDEX.MAP_NAME = LOST_TREASURE_INDEX.MAP_NAME_EN
  end

  createMiniTreasureMap()
  EVENT_MANAGER:RegisterForEvent(Addon.Name, EVENT_SHOW_TREASURE_MAP, function(...) LT:EVENT_SHOW_TREASURE_MAP(...) end)
  EVENT_MANAGER:RegisterForEvent(Addon.Name, EVENT_SHOW_BOOK, function(...) LT:EVENT_SHOW_BOOK(...) end)

  SHARED_INVENTORY:RegisterCallback("SlotAdded", LT.SlotAdded, self)
  SHARED_INVENTORY:RegisterCallback("SlotRemoved", LT.SlotRemoved, self)

  pinLayout_Treasure.texture = pinTextures[LT.SavedVariables.treasurePinTexture]
  pinLayout_Treasure.size = LT.SavedVariables.pinTextureSize
  pinLayout_Treasure.level = LT.SavedVariables.pinLevel

  compassLayout_Treasure.texture = pinTextures[LT.SavedVariables.treasurePinTexture]
  LMP:AddPinType(MAP_PIN_TYPES.treasure, function() pinCreator("treasure") end, nil, pinLayout_Treasure, pinTooltipCreator)
  LMP:AddPinFilter(MAP_PIN_TYPES.treasure, "Lost Treasure Maps", false, LT.SavedVariables, "showTreasure")
  COMPASS_PINS:AddCustomPin(COMPASS_PIN_TYPES.treasure, function() compassCallback("treasure") end, compassLayout_Treasure)

  pinLayout_Surveys.texture = pinTextures[LT.SavedVariables.surveysPinTexture]
  pinLayout_Surveys.size = LT.SavedVariables.pinTextureSize
  pinLayout_Surveys.level = LT.SavedVariables.pinLevel

  compassLayout_Surveys.texture = pinTextures[LT.SavedVariables.surveysPinTexture]
  LMP:AddPinType(MAP_PIN_TYPES.surveys, function() pinCreator("surveys") end, nil, pinLayout_Surveys, pinTooltipCreator)
  LMP:AddPinFilter(MAP_PIN_TYPES.surveys, "Lost Treasure Survey Maps", false, LT.SavedVariables, "showSurveys")
  COMPASS_PINS:AddCustomPin(COMPASS_PIN_TYPES.surveys, function() compassCallback("surveys") end, compassLayout_Surveys)

  createLAM2Panel()

  OnGamepadPreferredModeChanged()
  EVENT_MANAGER:RegisterForEvent(Addon.Name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnGamepadPreferredModeChanged)

  EVENT_MANAGER:UnregisterForEvent(Addon.Name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(Addon.Name, EVENT_ADD_ON_LOADED, function(...) LT:EVENT_ADD_ON_LOADED(...) end)
