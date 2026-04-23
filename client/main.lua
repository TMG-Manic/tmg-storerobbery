local TMGCore = exports['tmg-core']:GetCoreObject()
local currentRegister = 0
local currentSafe = 0
local copsCalled = false
local CurrentCops = 0
local PlayerJob = {}
local onDuty = false
local usingAdvanced = false

CreateThread(function()
    setupRegister()
    setupSafes()
    
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local sleep = 1500 
        local inRange = false

        for safe, _ in pairs(Config.Safes) do
            local safePos = Config.Safes[safe][1].xyz
            local dist = #(pos - safePos)

            if dist < 4.0 then
                sleep = 0 
                inRange = true
                
                if dist < 1.0 then
                    if not Config.Safes[safe].robbed then
                        DrawText3Ds(safePos, Lang:t('text.try_combination'))
                        
                        if IsControlJustPressed(0, 38) then
                            if not isRobbing then
                                TriggerSafeRobbery(safe, pos)
                            end
                        end
                    else
                        DrawText3Ds(safePos, Lang:t('text.safe_opened'))
                    end
                end
            end
        end

        if not inRange then
            for k, v in pairs(Config.Registers) do
                if #(pos - v[1].xyz) < 4.0 then
                    sleep = 0
                    inRange = true
                    
                end
            end
        end

        Wait(sleep)
    end
end)


function TriggerSafeRobbery(safe, pos)
    if CurrentCops < Config.MinimumStoreRobberyPolice then
        TMGCore.Functions.Notify(Lang:t('error.minimum_store_robbery_police', { MinimumStoreRobberyPolice = Config.MinimumStoreRobberyPolice }), 'error')
        return
    end

    isRobbing = true
    currentSafe = safe

    if math.random(100) <= 50 then
        TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
    end

    if not copsCalled then
        local s1, s2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
        local streetLabel = GetStreetNameFromHashKey(s1)
        if s2 ~= 0 then streetLabel = streetLabel .. ' ' .. GetStreetNameFromHashKey(s2) end
        
        TriggerServerEvent('tmg-storerobbery:server:callCops', 'safe', currentSafe, streetLabel, pos)
        copsCalled = true
    end

    if Config.Safes[safe].type == 'keypad' then
        SendNUIMessage({ action = 'openKeypad' })
        SetNuiFocus(true, true)
    else
        TMGCore.Functions.TriggerCallback('tmg-storerobbery:server:getPadlockCombination', function(combination)
            if #(GetEntityCoords(PlayerPedId()) - pos) < 2.0 then
                TriggerEvent('SafeCracker:StartMinigame', combination)
            else
                isRobbing = false 
            end
        end, safe)
    end
end

RegisterNetEvent('SafeCracker:EndMinigame', function(success)
    if isRobbing and currentSafe ~= 0 then
        if success then
            TriggerServerEvent('tmg-storerobbery:server:SafeReward', currentSafe)
            TriggerServerEvent('tmg-storerobbery:server:SetSafeStatus', currentSafe)
            
            if not TMGCore.Functions.IsWearingGloves() then
                TriggerServerEvent('evidence:server:CreateFingerDrop', GetEntityCoords(PlayerPedId()))
            end
        end
        isRobbing = false
        currentSafe = 0
    end
end)


RegisterNetEvent('lockpicks:UseLockpick', function(isAdvanced)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local closestRegister = nil
    local minDistance = 1.5 

    for k, v in pairs(Config.Registers) do
        local dist = #(pos - v[1].xyz)
        if dist < minDistance then
            closestRegister = k
            minDistance = dist 
        end
    end

    if not closestRegister or Config.Registers[closestRegister].robbed then return end
    
    if CurrentCops < Config.MinimumStoreRobberyPolice then
        TMGCore.Functions.Notify(Lang:t('error.minimum_store_robbery_police', { 
            MinimumStoreRobberyPolice = Config.MinimumStoreRobberyPolice 
        }), 'error')
        return
    end

    usingAdvanced = isAdvanced
    currentRegister = closestRegister
    
    StartRegisterRobbery(currentRegister, pos)
end)



