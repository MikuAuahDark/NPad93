NLay Documentation
=====

If you don't know what NLay is, please go back to https://github.com/MikuAuahDark/NPad93#nlay

Functions in v1.0.1
-----

************************************************

### `RootConstraint NLay = require("path.to.nlay")`

Loading NLay using `require` will give you a `RootConstraint` object which you can pass to functions that expects
`BaseConstraint` object. This constraint is "attached" to your game screen.

From now on, `RootConstraint` static functions is named `NLay`.

************************************************

### `Inside NLay.inside(BaseConstraint constraint, number padding)`

### `Inside NLay.inside(BaseConstraint constraint, {number padTop, number padLeft, number padBottom, number padRight})`

Create new `Inside` object. This object is used to construct `Constraint` later on.

If padding is `nil`, then it's 0. If `padding` is `number` then it sets the padding for all sides. Otherwise it sets the padding
for sides according to the 2nd overload (any absent or `nil` field means 0)

Returns: `Inside` object.

> Consider caching the return value if you have lots of this call with same parameters.

************************************************

### `void NLay.update(number x, number y, number w, number h)`

Update the game window dimensions. Normally all return values from [`love.window.getSafeArea`](https://love2d.org/wiki/love.window.getSafeArea) should
be passed unless your game performs its own logical dimension translation. In that case, adjust accordingly.

************************************************

### `MaxConstraint NLay.max(BaseConstraint...)`

Create new constraint whose the size and the position is based on bounding box of the other constraint.

At least 2 constraint must be passed to this function.

Returns: `MaxConstraint` which is derived from `BaseConstraint`.

************************************************

### `Constraint Inside:constraint(BaseConstraint top, BaseConstraint left, BaseConstraint bottom, BaseConstraint right)`

Create new `Constraint` object.

As per Android's ConstraintLayout, constraint must at least contain 1 horizontal (either `top` or `bottom` must be not nil) and 1 vertical (either `left`
or `right` must be not nil) constraints. The new constraint object will "attach" to specified constraints.

Returns: `Constraint` which is derived from `BaseConstraint`.

************************************************

### `number, number, number, number BaseConstraint:get([number offx = 0][, number offy = 0])`

Retrieve the positions and the dimensions of specified constraint. Note that `BaseConstraint` is the base class for all constraint in this library.

**v1.0.2**: If offset is specified, then the resulting position will be added by the offset accordingly

Returns: x coordinate, y coordinate, width, and height of the constraint, **in that order**.

> `offx` and `offy` parameter is added in v1.0.2!

************************************************

### `Constraint Constraint:into(boolean top, boolean left, boolean bottom, boolean right)`

This function tells that for constraint specified at `top`, `left`, `bottom`, and/or `right`, it should NOT use the opposite sides of the constraint.
This mainly used to prevent ambiguity.

For example

```lua
-- Say we have "baseConstraint"
local constraint = NLay.inside(NLay):constraint(baseConstraint, baseConstraint)
```

Without the `:into` function, `constraint` is placed southeast of `baseConstraint` because it will sample the right side and the bottom side
of `baseConstraint`. With `:into` function:

```lua
local constraint = NLay.inside(NLay):constraint(baseConstraint, baseConstraint):into(false, true)
```

It means "sample the bottom side of the `baseConstraint` **but** sample the left side of the `baseConstraint`", thus `constraint` will be placed exactly
below `baseConstraint`.

Returns: itself

************************************************

### `Constraint Constraint:margin(number margin)`

### `Constraint Constraint:margin({number marginTop, number marginLeft, number marginBottom, number marginRight})`

Sets the constraint margin.

If margin is `nil`, then it's 0. If margin is a number, then it sets the margin for all sides. Otherwise it sets the margin
for sides according to the 2nd overload (any absent or `nil` field means 0).

Returns: itself

************************************************

### `Constraint Constraint:size(number width, number height, string modeW, string modeH)`

Sets the constraint width and height.

If width/height is 0, it will calculate it based on the other connected constraint. If it's -1, then it will use parent's width/height minus padding.
Otherwise it will try to place the constraint based on the bias (see function below).

**v1.3.0**: `modeW` (for `width`) and `modeH` (for `height`) changes how the size calculation work. If it's `"pixel"` then the specified `width` and
`height` are absolute value which matches the v1.2.x and earlier. If it's `"percent"` then the actual dimensions is determined by performing "size 0"
resolve then the resulting size is multiplied by the `width` and `height`. The default value for `modeW` and `modeH` is `"pixel"` to allow existing
codes to work.

Returns: itself

> `modeW` and `modeH` parameter is added in v1.3.0!

************************************************

### `Constraint Constraint:bias(number horizontalBias, number verticalBias, boolean unclamped)`

Set the constraint bias.

By default, for fixed width/height, the bias is 0.5 which means the position are centered.

If the parameter is `nil`, then it won't set the bias of such parameter.

Returns: itself

> `unclamped` parameter is added in v1.1.2!

Additional Functions in v1.0.3
-----

************************************************

### `Constraint Constraint:forceIn(boolean force)`

