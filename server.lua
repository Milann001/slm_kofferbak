-- Callback: Speler probeert kofferbak te claimen
lib.callback.register('trunk:attemptEntry', function(source, netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if not DoesEntityExist(vehicle) then return false, 'Voertuig bestaat niet meer.' end

    -- Check of er al iemand in ligt (Occupied) OF bezig is met instappen (Busy)
    if Entity(vehicle).state.trunkOccupied or Entity(vehicle).state.trunkBusy then
        return false, 'Er ligt al iemand in de kofferbak of is bezig met instappen.'
    end

    -- SLOT EROP: Zet status op 'Busy' zodat niemand anders kan starten
    Entity(vehicle).state.trunkBusy = true
    
    -- Geef groen licht aan de speler
    return true, nil
end)

-- Event: Speler zit er succesvol in
RegisterNetEvent('trunk:entered', function(netId)
    local source = source
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        -- Nu is hij echt bezet
        Entity(vehicle).state.trunkOccupied = true
        Entity(vehicle).state.trunkBusy = false -- Busy mag uit, want hij is nu Occupied
    end
end)

-- Event: Speler heeft geannuleerd of is eruit gegaan
RegisterNetEvent('trunk:left', function(netId)
    local source = source
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(vehicle) then
        -- Alles vrijgeven
        Entity(vehicle).state.trunkOccupied = false
        Entity(vehicle).state.trunkBusy = false
    end
end)