function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    if timeout >= 100 then
        print("[TMG Mainframe] Animation Load Failed: " .. dict)
        return false
    end
    return true
end

function takeAnim()
    local ped = PlayerPedId()
    local ad = 'amb@prop_human_bum_bin@idle_b'
    
    if loadAnimDict(ad) then
        TaskPlayAnim(ped, ad, 'idle_d', 8.0, 8.0, -1, 50, 0, false, false, false)
        Wait(2500)
        TaskPlayAnim(ped, ad, 'exit', 8.0, 8.0, -1, 50, 0, false, false, false)
    end
end

DrawText3Ds = function(coords, text)
    SetTextScale(0.32, 0.32) 
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    BeginTextCommandDisplayText('STRING')
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    
    
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end



function lockpick(bool)
    SetNuiFocus(bool, bool)
    SendNUIMessage({
        action = 'ui',
        toggle = bool,
    })
    
    SetCursorLocation(0.5, 0.5) 
end

RegisterNUICallback('success', function(_, cb)
    if currentRegister ~= 0 then
        lockpick(false)
        
        openingDoor = true 
        local lockpickTime = 25000 
        local ped = PlayerPedId()

        TriggerServerEvent('tmg-storerobbery:server:setRegisterStatus', currentRegister)
        
        TMGCore.Functions.Progressbar('search_register', Lang:t('text.emptying_the_register'), lockpickTime, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'veh@break_in@0h@p_m_one@',
            anim = 'low_force_entry_ds',
            flags = 16,
        }, {}, {}, function() 
            openingDoor = false
            ClearPedTasks(ped)
            
            TriggerServerEvent('tmg-storerobbery:server:takeMoney', currentRegister, true)
            
            currentRegister = 0 
        end, function() 
            openingDoor = false
            ClearPedTasks(ped)
            TMGCore.Functions.Notify(Lang:t('error.process_canceled'), 'error')
            
            currentRegister = 0
        end)

        CreateThread(function()
            while openingDoor do
                TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                Wait(5000) 
            end
        end)
    else
        SendNUIMessage({ action = 'close' }) 
    end
    cb('ok')
end)
function LockpickDoorAnim(time)
    local ped = PlayerPedId()
    local ad = 'veh@break_in@0h@p_m_one@'
    local anim = 'low_force_entry_ds'
    
    if not loadAnimDict(ad) then return end

    TaskPlayAnim(ped, ad, anim, 3.0, 3.0, -1, 16, 0, false, false, false)
    
    openingDoor = true

    CreateThread(function()
        while openingDoor do
            if IsEntityDead(ped) or IsPedRagdoll(ped) then
                openingDoor = false
                break
            end
            Wait(500) 
        end

        StopAnimTask(ped, ad, anim, 1.0)
    end)
end

function setupRegister()
    TMGCore.Functions.TriggerCallback('tmg-storerobbery:server:getRegisterStatus', function(Registers)
        for k in pairs(Registers) do
            Config.Registers[k].robbed = Registers[k].robbed
        end
    end)
end

function setupSafes()
    TMGCore.Functions.TriggerCallback('tmg-storerobbery:server:getSafeStatus', function(Safes)
        for k in pairs(Safes) do
            Config.Safes[k].robbed = Safes[k].robbed
        end
    end)
end

RegisterNUICallback('callcops', function(_, cb)
    TriggerEvent('police:SetCopAlert')
    cb('ok')
end)

RegisterNetEvent('SafeCracker:EndMinigame', function(won)
    if currentSafe ~= 0 then
        if won then
            if currentSafe ~= 0 then
                if not Config.Safes[currentSafe].robbed then
                    SetNuiFocus(false, false)
                    TriggerServerEvent('tmg-storerobbery:server:SafeReward', currentSafe)
                    TriggerServerEvent('tmg-storerobbery:server:setSafeStatus', currentSafe)
                    currentSafe = 0
                    takeAnim()
                end
            else
                SendNUIMessage({
                    action = 'kekw',
                })
            end
        end
    end
    copsCalled = false
end)

