local Tinkr, Bastion = ...

-- Create a new DrawLine class
---@class DrawLine
local DrawLine = {}
DrawLine.__index = DrawLine

-- Default configuration
local DEFAULT_CONFIG = {
    color = { r = 255, g = 0, b = 0 },
    width = 3,
    alpha = 255
}

---Create a deep copy of a table so defaults never leak
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

---Merge defaults into a config table (non-destructive for nested tables)
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

-- Constructor
---@param config? table
---@return DrawLine
function DrawLine:New(config)
    local self = setmetatable({}, DrawLine)
    
    self.config = config and deepCopy(config) or {}
    self:MergeConfig(DEFAULT_CONFIG)
    
    self.enabled = false
    self.draw = Tinkr.Util.Draw:New()
    
    return self
end

-- Merge default config with provided config
---@param defaults table
---@return nil
function DrawLine:MergeConfig(defaults)
    self.config = mergeDefaults(self.config or {}, defaults)
end

-- Reset config with a new table and apply defaults
---@param config? table
---@return nil
function DrawLine:SetConfig(config)
    self.config = config and deepCopy(config) or {}
    self:MergeConfig(DEFAULT_CONFIG)
    self:ApplyStyle()
end

-- Apply draw style so every primitive shares the same look
---@param draw? table
---@return nil
function DrawLine:ApplyStyle(draw)
    draw = draw or self.draw
    if not draw then
        return
    end

    local color = self.config.color
    draw:SetColor(color.r, color.g, color.b)
    draw:SetWidth(self.config.width)
    draw:SetAlpha(self.config.alpha)
end

-- Setup default sync function (draw line from player to target)
---@return nil
function DrawLine:SetupDefaultSync()
    self.draw:Sync(function(draw)
        if not self.enabled then
            return
        end

        local Target = Bastion.UnitManager:Get('target')
        if not Target:Exists() or not Target:IsAlive() then
            return
        end

        local px, py, pz = ObjectRawPosition('player')
        local tx, ty, tz = ObjectRawPosition('target')

        if px and py and pz and tx and ty and tz then
            self:ApplyStyle(draw)
            draw:Line(px, py, pz, tx, ty, tz)
        end
    end)
end

-- Setup custom sync function
---@param func function
---@return nil
function DrawLine:SetupSync(func)
    self.syncFunc = func
    self.draw:Sync(function(draw)
        if not self.enabled then
            return
        end
        self:ApplyStyle(draw)
        func(draw, self)
    end)
end

-- Enable drawing
---@return nil
function DrawLine:Enable()
    self.enabled = true
    self.draw:Enable()
end

-- Disable drawing
---@return nil
function DrawLine:Disable()
    self.enabled = false
    self.draw:Disable()
end

-- Toggle drawing
---@return boolean
function DrawLine:Toggle()
    if self.enabled then
        self:Disable()
    else
        self:Enable()
    end
    return self.enabled
end

-- Check if enabled
---@return boolean
function DrawLine:IsEnabled()
    return self.enabled
end

-- Set color
---@param r number
---@param g number
---@param b number
---@return nil
function DrawLine:SetColor(r, g, b)
    self.config.color = { r = r, g = g, b = b }
    self:ApplyStyle()
end

-- Set width
---@param width number
---@return nil
function DrawLine:SetWidth(width)
    if width and width > 0 then
        self.config.width = width
    end
    self:ApplyStyle()
end

-- Set alpha
---@param alpha number
---@return nil
function DrawLine:SetAlpha(alpha)
    self.config.alpha = math.max(0, math.min(255, alpha))
    self:ApplyStyle()
end

-- Draw a line between two points
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return nil
function DrawLine:Line(x1, y1, z1, x2, y2, z2)
    if not self.enabled then
        return
    end
    self:ApplyStyle()
    self.draw:Line(x1, y1, z1, x2, y2, z2)
end

-- Draw a line between two units
---@param unit1 Unit
---@param unit2 Unit
---@return nil
function DrawLine:LineBetweenUnits(unit1, unit2)
    if not self.enabled then
        return
    end
    
    if not unit1:Exists() or not unit2:Exists() then
        return
    end
    
    local p1 = unit1:GetPosition()
    local p2 = unit2:GetPosition()

    if not p1 or not p2 then
        return
    end
    
    self:ApplyStyle()
    self.draw:Line(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z)
end

-- Draw a circle around a position
---@param x number
---@param y number
---@param z number
---@param radius number
---@param segments? number
---@return nil
function DrawLine:Circle(x, y, z, radius, segments)
    if not self.enabled then
        return
    end

    segments = math.max(segments or 32, 3)
    if radius <= 0 then
        return
    end
    
    local step = (2 * math.pi) / segments
    self:ApplyStyle()
    
    for i = 0, segments - 1 do
        local angle1 = i * step
        local angle2 = (i + 1) * step
        
        local x1 = x + radius * math.cos(angle1)
        local y1 = y + radius * math.sin(angle1)
        local x2 = x + radius * math.cos(angle2)
        local y2 = y + radius * math.sin(angle2)
        
        self.draw:Line(x1, y1, z, x2, y2, z)
    end
end

-- Draw a circle around a unit
---@param unit Unit
---@param radius number
---@param segments? number
---@return nil
function DrawLine:CircleAroundUnit(unit, radius, segments)
    if not self.enabled or not unit:Exists() then
        return
    end
    
    local pos = unit:GetPosition()
    if not pos then
        return
    end
    self:Circle(pos.x, pos.y, pos.z, radius, segments)
end

-- tostring
---@return string
function DrawLine:__tostring()
    return "Bastion.__DrawLine(" .. (self.enabled and "enabled" or "disabled") .. ")"
end

return DrawLine








