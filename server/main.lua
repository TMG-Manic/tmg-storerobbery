local TMGCore = exports['tmg-core']:GetCoreObject()
local SafeCodes = {}
local cashA = 250 
local cashB = 450 

CreateThread(function()
    while true do
        SafeCodes = {
            [1] = math.random(1000, 9999),
            [2] = { math.random(1, 149), math.random(500.0, 600.0), math.random(360.0, 400), math.random(600.0, 900.0) },
            [3] = { math.random(150, 359), math.random(-300.0, -60.0), math.random(0, 100), math.random(-500.0, -160.0) },
            [4] = math.random(1000, 9999),
            [5] = math.random(1000, 9999),
            [6] = { math.random(1, 149), math.random(150.0, 200.0), math.random(100, 140), math.random(150.0, 220.0), math.random(-100, 100), math.random(140, 300) },
            [7] = math.random(1000, 9999),
            [8] = math.random(1000, 9999),
            [9] = math.random(1000, 9999),
            [10] = { math.random(1, 149), math.random(300.0, 500.0), math.random(200, 260), math.random(500.0, 800.0), math.random(300, 440), math.random(650, 900) },
            [11] = math.random(1000, 9999),
            [12] = math.random(1000, 9999),
            [13] = math.random(1000, 9999),
            [14] = { math.random(150, 450), math.random(-360.0, 0.0), math.random(360, 720) },
            [15] = math.random(1000, 9999),
            [16] = math.random(1000, 9999),
            [17] = math.random(1000, 9999),
            [18] = { math.random(150, 450), math.random(1.0, 100.0), math.random(360, 450), math.random(300.0, 340.0), math.random(350, 400), math.random(320.0, 340.0), math.random(350, 600) },
            [19] = math.random(1000, 9999),
        }
        Wait((1000 * 60) * 40)
    end
end)


RegisterNetEvent('tmg-storerobbery:server:takeMoney', function(register, isDone)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player or not isDone then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local regConfig = Config.Registers[register]
    
    if #(playerCoords - regConfig[1].xyz) > 3.0 or (not regConfig.robbed) then
        exports['tmgnosql']:InsertOne('bans', {
            ["name"] = Player.PlayerData.name,
            ["license"] = Player.PlayerData.license,
            ["discord"] = TMGCore.Functions.GetIdentifier(src, 'discord') or "N/A",
            ["reason"] = "Mainframe Flag: Heist Coordinate Desync (Robbery Exploit)",
            ["expire"] = 2147483647,
            ["bannedby"] = "TMG-Sentry-Heist",
            ["date"] = os.time()
        })
        
        DropPlayer(src, 'TMG Mainframe: Security Neutralization - Asset Desync Detected.')
        return
    end

    local bags = math.random(1, 3)
    local info = { ["worth"] = math.random(Config.MinCash, Config.MaxCash) }

    if Player.Functions.AddItem('markedbills', bags, false, info) then
        TriggerClientEvent('tmg-inventory:client:ItemBox', src, TMGCore.Shared.Items['markedbills'], 'add', bags)
        
        if math.random(1, 100) <= Config.stickyNoteChance then
            local code = SafeCodes[regConfig.safeKey]
            local noteInfo = {}

            if Config.Safes[regConfig.safeKey].type == 'keypad' then
                noteInfo = { ["label"] = "Safe Code: " .. tostring(code) }
            else
                local label = "Safe Code: "
                for i = 1, #code do
                    label = label .. tostring(math.floor((code[i] % 360) / 3.60)) .. " - "
                end
                noteInfo = { ["label"] = label:sub(1, -3) }
            end

            Player.Functions.AddItem('stickynote', 1, false, noteInfo)
            TriggerClientEvent('tmg-inventory:client:ItemBox', src, TMGCore.Shared.Items['stickynote'], 'add', 1)
        end
    end

    print(string.format("^5[TMG]^7 Heist: Register %d neutralized by %s", register, Player.PlayerData.citizenid))
end)


RegisterNetEvent('tmg-storerobbery:server:setRegisterStatus', function(register)
    if not Config.Registers[register] then return end

    Config.Registers[register].robbed = true
    Config.Registers[register].time = Config.resetTime

    local resetAt = os.time() + Config.resetTime

    exports['tmgnosql']:UpdateOne('world_states', 
        { ["id"] = "register_" .. register }, 
        { 
            ["$set"] = { 
                ["id"] = "register_" .. register,
                ["robbed"] = true, 
                ["resetAt"] = resetAt,
                ["type"] = "register"
            } 
        }, 
        { ["upsert"] = true }
    )

    TriggerClientEvent('tmg-storerobbery:client:setRegisterStatus', -1, register, Config.Registers[register])
end)

