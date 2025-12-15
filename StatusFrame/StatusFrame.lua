local Tinkr, Bastion = ...

-- Create a new StatusFrame class
---@class StatusFrame
local StatusFrame = {}
StatusFrame.__index = StatusFrame

-- Default configuration
local DEFAULT_CONFIG = {
    size = 48,
    position = { point = "CENTER", x = -500, y = 300 },
    icon = "Interface\\Icons\\Ability_Hunter_RunningShot",
    enabledColor = { r = 1, g = 2, b = 1, a = 1 },
    disabledColor = { r = 0.4, g = 0.4, b = 0.4, a = 0.8 }
}

local ICON_FILE = "status_frame_icon"
local ICON_REQUIRE_PATH = "~src/StatusFrame/" .. ICON_FILE
local ICON_FILE_PATH = "scripts/bastion/src/StatusFrame/" .. ICON_FILE .. ".lua"
local POSITION_FILE = "status_frame_position"
local POSITION_REQUIRE_PATH = "~src/StatusFrame/" .. POSITION_FILE
local POSITION_FILE_PATH = "scripts/bastion/src/StatusFrame/" .. POSITION_FILE .. ".lua"

---Create a deep copy so shared defaults are never mutated
---@param value any
---@return any
local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepCopy(v)
    end
    return copy
end

---Merge defaults into a config table without overriding nested tables
---@param config table
---@param defaults table
---@return table
local function mergeDefaults(config, defaults)
    for k, v in pairs(defaults) do
        if config[k] == nil then
            config[k] = deepCopy(v)
        elseif type(v) == "table" and type(config[k]) == "table" then
            mergeDefaults(config[k], v)
        end
    end

    return config
end

local function loadSavedIcon()
    local ok, result = pcall(function()
        if Bastion and Bastion.Require then
            return Bastion:Require(ICON_REQUIRE_PATH)
        end
        return require(ICON_FILE)
    end)

    if ok and type(result) == "table" then
        return result.icon
    end

    if not ok and Bastion and Bastion.Debug then
        Bastion:Debug("StatusFrame icon load failed:", result)
    end

    return nil
end

local function saveIcon(icon)
    if not icon then
        return false
    end

    local code = string.format([[return {
    icon = %q,
}
]], icon)

    local saved = WriteFile(ICON_FILE_PATH, code, false)

    if not saved and Bastion and Bastion.Debug then
        Bastion:Debug("StatusFrame icon save failed:", icon)
    end

    return saved
end

local function loadSavedPosition()
    local ok, result = pcall(function()
        if Bastion and Bastion.Require then
            return Bastion:Require(POSITION_REQUIRE_PATH)
        end
        return require(POSITION_FILE)
    end)

    if ok and type(result) == "table" then
        return {
            point = result.point or "CENTER",
            relative = result.relative or "UIParent",
            relativePoint = result.relativePoint or "CENTER",
            x = result.x or 0,
            y = result.y or 0
        }
    end

    if not ok and Bastion and Bastion.Debug then
        Bastion:Debug("StatusFrame position load failed:", result)
    end

    return nil
end

local function savePosition(pos)
    if not pos then
        return false
    end

    local code = string.format([[return {
    point = %q,
    relative = "UIParent",
    relativePoint = %q,
    x = %f,
    y = %f,
}
]], pos.point, pos.relativePoint, pos.x, pos.y)

    local saved = WriteFile(POSITION_FILE_PATH, code, false)

    if not saved and Bastion and Bastion.Debug then
        Bastion:Debug("StatusFrame position save failed:", pos.point, pos.relativePoint, pos.x, pos.y)
    end

    return saved
end

-- Constructor
---@param config? table
---@return StatusFrame
function StatusFrame:New(config)
    local self = setmetatable({}, StatusFrame)
    
    self.config = config and deepCopy(config) or {}
    self:MergeConfig(DEFAULT_CONFIG)

    local savedPos = loadSavedPosition()
    if savedPos then
        self.config.position = {
            point = savedPos.point,
            relativePoint = savedPos.relativePoint,
            x = savedPos.x,
            y = savedPos.y
        }
    end

    local savedIcon = loadSavedIcon()
    if savedIcon then
        self.config.icon = savedIcon
    end

    self.enabled = true
    self.modulesRef = {}
    
    self:CreateFrame()
    self:CreateTexture()
    self:SetupDragging()
    self:Update()
    
    return self
