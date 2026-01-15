local inTrunk = false
local currentVehicle = nil

-- Hulpfunctie: Check of voertuig klasse toegestaan is en slot status
local function canEnterTrunk(vehicle)
    local class = GetVehicleClass(vehicle)
    if not Config.AllowedClasses[class] then return false end
    if GetVehicleDoorLockStatus(vehicle) > 1 then return false end
    
    -- Check of er al iemand in de kofferbak ligt (State Bag)
    if Entity(vehicle).state.trunkOccupied then return false end

    local bootBone = GetEntityBoneIndexByName(vehicle, 'boot')
    if bootBone == -1 then bootBone = GetEntityBoneIndexByName(vehicle, 'trunk') end
    
    return bootBone ~= -1
end

-- Hulpfunctie: Check of het voertuig volledig leeg is
local function isVehicleEmpty(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    
    -- Check bestuurder
    if not IsVehicleSeatFree(vehicle, -1) then return false end
    
    -- Check passagiers
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for i = 0, maxSeats - 1 do
        if not IsVehicleSeatFree(vehicle, i) then return false end
    end
    
    return true
end

local function getTrunkOffset(vehicle)
    local model = GetEntityModel(vehicle)
    local min, max = GetModelDimensions(model)
    local zPos = (max.z - min.z) / 2
    return vector3(0.0, min.y + 0.4, zPos - 0.2)
end

-- Reset de trunk status op het voertuig
local function setTrunkOccupied(vehicle, occupied)
    if DoesEntityExist(vehicle) then
        -- true als 3e argument zorgt voor replicatie naar andere spelers
        Entity(vehicle).state:set('trunkOccupied', occupied, true)
    end
end

local function startTrunkLoop()
    lib.showTextUI('[E] - Uit kofferbak', {position = "left-center"})
    LocalPlayer.state:set('invBusy', true, true)

    CreateThread(function()
        while inTrunk do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 245, true)
            EnableControlAction(0, 38, true)

            SetGameplayCamRelativePitch(0.0, 1.0)

            -- Veiligheidscheck
            if not DoesEntityExist(currentVehicle) or IsEntityDead(cache.ped) then
                if currentVehicle then setTrunkOccupied(currentVehicle, false) end
                inTrunk = false
                LocalPlayer.state:set('invBusy', false, true)
                
                DetachEntity(cache.ped, true, true)
                SetEntityVisible(cache.ped, true, false)
                SetEntityCollision(cache.ped, true, true)
                
                lib.hideTextUI()
                ClearPedTasksImmediately(cache.ped)
            end

            -- Uitstappen
            if IsDisabledControlJustPressed(0, 38) then
                local speed = GetEntitySpeed(currentVehicle) * 3.6
                
                if speed > 1.0 then
                    lib.notify({type = 'error', description = 'Voertuig rijdt te snel!'})
                else
                    inTrunk = false
                    
                    if lib.progressBar({
                        duration = Config.ActionDuration,
                        label = 'Kofferbak uitklimmen...',
                        useWhileDead = false,
                        canCancel = false,
                        disable = { move = true, car = true, mouse = false, combat = true }
                    }) then
                        SetVehicleDoorOpen(currentVehicle, 5, false, false)
                        Wait(500)
                        
                        SetEntityVisible(cache.ped, true, false)
                        local model = GetEntityModel(currentVehicle)
                        local min, _ = GetModelDimensions(model)
                        
                        DetachEntity(cache.ped, true, true)
                        
                        -- Veilig spawnen
                        local off = GetOffsetFromEntityInWorldCoords(currentVehicle, 0.0, min.y - 1.5, 0.0)
                        SetEntityCoords(cache.ped, off.x, off.y, off.z)
                        SetEntityCollision(cache.ped, true, true)
                        
                        -- Status vrijgeven
                        setTrunkOccupied(currentVehicle, false)
                        
                        ClearPedTasks(cache.ped)
                        LocalPlayer.state:set('invBusy', false, true)
                        lib.hideTextUI()
                        
                        SetTimeout(1000, function()
                             if DoesEntityExist(currentVehicle) then
                                SetVehicleDoorShut(currentVehicle, 5, false) 
                             end
                             currentVehicle = nil
                        end)
                    else
                        inTrunk = true
                        startTrunkLoop()
                    end
                end
            end
            Wait(0)
        end
    end)
end

local function enterTrunk(entity)
    if inTrunk then return end
    
    -- Check 1: Is voertuig leeg bij start?
    if not isVehicleEmpty(entity) then
        lib.notify({type = 'error', description = 'Voertuig is niet leeg!'})
        return
    end

    -- Check 2: Zit er al iemand in de kofferbak?
    if Entity(entity).state.trunkOccupied then
        lib.notify({type = 'error', description = 'Kofferbak is al bezet!'})
        return
    end

    SetVehicleDoorOpen(entity, 5, false, false)

    -- Progressbar met "tick" functie voor continue controle
    local success = lib.progressBar({
        duration = Config.ActionDuration,
        label = 'In kofferbak kruipen...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer' 
        },
        -- Deze functie runt elke frame tijdens de progressbar
        tick = function()
            -- Als het voertuig NIET meer leeg is, cancel de actie direct
            if not isVehicleEmpty(entity) then
                return false -- Dit stopt de progressbar (geeft 'cancel' terug)
            end
            return true
        end
    })

    if success then
        -- Dubbelcheck state voor de zekerheid (race conditions)
        if Entity(entity).state.trunkOccupied then
            lib.notify({type = 'error', description = 'Kofferbak is net bezet!'})
            SetVehicleDoorShut(entity, 5, false)
            return
        end

        inTrunk = true
        currentVehicle = entity
        
        -- Markeer kofferbak als bezet
        setTrunkOccupied(entity, true)
        
        local dict = 'timetable@floyd@cryingonbed@base'
        lib.requestAnimDict(dict)
        
        local offset = Config.CustomOffsets[GetEntityModel(entity)] or getTrunkOffset(entity)
        AttachEntityToEntity(cache.ped, entity, 0, offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
        
        TaskPlayAnim(cache.ped, dict, 'base', 8.0, -8.0, -1, 1, 0, false, false, false)
        
        SetEntityVisible(cache.ped, false, false)

        SetTimeout(800, function()
            if inTrunk and DoesEntityExist(entity) then
                SetVehicleDoorShut(entity, 5, false)
            end
        end)
        
        startTrunkLoop()
    else
        -- Geannuleerd (door speler of door tick check)
        SetVehicleDoorShut(entity, 5, false)
        if not isVehicleEmpty(entity) then
            lib.notify({type = 'error', description = 'Actie geannuleerd: Iemand stapte in!'})
        else
            lib.notify({type = 'inform', description = 'Geannuleerd'})
        end
    end
end

exports.ox_target:addGlobalVehicle({
    {
        label = 'In kofferbak liggen',
        icon = 'fa-solid fa-car-rear',
        distance = 2.5,
        canInteract = function(entity)
            -- Check of kofferbak vrij is in het menu
            return not inTrunk and canEnterTrunk(entity) and not Entity(entity).state.trunkOccupied
        end,
        onSelect = function(data)
            enterTrunk(data.entity)
        end,
        bones = {'boot', 'trunk'}
    }
})