Force the "into" flags to be determined by user even if it may result as invalid constraint. By default some
"into" flags were determined automatically. Setting this function to true causes NLay not to determine
the "into" flags automatically. This function is only used for some "niche" cases. You don't have to use this
almost all the time.

Returns: itself

Additional Functions in v1.1.0
-----

************************************************

### `LineConstraint NLay.line(constraint BaseConstraint, string direction, string mode, number value)`

### `LineConstraint NLay.line(inside Inside, string direction, string mode, number value)`

Create new [guideline constraint](https://developer.android.com/training/constraint-layout#constrain-to-a-guideline).

Direction can be either `"horizontal"` or `"vertical"`. Horizontal direction creates **vertical line** with width of 0 for
constraint to attach horizontally. Vertical direction creates **horizontal line** with height of 0 for constraint to attach
vertically.

Mode can be either `"percent"` or `"pixel"`. If it's percentage, then `value` is bias inside the constraint where 0 denotes top/left
and 1 denotes bottom/right. If it's pixel, then it behaves identical to "margin". Negative values start the bias/offset from opposing
direction.

Returns: `LineConstraint` which is derived from `BaseConstraint`

************************************************

### `Constraint Constraint:tag(any data)`

Tag this constraint with user-specific data (i.e. id). Useful to keep track of constraints when they're rebuilt.

Returns: itself

************************************************

### `any Constraint:getTag()`

Retrieve tag data from constraint (or `nil` if this constraint is not tagged). See above function for more information.

Returns: tag data

Additional Functions in v1.2.0
-----

************************************************

### `Constraint Constraint:ratio(ratio)`

Set the size aspect ratio. The `ratio` is in format `numerator/denominator`, so for aspect ratio of 16:9, pass `16/9`.
[Aspect ratio size 0 constraint](https://developer.android.com/training/constraint-layout#ratio) is supported.

Returns: itself

Additional Functions in v1.2.1
-----

### `LineConstraint LineConstraint:offset(off)`

(Re)-set the line offset previously set from `NLay.line`

Returns: itself

Additional Functions in v1.3.0
-----

************************************************

### `table NLay.batchGet(BaseConstraint...)`

Performs batched retrieval of constraint values, improves performance when resolving different constraints with
identical attached constraints.

Returns: table of numbers in form of `{x1, y1, w1, h1, x2, y2, w2, h2, ..., xn, yn, wn, hn}`

************************************************

### `Grid NLay.grid(Constraint constraint, integer nrows, integer ncols, table settings)`

Create new grid layout using the constraint `constraint` as the base.

The `settings` table may contain these fields:

* `hspacing` Horizontal spacing of the cell. (number)

* `vspacing` Vertical spacing of the cell. (number)

* `spacing` Spacing of the cell. `hspacing` and `vspacing` takes precedence if it's specified. (number)

* `hspacingfl` Should the horizontal spacing applies before the first and after the last columm? (boolean)

* `vspacingfl` Should the vertical spacing applies before the first and after the last row? (boolean)

* `spacingfl` Should the spacing applies before the first and after the last element? `hspacingfl` and `vspacingfl` takes precedence if it's specified. (boolean)

* `cellwidth` Fixed width of single cell. Setting this requires `cellheight` to be specified. (number)

* `cellheight` Fixed height of single cell. Setting this requires `cellwidth` to be specified. (number)

Both `cellwidth` and `cellheight` **must** be specified **or not** specified at all. Specifying both result in "fixed" mode where `constraint`
must be `Constraint` instead of `BaseConstraint` and the `Grid` object takes the ownership of the `constraint`.

Returns: `Grid` object.

************************************************

### `GridCellConstraint Grid:get(number row, number column)`

Retrieve `GridCellConstraint` at specified row and column. `GridCellConstraint` implements `BaseConstraint`.

> First call to this function may be slower _slightly_ as the object is being created on-demand.

Returns: `GridCellConstraint` object.

************************************************

### `Grid Grid:spacing(number horizontal, number vertical, boolean horizontalFL, boolean verticalFL)`

Change the spacing of each cell.

For the last two parameters, it determines if the spacing should be applied before the first and after the last element. Thus,

* If `horizontalFL` is set, spacing is applied before the first column and after the last column.

* If `verticalFL` is set, spacing is applied before the first row and after the last row.

An example how the "FL"-suffix parameter affects the spacing can be seen in here: https://imgur.com/a/2PytQSd

Returns: itself

************************************************

### `Grid Grid:cellSize(number width, number height)

Set the cell size of the grid, excluding spacing. This function only takes effect on fixed mode described earlier,
otherwise it does nothing.

Returns: itself

************************************************

### `Grid Grid:foreach(function func(GridCellConstraint constraint, number row, number col))`

Call a function for each `GridCellConstraint` in the grid. That's it, this function is called `row * col` times.

> This initializes all the `GridCellConstraint` in this grid, which may slow.

Returns: itself

************************************************

### `boolean Grid:isFixed()`

Returns: Is the grid in dynamic mode (`false`) or fixed mode (`true`)?

************************************************

### `number,number Grid:getCellDimensions()`

Retrieve the dimensions of a single cell.

> On dynamic mode, this function resolve the constraint used to base the grid, so use with care!

Returns: width and height of a single cell.
