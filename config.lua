Config = {}

-- Hoe lang het duurt om in/uit te stappen (in ms)
Config.ActionDuration = 3000

-- Voertuigklassen die toegestaan zijn (GTA V Class ID's)
-- 0: Compacts, 1: Sedans, 2: SUVs, 3: Coupes, 4: Muscle, 5: Sports Classics
-- 6: Sports, 7: Super, 9: Off-road, 10: Industrial, 11: Utility, 12: Vans
-- WEIGERT: Cycles, Motorcycles, Boats, Helicopters, Planes, Trains
Config.AllowedClasses = {
    [0] = true, [1] = true, [2] = true, [3] = true, 
    [4] = true, [5] = true, [6] = true, [7] = true, 
    [9] = true, [10] = true, [11] = true, [12] = true
}

-- Offset correcties voor specifieke voertuigen indien de automatische berekening faalt
-- Voorbeeld: `['adder'] = {x=0.0, y=-0.5, z=0.2}`
Config.CustomOffsets = {}