---@comments หากเทสกับ AFUCore ให้เปลี่ยนเป็น false เพราะการสร้างข้อมูลผู้เล่นไม่เหมือนกันกับ ESX
---@type boolean หากเทสกับ AFUCore ให้เปลี่ยนเป็น false เพราะการสร้างข้อมูลผู้เล่นไม่เหมือนกันกับ ESX
IS_ES_EXTENDED_FRAMEWORK = false 

---@comments ตั้งค่าจำนวนผู้เล่นของเทส
---@type number จำนวนผู้เล่นของเทส
local testTotalPlayers <const> = 1024

---@comments ตั้งค่าจำนวน task ของเทส
---@type number จำนวน task ของเทส
local totalTasks <const> = 1



---@function RandomSteamIdentifier สร้างรหัสสเตมอร์สสำหรับผู้เล่น
---@return string รหัสสเตมอร์สของผู้เล่น
function RandomSteamIdentifier()
    local steamIdentifier = "steam:"
    for _ = 1, 17 do
        steamIdentifier = steamIdentifier .. math.random(0, 9)
    end
    return steamIdentifier
end

---@function RandomString สร้างสตริงสุ่ม
---@param length number ความยาวของสตริงสุ่ม
---@return string สตริงสุ่ม
function RandomString(length)
    local result = ""
    for _ = 1, length do
        result = result .. string.char(math.random(97, 122))
    end
    return result
end

---@comments test zone
CreateThread(function()
    ESX = exports.es_extended:getSharedObject()

    for playerId = 1, testTotalPlayers do
        local steamIdentifier = RandomSteamIdentifier()
        if IS_ES_EXTENDED_FRAMEWORK then
            ESX.createESXPlayer(steamIdentifier, playerId)
        else
            local identifier = {
                primary = steamIdentifier,
                synced = {}
            }
            local data = ESX.CreateNewPlayerData(identifier, playerId)
            ESX.SaveNewPlayer(data.xPlayer, data.syncedIdentifiers)
            ESX.ReleaseDBTList(data.xPlayer, data.shouldReleaseDBTList)
            ESX.addPlayer(data.xPlayer)
        end
    end

    local function doTask(from, to)
        for playerId = from, to do
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer then
                -- xPlayer.setMoney(math.random(5000, 23456))
                math.randomseed(GetGameTimer())
                xPlayer.addMoney(math.random(400, 1000))

                -- xPlayer.getMoney()
                xPlayer.removeMoney(math.random(10, 234))

                -- xPlayer.getIdentifier()

                -- xPlayer.getGroup()

                -- xPlayer.getAccounts()
                -- xPlayer.getInventory()
                -- xPlayer.getJob()

                -- xPlayer.addInventoryItem("bandage", math.random(1, 5))
                -- xPlayer.removeInventoryItem("bandage", math.random(1, 2))


                -- xPlayer.getLoadout()

                -- xPlayer.addWeapon("WEAPON_PISTOL", math.random(1, 100))

                -- xPlayer.setName(RandomString(20))

                -- xPlayer.setJob("police", 0)

                -- xPlayer.canCarryItem("bandage", 100)
                -- xPlayer.addWeaponComponent("WEAPON_PISTOL", "clip_default")

                -- xPlayer.addWeaponAmmo("WEAPON_PISTOL", math.random(1, 100))

                -- xPlayer.setWeaponTint("WEAPON_PISTOL", 4)

                -- xPlayer.removeWeaponComponent("WEAPON_PISTOL", "clip_default")

                -- xPlayer.removeWeaponAmmo("WEAPON_PISTOL", math.random(5, 10))

                -- xPlayer.hasWeaponComponent("WEAPON_PISTOL", "clip_default")
            end
            -- local promise_save_player = promise.new()
            -- ESX.SavePlayer(xPlayer, function()
            --     promise_save_player:resolve()
            -- end)
            -- Citizen.Await(promise_save_player)
        end
    end

    local playersPerTask = math.floor(testTotalPlayers / totalTasks)
    local startTime = os.clock() -- Start overall timing
    local completedTasks = 0
    
    for taskId = 1, totalTasks do
        local startPlayer = ((taskId - 1) * playersPerTask) + 1
        local endPlayer = taskId == totalTasks and testTotalPlayers or (taskId * playersPerTask)
        CreateThread(function()
            while true do
                local taskStartTime = os.clock()
                doTask(startPlayer, endPlayer)
                local taskEndTime = os.clock()
                local taskDuration = (taskEndTime - taskStartTime) * 1000 -- Convert to milliseconds
                
                completedTasks = completedTasks + 1
                print(("[^2Simulate Test ^3#%s-TASKS^0] ^0Task %d completed in ^1%.2f^0 ms"):format(totalTasks, taskId, taskDuration))
                
                -- Print final results when all tasks are done
                if completedTasks == totalTasks then
                    local totalDuration = (os.clock() - startTime) * 1000 -- Convert to milliseconds
                    print(("[^2Simulate Test Complete^0] ^0Total execution time: ^1%.2f^0 ms for ^1%s^0 players"):format(totalDuration, testTotalPlayers))
                end
                Wait(1000)
            end
        end)
    end
end)