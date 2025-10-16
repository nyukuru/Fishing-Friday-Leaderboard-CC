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

BACKGROUND_COLOR = {r=20, g=131, b=156}
FOREGROUND_COLOR = {r=219, g=215, b=204}

HEADS_Y_LEVEL = 25
HEADS_PER_PAGE = 3

HEADS_WIDTH = 8
HEADS_HEIGHT = 8

FOREGROUND_INDEX = 1
BACKGROUND_INDEX = 2

local colorutils = require("colorutils.colorutils")
local assets = require("assets")

local Game_State = {
  SETUP = 1,
  RUNNING = 2
}

local fishers = {}
local palettes = {}
local current_page = 1
local current_state = Game_State.SETUP


local function render_page(page)
    local start_index = (page - 1) * HEADS_PER_PAGE + 1

    colorutils.use_palette(palettes[page])

    local mon_width, _ = term.getSize()
    local available_space = mon_width - (HEADS_WIDTH * HEADS_PER_PAGE)
    local gap_size = available_space / (HEADS_PER_PAGE + 1)

    paintutils.drawFilledBox(1, HEADS_Y_LEVEL, mon_width, HEADS_Y_LEVEL + HEADS_HEIGHT, BACKGROUND_INDEX)
    for i = 1, math.min(#fishers - start_index + 1, HEADS_PER_PAGE) do
        local fisher = fishers[start_index + i - 1]
        local img_x = gap_size + (HEADS_WIDTH + gap_size) * (i - 1)
        paintutils.drawImage(fisher.image, math.ceil(img_x + 0.5), HEADS_Y_LEVEL)

        local center_x = img_x + 4
        term.setCursorPos(math.ceil(center_x - #fisher.username / 2 + 0.5), HEADS_Y_LEVEL + HEADS_HEIGHT)
        term.write(fisher.username)

        if current_state == Game_State.RUNNING then
          local points_string = string.format("%05d", fisher.points)
          term.setCursorPos(math.ceil(center_x - #points_string / 2 + 0.5), HEADS_Y_LEVEL + HEADS_HEIGHT + 1)
        end
    end
end

local function generate_heads_palette(page)
    local all_pixels = {}
    local index = 1
    local start_index = (page - 1) * HEADS_PER_PAGE + 1

    for i = start_index, math.min(#fishers, start_index + HEADS_PER_PAGE - 1) do
        for _, row in ipairs(fishers[i].pixel_table) do
            for _, pixel in ipairs(row) do
                all_pixels[index] = pixel
                index = index + 1
            end
        end
    end

    palettes[page] = colorutils.generate_palette_with_statics(all_pixels, FOREGROUND_COLOR, BACKGROUND_COLOR)

    for i = start_index, math.min(#fishers, start_index + HEADS_PER_PAGE - 1) do
        fishers[i].image = colorutils.quantize_image(fishers[i].pixel_table, palettes[page])
    end
end

local function main()
    local monitor = peripheral.find("monitor")
    local terminal = term.native()

    monitor.setTextScale(0.5)

    term.redirect(monitor)
    term.setPaletteColor(FOREGROUND_INDEX, colorutils.pack_rgb(FOREGROUND_COLOR))
    term.setPaletteColor(BACKGROUND_INDEX, colorutils.pack_rgb(BACKGROUND_COLOR))
    term.setBackgroundColor(BACKGROUND_INDEX)
    term.setTextColor(FOREGROUND_INDEX)
    term.clear()

    paintutils.drawImage(paintutils.parseImage(assets.banner), 2, 2)

    term.redirect(terminal)

    while true do
        term.clear()
        term.setCursorPos(1,1)
        write("Enter your username to recieve your fishing license: ")
        local username = string.lower(read())

        local f = io.open(username, "r")
        if f then
            io.close(f)
            table.insert(fishers, {
              username=username,
              points=0,
              pixel_table=colorutils.load_image_data(username)
            })
        else
            table.insert(fishers, {
              username=username,
              points=0,
              pixel_table=colorutils.generate_head_image_data(username)
            })
        end

        current_page = math.floor((#fishers - 1) / HEADS_PER_PAGE) + 1
        generate_heads_palette(current_page)

        term.redirect(monitor)
        render_page(current_page)
        term.redirect(terminal)
    end
end

main()
