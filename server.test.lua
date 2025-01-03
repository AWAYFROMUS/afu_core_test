---@type boolean เลือก Framework (true = ESX, false = AFUCore)
IS_ES_EXTENDED_FRAMEWORK = false

-- Configuration
local config = {
    testLevels = {
        light = { players = 500, delay = 5 },
        medium = { players = 1000, delay = 3 },
        heavy = { players = 1600, delay = 1 },
        stress = { players = 2000, delay = 0 }
    },
    tasks = 1,
    currentLevel = "stress", -- เลือกระดับการทดสอบ
    features = {
        SET_MONEY = true,
        ADD_MONEY = true,
        REMOVE_MONEY = true,
        GET_MONEY = false,
        GET_IDENTIFIER = false,
        GET_GROUP = false,
        GET_ACCOUNTS = false,
        GET_INVENTORY = false,
        GET_JOB = false,
        ADD_INVENTORY_ITEM = false,
        REMOVE_INVENTORY_ITEM = false,
        GET_LOADOUT = false,
        ADD_WEAPON = false,
        ADD_WEAPON_COMPONENT = false,
        ADD_WEAPON_AMMO = false,
        SET_WEAPON_TINT = false,
        REMOVE_WEAPON_COMPONENT = false,
        REMOVE_WEAPON_AMMO = false,
        HAS_WEAPON_COMPONENT = false,
        SAVE_PLAYER = false
    },
    thresholds = {
        maxErrors = 100,
        maxResponseTime = 0.5, -- seconds
        maxOperationsPerSecond = 1000
    }
}

-- Metrics tracking
local metrics = {
    operations = 0,
    errors = 0,
    startTime = 0,
    lastOperationCount = 0,
    operationsPerSecond = 0,
    avgResponseTime = 0,
    maxResponseTime = 0,
    minResponseTime = math.huge,
    lastUpdateTime = 0
}

-- Utility Functions
function RandomSteamIdentifier()
    local steamIdentifier = "steam:"
    for _ = 1, 17 do
        steamIdentifier = steamIdentifier .. math.random(0, 9)
    end
    return steamIdentifier
end

function RandomString(length)
    local result = ""
    for _ = 1, length do
        result = result .. string.char(math.random(97, 122))
    end
    return result
end

-- Update metrics function
local function updateMetrics()
    local currentTime = os.clock()
    local timeDiff = currentTime - metrics.lastUpdateTime
    
    if timeDiff >= 1.0 then -- Update every second
        metrics.operationsPerSecond = (metrics.operations - metrics.lastOperationCount) / timeDiff
        metrics.lastOperationCount = metrics.operations
        metrics.lastUpdateTime = currentTime
    end
end

-- Monitoring Thread
CreateThread(function()
    metrics.lastUpdateTime = os.clock()
    while true do
        updateMetrics()
        
        print(string.format([[
^2Load Test Metrics^0
Operations/sec: ^3%.1f^0
Total Operations: ^3%d^0
Errors: ^1%d^0
Avg Response: ^3%.3f^0ms
Max Response: ^1%.3f^0ms
Min Response: ^2%.3f^0ms
]],
            metrics.operationsPerSecond,
            metrics.operations,
            metrics.errors,
            metrics.avgResponseTime * 1000,
            metrics.maxResponseTime * 1000,
            metrics.minResponseTime * 1000
        ))
        
        -- Check thresholds
        if metrics.errors > config.thresholds.maxErrors or
           metrics.avgResponseTime > config.thresholds.maxResponseTime or
           metrics.operationsPerSecond > config.thresholds.maxOperationsPerSecond then
            print("^1Warning: Performance thresholds exceeded^0")
        end
        
        Wait(5000)
    end
end)

-- Main Test Functions
local function buildTestFunctions()
    local testFuncs = {}
    
    if config.features.SET_MONEY then
        testFuncs[#testFuncs + 1] = function(xPlayer)
            xPlayer.setMoney(math.random(5000, 23456))
        end
    end

    if config.features.ADD_MONEY then
        testFuncs[#testFuncs + 1] = function(xPlayer)
            xPlayer.addMoney(math.random(400, 1000))
        end
    end

    if config.features.REMOVE_MONEY then
        testFuncs[#testFuncs + 1] = function(xPlayer)
            xPlayer.removeMoney(math.random(10, 234))
        end
    end

    return testFuncs
end

-- Main Test Thread
CreateThread(function()
    ESX = exports.es_extended:getSharedObject()
    local testLevel = config.testLevels[config.currentLevel]
    local testTotalPlayers = testLevel.players
    
    -- Create test players
    _QUERT_IDENTIFIERS_FOR_TEST_DELETIONS = {}
    print("^3Creating test players...^0")
    
    for playerId = 1, testTotalPlayers do
        local steamIdentifier = RandomSteamIdentifier()
        table.insert(_QUERT_IDENTIFIERS_FOR_TEST_DELETIONS, {
            "DELETE FROM users WHERE identifier = ?",
            {steamIdentifier}
        })
        
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
    
    print(("^2Created %d test players^0"):format(testTotalPlayers))
    local testFuncs = buildTestFunctions()
    
    -- Execute tasks
    local function doTask(from, to)
        for playerId = from, to do
            local startTime = os.clock()
            local xPlayer = ESX.GetPlayerFromId(playerId)
            
            if xPlayer then
                for _, func in pairs(testFuncs) do
                    local success, result = pcall(func, xPlayer)
                    metrics.operations = metrics.operations + 1
                    
                    if not success then
                        metrics.errors = metrics.errors + 1
                        print(string.format("^1Error^0: %s", result))
                    end
                end
            end
            
            local responseTime = os.clock() - startTime
            metrics.avgResponseTime = (metrics.avgResponseTime * (metrics.operations - 1) + responseTime) / metrics.operations
            metrics.maxResponseTime = math.max(metrics.maxResponseTime, responseTime)
            metrics.minResponseTime = math.min(metrics.minResponseTime, responseTime)
            
            Wait(testLevel.delay)
        end
    end
    
    -- Distribute players across tasks
    local playersPerTask = math.floor(testTotalPlayers / config.tasks)
    metrics.startTime = os.clock()
    local completedTasks = 0
    
    for taskId = 1, config.tasks do
        local startPlayer = ((taskId - 1) * playersPerTask) + 1
        local endPlayer = taskId == config.tasks and testTotalPlayers or (taskId * playersPerTask)
        
        CreateThread(function()
            while true do
                local taskStartTime = os.clock()
                doTask(startPlayer, endPlayer)
                local taskDuration = (os.clock() - taskStartTime) * 1000
                
                completedTasks = completedTasks + 1
                print(string.format("^2Task %d^0 completed in ^3%.2f^0ms", taskId, taskDuration))
                
                if completedTasks == config.tasks then
                    local totalDuration = (os.clock() - metrics.startTime) * 1000
                    print(string.format("^2Test Complete^0: ^3%.2f^0ms total for ^3%d^0 players", 
                        totalDuration, testTotalPlayers))
                end
                
                Wait(1000)
            end
        end)
    end
end)

-- Cleanup on resource stop
local currentResourceName = GetCurrentResourceName()
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= currentResourceName then return end
    MySQL.transaction(_QUERT_IDENTIFIERS_FOR_TEST_DELETIONS, function(success)
        print(string.format("^2Cleanup complete^0: %d test players removed", #_QUERT_IDENTIFIERS_FOR_TEST_DELETIONS))
    end)
end)
