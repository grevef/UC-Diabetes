
local function playAnim(animationSettings)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    local dict = animationSettings.dict
    local clip = animationSettings.clip
    local duration = animationSettings.duration or 5000
    local flag = animationSettings.flag or 49

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end

    local propEnt
    if animationSettings.prop then
        local model = type(animationSettings.prop) == "string" and animationSettings.prop or animationSettings.prop.model
        local bone  = (animationSettings.prop.bone) or 18905
        local pos   = (animationSettings.prop.pos) or {0.12, 0.03, 0.02}
        local rot   = (animationSettings.prop.rot) or {10.0, 160.0, 10.0}

        local hash = joaat(model)
        RequestModel(hash)
        while not HasModelLoaded(hash) do Wait(10) end

        local coords = GetEntityCoords(ped)
        propEnt = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)

        AttachEntityToEntity(
            propEnt, ped, GetPedBoneIndex(ped, bone),
            pos[1], pos[2], pos[3],
            rot[1], rot[2], rot[3],
            true, true, false, true, 1, true
        )
    end

    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, duration, flag, 0.0, false, false, false)
    Wait(duration)
    StopAnimTask(ped, dict, clip, 1.0)

    if propEnt and DoesEntityExist(propEnt) then
        DetachEntity(propEnt, true, true)
        DeleteEntity(propEnt)
    end

    RemoveAnimDict(dict)
end

local function PlaySound(name, dict)
    PlaySoundFrontend(-1, name, dict, true)
end

local function setScreenEffect(start ,effectName, duration, loop)
    if start then
        StartScreenEffect(effectName, duration, loop)
        return
    else
        StopScreenEffect(effectName)
    end
end

local function setWalkingSpeed(start, speedMultiplier, animation)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    if start then
        RequestAnimSet(animation)
        while not HasAnimSetLoaded(animation) do
            Wait(0)
        end
        SetPedMovementClipset(ped, animation, 1.0)
    else
        ResetPedMovementClipset(ped, 0.0)
    end
end

local function applyHealthLoss(healthLoss)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    local currentHealth = GetEntityHealth(ped)
    local newHealth = currentHealth - healthLoss
    if newHealth < 0 then newHealth = 0 end

    SetEntityHealth(ped, newHealth)
end



RegisterNetEvent('UC-diabetes:client:useInsulin', function()
   TriggerServerEvent('UC-diabetes:server:useInsulin')
end)

RegisterNetEvent('UC-diabetes:client:useEnergyTablet', function()
   TriggerServerEvent('UC-diabetes:server:useEnergyTablet')
end)

RegisterNetEvent('UC-diabetes:client:useBloodSugarMonitor', function()
   TriggerServerEvent('UC-diabetes:server:useBloodSugarMonitor')
end)

RegisterNetEvent('UC-diabetes:client:playSound', function(name, dict)
   PlaySound(name, dict)
end)

RegisterNetEvent('UC-diabetes:client:applyScreenEffect', function(start, effectName)
    setScreenEffect(start, effectName, 0, true)
end)

RegisterNetEvent('UC-diabetes:client:setWalkingSpeed', function(start, speedMultiplier, animation)
    setWalkingSpeed(start, speedMultiplier, animation)
end)

RegisterNetEvent('UC-diabetes:client:applyHealthLoss', function(healthLoss)
    applyHealthLoss(healthLoss)
end)

RegisterNetEvent('UC-diabetes:client:playAnimation', function(animationSettings)
   playAnim(animationSettings)
end)

-- Blood sugar monitor UI

local monitorOpen = false
local monitorProp
local monitorHistory = {}

local function startMonitorHold(anim)
    local ped = PlayerPedId()

    RequestAnimDict(anim.dict)
    while not HasAnimDictLoaded(anim.dict) do Wait(10) end

    if anim.prop then
        local hash = joaat(anim.prop.model)
        RequestModel(hash)
        while not HasModelLoaded(hash) do Wait(10) end

        local coords = GetEntityCoords(ped)
        local pos, rot = anim.prop.pos, anim.prop.rot
        monitorProp = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
        AttachEntityToEntity(
            monitorProp, ped, GetPedBoneIndex(ped, anim.prop.bone),
            pos[1], pos[2], pos[3],
            rot[1], rot[2], rot[3],
            true, true, false, true, 1, true
        )
        SetModelAsNoLongerNeeded(hash)
    end

    TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, anim.flag or 49, 0.0, false, false, false)
