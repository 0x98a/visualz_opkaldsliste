-- -------------------------------------------------------------------------- --
--                                  Variables                                 --
-- -------------------------------------------------------------------------- --
local calls, callid = {}, {}

-- Config load jobs for id and load the calls array for each job in config, and load the for the loadedJobs array which will do better performance
for k, v in ipairs(Config.Jobs) do
    calls[v] = {}
    callid[v] = 0
    loadedJobs[v] = k
end


-- Test call
-- RegisterCommand('test_call', function(src, args)
--     AddCall(d, "Test call! Skynd jer!", "police", { x = 0, z = 0, y = 0 })
-- end, false)

-- -------------------------------------------------------------------------- --
--                                  Functions                                 --
-- -------------------------------------------------------------------------- --

function AddCall(src, message, number, coords)
    if calls[number] ~= nil then
        local playerCoords = nil

        if src == nil then
            if type(coords) == "vector3" or (type(coords) == "table" and coords.x and coords.y and coords.z) then
                playerCoords = type(coords) == "vector3" and coords or vector3(coords.x, coords.y, coords.z)
            else
                print("Fejl: Ugyldige koordinater, brug vector3(x, y, z) eller {x = 0, y = 0, z = 0}")
                return
            end
        end

        local data = {
            identifier = src ~= nil and GetIdentifier(src) or nil,
            date = os.date("%x %X"),
            message = message,
            taken = nil,
            deleted = false,
            fromnumber = GetPlayer(src) and GetPhoneNumber(GetIdentifier(src)) or Config.AutomaticMessage,
            number = number,
            coords = src ~= nil and GetEntityCoords(GetPlayerPed(src)) or playerCoords,
            onCall = 0,
            onCallPlayers = {},
            id = callid[number] + 1
        }

        callid[number] = callid[number] + 1
        
        table.insert(calls[number], data)
        SendToAddCall(number, calls[number][callid[number]])
    end
end

-- -------------------------------------------------------------------------- --
--                                 Net Events                                 --
-- -------------------------------------------------------------------------- --

RegisterNetEvent("visualz_opkaldsliste:server:takeCall")
AddEventHandler("visualz_opkaldsliste:server:takeCall", function(id, number)
    if calls[number][id] ~= nil then
        local xPlayer = GetPlayerFromIdentifier(calls[number][id].identifier)
        local sourcePlayer = GetPlayer(source)
        local identifier = GetIdentifier(source)
    
        -- Tjek om sourcen faktisk er en spiller, og hvis det er så tjek om han har jobbet.
        if not sourcePlayer or sourcePlayer.job.name ~= number or not identifier then
            return
        end
    
        -- Cache tingene til locals, så vi ikke skal tilgå arrays flere gange og den måde bruge mindre in-memory
        local currOpkald = calls[number][id]
        local onCallPlayers = currOpkald["onCallPlayers"]
    
        if not onCallPlayers[identifier] then
            onCallPlayers[identifier] = sourcePlayer.getName() -- Ikke standalone
            currOpkald.onCall = currOpkald.onCall + 1
    
            if not currOpkald["taken"] then
                currOpkald["taken"] = sourcePlayer.getName() -- Ikke standalone
    
                if Config.SendTakenMessage and currOpkald.fromnumber ~= Config.AutomaticMessage and xPlayer and xPlayer.source then
                    SendTakenMessage(currOpkald.identifier, currOpkald.number, currOpkald.fromnumber, xPlayer)
                end
            end
    
            UpdateCall(number, currOpkald["taken"], currOpkald.onCall, onCallPlayers, id)
        end
    else
        print("Fejl: Ugyldigt opkald blev parsed i takeCall eventet??")
        return
    end
end)

RegisterNetEvent("visualz_opkaldsliste:server:dropCall")
AddEventHandler("visualz_opkaldsliste:server:dropCall", function(id, number)
    local opkald = calls[number][id]
        
    if opkald then
        local sourcePlayer = GetPlayer(source)

        if not sourcePlayer or sourcePlayer.job.name ~= number or then --Check på om spilleren FAKTISK har jobbet, eller det en ugyldig spiller??, gør det tidligt så den køre videre i koden, mangler check til at check om de faktisk har jobbet i config
            return
        end

        local identifier = GetIdentifier(source) -- få identifier efter vi har sikret os spilleren er gyldig
        
        if not identifier then --dog return hvis den ik kan få en identifier
            return
        end

        local onCallPlayers = opkald["onCallPlayers"] --få opkaldsdata med onCallPlayers

        if onCallPlayers[identifier] then --tjek om identifieren faktisk er på jobbet
            onCallPlayers[identifier] = nil --fjern ham fra opkaldet
            opkald.onCall = math.max(0, opkald.onCall - 1) -- sikre os at onCall ikke går ned under 0 med math.max (tror det er det ellers må det være math.ceil + 0.5)
            
            UpdateCall(number, opkald["taken"], opkald.onCall, onCallPlayers, id)
        end
    else 
        print("Fejl: Ugyldigt opkald blev parsed i dropCall eventet??")
        return
    end
end)

RegisterNetEvent("visualz_opkaldsliste:server:deleteCall")
AddEventHandler("visualz_opkaldsliste:server:deleteCall", function(id, number)
    local sourcePlayer = GetPlayer(source)

    if not sourcePlayer or sourcePlayer.job.name ~= number then --return hvis spilleren ikke er det rigtige job eller spilleren er ugyldig, mangler check til at check om de faktisk har jobbet i config
        return
    end

    local opkald = calls[number][id]

    if opkald then
        opkald["deleted"] = true
        DeleteCall(number, id)
    else
        print("Fejl: Ugyldigt opkald parsed i deleteCall??")
    end
end)

RegisterNetEvent("visualz_opkaldsliste:server:deleteAll")
AddEventHandler("visualz_opkaldsliste:server:deleteAll", function(number)
    local sourcePlayer = GetPlayer(source)

    if not sourcePlayer or sourcePlayer.job.name ~= number then --return hvis spilleren ikke er det rigtige job eller spilleren er ugyldig, mangler check til at check om de faktisk har jobbet i config
        return
    end

    local opkaldsArray = calls[number]

    if opkaldsArray then
        calls[number] = {}
        callid[number] = 0
        DeleteAll(number, sourcePlayer)
    else
        print("Fejl: Ugyldigt job parsed i deleteAll??")
    end
end)

-- Mangler sikkerhed
RegisterNetEvent("visualz_opkaldsliste:server:sendMessage")
AddEventHandler("visualz_opkaldsliste:server:sendMessage", function(number, message, id)
    SendCallMessage(calls[number][id].identifier, number, calls[number][id].fromnumber, message)
end)


-- -------------------------------------------------------------------------- --
--                               ServerCallbacks                              --
-- -------------------------------------------------------------------------- --
lib.callback.register("visualz_opkaldsliste:loadCalls", function(source, number)
    return calls[number]
end)

lib.callback.register("visualz_opkaldsliste:loadIdentifier", function()
    return GetIdentifier(source)
end)

-- declare export
exports('AddCall', AddCall)