end

-- Merge default config with provided config
---@param defaults table
---@return nil
function StatusFrame:MergeConfig(defaults)
    self.config = mergeDefaults(self.config or {}, defaults)
end

-- Create the main frame
---@return nil
function StatusFrame:CreateFrame()
    self.frame = CreateFrame("Frame", "BastionStatusFrame", UIParent)
    self.frame:SetSize(self.config.size, self.config.size)
    self.frame:SetPoint(
        self.config.position.point,
        UIParent,
        self.config.position.relativePoint or self.config.position.point,
        self.config.position.x,
        self.config.position.y
    )
end

-- Create the texture
---@return nil
function StatusFrame:CreateTexture()
    self.texture = self.frame:CreateTexture(nil, "ARTWORK")
    self.texture:SetAllPoints()
    self.texture:SetTexture(self.config.icon)
end

-- Setup dragging functionality
---@return nil
function StatusFrame:SetupDragging()
    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)
    self.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()

        local point, _, relativePoint, x, y = frame:GetPoint()
        self.config.position = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y
        }
        savePosition({
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y
        })
    end)
end

-- Enable the status frame logic and visuals
---@return nil
function StatusFrame:Enable()
    if self.enabled then
        return
    end
    self.enabled = true
    self:Update()
end

-- Disable the status frame logic and visuals
---@return nil
function StatusFrame:Disable()
    if not self.enabled then
        return
    end
    self.enabled = false
    self:Hide()
end

-- Check if the status frame is enabled
---@return boolean
function StatusFrame:IsEnabled()
    return self.enabled
end

-- Set modules reference for status checking
---@param modules? table
---@return nil
function StatusFrame:SetModulesRef(modules)
    self.modulesRef = modules or {}
    self:Update()
end

-- Check if any module is enabled
---@return boolean
function StatusFrame:IsAnyModuleEnabled()
    if not self.modulesRef or #self.modulesRef == 0 then
        return false
    end
    
    for i = 1, #self.modulesRef do
        local module = self.modulesRef[i]
        if module then
            if type(module.IsEnabled) == "function" then
                if module:IsEnabled() then
                    return true
                end
            elseif module.enabled then
                return true
            end
        end
    end
    
    return false
end

-- Apply the correct visual state
---@param anyEnabled boolean
---@return nil
function StatusFrame:ApplyState(anyEnabled)
    if not self.texture then
        return
    end
    
    local color = anyEnabled and self.config.enabledColor or self.config.disabledColor
    self.texture:SetDesaturated(not anyEnabled)
    self.texture:SetVertexColor(
        color.r,
        color.g,
        color.b,
        color.a
    )
end

-- Update the display based on module states
---@return nil
function StatusFrame:Update()
    if not self.enabled then
        self:Hide()
        return
    end
    
    self:Show()
    
    local anyEnabled = self:IsAnyModuleEnabled()
    self:ApplyState(anyEnabled)
end

-- Show the frame
---@return nil
function StatusFrame:Show()
    if self.frame then
        self.frame:Show()
    end
end

-- Hide the frame
---@return nil
function StatusFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- Toggle visibility
---@return nil
function StatusFrame:Toggle()
    if self.enabled then
        self:Disable()
    else
        self:Enable()
    end
end

-- Set icon texture
---@param icon string
---@return nil
function StatusFrame:SetIcon(icon)
    self.config.icon = icon
    self.texture:SetTexture(icon)
    saveIcon(icon)
end

-- Set position
---@param point string
---@param x number
---@param y number
---@return nil
function StatusFrame:SetPosition(point, x, y)
    self.config.position = { point = point, relativePoint = point, x = x, y = y }
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, UIParent, point, x, y)
    savePosition({
        point = point,
        relativePoint = point,
        x = x,
        y = y
    })
end

-- Set size
---@param size number
---@return nil
function StatusFrame:SetSize(size)
    self.config.size = size
    self.frame:SetSize(size, size)
end

-- Get frame
---@return Frame
function StatusFrame:GetFrame()
    return self.frame
end

-- tostring
---@return string
function StatusFrame:__tostring()
    return "Bastion.__StatusFrame(" .. (self.enabled and "enabled" or "disabled") .. ")"
end

return StatusFrame