end

local function stopMonitorHold(anim)
    StopAnimTask(PlayerPedId(), anim.dict, anim.clip, 1.0)
    RemoveAnimDict(anim.dict)

    if monitorProp and DoesEntityExist(monitorProp) then
        DetachEntity(monitorProp, true, true)
        DeleteEntity(monitorProp)
    end
    monitorProp = nil
end

local function getClockString()
    local hours, minutes = GetClockHours(), GetClockMinutes()
    local suffix = hours >= 12 and "PM" or "AM"
    hours = hours % 12
    if hours == 0 then hours = 12 end
    return ("%d:%02d"):format(hours, minutes), suffix
end

-- Maps the 0-100 sugar level onto a meter reading, so the effect thresholds
-- line up with the edges of the target range.
local function buildReading(level)
    local cfg = Config.Monitor
    local lowThreshold = Config.Effects.lowSugar.threshold
    local highThreshold = Config.Effects.highSugar.threshold

    local slope = (cfg.targetHigh - cfg.targetLow) / (highThreshold - lowThreshold)
    local mgdl = math.max(20, cfg.targetLow + (level - lowThreshold) * slope)

    local value
    if cfg.unit == "mmol/L" then
        value = ("%.1f"):format(mgdl / 18.0)
    else
        value = tostring(math.floor(mgdl + 0.5))
    end

    local status = "target"
    if level <= lowThreshold then
        status = "low"
    elseif level >= highThreshold then
        status = "high"
    end

    local clock, suffix = getClockString()

    return {
        value = value,
        unit = cfg.unit,
        status = status,
        position = math.min(math.max(level / 100, 0.0), 1.0),
        time = clock .. " " .. suffix,
    }
end

local function addToHistory(reading)
    table.insert(monitorHistory, 1, reading)
    while #monitorHistory > Config.Monitor.historySize do
        table.remove(monitorHistory)
    end
end

local function formatTarget(mgdl)
    if Config.Monitor.unit == "mmol/L" then
        return ("%.1f"):format(mgdl / 18.0)
    end
    return tostring(mgdl)
end

local function closeMonitor()
    if not monitorOpen then return end
    monitorOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
    stopMonitorHold(Config.items.bloodSugarMonitor.animation)
end

RegisterNetEvent('UC-diabetes:client:openMonitor', function(level, dtype)
    if monitorOpen then return end
    monitorOpen = true

    local reading = buildReading(level)
    addToHistory(reading)

    startMonitorHold(Config.items.bloodSugarMonitor.animation)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        reading = reading,
        history = monitorHistory,
        clock = (getClockString()),
        testDuration = Config.Monitor.testDuration,
        info = {
            type = dtype,
            unit = Config.Monitor.unit,
            targetLow = formatTarget(Config.Monitor.targetLow),
            targetHigh = formatTarget(Config.Monitor.targetHigh),
        },
    })

    CreateThread(function()
        while monitorOpen do
            SendNUIMessage({ action = "clock", clock = (getClockString()) })
            if IsEntityDead(PlayerPedId()) then closeMonitor() end
            Wait(1000)
        end
    end)
end)

RegisterNUICallback('close', function(_, cb)
    closeMonitor()
    cb({})
end)

RegisterNUICallback('measure', function(_, cb)
    local level = lib.callback.await('UC-diabetes:server:getSugarLevel', false)
    if not level then return cb({}) end

    local reading = buildReading(level)
    addToHistory(reading)
    cb({ reading = reading, history = monitorHistory })
end)

RegisterNUICallback('beep', function(_, cb)
    PlaySound(Config.Monitor.sound.name, Config.Monitor.sound.dict)
    cb({})
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeMonitor()
end)
