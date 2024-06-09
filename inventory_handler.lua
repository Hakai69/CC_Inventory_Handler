--- Inventory Handler module

local prefix = ... and (...):match('(.-)[^%.]+$') or 'CC_Inventory_Handler'
local function import (modname)
    return require(prefix .. modname)
end

---@module 'item_quality_handler'
local item_handler = import 'item_quality_handler'

local inventory = {
    selected_slot = 1,
    num_slots = 16,
    slots = {},
    lookup = {},
}

local inventory_mt = {}

---If a turtle function is not implemented by the module, you should still be able to call it with the module
function inventory_mt:__index(k)
    return turtle[k]
end

setmetatable(inventory, inventory_mt)

---Inserts items into an inventory slot
---@param slot integer
---@param item_data table
function inventory.insert_new_item(slot, item_data)
    inventory.slots[slot] = {
        name = item_data.name,
        count = item_data.count,
        max_count = item_data.max_count
    }

    if not inventory.lookup[item_data.name] then
        inventory.lookup[item_data.name] = {
            [slot] = inventory.slots[slot]
        }
    else
        inventory.lookup[item_data.name][slot] = inventory.slots[slot]
    end
end

---Register items inside a slot into the inventory handler
---@param slot integer
function inventory.register_slot(slot)
    local item_data = turtle.getItemDetail(slot)
    if not item_data then
        if inventory.slots[slot] then
            inventory.set_slot_to(slot, 0)
        end
        return
    end
    local space = turtle.getItemSpace(slot)
    item_data.max_count = item_data.count + space

    inventory.insert_new_item(slot, item_data)
end

---Gets the item's name from a certain slot
---@param slot integer
---@return string?
function inventory.get_item_name(slot)
    local instance = inventory.slots[slot]
    return instance and instance.name or nil
end

---Sets a slot to a certain amount of items (values under the min and over the max are admitted)
---@param slot integer
---@param amount integer
function inventory.set_slot_to(slot, amount)
    local instance = inventory.slots[slot]

    amount = math.min(amount, instance.max_count)
    amount = math.max(amount, 0)

    if amount == 0 then
        inventory.lookup[instance.name][slot] = nil
        inventory.slots[slot] = nil
    else
        inventory.slots[slot].count = amount
    end
end

---Adds a certain amount of items to a slot (can also remove items if ammount negative)
---@param slot integer
---@param amount integer
function inventory.add_to_slot(slot, amount)
    local new_amount = inventory.slots[slot].count + amount
    inventory.set_slot_to(slot, new_amount)
end

---Equivalent to turtle.select(slot) (but also registering it)
---@param slot integer
---@return boolean | nil
function inventory.select(slot)
    if turtle.select(slot) then
        inventory.selected_slot = slot
        return true
    end
end

---Equivalent to turtle.getSelectedSlot()
---@return integer
function inventory.getSelectedSlot()
    assert(turtle.getSelectedSlot() == inventory.selected_slot, 'Selected slot does not coincide with the selected slot registered in the inventory handler. Make sure to use the commands from the inventory handler instead of turtle commands.')
    return inventory.selected_slot
end

---Equivalent to turtle.transferTo(slot, [quantity]) (but also registering it)
---@param slot integer
---@param quantity? integer
---@return boolean success The success of the operation
---@return string? reason The reason why it wasn't successful
function inventory.transferTo(slot, quantity)
    local bool, str = turtle.transferTo(slot, quantity)
    if not bool then
        return bool, str
    end

    if inventory.slots[slot] then --If there are items already, determine how many have transferred
        local origin_count = quantity or inventory.slots[inventory.selected_slot].count
        local target_max_count = inventory.slots[slot].max_count
        local target_count = inventory.slots[slot].count

        inventory.add_to_slot(inventory.selected_slot, - (quantity or (target_max_count - target_count)))
        inventory.add_to_slot(slot, origin_count)

    else --If the slot is empty just transfer everything
        local instance = inventory.slots[inventory.selected_slot]
        inventory.insert_new_item(slot, {name = instance.name, count = quantity or instance.count, max_count = instance.max_count})
        inventory.add_to_slot(inventory.selected_slot, - (quantity or instance.count))
    end

    return bool, str
end


---Abstract function for dropping
---@param func function Dropping function
---@param count? integer Amount
---@return boolean success The success of the operation
---@return string? reason The reason why it wasn't successful
function inventory.drop_function(func, count)
    local bool, str = func(count)
    if not bool then
        return bool, str
    end

    if count then
        inventory.add_to_slot(inventory.selected_slot, -count)
    else
        inventory.set_slot_to(inventory.selected_slot, 0)
    end
    return bool, str
end

---Equivalent to turtle.drop(count) (but also registering it)
---@params count? integer
---@return boolean|string|nil
function inventory.drop(count)
    return inventory.drop_function(turtle.drop, count)
end

---Equivalent to turtle.dropUp(count) (but also registering it)
---@params count? integer
---@return boolean|string|nil
function inventory.dropUp(count)
    return inventory.drop_function(turtle.dropUp, count)
