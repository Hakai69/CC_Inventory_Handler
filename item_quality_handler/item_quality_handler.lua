--[[
To consider:
    - Individuals (Uncentralized) Not even connected between them
        - The current implementation works (No code needs to be deleted yay :D)
        - Easier to handle
        - Customization is haaaaard: Considering it is really hard to customize it whilst running and it would probably only run for specific tasks
        - And updating it each run is unefficient
        => Assume all modded stuff is important (between average and good)
        => Assume all mc stuff is contemplated (Unknown from mc = Trash)

]]

local prefix = ... and (...):match('(.-)[^%.]+$') or 'item_quality_handler'
local function import(modname)
    return require(prefix .. modname)
end

-- For all the item list shenanigans
local item_quality_handler = {}

item_quality_handler.IDs = {
    good = 4,
    unknown = 3,
    average = 2,
    bad = 1
}

local function build_item_list(from, to)
    for _, v in pairs(from) do
        to[v] = true
    end
end

item_quality_handler.good_items = {}
function Good_items_base(data)
    build_item_list(data, item_quality_handler.good_items)
end

item_quality_handler.average_items = {}
function Average_items_base(data)
    build_item_list(data, item_quality_handler.average_items)
end

item_quality_handler.bad_items = {}
local bad_items_mt = {
	__index = function (_, k) -- Bad item if it's from minecraft and it isn't considered as good
		return (string.sub(k,1, string.len("minecraft:")) == "minecraft:"
				and not item_quality_handler.good_items[k]
				and not item_quality_handler.average_items[k])
	end
}

setmetatable(item_quality_handler.bad_items, bad_items_mt)
function Bad_items_base(data)
    build_item_list(data, item_quality_handler.bad_items)
end

---Classifies an item according to the lists
---@param item_name string
---@return integer
function item_quality_handler.classify_item(item_name)
    if item_quality_handler.good_items[item_name] then
        return item_quality_handler.IDs.good
    end
    if item_quality_handler.average_items[item_name] then
        return item_quality_handler.IDs.average
    end
    if item_quality_handler.bad_items[item_name] then
        return item_quality_handler.IDs.bad
    end
    return item_quality_handler.IDs.unknown
end

---Compare two items and returns them in decreasing order of importance
---@param item1_name string
---@param item2_name string
---@return boolean
function item_quality_handler.is_better_than(item1_name, item2_name)
    return item_quality_handler.classify_item(item1_name) > item_quality_handler.classify_item(item2_name)
end

import 'items'

return item_quality_handler