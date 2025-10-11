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

local png = require("pngutils.pngutils")
local M = {}

local function color_distance(c1, c2)
    local dr = c1.r - c2.r
    local dg = c1.g - c2.g
    local db = c1.b - c2.b
    -- No need to sqrt, we're only comparing
    return dr*dr + dg*dg + db*db
end

local function find_nearest_color(color, palette, skip_one)
    skip_one = skip_one or false
    local best_color_index

    if not skip_one then
        best_color_index = 1
    else
        best_color_index = 2
    end

    local best_dist = color_distance(color, palette[best_color_index])

    for i = best_color_index + 1, #palette do
        local d = color_distance(color, palette[i])
        if d < best_dist then
            best_color_index = i
            best_dist = d
        end
    end

    return best_color_index
end

-- Find the channel with the largest range
local function get_largest_range(colors)
    local min_r, max_r = 255, 0
    local min_g, max_g = 255, 0
    local min_b, max_b = 255, 0

    for _, color in ipairs(colors) do
        local r = color.r
        local g = color.g
        local b = color.b

        if r < min_r then min_r = r end
        if r > max_r then max_r = r end
        if g < min_g then min_g = g end
        if g > max_g then max_g = g end
        if b < min_b then min_b = b end
        if b > max_b then max_b = b end
    end

    local range_r = max_r - min_r
    local range_g = max_g - min_g
    local range_b = max_b - min_b

    if range_r >= range_g and range_r >= range_b then
        return "r"  -- Red
    elseif range_g >= range_r and range_g >= range_b then
        return "g"  -- Green
    else
        return "b"  -- Blue
    end
end

local function median_cut(colors, depth, max_depth)
    if #colors == 0 then return {} end
    if depth == max_depth or #colors == 1 then
        local r_sum, g_sum, b_sum = 0, 0, 0
        for _, color in ipairs(colors) do
            r_sum = r_sum + color.r
            g_sum = g_sum + color.g
            b_sum = b_sum + color.b
        end
        local n = #colors
        return {{
            r = math.floor(r_sum / n + 0.5),
            g = math.floor(g_sum / n + 0.5),
            b = math.floor(b_sum / n + 0.5)
        }}
    end

    local channel = get_largest_range(colors)
    table.sort(colors, function(a, b)
        return a[channel] < b[channel]
    end)

    local mid = math.floor(#colors / 2)
    local left, right = {}, {}
    for i = 1, mid do table.insert(left, colors[i]) end
    for i = mid + 1, #colors do table.insert(right, colors[i]) end

    local result = {}
    for _, c in ipairs(median_cut(left, depth + 1, max_depth)) do table.insert(result, c) end
    for _, c in ipairs(median_cut(right, depth + 1, max_depth)) do table.insert(result, c) end
    return result
end

function M.pack_rgb(color)
    return color.r * 65536 + color.g * 256 + color.b
end


function M.use_palette(palette)
    for i = 1, #palette do
        term.setPaletteColor(i, M.pack_rgb(palette[i]))
    end
end

function M.generate_palette(colors)
    return median_cut(colors, 0, 4)
end

function M.generate_palette_with_statics(colors, foreground, background)
    local palette = M.generate_palette(colors)

    local fg_index = find_nearest_color(foreground, palette)
    palette[fg_index] = palette[1]
    palette[1] = foreground

    local bg_index = find_nearest_color(background, palette, true)
    palette[bg_index] = palette[2]
    palette[2] = background

    return palette
end

function M.quantize_image(image, palette)
    local new_image = {}
    for y = 1, #image do 
        local new_row = {}
        for x = 1, #image[y] do
            local color = image[y][x]
            local quantized = find_nearest_color(color, palette)
            table.insert(new_row, 2 ^ (quantized - 1))
        end
        table.insert(new_image, new_row)
    end
    return new_image
end

function M.save_image_data(pixel_table, filename)
    local file = io.open(filename, "w")
    if file then
        file:write("return {")
        for i = 1, #pixel_table do
            file:write("{")
            for j = 1, #pixel_table[i] do
                local color = pixel_table[i][j]
                file:write(string.format("{r=%i,g=%i,b=%i}", color.r, color.g, color.b))
                if j < #pixel_table[i] then file:write(",") end
            end
            file:write("}")
            if i < #pixel_table then file:write(",") end
        end
        file:write("}")
        file:close()
    end
end

function M.load_image_data(filename)
    return dofile(filename)
end

function M.generate_head_image_data(username)
    local response = http.get({url=string.format("https://mc-heads.net/avatar/%s/8", username), binary=true})
    local pixel_table
    if response then
        pixel_table = png(response).pixels
        M.save_image_data(pixel_table, username)
    else
        pixel_table = {{{r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}},
                       {{r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}},
                       {{r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}},
                       {{r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}},
                       {{r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}},
                       {{r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}},
                       {{r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}},
                       {{r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}, {r=255,g=255,b=255}}}
    end
    return pixel_table
end

return M
