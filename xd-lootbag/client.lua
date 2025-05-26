local QBCore = exports['qb-core']:GetCoreObject()
local lootBags = {}
local blips = {}
local nearBag = false
local currentBag = nil

-- Crear bolsa en el mundo y blip sólo para el owner
RegisterNetEvent('qb-lootbag:client:createBag', function(bagId, coords, owner)
    -- Eliminar si ya existe
    if lootBags[bagId] then
        if lootBags[bagId].object then
            DeleteObject(lootBags[bagId].object)
        end
        if blips[bagId] then
            RemoveBlip(blips[bagId])
        end
    end

    -- Guardar datos de la bolsa
    lootBags[bagId] = {
        coords = coords,
        owner = owner,
        object = nil
    }

    -- Cargar modelo y crear objeto físico
    local model = Config.ItemDropObject
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    local obj = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    PlaceObjectOnGroundProperly(obj)
    SetEntityAsMissionEntity(obj, true, true)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)
    lootBags[bagId].object = obj

    -- Crear blip solo para el dueño
    if owner == GetPlayerServerId(PlayerId()) then
        local b = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(b, Config.Blip.sprite or 351)
        SetBlipColour(b, Config.Blip.color or 2)
        SetBlipScale(b, Config.Blip.scale or 0.8)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Blip.text or "Tu Loot Bag")
        EndTextCommandSetBlipName(b)
        blips[bagId] = b
    end
end)

-- Eliminar bolsa y su blip
RegisterNetEvent('qb-lootbag:client:removeBag', function(bagId)
    -- Borrar objeto físico
    if lootBags[bagId] and lootBags[bagId].object then
        DeleteObject(lootBags[bagId].object)
    end
    lootBags[bagId] = nil

    -- Borrar blip si existe
    if blips[bagId] then
        RemoveBlip(blips[bagId])
        blips[bagId] = nil
    end
    
    -- Resetear variables si era la bolsa actual
    if currentBag == bagId then
        nearBag = false
        currentBag = nil
    end
end)

-- Detección de proximidad (optimizado para rendimiento)
CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        nearBag = false
        
        for bagId, data in pairs(lootBags) do
            local dist = #(pos - vector3(data.coords.x, data.coords.y, data.coords.z))
            if dist < (Config.InteractDistance or 2.0) and not IsPedDeadOrDying(ped) then
                nearBag = true
                currentBag = bagId
                break
            end
        end
    end
end)

-- Dibujar texto y manejar interacción
CreateThread(function()
    while true do
        Wait(0)
        if nearBag and currentBag then
            local data = lootBags[currentBag]
            DrawText3D(data.coords.x, data.coords.y, data.coords.z + 1.0, "[E] Abrir Loot")
            if IsControlJustReleased(0, 38) then -- Tecla E
                TriggerServerEvent('qb-lootbag:server:requestLoot', currentBag)
                Wait(500) -- Pequeño delay para evitar spam
            end
        end
    end
end)

-- Abrir menú de loot con qb-menu
RegisterNetEvent('qb-lootbag:client:openLootBag', function(bagId, items)
    local menu = {
        {
            header = "📦 Loot Bag",
            isMenuHeader = true
        }
    }

    -- Añadir items al menú
    for _, it in ipairs(items) do
        table.insert(menu, {
            header = ("%s x%d"):format(it.label, it.amount),
            txt = "Tomar este ítem",
            params = {
                event = "qb-lootbag:client:lootItem",
                args = { bagId = bagId, item = it }
            }
        })
    end

    -- Opciones adicionales
    table.insert(menu, {
        header = "🧳 Tomar todo",
        txt = "Lootear todos los ítems",
        params = {
            event = "qb-lootbag:client:lootAll",
            args = { bagId = bagId }
        }
    })
    
    table.insert(menu, {
        header = "❌ Cerrar",
        txt = "",
        params = {
            event = "qb-menu:closeMenu"
        }
    })

    exports['qb-menu']:openMenu(menu)
end)

-- Eventos para lootear items
RegisterNetEvent('qb-lootbag:client:lootItem', function(data)
    TriggerServerEvent('qb-lootbag:server:lootItem', data.bagId, data.item)
end)

RegisterNetEvent('qb-lootbag:client:lootAll', function(data)
    TriggerServerEvent('qb-lootbag:server:lootAll', data.bagId)
end)

function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(1, 0, 0, 0, 150) -- Sombra suave
    SetTextCentre(true) -- Centrado
    
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end