local inTrunk = false
local currentVehicle = nil

-- Hulpfunctie: Check of voertuig fysiek geschikt is
local function canEnterTrunk(vehicle)
    local class = GetVehicleClass(vehicle)
    if not Config.AllowedClasses[class] then return false end
    if GetVehicleDoorLockStatus(vehicle) > 1 then return false end
    
    local bootBone = GetEntityBoneIndexByName(vehicle, 'boot')
    if bootBone == -1 then bootBone = GetEntityBoneIndexByName(vehicle, 'trunk') end
    
    return bootBone ~= -1
end

-- Hulpfunctie: Check of het voertuig volledig leeg is (Bestuurder + Passagiers)
local function isVehicleEmpty(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    
    -- Check 1: Bestuurdersstoel (Seat -1)
    if not IsVehicleSeatFree(vehicle, -1) then 
        return false 
    end
    
    -- Check 2: Aantal passagiers (exclusief bestuurder)
    -- Als dit getal hoger is dan 0, zit er ergens iemand.
    if GetVehicleNumberOfPassengers(vehicle) > 0 then 
        return false 
    end
    
    return true
end

local function getTrunkOffset(vehicle)
    local model = GetEntityModel(vehicle)
    local min, max = GetModelDimensions(model)
    local zPos = (max.z - min.z) / 2
    return vector3(0.0, min.y + 0.4, zPos - 0.2)
end

-- De loop die draait als de speler in de kofferbak ligt
local function startTrunkLoop(netId)
    lib.showTextUI('[E] - Uit kofferbak', {position = "left-center"})
    LocalPlayer.state:set('invBusy', true, true)

    CreateThread(function()
        while inTrunk do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true) -- Muis
            EnableControlAction(0, 2, true) -- Muis
            EnableControlAction(0, 245, true) -- Chat
            EnableControlAction(0, 38, true) -- E

            SetGameplayCamRelativePitch(0.0, 1.0)

            -- Veiligheidscheck (Auto despawned of speler dood)
            if not DoesEntityExist(currentVehicle) or IsEntityDead(cache.ped) then
                TriggerServerEvent('trunk:left', netId)
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
                        
                        local off = GetOffsetFromEntityInWorldCoords(currentVehicle, 0.0, min.y - 1.5, 0.0)
                        SetEntityCoords(cache.ped, off.x, off.y, off.z)
                        SetEntityCollision(cache.ped, true, true)
                        
                        TriggerServerEvent('trunk:left', netId)
                        
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
                        startTrunkLoop(netId)
                    end
                end
            end
            Wait(0)
        end
    end)
end

local function enterTrunk(entity)
    if inTrunk then return end
    
    -- Check 1: Vooraf checken
    if not isVehicleEmpty(entity) then
        lib.notify({type = 'error', description = 'Er zitten personen in het voertuig!'})
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)

    -- STAP 2: Server Callback (Reserveren van de kofferbak)
    local success, msg = lib.callback.await('trunk:attemptEntry', false, netId)

    if not success then
        lib.notify({type = 'error', description = msg or 'Kofferbak is niet beschikbaar.'})
        return
    end

    SetVehicleDoorOpen(entity, 5, false, false)

    local progressSuccess = lib.progressBar({
        duration = Config.ActionDuration,
        label = 'In kofferbak kruipen...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer' 
        },
        -- Tick functie checkt ELKE frame
        tick = function()
            if not isVehicleEmpty(entity) then
                -- Return false stopt de progressbar direct
                return false 
            end
            return true
        end
    })

    if progressSuccess then
        -- STAP 3: LAATSTE Check (Race condition op laatste milliseconde)
        if not isVehicleEmpty(entity) then
            TriggerServerEvent('trunk:left', netId)
            SetVehicleDoorShut(entity, 5, false)
            lib.notify({type = 'error', description = 'Iemand is net ingestapt!'})
            return
        end

        -- Succes: We gaan erin
        inTrunk = true
        currentVehicle = entity
        
        TriggerServerEvent('trunk:entered', netId)
        
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
        
        startTrunkLoop(netId)
    else
        -- Geannuleerd (door speler of door tick check)
        TriggerServerEvent('trunk:left', netId) -- Maak kofferbak reservering ongedaan
        SetVehicleDoorShut(entity, 5, false)
        
        if not isVehicleEmpty(entity) then
            lib.notify({type = 'error', description = 'Actie gestopt: Er stapte iemand in!'})
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
            -- We tonen de optie ALTIJD (behalve als je al in trunk zit),
            -- de server checkt bij klikken of het mag. Dit voorkomt UI bugs.
            return not inTrunk and canEnterTrunk(entity)
        end,
        onSelect = function(data)
            enterTrunk(data.entity)
        end,
        bones = {'boot', 'trunk'}
    }
})
