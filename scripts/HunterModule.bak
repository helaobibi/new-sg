local Tinkr, Bastion = ...

-- 创建模块
local HunterModule = Bastion.Module:New('HunterModule')

-- 获取玩家和目标单位
local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local Pet = Bastion.UnitManager:Get('pet')
local PetTarget = Bastion.UnitManager:Get('pettarget')
local TargetTarget = Bastion.UnitManager:Get('targettarget')

-- 创建法术书
local SpellBook = Bastion.Globals.SpellBook
-- 创建物品书
local ItemBook = Bastion.Globals.ItemBook
-- 定义技能
-- 基础技能
local MendPet = SpellBook:GetSpell(13544)                  -- 治疗宠物
local kuishe = SpellBook:GetSpell(34074)                  -- 蝰蛇守护
local AimedShot = SpellBook:GetSpell(20904)               -- 瞄准射击
local Serpent = SpellBook:GetSpell(25295)                 -- 毒蛇钉刺
local HuntersMark = SpellBook:GetSpell(14325)             -- 猎人印记
local Cower = SpellBook:GetSpell(1742)                    -- 畏缩
local FeignDeath = SpellBook:GetSpell(5384)               -- 假死
local AutoShot = SpellBook:GetSpell(75)                   -- 自动射击
local Growl = SpellBook:GetSpell(14921)                   -- 低吼
local AspectOfTheHawk = SpellBook:GetSpell(25296)         -- 雄鹰守护
local ArcaneShot = SpellBook:GetSpell(14287)              -- 奥术射击
local SteadyShot = SpellBook:GetSpell(34120)              -- 稳固射击
-- AOE技能
local MultiShotSpell = SpellBook:GetSpell(27022)           -- 乱射
-- 宠物技能
local ShellShield = SpellBook:GetSpell(26064)             -- 甲壳护盾
local Intimidation = SpellBook:GetSpell(19577)            -- 胁迫
local Bite = SpellBook:GetSpell(27050)                    -- 撕咬

-- 寻找最佳目标
local BestTarget = Bastion.UnitManager:CreateCustomUnit('besttarget', function()
    local bestTarget = nil
    local highestHealth = 0

    -- 遍历所有敌人，寻找最适合的目标
    Bastion.ObjectManager.enemies:each(function(unit)
        -- 获取unit的目标
        local unitTarget = unit:GetTarget()
        -- 检查unit的目标是否是player或pet
        local isTargetingPlayerOrPet = (unitTarget:Exists() and (unitTarget:IsUnit(Player) or (Pet:Exists() and unitTarget:IsUnit(Pet))))
        
        -- 检查目标是否符合条件：
        -- 1. 正在战斗中
        -- 2. 在35码范围内
        -- 3. 玩家可以看见该目标
        -- 4. 目标距离玩家至少5码
        -- 5. 玩家面向该目标
        -- 6. unit的目标必须是player或pet
        if unit:IsAffectingCombat() and Player:CanSee(unit) and unit:IsAlive() and unit:Exists() and Player:IsFacing(unit) and isTargetingPlayerOrPet then
            -- 如果没有最佳目标或当前单位血量更高
            if unit:GetHealth() > highestHealth then
                highestHealth = unit:GetHealth()
                bestTarget = unit
            end
        end
    end)

    -- 如果没找到合适目标，返回空目标
    return bestTarget or Bastion.UnitManager:Get('none')
end)

-- 通过 Bastion.Globals.HERUI 读取 UI 状态，避免使用全局函数污染环境
local function createUIAccessor(name, default)
    return function()
        local api = Bastion.Globals and Bastion.Globals.HERUI
        if api and api[name] then
            return api[name]()
        end
        return default
    end
end

local HERUI = {
    PetAttack = createUIAccessor("PetAttack", true),
    PetFollow = createUIAccessor("PetFollow", false),
    Growl = createUIAccessor("Growl", true),
    ViperSting = createUIAccessor("ViperSting", false),
    AutoTarget = createUIAccessor("AutoTarget", true),
    AOE = createUIAccessor("AOE", false),
    AOEAuto = createUIAccessor("AOEAuto", false),
    Normal = createUIAccessor("Normal", true),
    Simple = createUIAccessor("Simple", false)
}

-- 选择目标
local function CheckAndSetTarget()
    if not Target:Exists() or Target:IsFriendly() or not Target:IsAlive() then
        if BestTarget:Exists() then -- 检查返回值有效
            -- 设置最佳目标为当前目标
            SetTargetObject(BestTarget.unit)
            return true
        end
    end
    return false
end

