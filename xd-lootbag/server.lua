local QBCore = exports['qb-core']:GetCoreObject()
local lootBags = {}
local bagCounter = 0

-- Limpieza periódica de bolsas viejas
CreateThread(function()
    while true do
        Wait(Config.CleanupDropInterval * 60000)
        local now = os.time()
        for bagId, data in pairs(lootBags) do
            if not data.isOpen and (data.created + Config.CleanupDropTime * 60) < now then
                -- Eliminar bolsa (cliente)
                TriggerClientEvent('qb-lootbag:client:removeBag', -1, bagId)
                lootBags[bagId] = nil
            end
        end
    end
end)

function CreateLootBag(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local items = Player.PlayerData.items or {}
    if next(items) == nil then return end  -- no items → no bolsa

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    bagCounter = bagCounter + 1
    local bagId = tostring(bagCounter)

    -- Registrar bolsa en servidor
    lootBags[bagId] = {
        owner = src,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        items = {},
        created = os.time(),
        isOpen = false
    }

    -- Copiar items y vaciar inventario
    for _, item in pairs(items) do
        table.insert(lootBags[bagId].items, {
            name = item.name,
            amount = item.amount,
            slot = item.slot,
            info = item.info
        })
        Player.Functions.RemoveItem(item.name, item.amount, item.slot)
    end

    -- Avisar clientes para crear la bolsa en el mundo
    TriggerClientEvent('qb-lootbag:client:createBag', -1, bagId, lootBags[bagId].coords, src)
end

-- Eventos de muerte
RegisterNetEvent('baseevents:onPlayerDied', function()
    CreateLootBag(source)
end)

RegisterNetEvent('baseevents:onPlayerKilled', function()
    CreateLootBag(source)
end)

-- Solicitud de contenido de la bolsa
RegisterNetEvent('qb-lootbag:server:requestLoot', function(bagId)
    local src = source
    local bag = lootBags[bagId]
    if not bag then return end

    -- Marcar como abierta
    bag.isOpen = true

    -- Formatear ítems para el menú
    local formatted = {}
    for _, it in ipairs(bag.items) do
        local itemInfo = QBCore.Shared.Items[it.name]
        if itemInfo then
            table.insert(formatted, {
                name = it.name,
                label = itemInfo.label,
                amount = it.amount,
                slot = it.slot,
                info = it.info
            })
        end
    end

    TriggerClientEvent('qb-lootbag:client:openLootBag', src, bagId, formatted)
end)

-- Tomar un solo ítem
RegisterNetEvent('qb-lootbag:server:lootItem', function(bagId, itemData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local bag = lootBags[bagId]
    if not Player or not bag then return end

    for i, it in ipairs(bag.items) do
        if it.name == itemData.name and it.slot == itemData.slot then
            if Player.Functions.AddItem(it.name, it.amount, false, it.info) then
                table.remove(bag.items, i)
            end
            break
        end
    end

    -- Si la bolsa queda vacía, eliminarla
    if #bag.items == 0 then
        lootBags[bagId] = nil
        TriggerClientEvent('qb-lootbag:client:removeBag', -1, bagId)
    end
end)

-- Tomar todos los ítems
RegisterNetEvent('qb-lootbag:server:lootAll', function(bagId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local bag = lootBags[bagId]
    if not Player or not bag then return end

    for _, it in ipairs(bag.items) do
        Player.Functions.AddItem(it.name, it.amount, false, it.info)
    end

    lootBags[bagId] = nil
    TriggerClientEvent('qb-lootbag:client:removeBag', -1, bagId)
end)