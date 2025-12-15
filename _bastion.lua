local Tinkr = ...

local Evaulator = Tinkr.Evaluator

---@class Bastion
local Bastion = {DebugMode = false}
Bastion.__index = Bastion

function Bastion:Require(file)
    -- If require starts with an @ then we require from the scripts/bastion/scripts folder
    if file:sub(1, 1) == '@' then
        file = file:sub(2)
        return require('scripts/bastion/scripts/' .. file, Bastion)
    elseif file:sub(1, 1) == "~" then
        file = file:sub(2)
        return require('scripts/bastion/' .. file, Bastion)
    else
        return require(file, Bastion)
    end
end

local function Load(dir)
    local dir = dir

    if dir:sub(1, 1) == '@' then
        dir = dir:sub(2)
        dir = 'scripts/bastion/scripts/' .. dir
    end

    if dir:sub(1, 1) == '~' then
        dir = dir:sub(2)
        dir = 'scripts/bastion/' .. dir
    end

    local files = ListFiles(dir)

    for i = 1, #files do
        local file = files[i]
        if file:sub(-4) == ".lua" or file:sub(-5) == '.luac' then
            local fileName = file:sub(1, -5)
            Bastion:Require(dir .. fileName)
        end
    end
end

function Bastion.require(class)
    return Bastion:Require("~/src/" .. class .. "/" .. class)
end

