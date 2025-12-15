-- HunterUI Class
-- =============================================

local Tinkr, Bastion = ...

---@class HunterUI
local HunterUI = {}
HunterUI.__index = HunterUI

local function trim(str)
    if not str then return str end
    return (str:gsub("^%s+", "")):gsub("%s+$", "")
end

-- =============================================
-- Constructor
-- =============================================
---@return HunterUI
function HunterUI:New()
    local self = setmetatable({}, HunterUI)
    
    -- Initialize states
    self.states = {
        blackArrow = false,
        explosiveTrap = true,
        normal = true,
        aoe = false,
        aoeAuto = false,
        simple = false,
        aimedShot = false,
        multiShot = true,
        petAttack = true,
        petFollow = false,
        viperSting = false,
        autoTarget = true,
        growl = true
    }
    
    -- Initialize frame
    self:CreateMainFrame()
    self:CreateButtons()
    self:UpdateStates()
    self:RegisterSlashCommands()
    
    return self
end

-- =============================================
-- State Management
-- =============================================
---@param stateName string
---@param exclusiveWith? table
---@return nil
function HunterUI:ToggleState(stateName, exclusiveWith)
    local oldState = self.states[stateName]
    self.states[stateName] = not oldState
    if self.states[stateName] and exclusiveWith then
        for _, state in ipairs(exclusiveWith) do
            self.states[state] = false
        end
    end
    self:UpdateStates(stateName, oldState)
end

---@param stateName string
---@param state? string
---@return nil
function HunterUI:OptimizedToggle(stateName, state)
    local oldState = self.states[stateName]
    -- 去除参数首尾空格
    if state then
        state = trim(state)
    end
    if state == "on" then
        self.states[stateName] = true
    elseif state == "off" then
        self.states[stateName] = false
    else
        self.states[stateName] = not oldState
    end
    self:UpdateStates(stateName, oldState)
end

-- =============================================
-- UI Creation
-- =============================================
---@return nil
function HunterUI:CreateMainFrame()
    -- 1. 创建框体
    self.frame = CreateFrame("Frame", "MainFrame", UIParent)
    self.frame:SetSize(420, 90)

    -- 2. 默认位置
    self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    self.frame:SetMovable(true)
    self.frame:EnableMouse(true)
    self.frame:RegisterForDrag("LeftButton")
    self.frame:SetScript("OnDragStart", self.frame.StartMoving)

    -- 3. 拖动结束时：仅停止移动（不保存位置）
    self.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
    end)
end

---@param name string
---@param parent Frame
---@param icon string
---@param label string
---@param onClick function
---@return Button
function HunterUI:CreateButton(name, parent, icon, label, onClick)
    local button = CreateFrame("Button", name, parent, "ActionButtonTemplate")
    button:SetSize(36, 36)
    button.icon = _G[button:GetName().."Icon"]
    button.icon:SetTexture(icon)
    button:SetScript("OnClick", onClick)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("BOTTOM", button, "BOTTOM", 0, -10)
    button.text:SetText(label)
    return button
end

---@return nil
function HunterUI:CreateButtons()
    local buttonConfigs = {
        -- 第一行：技能相关
        { name = "BlackArrowButton",    state = "blackArrow",    icon = "Interface\\Icons\\spell_shadow_painspike",           label = "黑箭",   exclusive = {"explosiveTrap"}, row = 1 },
        { name = "ExplosiveTrapButton", state = "explosiveTrap", icon = "Interface\\Icons\\Spell_Fire_SelfDestruct",          label = "爆炸",   exclusive = {"blackArrow"}, row = 1 },
        { name = "AimedShotButton",     state = "aimedShot",     icon = "Interface\\Icons\\inv_spear_07",                     label = "瞄准",   exclusive = {"multiShot"}, row = 1 },
        { name = "MultiShotButton",     state = "multiShot",     icon = "Interface\\Icons\\ability_upgrademoonglaive",       label = "多重",   exclusive = {"aimedShot"}, row = 1 },
        { name = "AOEAutoButton",       state = "aoeAuto",       icon = "Interface\\Icons\\Spell_Holy_CircleOfRenewal",      label = "AOE", row = 1 },
        -- 第二行：宠物和功能相关
        { name = "PetAttackButton",     state = "petAttack",     icon = "Interface\\Icons\\Ability_Physical_Taunt",          label = "攻击",   exclusive = {"petFollow"}, row = 2 },
        { name = "PetFollowButton",     state = "petFollow",     icon = "Interface\\Icons\\Spell_Nature_Spiritwolf",         label = "跟随",   exclusive = {"petAttack"}, row = 2 },
        { name = "GrowlButton",         state = "growl",         icon = "Interface\\Icons\\ability_physical_taunt",         label = "低吼", row = 2 },
        { name = "ViperStingButton",    state = "viperSting",    icon = "Interface\\Icons\\ability_hunter_aspectoftheviper", label = "蚰蛇", row = 2 },
        { name = "AutoTargetButton",    state = "autoTarget",    icon = "Interface\\Icons\\ability_hunter_snipershot",       label = "切目标", row = 2 },
    }

    self.buttonStateMap = {}  -- 建立按钮与状态的映射

    local lastButtonRow1 = nil
    local lastButtonRow2 = nil
    
    for _, config in ipairs(buttonConfigs) do
        local button = self:CreateButton(
            config.name,
            self.frame,
            config.icon,
            config.label,
            function() self:ToggleState(config.state, config.exclusive) end
        )

        if config.row == 1 then
            if lastButtonRow1 then
                button:SetPoint("LEFT", lastButtonRow1, "RIGHT", 10, 0)
            else
                button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -5)
            end
            lastButtonRow1 = button
        else
            if lastButtonRow2 then
                button:SetPoint("LEFT", lastButtonRow2, "RIGHT", 10, 0)
            else
                button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 10, -51)
            end
            lastButtonRow2 = button
        end

        self[config.name] = button
        self.buttonStateMap[config.state] = button
    end
