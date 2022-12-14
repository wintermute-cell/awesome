---------------------------------------------------------------------------
-- A boolean display widget.
--
-- If necessary, themes can implement custom shape:
--
--@DOC_wibox_widget_checkbox_custom_EXAMPLE@
--
--@DOC_wibox_widget_defaults_checkbox_EXAMPLE@
-- @author Emmanuel Lepage Valle
-- @copyright 2010 Emmanuel Lepage Vallee
-- @widgetmod wibox.widget.checkbox
-- @supermodule wibox.widget.base
---------------------------------------------------------------------------

local color     = require( "gears.color"       )
local base      = require( "wibox.widget.base" )
local beautiful = require( "beautiful"         )
local shape     = require( "gears.shape"       )
local gtable    = require( "gears.table"       )

local checkbox = {}

--- The outer (unchecked area) border width.
--
-- @beautiful beautiful.checkbox_border_width
-- @param number

--- The outer (unchecked area) background color, pattern or gradient.
--
-- @beautiful beautiful.checkbox_bg
-- @param color

--- The outer (unchecked area) border color.
--
-- @beautiful beautiful.checkbox_border_color
-- @param color

--- The checked part border color.
--
-- @beautiful beautiful.checkbox_check_border_color
-- @param color

--- The checked part border width.
--
-- @beautiful beautiful.checkbox_check_border_width
-- @param number

--- The checked part filling color.
--
-- @beautiful beautiful.checkbox_check_color
-- @param number

--- The outer (unchecked area) shape.
--
-- @beautiful beautiful.checkbox_shape
-- @tparam gears.shape|function shape
-- @see gears.shape

--- The checked part shape.
--
-- If none is set, then the `shape` property will be used.
-- @beautiful beautiful.checkbox_check_shape
-- @tparam gears.shape|function shape
-- @see gears.shape

--- The padding between the outline and the progressbar.
--
-- @beautiful beautiful.checkbox_paddings
-- @tparam[opt=0] table|number paddings A number or a table
-- @tparam[opt=0] number paddings.top
-- @tparam[opt=0] number paddings.bottom
-- @tparam[opt=0] number paddings.left
-- @tparam[opt=0] number paddings.right

--- The checkbox color.
--
-- This will be used for the unchecked part border color and the checked part
-- filling color. Note that `check_color` and `border_color` have priority
-- over this property.
-- @beautiful beautiful.checkbox_color
-- @param color

--- The outer (unchecked area) border width.
--
-- @property border_width
-- @tparam number|nil border_width
-- @negativeallowed false
-- @propertyunit pixel
-- @propbeautiful
-- @propemits true false

--- The outer (unchecked area) background color, pattern or gradient.
--
--@DOC_wibox_widget_checkbox_bg_EXAMPLE@
-- @property bg
-- @tparam color|nil bg
-- @propbeautiful
-- @propemits true false

--- The outer (unchecked area) border color.
--
-- @property border_color
-- @tparam color|nil border_color
-- @propbeautiful
-- @propemits true false

--- The checked part border color.
--
-- @property check_border_color
-- @tparam color|nil check_border_color
-- @propbeautiful
-- @propemits true false

--- The checked part border width.
--
-- @property check_border_width
-- @tparam number|nil check_border_width
-- @propbeautiful
-- @negativeallowed false
-- @propertyunit pixel
-- @propemits true false

--- The checked part filling color.
--
-- @property check_color
-- @tparam color|nil check_color
-- @propbeautiful
-- @propemits true false

--- The outer (unchecked area) shape.
--
--@DOC_wibox_widget_checkbox_shape_EXAMPLE@
-- @property shape
-- @tparam shape|nil shape
-- @propbeautiful
-- @propemits true false
-- @see gears.shape

--- The checked part shape.
--
-- If none is set, then the `shape` property will be used.
--@DOC_wibox_widget_checkbox_check_shape_EXAMPLE@
-- @property check_shape
-- @tparam shape|nil check_shape
-- @propbeautiful
-- @propemits true false
-- @see gears.shape

--- The padding between the outline and the progressbar.
--
-- @property paddings
-- @tparam[opt=0] table|number|nil paddings A number or a table
-- @tparam[opt=0] number paddings.top
-- @tparam[opt=0] number paddings.bottom
-- @tparam[opt=0] number paddings.left
-- @tparam[opt=0] number paddings.right
-- @propertyunit pixel
-- @negativeallowed true
-- @propertytype number A single number for all sides.
-- @propertytype table A different value for each sides:
-- @propbeautiful
-- @propemits false false

