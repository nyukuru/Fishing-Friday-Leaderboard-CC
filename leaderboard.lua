--[[
MIT License

Copyright (c) 2025 nyukuru

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

BACKGROUND_COLOR = {r=40, g=47, b=64}
FOREGROUND_COLOR = {r=219, g=215, b=204}

FOREGROUND_INDEX = 1
BACKGROUND_INDEX = 2

HEADS_Y_LEVEL = 25
HEADS_PER_PAGE = 5

FISH_OF_THE_DAY = "aquaculture:rainbow_trout"
FISH_OF_THE_DAY_MULT = 5

HEADS_WIDTH = 8
HEADS_HEIGHT = 8

ARROWS_WIDTH = 6

local colorutils = require("colorutils.colorutils")
local assets = require("assets")

local Game_State = {
  SETUP = 1,
  RUNNING = 2,
  STOPPED = 3
}

local fishers = {}
local palettes = {}
local current_page = 1
local current_state = Game_State.SETUP

local monitor = peripheral.find("monitor")
local modem = peripheral.find("modem")
term.redirect(monitor)

local function get_last_page()
  return math.floor((#fishers - 1) / HEADS_PER_PAGE) + 1
end

local function is_fish(item)
  for _, tag in ipairs(item.tags) do
    if tag == "minecraft:item/minecraft:fishes" then
      return true
    end
  end
  return false
end


local function index_with_username(tbl, username)
  for i, entry in ipairs(tbl) do
    if entry.username == username then
      return i
    end
  end
  return nil
end

local function render_page(page)
  local start_index = (page - 1) * HEADS_PER_PAGE + 1
  local mon_width, _ = monitor.getSize()
  local available_space = mon_width - (HEADS_WIDTH * HEADS_PER_PAGE) - (ARROWS_WIDTH + 1 * 2)
  local gap_size = available_space / (HEADS_PER_PAGE + 1)
  local start_x = ARROWS_WIDTH + 1 + gap_size

  colorutils.use_palette(palettes[page])

  -- Draw over previous page info
  paintutils.drawFilledBox(1, HEADS_Y_LEVEL, mon_width, HEADS_Y_LEVEL + HEADS_HEIGHT, BACKGROUND_INDEX)

  -- Conditionally render arrows
  if current_page ~= 1 then
    paintutils.drawImage(paintutils.parseImage(assets.left_arrow), 2, HEADS_Y_LEVEL + 1)
  end
  if current_page ~= get_last_page() then
    paintutils.drawImage(paintutils.parseImage(assets.right_arrow), mon_width - ARROWS_WIDTH - 1, HEADS_Y_LEVEL + 1)
  end

  for i = 1, math.min(#fishers - start_index + 1, HEADS_PER_PAGE) do
    local fisher = fishers[start_index + i - 1]
    local img_x = start_x + (HEADS_WIDTH + gap_size) * (i - 1)
    local center_x = img_x + HEADS_WIDTH / 2

    -- Draw the player's head
    paintutils.drawImage(fisher.image, math.ceil(img_x + 0.5), HEADS_Y_LEVEL)

    -- Re-set background color because it is overriden by drawImage
    term.setBackgroundColor(BACKGROUND_INDEX)

    -- Write player's username
    term.setCursorPos(math.ceil(center_x - #fisher.username / 2 + 0.5), HEADS_Y_LEVEL + HEADS_HEIGHT)
    term.write(fisher.username)

    -- Conditionally write player's score
    if current_state ~= Game_State.SETUP then
      local points_string = string.format("%05d points", fisher.points)
      term.setCursorPos(math.ceil(center_x - #points_string / 2 + 0.5), HEADS_Y_LEVEL + HEADS_HEIGHT + 1)
      term.write(points_string)
    end
  end
end

local function generate_heads_palette(page)
  local all_pixels = {}
  local start_index = (page - 1) * HEADS_PER_PAGE + 1

  -- Gather all pixels in a flat list
  for i = start_index, math.min(#fishers, start_index + HEADS_PER_PAGE - 1) do
    for _, row in ipairs(fishers[i].pixel_table) do
      for _, pixel in ipairs(row) do
        table.insert(all_pixels, pixel)
      end
    end
  end

  palettes[page] = colorutils.generate_palette_with_statics(all_pixels, FOREGROUND_COLOR, BACKGROUND_COLOR)

  -- Cache the quantized image in fisher.image for lookup when rendering
  for i = start_index, math.min(#fishers, start_index + HEADS_PER_PAGE - 1) do
    fishers[i].image = colorutils.quantize_image(fishers[i].pixel_table, palettes[page])
  end
end

local function update_scores()
  -- Resort table
  table.sort(fishers, function(a, b)
    return a.points < b.points
  end)

  for i = 1, get_last_page() do
    generate_heads_palette(i)
  end

  render_page(current_page)
end

local function spawn_inv_man_thread(name)
  return (function()
    while true do
      local owner = modem.callRemote(name, "getOwner")
      if owner ~= nil then
        local owner_index = index_with_username(fishers, owner)
        if owner_index == nil then
          local f = io.open(owner, "r")
          if f then
            io.close(f)
            table.insert(fishers, {
              username=owner,
              points=0,
              pixel_table=colorutils.load_image_data(owner)
            })
          else
            table.insert(fishers, {
              username=owner,
              points=0,
              pixel_table=colorutils.generate_head_image_data(owner)
            })
          end

          current_page = get_last_page()
          generate_heads_palette(current_page)
          render_page(current_page)
        elseif current_state == Game_State.RUNNING then
          local items = modem.callRemote(name, "getItems")
          local updated_score = false
          for _, item in ipairs(items) do
            if item.name == FISH_OF_THE_DAY then
              -- Fish of the day wis given a mult
              fishers[owner_index].points = fishers[owner_index].points + FISH_OF_THE_DAY_MULT * item.count
              modem.callRemote(name, "removeItemFromPlayer", "front", {fromSlot = item.slot, count = item.count})
              updated_score = true
            elseif item.name == "extendedae:fishbig" then
              -- Fumo is worth 100 each
              fishers[owner_index].points = fishers[owner_index].points + 100 * item.count
              modem.callRemote(name, "removeItemFromPlayer", "front", {fromSlot = item.slot, count = item.count})
              updated_score = true
            elseif item.name == "minecraft:nautilus_shell" then
              -- Nautilus Shell is worth 50 each
              fishers[owner_index].points = fishers[owner_index].points + 50 * item.count
              modem.callRemote(name, "removeItemFromPlayer", "front", {fromSlot = item.slot, count = item.count})
              updated_score = true
            elseif item.name == "minecraft:pufferfish" then
              -- Pufferfish isn't worth anything itself because u must craft fumo using it
            elseif is_fish(item) then
              -- Other fish are worth 1
              fishers[owner_index].points = fishers[owner_index].points + item.count
              modem.callRemote(name, "removeItemFromPlayer", "front", {fromSlot = item.slot, count = item.count})
              updated_score = true
            end
          end
          if updated_score then
            update_scores()
          end
        end
      end
      os.sleep(5)
    end
  end)
end

local function clear_inventories()
  for _, inv_man in ipairs(modem.getNamesRemote()) do
    if modem.callRemote(inv_man, "getOwner") ~= nil then
      for _, item in ipairs(modem.callRemote(inv_man, "getItems")) do
        if item.name == "extendedae:fishbig" or item.name == "minecraft:nautilus_shell " or is_fish(item) then
          modem.callRemote(inv_man, "removeItemFromPlayer", "front", {fromSlot = item.slot, count = item.count})
        end
      end
    end
  end
end

local function handle_touch()
  local mon_width, _ = monitor.getSize()
  while true do
    local _, _, x, y = os.pullEvent("monitor_touch")

    if x >= 12 and y >= 12 and x <= 34 and y <= 20 then
      if current_state == Game_State.SETUP then
        paintutils.drawFilledBox(12, 12, 34, 20, BACKGROUND_INDEX)
        clear_inventories()
        current_state = Game_State.RUNNING
        render_page(1)
      elseif current_state == Game_State.RUNNING then
        current_state = Game_State.STOPPED
      end
    elseif x < mon_width / 2 then
      if current_page ~= 1 then
        current_page = current_page - 1
        render_page(current_page)
      end
    elseif current_page ~= get_last_page() then
      current_page = current_page + 1
      render_page(current_page)
    end
  end
end

-- Some display setup
monitor.setTextScale(0.5)

term.setPaletteColor(FOREGROUND_INDEX, colorutils.pack_rgb(FOREGROUND_COLOR))
term.setPaletteColor(BACKGROUND_INDEX, colorutils.pack_rgb(BACKGROUND_COLOR))
term.setBackgroundColor(BACKGROUND_INDEX)
term.setTextColor(FOREGROUND_INDEX)
term.clear()

paintutils.drawImage(paintutils.parseImage(assets.banner), 2, 2)

local inv_mans = modem.getNamesRemote()
for i, v in ipairs(inv_mans) do
  inv_mans[i] = spawn_inv_man_thread(v)
end

parallel.waitForAll(handle_touch, table.unpack(inv_mans))
