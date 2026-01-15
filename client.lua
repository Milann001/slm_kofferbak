local inTrunk = false
local currentVehicle = nil

-- Hulpfunctie: Check of voertuig klasse toegestaan is en of slot open is
local function canEnterTrunk(vehicle)
    local class = GetVehicleClass(vehicle)
    if not Config.AllowedClasses[class] then return false end
    if GetVehicleDoorLockStatus(vehicle) > 1 then return false end -- Voertuig op slot
    
    local bootBone = GetEntityBoneIndexByName(vehicle, 'boot')
    if bootBone == -1 then bootBone = GetEntityBoneIndexByName(vehicle, 'trunk') end
    
    return bootBone ~= -1
end

-- Hulpfunctie: Check of het voertuig volledig leeg is
local function isVehicleEmpty(vehicle)
    -- Check bestuurder
    if not IsVehicleSeatFree(vehicle, -1) then return false end
    
    -- Check passagiers
    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for i = 0, maxSeats - 1 do
        if not IsVehicleSeatFree(vehicle, i) then return false end
    end
    
    return true
end

-- Hulpfunctie: Bereken positie in/achter voertuig (voor camera focus)
local function getTrunkOffset(vehicle)
    local model = GetEntityModel(vehicle)
    local min, max = GetModelDimensions(model)
    local zPos = (max.z - min.z) / 2
    return vector3(0.0, min.y + 0.4, zPos - 0.2)
end

-- De loop die draait als de speler in de kofferbak ligt
local function startTrunkLoop()
    lib.showTextUI('E - Uit kofferbak', {position = "left-center"})
    
    -- Vertel ox_inventory dat de speler "bezig" is
    LocalPlayer.state:set('invBusy', true, true)

    CreateThread(function()
        while inTrunk do
            -- Disable controls
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true) -- Muis Camera X
            EnableControlAction(0, 2, true) -- Muis Camera Y
            EnableControlAction(0, 245, true) -- Chat (T)
            EnableControlAction(0, 38, true) -- E Key

            -- Camera rotatie toestaan maar beperken
            SetGameplayCamRelativePitch(0.0, 1.0)

            -- Veiligheidscheck: Als auto despawned of speler dood gaat
            if not DoesEntityExist(currentVehicle) or IsEntityDead(cache.ped) then
                inTrunk = false
                LocalPlayer.state:set('invBusy', false, true)
                
                -- Reset zichtbaarheid en collision
                DetachEntity(cache.ped, true, true)
                SetEntityVisible(cache.ped, true, false)
                SetEntityCollision(cache.ped, true, true)
                
                lib.hideTextUI()
                ClearPedTasksImmediately(cache.ped)
            end

            -- Uitstappen logica
            if IsDisabledControlJustPressed(0, 38) then -- E key
                local speed = GetEntitySpeed(currentVehicle) * 3.6
                
                if speed > 1.0 then
                    lib.notify({type = 'error', description = 'Voertuig rijdt te snel om eruit te gaan!'})
                else
                    inTrunk = false -- Breek de loop
                    
                    if lib.progressBar({
                        duration = Config.ActionDuration,
                        label = 'Kofferbak uitklimmen...',
                        useWhileDead = false,
                        canCancel = false,
                        disable = { move = true, car = true, mouse = false, combat = true }
                    }) then
                        -- 1. Kofferbak openen
                        SetVehicleDoorOpen(currentVehicle, 5, false, false)
                        Wait(500)
                        
                        -- 2. Speler weer zichtbaar maken VOOR teleport
                        SetEntityVisible(cache.ped, true, false)
                        
                        -- 3. Positie bepalen
                        local model = GetEntityModel(currentVehicle)
                        local min, _ = GetModelDimensions(model)
                        
                        -- 4. Speler losmaken
                        DetachEntity(cache.ped, true, true)
                        
                        -- 5. Teleporteer speler VEILIG achter het voertuig
                        -- min.y - 1.5 zorgt voor genoeg afstand van de bumper
                        local off = GetOffsetFromEntityInWorldCoords(currentVehicle, 0.0, min.y - 1.5, 0.0)
                        SetEntityCoords(cache.ped, off.x, off.y, off.z)
                        
                        -- 6. Forceer collision weer aan
                        SetEntityCollision(cache.ped, true, true)
                        
                        -- 7. Reset status
                        ClearPedTasks(cache.ped)
                        LocalPlayer.state:set('invBusy', false, true)
                        lib.hideTextUI()
                        
                        -- 8. Kofferbak weer sluiten en cleanup
                        SetTimeout(1000, function()
                             if DoesEntityExist(currentVehicle) then
                                SetVehicleDoorShut(currentVehicle, 5, false) 
                             end
                             currentVehicle = nil
                        end)
                    else
                        -- Als progress geannuleerd zou worden
                        inTrunk = true
                        startTrunkLoop()
                    end
                end
            end
            Wait(0)
        end
    end)
end

-- De functie om de kofferbak in te gaan
local function enterTrunk(entity)
    if inTrunk then return end
    
    -- Check of het voertuig leeg is (NIEUW)
    if not isVehicleEmpty(entity) then
        lib.notify({type = 'error', description = 'Je kan pas in de kofferbak liggen als er niemand meer in het voertuig zit!'})
        return
    end

    -- Kofferbak openen VOOR de animatie start
    SetVehicleDoorOpen(entity, 5, false, false)

    if lib.progressBar({
        duration = Config.ActionDuration,
        label = 'In kofferbak kruipen...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer' 
        }
    }) then
        -- Succesvol
        inTrunk = true
        currentVehicle = entity
        
        -- Animatie laden
        local dict = 'timetable@floyd@cryingonbed@base'
        lib.requestAnimDict(dict)
        
        -- Attach Logic
        local offset = Config.CustomOffsets[GetEntityModel(entity)] or getTrunkOffset(entity)
        AttachEntityToEntity(cache.ped, entity, 0, offset.x, offset.y, offset.z, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
        
        -- Speel lig animatie (voor hitbox bepaling, ook al ben je onzichtbaar)
        TaskPlayAnim(cache.ped, dict, 'base', 8.0, -8.0, -1, 1, 0, false, false, false)
        
        -- MAAK ONZICHTBAAR (NIEUW)
        -- Dit zorgt ervoor dat je niet door de bumper heen clipt
        SetEntityVisible(cache.ped, false, false)

        -- Kofferbak SLUITEN na korte vertraging
        SetTimeout(800, function()
            if inTrunk and DoesEntityExist(entity) then
                SetVehicleDoorShut(entity, 5, false)
            end
        end)
        
        startTrunkLoop()
    else
        -- Geannuleerd? Doe de klep weer dicht
        SetVehicleDoorShut(entity, 5, false)
        lib.notify({type = 'inform', description = 'Geannuleerd'})
    end
end

-- Initialiseer ox_target
exports.ox_target:addGlobalVehicle({
    {
        label = 'In kofferbak liggen',
        icon = 'fa-solid fa-car-rear',
        distance = 2.5,
        canInteract = function(entity)
            -- Checkt nu ook of de auto leeg is in de interactie check (optioneel, maar netjes)
            return not inTrunk and canEnterTrunk(entity)
        end,
        onSelect = function(data)
            enterTrunk(data.entity)
        end,
        bones = {'boot', 'trunk'}
    }
})