--- The checkbox color.
--
-- This will be used for the unchecked part border color and the checked part
-- filling color. Note that `check_color` and `border_color` have priority
-- over this property.
-- @property color
-- @tparam color|nil color
-- @propbeautiful
-- @propemits true false

local function outline_workarea(self, width, height)
    local offset = (self._private.border_width or
        beautiful.checkbox_border_width or 1)/2

    return {
        x      = offset,
        y      = offset,
        width  = width-2*offset,
        height = height-2*offset
    }
end

-- The child widget area
local function content_workarea(self, width, height)
    local padding = self._private.paddings or {}
    local offset = self:get_check_border_width() or 0
    local wa = outline_workarea(self, width, height)

    wa.x      = offset + wa.x + (padding.left or 1)
    wa.y      = offset + wa.y + (padding.top  or 1)
    wa.width  = wa.width  - (padding.left or 1) - (padding.right  or 1) - 2*offset
    wa.height = wa.height - (padding.top  or 1) - (padding.bottom or 1) - 2*offset

    return wa
end

local function draw(self, _, cr, width, height)
    local size = math.min(width, height)

    local background_shape = self:get_shape() or shape.rectangle
    local border_width = self:get_border_width() or 1

    local main_color = self:get_color()
    local bg = self:get_bg()
    local border_color = self:get_border_color()

    -- If no color is set, it will fallback to the default one
    if border_color or main_color then
        cr:set_source(color(border_color or main_color))
    end

    local wa = outline_workarea(self, size, size)
    cr:translate(wa.x, wa.y)
    background_shape(cr, wa.width, wa.height)
    cr:set_line_width(border_width)

    if bg then
        cr:save()
        cr:set_source(color(bg))
        cr:fill_preserve()
        cr:restore()
    end

    cr:stroke()

    cr:translate(-wa.x, -wa.y)

    -- Draw the checked part
    if self._private.checked then
        local col = self:get_check_color() or main_color
        border_color = self:get_check_border_color()
        border_width = self:get_check_border_width() or 0
        local check_shape = self:get_check_shape() or background_shape

        wa = content_workarea(self, size, size)
        cr:translate(wa.x, wa.y)

        check_shape(cr, wa.width, wa.height)

        if col then
            cr:set_source(color(col))
        end

        if border_width > 0 then
            cr:fill_preserve()
            cr:set_line_width(border_width)
            cr:set_source(color(border_color))
            cr:stroke()
        else
            cr:fill()
        end
    end
end

local function fit(_, _, w, h)
    local size = math.min(w, h)
    return size, size
end

--- If the checkbox is checked.
-- @property checked
-- @tparam[opt=false] boolean checked

for _, prop in ipairs {"border_width", "bg", "border_color", "check_border_color",
    "check_border_width", "check_color", "shape", "check_shape", "paddings",
    "checked", "color" } do
    checkbox["set_"..prop] = function(self, value)
        self._private[prop] = value
        self:emit_signal("property::"..prop, value)
        self:emit_signal("widget::redraw_needed")
    end
    checkbox["get_"..prop] = function(self)
        return self._private[prop] or beautiful["checkbox_"..prop]
    end
end

function checkbox:set_paddings(val)
    self._private.paddings = type(val) == "number" and {
        left   = val,
        right  = val,
        top    = val,
        bottom = val,
    } or val or {}
    self:emit_signal("property::paddings")
    self:emit_signal("widget::redraw_needed")
end

--- Create a new checkbox.
-- @constructorfct wibox.widget.checkbox
-- @tparam[opt=false] boolean checked
-- @tparam[opt] table args
-- @tparam gears.color args.color The color.

local function new(checked, args)
    checked, args = checked or false, args or {}

    local ret = base.make_widget(nil, nil, {
        enable_properties = true,
    })

    gtable.crush(ret, checkbox)

    ret._private.checked = checked
    ret._private.color = args.color and color(args.color) or nil

    rawset(ret, "fit" , fit )
    rawset(ret, "draw", draw)

    return ret
end

return setmetatable({}, { __call = function(_, ...) return new(...) end})

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