-- ===================== APL定义 =====================
local DefaultAPL = Bastion.APL:New('default')         -- 默认输出循环
local DefensiveAPL = Bastion.APL:New('defensive')     -- 防御循环
local AoEAPL = Bastion.APL:New('aoe')                 -- AOE循环
local ResourceAPL = Bastion.APL:New('resource')       -- 资源管理循环
local ResourceAPL2 = Bastion.APL:New('resource2')     -- 资源管理循环2
local PetControlAPL = Bastion.APL:New('petcontrol')   -- 宠物控制
local DefaultSPAPL = Bastion.APL:New('DefaultSP')     -- 简单模式

-- ===================== 防御循环 =====================
-- 治疗石
DefensiveAPL:AddAction("UseHealingStone", function()
    -- 先检查血量，避免不必要的背包搜索
    if Player:GetHP() <= 50 and Player:IsAffectingCombat() then
        local healingStone = ItemBook:GetItemByName("治疗石")
        if healingStone and not healingStone:IsOnCooldown() then
            healingStone:Use(Player)
            return true
        end
    end
    return false
end)

-- 假死
DefensiveAPL:AddSpell(
    FeignDeath:CastableIf(function(self)
        return GetKeyState(3)  -- 按下F键时释放
            and not Player:GetAuras():FindMy(FeignDeath):IsUp()  -- 没有假死buff
    end):SetTarget(Player):PreCast(function(self)
        if Player:IsCastingOrChanneling() then
            SpellStopCasting()  -- 打断当前施法
        end
    end)
)

-- 胁迫
DefensiveAPL:AddSpell(
    Intimidation:CastableIf(function(self)
        return GetKeyState(58)  -- 按下左Option键时释放
            and Target:Exists()
            and Target:IsAlive()
            and not self:IsOnCooldown()
    end):SetTarget(Target):PreCast(function(self)
        if Player:IsCastingOrChanneling() then
            SpellStopCasting()  -- 打断当前施法
        end
    end)
)

-- 畏缩
PetControlAPL:AddSpell(
    Cower:CastableIf(function(self)
        return Pet:Exists()
            and Pet:IsAlive()
            and Player:IsAffectingCombat()
            and not self:IsOnCooldown()
            and Pet:GetHP() <= 90
    end):SetTarget(Pet)
)

-- 宠物攻击
PetControlAPL:AddAction("PetAttack", function()
    if Pet:Exists() and Pet:IsAlive()
        and Target:Exists()
        and Target:IsAlive()
        and HERUI.PetAttack()
        and (not PetTarget:Exists() or not PetTarget:IsUnit(Target)) then
        PetAttack()
        return true
    end
    return false
end)

-- 宠物跟随
PetControlAPL:AddAction("PetFollow", function()
    if Pet:Exists() and Pet:IsAlive()
        and PetTarget:Exists()
        and HERUI.PetFollow() then
        -- and (HERUI.PetFollow() or Pet:GetHP() < 75) then
        PetFollow()
        return true
    end
    return false
end)

-- 治疗宠物
PetControlAPL:AddSpell(
    MendPet:CastableIf(function(self)
        return Pet:Exists()
            and Pet:IsAlive()
            and Pet:GetHP() < 50
            and Player:IsAffectingCombat()
            and not Pet:GetAuras():FindAny(MendPet):IsUp()
            and not Player:IsChanneling()
            and self:IsKnownAndUsable()
    end):SetTarget(Pet)
)

-- 低吼（宠物嘲讽）
PetControlAPL:AddSpell(
    Growl:CastableIf(function(self)
        return Pet:Exists()
        and Pet:IsAlive()
        and Target:Exists()
        and Target:IsAlive()
        and Player:IsAffectingCombat()
            and HERUI.Growl()
            and not self:IsOnCooldown()
            and Pet:GetPower() >= 15
    end):SetTarget(Target)
)

-- 撕咬
PetControlAPL:AddSpell(
    Bite:CastableIf(function(self)
        return Pet:Exists()
            and Pet:IsAlive()
            and Target:Exists()
            and Target:IsAlive()
            and Player:IsAffectingCombat()
            and not self:IsOnCooldown()
            and Pet:GetPower() > 40
    end):SetTarget(Target)
)

-- 甲壳护盾
PetControlAPL:AddSpell(
    ShellShield:CastableIf(function(self)
        return Pet:Exists()
            and Pet:IsAlive()
            and Pet:GetHP() < 50
            and Player:IsAffectingCombat()
            and not self:IsOnCooldown()
    end):SetTarget(Pet)
)

-- ===================== AOE循环 =====================
-- 乱射(使用敌人群质心坐标)
AoEAPL:AddSpell(
    MultiShotSpell:CastableIf(function(self)
        return Target:Exists()
            and not Player:IsChanneling()
            and Target:IsAlive()
            and Target:IsEnemy()
            and Target:GetDistance(Player) <= 35
    end):SetTarget(Target):OnCast(function(self)
        -- 使用FindEnemiesCentroid函数找到敌人群的质心位置
        -- 参数：半径8码，范围35码，最少需要2个敌人才使用乱射
        local centroid = Bastion.UnitManager:FindEnemiesCentroid(8, 35, 2)
        local position

        if centroid then
            position = centroid
        else
            -- 如果没有找到足够密集的敌人群（少于2个敌人），退回到目标位置
            position = Target:GetPosition()
        end

        self:Click(position)
    end)
)

