# Computer Craft: Inventory Handler

Needed a library to handle turtle's inventory virtually, turtle's operations are way to slow for my liking, so having everything replicated in Lua tables saves a bit of time. Nevertheless, it isn't built to be the most optimized code. Furthermore, it gives me a lot of freedom to configure complex operations.  

If you check the files you will be able to see the file 'inventory_handler.lua', this is where the magic happens. There is an inventory object that holds a table representing the slots and an item lookup table to represent the turtle's inventory. Every call to a turtle can be done through this module, since if something is not implemented it just redirects it to the turtle command, though it may cause faulty behaviour such as with turtle.suck(), since it adds items to the inventory it wouldn't register. It's implemented from the basic operations to more abstract functions. The star of the day is the vacate_slot() function, some kind of smart dropping function, and it is the most important part of emulating the inventory, because the hole point of this was a to have a way to decide which items the turtle would keep. Firstly it relocates to vacant spots, then to empty spots, then finds a lesser quality material to vacate, and if everything fails it drops the items. It also keeps slot 16 empty (inefficient but I couldn't bother programming a completely different behaviour for when it was full).  

The submodule item_quality_handler is responsible for assessing the quality of materials, it currently holds simple logic:
- Most important Minecraft mining items are already assessed into good and average (you'll also find an old list I had that I preferred to simplify)
- Any not assessed Minecraft items are automatically set to bad quality
- Any item from unknown mods are set to unknown quality
- Quality follows the order: Good > Unknown > Average > Bad
I might change this to a more advanced way of deciding the value of items, but it will probably stay this way.  

Turtle functions implemented:
```lua
- turtle.getSelectedSlot()
- turtle.transferTo()
- turtle.drop(), turtle.dropUp(), turtle.dropDown()
- turtle.dig(), turtle.digUp(), turtle.digDown()
```

## Author
- [Hakai69](https://github.com/Hakai69)

## License
[MIT License](LICENSE)