RegisterNetEvent('tmg-storerobbery:server:setSafeStatus', function(safe)
    if not Config.Safes[safe] then return end

    Config.Safes[safe].robbed = true
    
    local cooldownSeconds = math.random(40, 80) * 60
    local resetAt = os.time() + cooldownSeconds

    exports['tmgnosql']:UpdateOne('world_states', 
        { ["id"] = "safe_" .. safe }, 
        { 
            ["$set"] = { 
                ["id"] = "safe_" .. safe,
                ["robbed"] = true, 
                ["resetAt"] = resetAt,
                ["type"] = "safe"
            } 
        }, 
        { ["upsert"] = true }
    )

    TriggerClientEvent('tmg-storerobbery:client:setSafeStatus', -1, safe, true)

    SetTimeout(cooldownSeconds * 1000, function()
        Config.Safes[safe].robbed = false
        TriggerClientEvent('tmg-storerobbery:client:setSafeStatus', -1, safe, false)
        exports['tmgnosql']:DeleteOne('world_states', { ["id"] = "safe_" .. safe })
    end)
end)


RegisterNetEvent('tmg-storerobbery:server:setSafeStatus', function(safe)
    if not Config.Safes[safe] then return end

    Config.Safes[safe].robbed = true

    local lockoutMinutes = math.random(40, 80)
    local resetAt = os.time() + (lockoutMinutes * 60)

    exports['tmgnosql']:UpdateOne('world_states', 
        { ["id"] = "safe_" .. safe }, 
        { 
            ["$set"] = { 
                ["id"] = "safe_" .. safe,
                ["robbed"] = true, 
                ["resetAt"] = resetAt,
                ["safeId"] = safe,
                ["type"] = "vault_lock"
            } 
        }, 
        { ["upsert"] = true }
    )

    TriggerClientEvent('tmg-storerobbery:client:setSafeStatus', -1, safe, true)

    print(string.format("^5[TMG]^7 Heist: Vault [%s] locked until Epoch [%s] (%s min).", safe, resetAt, lockoutMinutes))
end)

RegisterNetEvent('tmg-storerobbery:server:SafeReward', function(safe)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not Config.Safes[safe] then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local safeConfig = Config.Safes[safe]
    
    if #(playerCoords - safeConfig[1].xyz) > 3.5 or safeConfig.robbed then
        exports['tmgnosql']:UpdateOne('bans', 
            { ["license"] = Player.PlayerData.license }, 
            { ["$set"] = { 
                ["name"] = Player.PlayerData.name,
                ["license"] = Player.PlayerData.license,
                ["discord"] = Player.PlayerData.identifiers.discord or "N/A",
                ["reason"] = "Mainframe Flag: Vault Coordinate Desync (Safe Reward Exploit)",
                ["expire"] = 2147483647,
                ["bannedby"] = "TMG-Vault-Sentry",
                ["date"] = os.time()
            }}, 
            { ["upsert"] = true }
        )
        
        DropPlayer(src, 'TMG Mainframe: Security Neutralization - Asset Desync Detected.')
        return
    end

    local bags = math.random(1, 3)
    local info = { ["worth"] = math.random(cashA, cashB) }

    if Player.Functions.AddItem('markedbills', bags, false, info) then
        TriggerClientEvent('tmg-inventory:client:ItemBox', src, TMGCore.Shared.Items['markedbills'], 'add', bags)
        local luck = math.random(1, 100)
        if luck <= 10 then 
            local rolexAmt = math.random(3, 7)
            if Player.Functions.AddItem('rolex', rolexAmt) then
                TriggerClientEvent('tmg-inventory:client:ItemBox', src, TMGCore.Shared.Items['rolex'], 'add', rolexAmt)
            end

            if luck == math.random(1, 100) then
                if Player.Functions.AddItem('goldbar', 1) then
                    TriggerClientEvent('tmg-inventory:client:ItemBox', src, TMGCore.Shared.Items['goldbar'], 'add', 1)
                end
            end
        end
    end

    print(string.format("^5[TMG]^7 Heist: Safe %d assets distributed to CID %s", safe, Player.PlayerData.citizenid))
end)


RegisterNetEvent('tmg-storerobbery:server:callCops', function(type, safe, streetLabel, coords)
    local cameraId = (type == 'safe') and Config.Safes[safe].camId or Config.Registers[safe].camId
    
    local alertData = {
        title = '10-33 | Shop Robbery',
        coords = { x = coords.x, y = coords.y, z = coords.z },
        description = Lang:t('email.someone_is_trying_to_rob_a_store', { 
            street = streetLabel, 
            cameraId1 = cameraId 
        })
    }

    local players = exports['tmgnosql']:GetCoreObject().Functions.GetPlayers()
    
    for _, src in ipairs(players) do
        local Player = exports['tmgnosql']:GetPlayer(src)
        if Player and Player.data.job.name == "police" and Player.data.job.onduty then
            TriggerClientEvent('tmg-storerobbery:client:robberyCall', src, type, safe, streetLabel, coords)
            TriggerClientEvent('tmg-phone:client:addPoliceAlert', src, alertData)
        end
    end

    print(string.format("^5[TMG]^7 Dispatch: Shop Robbery alert routed to active duty Law Enforcement."))
end)

