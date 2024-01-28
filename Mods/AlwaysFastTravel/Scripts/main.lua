--------------- Configure Section ---------------

---------Safemode----------
-- Disable mod auto-reg, only perform injection after pressing Alt+S
local safemode = false 
-------------------

----------VerySafeMode---------
-- Completely disable registration, 
-- Every time you open the map you need to manually press Alt+S 
-- to unlock fast travel
-- This should reduce crashes
local verysafemode = false 
-------------------

---------No Travel In Dungeon----------
-- Fast travel inside the dungeon is forbidden as 
-- it causes some problems, you can use the following 
-- runaway option to help get out of the dungeon 
-- (it's just that it hasn't been tested yet)
local notravelindungeon = true
-------------------

-------Allow Travel MovementModes----------
-- Some people reported bug when fast travel when flying
-- this disabled fast travel in different mode
-------------------
local MOVE = require('./move')
local allowtravelmodes = {
    [MOVE.None] = false,
    [MOVE.Walking] = true,
    [MOVE.NavWalking] = true,
    [MOVE.Falling] = false,
    [MOVE.Swimming] = false,
    [MOVE.Flying] = false,
    [MOVE.Custom] = false,
}
-------------------


---------------   Other Features   ---------------

---------Fast Move----------
-- Significant increase in movement speed and ability to pass obstacles, 
-- including continuously pressing the jump button to jump higher 
-- (it's NOT a two-stage jump, you just keep press the jump button..)
-- Set this to true and press Alt+Z in game, you can move faster
local fastmove = false -- disabled by default to not inference with tweak mod
-------------------

---------Dungeon Runaway----------
-- Press Alt+J to invoke the button to leave the dungeon
-- Considering that some people have had problems trying 
-- to fast travel through the dungeon, you can now leave 
-- the dungeon with this shortcut key. 
---
-- Note that this feature has NOT been tested a lot, 
-- as I looked for a long time with fast travel on above 
-- and didn't come across the dungeon
-- Especially in larger dungeons, I'm not sure if the dungeon's 
-- exit would be loaded in this case.
-- 
-- What I know must be a problem is that if you're already 
-- dead, don't use this shortcut, it'll get stuck
-- respawning
--
local dungeon = true -- allow you run away from dungeon
---------------

--------Unlock all fast travel-----------
-- Set all fasttravel points to active, 
-- !!BUT!! this action does **NOT** add them to the map.
-- You still need to go through these fast travel points by foot, 
-- you just don't need to press F to unlock them anymore
local unlockall = false 
-------------------

---------------       Keys       ---------------
-- Change however you want with the keys
Keybinds = {
    ["Unlock Travel Point"]          = {["Key"] = Key.U,             ["ModifierKeys"] = {ModifierKey.ALT}},
    ["Increase Travel Speed"]        = {["Key"] = Key.Z,             ["ModifierKeys"] = {ModifierKey.ALT}},
    ["HookMapSafe"]                  = {["Key"] = Key.S,             ["ModifierKeys"] = {ModifierKey.ALT}},
    ["Escape From the Dungeon"]      = {["Key"] = Key.J,             ["ModifierKeys"] = {ModifierKey.ALT}},
}

--------------- Configure Section ---------------


local function RegisterKey(KeyBindName, Callable)
    if (Keybinds[KeyBindName] and not IsKeyBindRegistered(Keybinds[KeyBindName].Key, Keybinds[KeyBindName].ModifierKeys)) then
        RegisterKeyBind(Keybinds[KeyBindName].Key, Keybinds[KeyBindName].ModifierKeys, Callable)
    end
end

local PalUtility = StaticFindObject("/Script/Pal.Default__PalUtility")
if not PalUtility:IsValid() then 
    print("Can't get PalUtility")
end

function sendmessage(msg)
    local Player = FindFirstOf("PalPlayerCharacter")
    PalUtility:SendSystemAnnounce(Player, msg)
end

--------------------------------------------------

function getPlayerController()
    -- this will be a faster way to find world object?
    local PlayerControllers = FindAllOf("PalPlayerController")
    if not PlayerControllers then error("No PlayerController found\n") end
    local PlayerController = nil
    for Index,Controller in pairs(PlayerControllers) do
        if Controller.Pawn:IsValid() and Controller.Pawn:IsPlayerControlled() then
            PlayerController = Controller
        else
            print("Not valid or not player controlled\n")
        end
    end
    if PlayerController and PlayerController:IsValid() then
        return PlayerController
    else
        return FindFirstOf("PalPlayerController")
    end
end

function getDungeonExit()
    local PalDungeonExits = FindFirstOf("PalDungeonExit")
    return PalDungeonExits
end


local hooked = false
local gworld
function get_world_cached()
    -- no we can't cache this, or it crashes when join another world
    if safemode or verysafemode then
        return getPlayerController()
    else
        if not gworld then
            gworld = getPlayerController()
        end
        return gworld
    end
end

function IsPlayerInStage(APalPlayerCharacter)
    -- GetPlayerStateByPlayer
    return PalUtility:GetPlayerStateByPlayer(APalPlayerCharacter):IsInStage()
end


function hook_maps()
    local function shouldFastTravel()
        local world = get_world_cached()
        if PalUtility:IsValid() and world:IsValid() then
            local pl = PalUtility:GetPalmi(world)
            if not pl:IsValid() then
                -- can't find player?
                return false
            end
            if notravelindungeon then
                if IsPlayerInStage(pl) then
                    return false
                end
            end
            local movement = pl:GetPalCharacterMovementComponent()
            if not allowtravelmodes[movement.MovementMode] then
                return false
            end
        else
            return false
        end
        return true
    end
    local function mod_map_base(map_base)
        -- print(string.format("[AlwaysFastTravel] [%d]\n", map_base:GetAddress()))
        map_base['Can Fast Travel'] = shouldFastTravel()
    end
    local function mod_map_body(map_body)
        -- print(string.format("[Travel] [%d]\n", map_body:GetAddress()))
        map_body.CanFastTravel = shouldFastTravel()
    end
    if not hooked then
        hooked = true
        -- /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:OnSetup
        if not verysafemode then
            -- sendmessage("Hooking map objects!")
            RegisterHook("/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Base.WBP_Map_Base_C:OnSetup", function(self)
                mod_map_base(self:get())
            end)
            -- /Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:OnLoaded_D35D903A4572C11561B776A766C7733D
            RegisterHook("/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_Map_Body.WBP_Map_Body_C:OnLoaded_D35D903A4572C11561B776A766C7733D", function(self)
                mod_map_body(self:get())
            end)
        end
    end
    if safemode or verysafemode then
        if verysafemode then
            sendmessage("Use this when you're in the map!")
        end
        local map_bases = FindAllOf("WBP_Map_Base_C")
        if map_bases then
            for idx, map_base in pairs(map_bases) do
                mod_map_base(map_base)
            end
        end
        local map_bodies = FindAllOf("WBP_Map_Body_C")
        if map_bodies then
            for idx, map_body in pairs(map_bodies) do
                mod_map_body(map_body)
            end
        end
    end
end

if safemode or verysafemode then
    RegisterKey("HookMapSafe", function() 
        hook_maps()
    end)
else
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function (self) 
        gworld = getPlayerController()
        hook_maps() 
    end)