end

-- =============================================
-- UI State Update
-- =============================================
---@param button Button
---@param isActive boolean
---@return nil
function HunterUI:UpdateButtonState(button, isActive)
    local brightness = isActive and 1 or 0.4
    button.icon:SetVertexColor(brightness, brightness, brightness)
end

---@param changedState? string
---@param oldState? boolean
---@return nil
function HunterUI:UpdateStates(changedState, oldState)
    -- 打印状态变化信息
    if changedState then
        local newState = self.states[changedState]
        if newState ~= oldState then
            local stateText = newState and "启用" or "禁用"
            local color = newState and "|cff00ff00" or "|cffff0000"
            print(changedState .. " 现在是 " .. color .. stateText .. "|r")
        end
    end

    -- 通过映射表更新所有按钮状态
    for stateName, button in pairs(self.buttonStateMap) do
        self:UpdateButtonState(button, self.states[stateName])
    end
end

-- =============================================
-- Slash Commands
-- =============================================
---@return nil
function HunterUI:RegisterSlashCommands()
    -- 使用 Bastion.Command 系统注册命令
    local HunterCommand = Bastion.Command:New('hunter')
    
    HunterCommand:Register('normal', '切换默认模式 (on/off)', function(args)
        local state = args[2] and string.lower(args[2]) or ""
        self:OptimizedToggle("normal", state)
    end)
    
    HunterCommand:Register('aoe', '切换AOE模式 (on/off)', function(args)
        local state = args[2] and string.lower(args[2]) or ""
        self:OptimizedToggle("aoe", state)
    end)
    
    HunterCommand:Register('simple', '切换简单模式 (on/off)', function(args)
        local state = args[2] and string.lower(args[2]) or ""
        self:OptimizedToggle("simple", state)
    end)
    
    HunterCommand:Register('ui', '显示UI界面', function(args)
        self.frame:Show()
    end)
    
    print("|cff00ff00[HERUI]|r 注册命令: /hunter normal, /hunter aoe, /hunter simple, /hunter ui")
end

-- =============================================
-- State Getter Methods
-- =============================================
---@param stateName string
---@return function
function HunterUI:GetState(stateName)
    return function()
        return self.states[stateName]
    end
end

-- =============================================
-- Export API
-- =============================================
---@return table
function HunterUI:BuildExports()
    local exports = {
        BlackArrow = self:GetState("blackArrow"),
        ExplosiveTrap = self:GetState("explosiveTrap"),
        Normal = self:GetState("normal"),
        Simple = self:GetState("simple"),
        AimedShot = self:GetState("aimedShot"),
        MultiShot = self:GetState("multiShot"),
        PetAttack = self:GetState("petAttack"),
        PetFollow = self:GetState("petFollow"),
        ViperSting = self:GetState("viperSting"),
        AOE = function() return self:HERUIAOE() end,
        AOEAuto = function() return self:HERUIAOEAuto() end,
        AutoTarget = self:GetState("autoTarget"),
        Growl = self:GetState("growl")
    }

    -- 统一入口，方便按名字取状态
    function exports:State(name)
        local getter = self[name]
        if getter then
            return getter()
        end
        return nil
    end

    return exports
end

-- =============================================
-- Special AOE State Getters
-- =============================================
function HunterUI:HERUIAOE()
    return self.states.aoe
end

function HunterUI:HERUIAOEAuto()
    return self.states.aoeAuto
end

-- tostring
---@return string
function HunterUI:__tostring()
    return "Bastion.__HunterUI"
end

-- =============================================
-- Initialize & API Registration
-- =============================================
local hunterUI = HunterUI:New()
if hunterUI then
    Bastion.Globals = Bastion.Globals or {}
    Bastion.Globals.HERUI = hunterUI:BuildExports()
    Bastion:Debug("HERUI exports registered to Bastion.Globals")
    print("|cff00ff00[HERUI]|r Hunter 模块已加载")
end