RegisterNUICallback('PadLockSuccess', function(_, cb)
    if currentSafe ~= 0 then
        if not Config.Safes[currentSafe].robbed then
            SendNUIMessage({
                action = 'kekw',
            })
        end
    else
        SendNUIMessage({
            action = 'kekw',
        })
    end
    cb('ok')
end)

RegisterNUICallback('PadLockClose', function(_, cb)
    SetNuiFocus(false, false)
    copsCalled = false
    cb('ok')
end)

RegisterNUICallback('CombinationFail', function(_, cb)
    PlaySound(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback('fail', function(_, cb)
    if usingAdvanced then
        if math.random(1, 100) < 20 then
            TriggerServerEvent('tmg-storerobbery:server:removeAdvancedLockpick')
            TriggerEvent('tmg-inventory:client:ItemBox', TMGCore.Shared.Items['advancedlockpick'], 'remove')
        end
    else
        if math.random(1, 100) < 40 then
            TriggerServerEvent('tmg-storerobbery:server:removeLockpick')
            TriggerEvent('tmg-inventory:client:ItemBox', TMGCore.Shared.Items['lockpick'], 'remove')
        end
    end
    if (not TMGCore.Functions.IsWearingGloves() and math.random(1, 100) <= 25) then
        local pos = GetEntityCoords(PlayerPedId())
        TriggerServerEvent('evidence:server:CreateFingerDrop', pos)
        TMGCore.Functions.Notify(Lang:t('error.you_broke_the_lock_pick'))
    end
    lockpick(false)
    cb('ok')
end)

RegisterNUICallback('exit', function(_, cb)
    lockpick(false)
    cb('ok')
end)

RegisterNUICallback('TryCombination', function(data, cb)
    TMGCore.Functions.TriggerCallback('tmg-storerobbery:server:isCombinationRight', function(combination)
        if tonumber(data.combination) ~= nil then
            if tonumber(data.combination) == combination then
                TriggerServerEvent('tmg-storerobbery:server:SafeReward', currentSafe)
                TriggerServerEvent('tmg-storerobbery:server:setSafeStatus', currentSafe)
                SetNuiFocus(false, false)
                SendNUIMessage({
                    action = 'closeKeypad',
                    error = false,
                })
                currentSafe = 0
                takeAnim()
            else
                TriggerEvent('police:SetCopAlert')
                SetNuiFocus(false, false)
                SendNUIMessage({
                    action = 'closeKeypad',
                    error = true,
                })
                currentSafe = 0
            end
        end
        cb('ok')
    end, currentSafe)
end)

RegisterNetEvent('tmg-storerobbery:client:setRegisterStatus', function(batch, val)
    
    if (type(batch) ~= 'table') then
        Config.Registers[batch] = val
    else
        for k in pairs(batch) do
            Config.Registers[k] = batch[k]
        end
    end
end)

RegisterNetEvent('tmg-storerobbery:client:setSafeStatus', function(safe, bool)
    Config.Safes[safe].robbed = bool
end)

RegisterNetEvent('tmg-storerobbery:client:robberyCall', function(_, _, _, coords)
    if (PlayerJob.name == 'police' or PlayerJob.type == 'leo') and onDuty then
        PlaySound(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', 0, 0, 1)
        TriggerServerEvent('police:server:policeAlert', Lang:t('email.storerobbery_progress'))

        local transG = 250
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 458)
        SetBlipColour(blip, 1)
        SetBlipDisplay(blip, 4)
        SetBlipAlpha(blip, transG)
        SetBlipScale(blip, 1.0)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Lang:t('email.shop_robbery'))
        EndTextCommandSetBlipName(blip)
        while transG ~= 0 do
            Wait(180 * 4)
            transG = transG - 1
            SetBlipAlpha(blip, transG)
            if transG == 0 then
                SetBlipSprite(blip, 2)
                RemoveBlip(blip)
                return
            end
        end
    end
end)