end

if dungeon then

RegisterKey("Escape From the Dungeon", function()
    print("[AlwaysFastTravel] Triggered\n")
    local PalDungeonExits = getDungeonExit()
    if PalUtility:IsValid() then 
        if PalDungeonExits:IsValid() then
            print("Find exit.\n")
            local APalPlayerCharacter = PalUtility:GetPalmi(PalDungeonExits)
            PalDungeonExits:OnTriggerInteract(APalPlayerCharacter, 0x27)
        else
            sendmessage("I can't find Dungeon Exits.")
            print("[AlwaysFastTravel] Can't find PalDungeonExit, you are in the dungeon at all?")
        end
    else 
        print("[AlwaysFastTravel] Can't find PalUtility, you are in the game at all?")
    end
end)

end

if fastmove then
RegisterKey("Increase Travel Speed", function()
    print("[AlwaysFastTravel] Triggered\n")
    -- PalCharacterMovementComponent /Game/Pal/Blueprint/Character/Player/Female/BP_Player_Female.Default__BP_Player_Female_C:CharMoveComp
    -- APalPlayerCharacter:GetPalCharacterMovementComponent()
    
    local world = get_world_cached()
    if PalUtility:IsValid() and world:IsValid() then
        local pl = PalUtility:GetPlayerControlledCharacter(world) -- GetPalmi(world)
        --print(string.format("Get Palmi = %x\n", pl:GetAddress()))
        local movement = pl:GetPalCharacterMovementComponent()
        pl.JumpMaxHoldTime = 10
        movement.MaxStepHeight = 1000.0
        movement.JumpZVelocity = 1400.0
        movement.WalkableFloorAngle = 90
        movement.MaxWalkSpeed = 2000.0
        movement.MaxWalkSpeedCrouched = 2000.0
        movement.MaxSwimSpeed = 2500.0
        movement.MaxCustomMovementSpeed = 2000.0
        movement.BrakingDecelerationSwimming = movement.BrakingDecelerationWalking
        -- movement.MaxAcceleration = 2048.0
        movement.bApplyGravityWhileJumping = true -- no g...?
        movement.MaxOutOfWaterStepHeight = 600.0 -- allow you to get out of water easier
        movement.ClimbMaxSpeed = 1000.0
        movement.GliderMaxSpeed = 2000.0 -- 350.0
        -- movement.JumpOutOfWaterPitch = ??
        sendmessage("I feel lighter.")
    end
end)
end