-- Bootstrap function for initializing all required files
function Bastion.Bootstrap()
    local LIBRARIES = {}
    local MODULES = {}

    Bastion.Globals = {}

    -- ===================== 核心类加载 =====================
    ---@type ClassMagic
    Bastion.ClassMagic = Bastion.require("ClassMagic")
    ---@type List
    Bastion.List = Bastion.require("List")
    ---@type Library
    Bastion.Library = Bastion.require("Library")
    ---@type NotificationsList, Notification
    Bastion.NotificationsList, Bastion.Notification = Bastion.require("NotificationsList")
    ---@type Vector3
    Bastion.Vector3 = Bastion.require("Vector3")
    ---@type Sequencer
    Bastion.Sequencer = Bastion.require("Sequencer")
    ---@type Command
    Bastion.Command = Bastion.require("Command")
    ---@type Cache
    Bastion.Cache = Bastion.require("Cache")
    ---@type Cacheable
    Bastion.Cacheable = Bastion.require("Cacheable")
    ---@type Refreshable
    Bastion.Refreshable = Bastion.require("Refreshable")
    ---@type Unit
    Bastion.Unit = Bastion.require("Unit")
    ---@type Aura
    Bastion.Aura = Bastion.require("Aura")
    ---@type APL, APLActor, APLTrait
    Bastion.APL, Bastion.APLActor, Bastion.APLTrait = Bastion.require("APL")
    ---@type Module
    Bastion.Module = Bastion.require("Module")
    ---@type UnitManager
    Bastion.UnitManager = Bastion.require("UnitManager"):New()
    ---@type ObjectManager
    Bastion.ObjectManager = Bastion.require("ObjectManager"):New()
    ---@type EventManager
    Bastion.EventManager = Bastion.require("EventManager")
    Bastion.Globals.EventManager = Bastion.EventManager:New()
    ---@type Spell
    Bastion.Spell = Bastion.require("Spell")
    ---@type SpellBook
    Bastion.SpellBook = Bastion.require("SpellBook")
    Bastion.Globals.SpellBook = Bastion.SpellBook:New()
    ---@type Item
    Bastion.Item = Bastion.require("Item")
    ---@type ItemBook
    Bastion.ItemBook = Bastion.require("ItemBook")
    Bastion.Globals.ItemBook = Bastion.ItemBook:New()
    ---@type AuraTable
    Bastion.AuraTable = Bastion.require("AuraTable")
    ---@type Class
    Bastion.Class = Bastion.require("Class")
    ---@type Timer
    Bastion.Timer = Bastion.require("Timer")
    ---@type Timer
    Bastion.CombatTimer = Bastion.Timer:New('combat')
    ---@type MythicPlusUtils
    Bastion.MythicPlusUtils = Bastion.require("MythicPlusUtils"):New()
    ---@type NotificationsList
    Bastion.Notifications = Bastion.NotificationsList:New()

    -- ===================== UI 系统初始化 =====================
    ---@type StatusFrame
    Bastion.StatusFrame = Bastion.require("StatusFrame")
    ---@type DrawLine
    Bastion.DrawLine = Bastion.require("DrawLine")

    -- 创建 UI 容器
    Bastion.UI = {}

    -- 初始化状态框架
    Bastion.UI.StatusFrame = Bastion.StatusFrame:New({
        size = 48,
        position = { point = "CENTER", x = -500, y = 300 },
        icon = "Interface\\Icons\\Ability_Hunter_RunningShot"
    })

    -- 初始化绘制线条功能
    Bastion.UI.DrawLine = Bastion.DrawLine:New({
        color = { r = 255, g = 0, b = 0 },
        width = 3,
        alpha = 255
    })
    Bastion.UI.DrawLine:SetupDefaultSync()

    -- ===================== 状态显示更新函数 =====================
    function Bastion:UpdateStatusDisplay()
        Bastion.UI.StatusFrame:SetModulesRef(MODULES)
        Bastion.UI.StatusFrame:Update()
    end

    -- ===================== 核心系统初始化完成 =====================

    -- 初始化游戏单位引用
    local Player = Bastion.UnitManager:Get('player')
    local Focus = Bastion.UnitManager:Get('focus')

    -- 初始化法术引用
    local TranquilizingShot = Bastion.Globals.SpellBook:GetSpell(19801)  -- 宁神射击
    local Frenzy = Bastion.Globals.SpellBook:GetSpell(72143)  -- 激怒（原有检测）
    local Enrage = Bastion.Globals.SpellBook:GetSpell(19451)  -- 激怒（新增检测）

    -- 初始化战斗日志相关变量
    local pguid = UnitGUID("player")
    local missed = {}

    -- 状态显示初始化
    Bastion:UpdateStatusDisplay()

    -- ===================== 事件注册 =====================
    -- 注册单位光环更新事件
    Bastion.Globals.EventManager:RegisterWoWEvent('UNIT_AURA', function(unit, auras)
        local u = Bastion.UnitManager[unit]
        if u then
            u:GetAuras():OnUpdate(auras)
        end
    end)

    -- 注册法术施放成功事件
    Bastion.Globals.EventManager:RegisterWoWEvent("UNIT_SPELLCAST_SUCCEEDED", function(...)
        local unit, _, spellID = ...
        local spell = Bastion.Globals.SpellBook:GetIfRegistered(spellID)

        if unit == "player" and spell then
            spell.lastCastAt = GetTime()
            if spell:GetPostCastFunction() then
                spell:GetPostCastFunction()(spell)
            end
        end
    end)

    -- 注册战斗日志事件
    Bastion.Globals.EventManager:RegisterWoWEvent("COMBAT_LOG_EVENT_UNFILTERED", function()
        local args = {CombatLogGetCurrentEventInfo()}

        local subEvent = args[2]
        local sourceGUID = args[4]
        local destGUID = args[8]
        local spellID = args[12]

        local u = Bastion.UnitManager[sourceGUID]
        local u2 = Bastion.UnitManager[destGUID]

        local t = GetTime()

        if u then
            u:SetLastCombatTime(t)
        end

        if u2 then
            u2:SetLastCombatTime(t)

            if subEvent == "SPELL_MISSED" and sourceGUID == pguid and spellID == 408 then
                local missType = args[15]
                if missType == "IMMUNE" then
                    local castingSpell = u:GetCastingOrChannelingSpell()
                    if castingSpell then
                        if not missed[castingSpell:GetID()] then
                            missed[castingSpell:GetID()] = true
                        end
                    end
                end
            end
        end
    end)

    -- ===================== 主循环定时器 =====================
    Bastion.Ticker = C_Timer.NewTicker(0.1, function()
        -- 战斗计时器管理
        if not Bastion.CombatTimer:IsRunning() and UnitAffectingCombat("player") then
            Bastion.CombatTimer:Start()
        elseif Bastion.CombatTimer:IsRunning() and not UnitAffectingCombat("player") then
            Bastion.CombatTimer:Reset()
        end

        -- 宁神射击功能（猎人专用，独立于模块系统）
        local _, class = UnitClass("player")
        if class == "HUNTER"
            and TranquilizingShot:GetCooldownRemaining() < 1.5
            and Focus:Exists()
            and Focus:IsAlive()
            and Focus:IsEnemy()
            and (Focus:GetAuras():FindAny(Frenzy):IsUp() or Focus:GetAuras():FindAny(Enrage):IsUp())
            and TranquilizingShot:IsInRange(Focus)
        then
            if Player:IsCastingOrChanneling() then
                SpellStopCasting()
            end

            if not Player:IsFacing(Focus) then
                FaceObject('focus')
            end

            TranquilizingShot:ForceCast(Focus)
        end

        -- 对象管理器刷新
        Bastion.ObjectManager:Refresh()

        -- 执行所有已注册的模块
        for i = 1, #MODULES do
            MODULES[i]:Tick()
        end
    end)

    -- ===================== 模块管理函数 =====================
    function Bastion:Register(module)
        table.insert(MODULES, module)
        Bastion:Print("Registered", module)
    end

    function Bastion:FindModule(name)
        for i = 1, #MODULES do
            if MODULES[i].name == name then
                return MODULES[i]
            end
        end
        return nil
    end

    -- ===================== 日志输出函数 =====================
    function Bastion:Print(...)
        local args = {...}
        local str = "|cFFDF362D[Bastion]|r |cFFFFFFFF"
        for i = 1, #args do
            str = str .. tostring(args[i]) .. " "
        end
        print(str)
    end

    function Bastion:Debug(...)
        if not Bastion.DebugMode then
            return
        end
        local args = {...}
        local str = "|cFFDF6520[Bastion]|r |cFFFFFFFF"
        for i = 1, #args do
            str = str .. tostring(args[i]) .. " "
        end
        print(str)
    end

    -- ===================== 命令注册 =====================
    local Command = Bastion.Command:New('bastion')

    Command:Register('debug', 'Toggle debug mode on/off', function()
        Bastion.DebugMode = not Bastion.DebugMode
        if Bastion.DebugMode then
            Bastion:Print("Debug mode enabled")
        else
            Bastion:Print("Debug mode disabled")
        end
    end)

    Command:Register('dumpspells', 'Dump spells to a file', function()
        local i = 1
        local rand = math.random(100000, 999999)
        local BOOKTYPE_SPELL = BOOKTYPE_SPELL or (Enum.SpellBookSpellBank.Player and Enum.SpellBookSpellBank.Player or 'spell')
        while true do
            local spellName, spellSubName

            if C_SpellBook.GetSpellBookItemName then
                spellName, spellSubName = C_SpellBook.GetSpellBookItemName(i, BOOKTYPE_SPELL)
            else
                spellName, spellSubName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            end

            if not spellName then
                break
            end

            local spellID
            if C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(spellName)
                spellID = info.spellID
            else
                spellID = select(7, GetSpellInfo(spellName))
            end

            if spellID then
                spellName = spellName:gsub("[%W%s]", "")
                WriteFile(
                    'bastion-' .. UnitClass('player') .. '-' .. rand .. '.lua',
                    "local " .. spellName .. " = Bastion.Globals.SpellBook:GetSpell(" .. spellID .. ")\n",
                    true
                )
            end
            i = i + 1
        end
    end)

    Command:Register('module', 'Toggle a module on/off', function(args)
        local module = Bastion:FindModule(args[2])
        if module then
            module:Toggle()
            if module.enabled then
                Bastion:Print("Enabled", module.name)
            else
                Bastion:Print("Disabled", module.name)
            end
            Bastion:UpdateStatusDisplay()
        else
            Bastion:Print("Module not found")
        end
    end)

    Command:Register('mplus', 'Toggle m+ module on/off', function(args)
        local cmd = args[2]
        if cmd == 'debuffs' then
            Bastion.MythicPlusUtils:ToggleDebuffLogging()
            Bastion:Print("Debuff logging", Bastion.MythicPlusUtils.debuffLogging and "enabled" or "disabled")
            return
        end

        if cmd == 'casts' then
            Bastion.MythicPlusUtils:ToggleCastLogging()
            Bastion:Print("Cast logging", Bastion.MythicPlusUtils.castLogging and "enabled" or "disabled")
            return
        end

        Bastion:Print("[MythicPlusUtils] Unknown command")
        Bastion:Print("Available commands:")
        Bastion:Print("debuffs")
        Bastion:Print("casts")
    end)

    Command:Register('missed', 'Dump the list of immune kidney shot spells', function()
        for k, v in pairs(missed) do
            Bastion:Print(k)
        end
    end)

    Command:Register('draw', 'Toggle draw line from player to target', function()
        local enabled = Bastion.UI.DrawLine:Toggle()
        if enabled then
            Bastion:Print("Draw line enabled - 红线从玩家到目标已开启")
        else
            Bastion:Print("Draw line disabled - 红线绘制已关闭")
        end
    end)

    -- ===================== 库管理函数 =====================
    ---@param library Library
    function Bastion:RegisterLibrary(library)
        LIBRARIES[library.name] = library
    end

    function Bastion:CheckLibraryDependencies()
        for k, v in pairs(LIBRARIES) do
            if v.dependencies then
                for i = 1, #v.dependencies do
                    local dep = v.dependencies[i]
                    if LIBRARIES[dep] then
                        if LIBRARIES[dep].dependencies then
                            for j = 1, #LIBRARIES[dep].dependencies do
                                if LIBRARIES[dep].dependencies[j] == v.name then
                                    Bastion:Print("Circular dependency detected between " .. v.name .. " and " .. dep)
                                    return false
                                end
                            end
                        end
                    else
                        Bastion:Print("Library " .. v.name .. " depends on " .. dep .. " but it's not registered")
                        return false
                    end
                end
            end
        end
        return true
    end

    function Bastion:Import(library)
        local lib = self:GetLibrary(library)
        if not lib then
            error("Library " .. library .. " not found")
        end
        return lib:Resolve()
    end

    function Bastion:GetLibrary(name)
        if not LIBRARIES[name] then
            error("Library " .. name .. " not found")
        end
        return LIBRARIES[name]
    end

    -- ===================== 外部文件加载 =====================
    Load("@Libraries/")
    Load("@Modules/")
    Load("@")

    -- 加载职业 UI
    local _, playerClass = UnitClass("player")
    if playerClass == "HUNTER" then
        Bastion:Require("~/src/herui/hunter")
        Bastion:Print("已加载猎人UI")
    end
end

-- ===================== 启动 Bastion 系统 =====================
Bastion.Bootstrap()
