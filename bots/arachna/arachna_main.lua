--ArachnaBot v1.0

--------------------------------------
--        Bot Initialization        --
--------------------------------------

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic 	= true
object.bRunBehaviors	= true
object.bUpdates 	= true
object.bUseShop 	= true

object.bRunCommands 	= true
object.bMoveCommands 	= true
object.bAttackCommands 	= true
object.bAbilityCommands = true
object.bOtherCommands 	= true

object.bReportBehavior	= false
object.bDebugUtility	= false
object.bDebugExecute	= false


object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core 		= {}
object.eventsLib 	= {}
object.metadata 	= {}
object.behaviorLib 	= {}
object.skills 		= {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading arachna_main...')

-----------------------------
--        Constants        --
-----------------------------

-- Arachna
object.heroName = 'Hero_Arachna'

-- Item buy order, using internal names.
behaviorLib.StartingItems = 
	{"2 Item_DuckBoots", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_Marchers", "2 Item_Soulscream", "Item_EnhancedMarchers"}
behaviorLib.MidItems = 
	{"Item_Sicarius", "Item_Immunity", "Item_ManaBurn2"} 
	--Item_Sicarius is Firebrand, ManaBurn2 is Geomenter's Bane, Immunity is Shrunken Head
behaviorLib.LateItems = 
	{"Item_Weapon3", "Item_Evasion", "Item_BehemothsHeart", "Item_Damage9" } 
	--Weapon3 is Savage Mace, Item_Evasion is Wingbow, and Item_Damage9 is Doombringer

-- Skillbuild table, 0 = q, 1 = w, 2 = e, 3 = r, 4 = attributes
object.tSkills = {
	2, 0, 0, 1, 0,
	3, 0, 2, 2, 2,
	3, 1, 1, 1, 4, 
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

-- Lane preferences
core.tLanePreferences = {
	Jungle = 0, 
	Mid = 5, 
	ShortSolo = 4, 
	LongSolo = 3, 
	ShortSupport = 1, 
	LongSupport = 1, 
	ShortCarry = 5, 
	LongCarry = 4
}

-- Bonus agression points if a skill/item is available for use
object.nWebUp = 5
object.nSpiderUp = 20

-- Bonus agression points that are applied to the bot upon successfully using a skill/item
object.spiderUseBonus = 45

--------------------------
--        Skills        --
--------------------------

function object:SkillBuild()
	local unitSelf = self.core.unitSelf

	if skills.abilWebbedShot == nil then
		skills.abilWebbedShot = unitSelf:GetAbility(0)\
		skills.abilSpiderSting = unitSelf:GetAbility(3)
	end
		
	local nPoints = unitSelf:GetAbilityPointsAvailable()
	if nPoints <= 0 then
		return
	end
 
	local nLevel = unitSelf:GetLevel()
	for i = nLevel, (nLevel + nPoints) do
		unitSelf:GetAbility( self.tSkills[i] ):LevelUp()
	end	
end

------------------------------------------
--        OnCombatEvent Override        --
------------------------------------------

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then	
		if EventData.InflictorName == "Ability_Arachna4" then
			nAddBonus = nAddBonus + object.spiderUseBonus
		end
	end
	
	if nAddBonus > 0 then
		core.DecayBonus(self)
	
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end

object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

-----------------------------------------------
--        CustomHarassUtilityOverride        --
-----------------------------------------------

local function CustomHarassUtilityOverride()
	local nUtility = 0
	
	if skills.abilWebbedShot:CanActivate() then
		nUtility = nUtility + object.nWebUp
	end
	
	if skills.abilSpiderSting:CanActivate() then
		nUtility = nUtility + object.nSpiderUp
	end
	
	return nUtility
end

behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   

----------------------------------------
--        PushStrengthOverride        --
----------------------------------------

local function PushingStrengthUtilOverride(unitSelf)
	local nMyDPS = core.GetFinalAttackDamageAverage(unitSelf) * 1000 / unitSelf:GetAdjustedAttackDuration()
	
	local nUtility = 0.5 * nMyDPS - 50
	nUtility = Clamp(nUtility, 0, 100)

	return nUtility
end

behaviorLib.PushingStrengthUtilFn = PushingStrengthUtilOverride

-----------------------------------
--        Harass Behavior        --
-----------------------------------

local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	
	if unitTarget == nil then
		return false
	end
	
	if core.CanSeeUnit(botBrain, unitTarget) then
		
		local bActionTaken = false
		
		local unitSelf = core.unitSelf
		local vecTargetPosition = unitTarget:GetPosition()
		local nTargetDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPosition)
		
		local abilSting = skills.abilSpiderSting
		if abilSting and abilSting:CanActivate() and core.nDifficulty ~= core.nEASY_DIFFICULTY or unitTarget:IsBotControlled() then
			local nStingRange = abilSting:GetRange() + core.GetExtraRange(unitSelf) + core.GetExtraRange(unitTarget)
			if nTargetDistanceSq < nStingRange * nStingRange then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilSting, unitTarget)
			else
				local itemGhostMarchers = core.itemGhostMarchers
				if itemGhostMarchers and itemGhostMarchers:CanActivate() then
					core.OrderItemClamp(botBrain, unitSelf, itemGhostMarchers)
				end
			
				vecDesiredPos = vecTargetPosition
				if behaviorLib.lastHarassUtil < behaviorLib.diveThreshold then
					vecDesiredPos = core.AdjustMovementForTowerLogic(vecDesiredPos)
				end
			
				bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, desiredPos, false)	
			end
		end
		
		if not bActionTaken then
			local abilWeb = skills.abilWebbedShot
			if abilWeb and abilWeb:CanActivate() and unitSelf:IsAttackReady() then
				local nWebRange = abilWeb:GetRange() + core.GetExtraRange(unitSelf) + core.GetExtraRange(unitTarget)
				if nTargetDistanceSq < nWebRange * nWebRange then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilWeb, unitTarget)
				end
			end
		end
	end
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end

object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

BotEcho('finished loading arachna_main')