-- ===================== 资源管理循环 =====================
-- 守护切换
-- 蝰蛇
ResourceAPL:AddSpell(
    kuishe:CastableIf(function(self)
        return Player:GetPP() <= 15 and
               not Player:GetAuras():FindMy(kuishe):IsUp() and
               Player:IsAffectingCombat()
    end):SetTarget(Player)
)

-- 雄鹰
ResourceAPL:AddSpell(
    AspectOfTheHawk:CastableIf(function(self)
        return Player:GetPP() >= 65 and
               not Player:GetAuras():FindMy(AspectOfTheHawk):IsUp() and
               Player:IsAffectingCombat()
    end):SetTarget(Player)
)

-- 资源管理循环2
-- 蝰蛇
ResourceAPL2:AddSpell(
    kuishe:CastableIf(function(self)
        return not Player:GetAuras():FindMy(kuishe):IsUp()
               and Player:IsAffectingCombat()
    end):SetTarget(Player)
)

-- ===================== 默认循环 =====================
-- 猎人印记
DefaultAPL:AddSpell(
    HuntersMark:CastableIf(function(self)
        return Target:Exists()
		    and Target:IsAlive()
            and self:IsKnownAndUsable()
            and not Target:GetAuras():FindAny(HuntersMark):IsUp()
    end):SetTarget(Target)
)

-- -- 毒蛇钉刺
-- DefaultAPL:AddSpell(
--     Serpent:CastableIf(function(self)
--         return Target:Exists()
--             and Target:IsAlive()
--             and Target:GetHP() >= 20  -- 目标血量大于20%才上DOT
--             and self:IsKnownAndUsable()
--             and not Target:GetAuras():FindMy(Serpent):IsUp()
--     end):SetTarget(Target)
-- )

-- 瞄准射击
-- DefaultAPL:AddSpell(
--     AimedShot:CastableIf(function(self)
--         return Target:Exists()
-- 		    and Target:IsAlive()
--             and self:IsKnownAndUsable()
--     end):SetTarget(Target)
-- )

-- 奥术射击
DefaultAPL:AddSpell(
    ArcaneShot:CastableIf(function(self)
        return Target:Exists()
            and Target:IsAlive()
            and self:IsKnownAndUsable()
    end):SetTarget(Target)
)

-- 稳固射击
DefaultAPL:AddSpell(
    SteadyShot:CastableIf(function(self)
        return Target:Exists()
            and Target:IsAlive()
            and self:IsKnownAndUsable()
    end):SetTarget(Target)
)

-- ===================== 简单模式循环 =====================
-- 瞄准射击
-- DefaultSPAPL:AddSpell(
--     AimedShot:CastableIf(function(self)
--         return Target:Exists()
-- 		    and Target:IsAlive()
--             and self:IsKnownAndUsable()
--     end):SetTarget(Target)
-- )

-- 奥术射击
DefaultSPAPL:AddSpell(
    ArcaneShot:CastableIf(function(self)
        return Target:Exists()
            and Target:IsAlive()
            and self:IsKnownAndUsable()
    end):SetTarget(Target)
)

-- 稳固射击
DefaultSPAPL:AddSpell(
    SteadyShot:CastableIf(function(self)
        return Target:Exists()
            and Target:IsAlive()
            and self:IsKnownAndUsable()
    end):SetTarget(Target)
)

-- ===================== 模块同步 =====================
HunterModule:Sync(function()
    --最高优先级：防御和资源管理
    DefensiveAPL:Execute()
    PetControlAPL:Execute()

    -- 如果按住F键（假死状态）或T键（威慑状态），则不执行其他循环
    if GetKeyState(3) then
        return
    end

    -- 如果targettarget不等于pet，或者target不在战斗中，则返回
    -- if (TargetTarget:Exists() and Pet:Exists() and not TargetTarget:IsUnit(Pet)) 
    --     or not Target:IsAffectingCombat() then
    --     return
    -- end
    if Player:IsCastingOrChanneling() then
        return
    end

    -- 强制蝰蛇模式
    if HERUI.ViperSting() then
        ResourceAPL2:Execute()
    end
    if not HERUI.ViperSting() then
        ResourceAPL:Execute()
    end

    -- 战斗中切目标
    if Player:IsAffectingCombat() and HERUI.AutoTarget() then
        CheckAndSetTarget()
    end
    
    if HERUI.AOE() then
        AoEAPL:Execute()
    end
    if HERUI.Normal() then
        DefaultAPL:Execute()
    end
    if HERUI.Simple() then
        DefaultSPAPL:Execute()
    end
end)
Bastion:Register(HunterModule)