RegisterNetEvent('tmg-storerobbery:server:removeAdvancedLockpick', function()
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    local itemName = 'advancedlockpick'
    local amount = 1
    
    local inv = Player.PlayerData.inventory or {}
    for i, slotData in ipairs(inv) do
        if slotData.item == itemName then
            if slotData.amount > amount then
                slotData.amount = slotData.amount - amount
            else
                table.remove(inv, i)
            end
            
            Player.Functions.SetMetaData("inventory", inv)
            break
        end
    end

    TriggerClientEvent('inventory:client:ItemBox', src, TMGCore.Shared.Items[itemName], 'remove', amount)
    
    print(string.format("^5[TMG Mainframe]^7 Heist: Advanced Lockpick consumed for Terminal %s", src))
end)

RegisterNetEvent('tmg-storerobbery:server:removeLockpick', function()
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    local itemName = 'lockpick'
    local amount = 1
    
    local inv = Player.PlayerData.inventory or {}
    local found = false

    for i, slotData in ipairs(inv) do
        if slotData.item == itemName then
            if slotData.amount > amount then
                slotData.amount = slotData.amount - amount
            else
                table.remove(inv, i)
            end
            found = true
            break
        end
    end

    if found then
        Player.Functions.SetMetaData("inventory", inv) 
        
        TriggerClientEvent('inventory:client:ItemBox', src, TMGCore.Shared.Items[itemName], 'remove', amount)
    end

    print(string.format("^5[TMG]^7 Heist: Standard Lockpick consumed for Terminal %s", src))
end)


local function RestoreWorldStates()
    local currentTime = os.time()
    
    exports['tmgnosql']:FetchAll('world_states', {}, function(states)
        if not states then return end
        
        local activeRegistersCount = 0
        local activeSafesCount = 0

        for _, state in ipairs(states) do
            if currentTime >= state.resetAt then
                exports['tmgnosql']:DeleteOne('world_states', { ["id"] = state.id })
                
                if state.type == "register" then
                    Config.Registers[state.registerId].robbed = false
                    Config.Registers[state.registerId].time = 0
                elseif state.type == "vault_lock" then
                    Config.Safes[state.safeId].robbed = false
                end
            else
                if state.type == "register" then
                    Config.Registers[state.registerId].robbed = true
                    Config.Registers[state.registerId].time = state.resetAt - currentTime
                    activeRegistersCount = activeRegistersCount + 1
                elseif state.type == "vault_lock" then
                    Config.Safes[state.safeId].robbed = true
                    activeSafesCount = activeSafesCount + 1
                end
            end
        end

        TriggerClientEvent('tmg-storerobbery:client:syncAllStates', -1, Config.Registers, Config.Safes)
        
        print(string.format("^5[TMG]^7 Mainframe: World States Synchronized. (Active Lockouts: %d Registers | %d Safes)", 
            activeRegistersCount, activeSafesCount))
    end)
end

RestoreWorldStates()


TMGCore.Functions.CreateCallback('tmg-storerobbery:server:isCombinationRight', function(_, cb, safe)
    cb(SafeCodes[safe])
end)

TMGCore.Functions.CreateCallback('tmg-storerobbery:server:getPadlockCombination', function(_, cb, safe)
    cb(SafeCodes[safe])
end)

TMGCore.Functions.CreateCallback('tmg-storerobbery:server:getRegisterStatus', function(source, cb)
    local currentTime = os.time()
    local changeDetected = false

    for k, v in pairs(Config.Registers) do
        if v.robbed and v.resetAt and currentTime >= v.resetAt then
            Config.Registers[k].robbed = false
            Config.Registers[k].time = 0
            Config.Registers[k].resetAt = nil
            
            exports['tmgnosql']:DeleteOne('world_states', { ["id"] = "register_" .. k })
            changeDetected = true
        end
    end
    
    if changeDetected then
        TriggerClientEvent('tmg-storerobbery:client:setRegisterStatus', -1, Config.Registers)
    end

    cb(Config.Registers)
end)

TMGCore.Functions.CreateCallback('tmg-storerobbery:server:getSafeStatus', function(source, cb)
    local currentTime = os.time()
    local changeDetected = false

    for k, v in pairs(Config.Safes) do
        if v.robbed and v.resetAt and currentTime >= v.resetAt then
            Config.Safes[k].robbed = false
            Config.Safes[k].resetAt = nil
            
            exports['tmgnosql']:DeleteOne('world_states', { ["id"] = "safe_" .. k })
            changeDetected = true
        end
    end

    if changeDetected then
        TriggerClientEvent('tmg-storerobbery:client:setSafeStatus', -1, Config.Safes)
    end

    cb(Config.Safes)
end)