end

---Equivalent to turtle.dropDown(count) (but also registering it)
---@params count? integer
---@return boolean|string|nil
function inventory.dropDown(count)
    return inventory.drop_function(turtle.dropDown, count)
end


---Finds the first empty slot
---@return integer | false
function inventory.find_empty_slot()
    local slot = 1
    while inventory.slots[slot] and slot < inventory.num_slots do
        slot = slot + 1
    end
    return slot < 16 and slot or false -- Slot 16 not included for managing items
end

---Fills vacant entries of an item with the items at the selected spot
---@param vacated_slot integer Slot being vacated
---@return boolean success If the transfer has been complete
function inventory.fill_vacant_slots(vacated_slot)
    if not inventory.slots[vacated_slot] then
        return true
    end

    local original_slot = inventory.selected_slot
    inventory.select(vacated_slot)

    local vacated_item_name = inventory.slots[vacated_slot].name
    local remaining_items = inventory.slots[vacated_slot].count

    local vacating_slot, vacating_instance = next(inventory.lookup[vacated_item_name])
    while remaining_items > 0 and vacating_slot do
        if vacating_slot ~= vacated_slot then
            inventory.transferTo(vacating_slot)
            remaining_items = remaining_items - vacating_instance.max_count + vacating_instance.count
        end
        vacating_slot, vacating_instance = next(inventory.lookup[vacated_item_name], vacating_slot)
    end

    inventory.select(original_slot)
    return remaining_items <= 0
end

---Vacates another item of lesser quality to fit the main item
---@param slot integer Slot where the main item is
---@return boolean success
---@return string? reason
function inventory.quality_vacate(slot)
    local i = 1
    while i < inventory.num_slots and not (inventory.slots[i] and item_handler.is_better_than(inventory.slots[slot].name, inventory.slots[i].name)) do
        i = i + 1
    end

    if i >= 16 then
        return false, 'No material with lesser quality inside the inventory'
    end

    inventory.vacate_slot(i) -- Vacates the slot of the lesser quality material recursively
    local original_slot = inventory.selected_slot
    inventory.select(slot)
    local bool, str = inventory.transferTo(i)
    inventory.select(original_slot)
    return bool, str
end

---Empties a slot by moving it in it's inventory, vacating a lesser quality material or just dropping stuff that's in it
---@param slot integer
---@return boolean success
---@return string? reason
function inventory.vacate_slot(slot)
    if not inventory.slots[slot] then
        return false, 'Nothing to vacate in slot ' .. tostring(slot)
    end

    -- Protocol 1: Find slots with item
    if inventory.fill_vacant_slots(slot) then
        return true
    end

    -- Protocol 2: Find empty slot
    local empty_slot = inventory.find_empty_slot()
    if empty_slot then
        local original_slot = inventory.selected_slot
        inventory.select(slot)
        inventory.transferTo(empty_slot)
        inventory.select(original_slot)
        return true
    end

    ---Protocol 3: Vacate lesser quality item
    if inventory.quality_vacate(slot) then
        return true
    end

    ---Protocol 4: Drop item
    local original_slot = inventory.selected_slot
    inventory.select(slot)
    inventory.drop()
    inventory.select(original_slot)
    return true
end


---Abstract function for digging
---@param func function Digging function
---@param toolSide? integer Side of the tool
---@return boolean success The success of the operation
---@return string? reason The reason why it wasn't successful
function inventory.dig_function(func, toolSide)
    inventory.select(16)

    local bool, str = func(toolSide)
    if not bool then
        return bool, str
    end

    inventory.register_slot(16)
    inventory.vacate_slot(16)
    return bool, str
end

---Equivalent to turtle.drop(count) (but also registering it)
---@params toolSide? string
---@return boolean
---@return string?
function inventory.dig(toolSide)
    return inventory.dig_function(turtle.dig, toolSide)
end

---Equivalent to turtle.dropUp(count) (but also registering it)
---@params toolSide? string
---@return boolean
---@return string?
function inventory.digUp(toolSide)
    return inventory.dig_function(turtle.digUp, toolSide)
end

---Equivalent to turtle.dropDown(count) (but also registering it)
---@params toolSide? string
---@return boolean
---@return string?
function inventory.digDown(toolSide)
    return inventory.dig_function(turtle.digDown, toolSide)
end


---Find first occurrence of an item
---@param item_name string
---@return integer | nil
function inventory.check_for(item_name)
    local slot, _ = next(inventory.lookup[item_name])
    return slot
end

---Find all occurrences of an item
---@param item_name string
---@return table
function inventory.check_for_all(item_name)
    local locations = {}
    for slot, _ in pairs(inventory.lookup[item_name]) do
        table.insert(locations, slot)
    end
    return locations
end


---Initialize inventory with all the information
function inventory.init()
    inventory.slots = {}
    inventory.lookup = {}
    for i=1, inventory.num_slots - 1 do
        inventory.register_slot(i)
    end
    turtle.select(16)
    turtle.drop()
    inventory.select(1)
end

inventory.init()

return inventory