if unlockall then
RegisterKey("Unlock Travel Point", function()
    -- BP_LevelObject_TowerFastTravelPoint_C /Script/Pal.Default__PalLocationPointFastTravel
    -- BP_LevelObject_TowerFastTravelPoint_C /Game/Pal/Maps/MainWorld_5/PL_MainWorld5.PL_MainWorld5:PersistentLevel.BP_LevelObject_TowerFastTravelPoint_C_UAID_FC349764B52DD7BA01_1172323148
    local recs = FindAllOf("BP_LevelObject_TowerFastTravelPoint_C")
    if recs == nil then
        print("FindAllOf(\"BP_LevelObject_TowerFastTravelPoint_C\") = nil")
    else
        print("FindAllOf(\"BP_LevelObject_TowerFastTravelPoint_C\") != nil")
    end
    local playstate = GetPlayerStateByPlayer(getPlayerController())
    if playstate == nil then
        print("play state is nil\n")
        return
    end
    print(string.format("[AlwaysFast] FindFirstOfPalPlayerState= %x\n",  playstate:GetAddress()))
    if playstate:IsValid() and recs then
        for Index,Rec in pairs(recs) do
            print(string.format("[AlwaysFast] Try unlock %s\n", Rec.FastTravelPointID:ToString()))
            -- (Items=((Key="6E03F8464BAD9E458B843AA30BE1CC8F",Value=True,ReplicationID=1,ReplicationKey=0)),ArrayReplicationKey=1)
            --if not Rec:IsUnlocked() then
                -- Rec.RequestUnlock()
                -- Function /Game/Pal/Blueprint/MapObject/Object/LevelObject/BP_LevelObject_TowerFastTravelPoint.BP_LevelObject_TowerFastTravelPoint_C:ReceiveBeginPlay
                --local guid = Rec.LevelObjectInstanceId
                -- Function /Script/Engine.KismetGuidLibrary:Conv_GuidToString
                local guidstr = string.format("%08X%08X%08X%08X", guid.A & 0xffffffff, guid.B & 0xffffffff, guid.C & 0xffffffff, guid.D & 0xffffffff)
                --print(string.format("[AlwaysFast] Try unlock A=%d, B=%d, C=%d, D=%d\n", guid.A & 0xffffffff, guid.B & 0xffffffff, guid.C & 0xffffffff, guid.D & 0xffffffff))
                --print(string.format("[AlwaysFast] Try unlock %s\n", guidstr))
                --Rec:ReceiveBeginPlay() <- not work, sad
                playstate:RequestUnlockFastTravelPoint_ToServer(FName(guidstr))
            --end
        end
    else
        print("[AlwaysFast] PalPlayerState is null, maybe you are not in game?")
    end
end)
end