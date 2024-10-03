NLay Documentation
=====

If you don't know what NLay is, please go back to https://github.com/MikuAuahDark/NPad93#nlay

Functions in v2.0.0
-----

************************************************

### `RootConstraint NLay = require("path.to.nlay")`

Loading NLay using `require` will give you a `RootConstraint` object which you can pass to functions that expects
`BaseConstraint` object. This constraint is "attached" to your game screen.

From now on, `RootConstraint` static functions is named `NLay`.

************************************************

### `void NLay.update(number x, number y, number w, number h)`

Update the game window dimensions. Normally all return values from
[`love.window.getSafeArea`](https://love2d.org/wiki/love.window.getSafeArea) should be passed unless your game
performs its own logical dimension translation. In that case, adjust accordingly.

************************************************

### `boolean NLay.isConstraint(any value)`

Check if `value` is any of `BaseConstraint` derivatives.

Returns: `true` if `value` is any derivatives of `BaseConstraint`, `false` otherwise. `false` is also returned if
`value` is not an object.

************************************************

### `Constraint NLay.constraint(BaseConstraint parent, BaseConstraint|Into top, BaseConstraint|Into left, BaseConstraint|Into bottom, BaseConstraint|Into right, number padding)`

### `Constraint NLay.constraint(BaseConstraint parent, BaseConstraint|Into top, BaseConstraint|Into left, BaseConstraint|Into bottom, BaseConstraint|Into right, {number padTop, number padLeft, number padBottom, number padRight})`

Create new `Constraint` object.

As per Android's ConstraintLayout, constraint must at least contain 1 horizontal (either `top` or `bottom` must be
set) and 1 vertical (either `left` or `right` must be set) constraints. The new constraint object will "attach" to
specified constraints considering the parent constraint `parent`.

Returns: `Constraint` which is derived from `BaseConstraint`.

************************************************

### `MaxConstraint NLay.max(BaseConstraint...)`

Create new constraint whose the size and the position is based on bounding box of the other constraint.

At least 2 constraint must be passed to this function.

Returns: `MaxConstraint` which is derived from `BaseConstraint`.

************************************************

### `number, number, number, number BaseConstraint:get([number offx = 0][, number offy = 0])`

Retrieve the positions and the dimensions of specified constraint. Note that `BaseConstraint` is the base class for
all constraint in this library.

If offset is specified, then the resulting position will be added by the offset accordingly

Returns: x coordinate, y coordinate, width, and height of the constraint, **in that order**.

************************************************

### `BaseConstraint Constraint:tag(any data)`

Tag this constraint with user-specific data (i.e. id). Useful to keep track of constraints when they're rebuilt.

Returns: itself

************************************************

### `any BaseConstraint:getTag()`

Retrieve tag data from constraint (or `nil` if this constraint is not tagged). See above function for more information.

Returns: tag data

************************************************

### `Into NLay.in_(BaseConstraint constraint)`

This function tells `NLay.constraint` to consider inner area of specified `constraint` as the anchor instead of the
outer. Note that these condition automatically assume inner part of constraint to be considered:

* Specified constraint (top/left/bottom/right) is the parent.

* Same constraint is specified for the adjacent axis (top and bottom is same or left and right is same)

Example diagram without `NLay.in_` of left constraint:
```txt
o------------o
|            |
|            | <-- anchor
|            |
o------------o
```

Example diagram **with** `NLay.in_` of left constraint:
```txt
o------------o
|            |
| <-- anchor |
|            |
o------------o
```

The underlying `constraint` can be retrieved using the `.value` member.

Returns: `Into` object that can be passed into `NLay.constraint`.

************************************************

### `Constraint Constraint:margin(number margin)`

### `Constraint Constraint:margin({number marginTop, number marginLeft, number marginBottom, number marginRight})`

Sets the constraint margin.

If margin is `nil`, then it's 0. If margin is a number, then it sets the margin for all sides. Otherwise it sets the
margin for sides according to the 2nd overload (any absent or `nil` field means 0).

Returns: itself

************************************************

### `Constraint Constraint:size(number width, number height, string modeW, string modeH)`

Sets the constraint width and height.

If width/height is 0, it will calculate it based on the other connected constraint. If it's -1, then it will use
parent's width/height minus padding. Otherwise it will try to place the constraint based on the bias (see function
below).

`modeW` (for `width`) and `modeH` (for `height`) changes how the size calculation work. If it's `"pixel"` then the
specified `width` and `height` are absolute value. If it's `"percent"` then the actual dimensions is determined
assuming as if 0 width/height is passed then the resulting size is multiplied by the `width` and `height`. The default
value for `modeW` and `modeH` is `"pixel"`.

Returns: itself

************************************************

### `Constraint Constraint:bias(number horizontalBias, number verticalBias, boolean unclamped)`

Set the constraint bias.

By default, for fixed width/height, the bias is 0.5 which means the position are centered.

If the parameter is `nil`, then it won't set the bias of such parameter.

Returns: itself

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

### `LineConstraint LineConstraint:offset(off)`

(Re)-set the line offset previously set from `NLay.line`

Returns: itself

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

### `Grid Grid:cellSize(number width, number height)`

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

************************************************

### `RatioConstraint NLay.contain(BaseConstraint parent)`

Create new constraint that fits exactly inside other constraint, downscaling the constraint if necessary. This is
equivalent to [`object-fit: contain`](https://developer.mozilla.org/en-US/docs/Web/CSS/object-fit) in CSS3. By
default, it creates `RatioConstraint` with aspect ratio of 1:1.

Returns: `RatioConstraint` which is derived from `BaseConstraint`.

************************************************

### `RatioConstraint NLay.cover(BaseConstraint parent)`

Create new constraint that cover all area inside other constraint, upscaling the constraint if necessary. This is
equivalent to [`object-fit: cover`](https://developer.mozilla.org/en-US/docs/Web/CSS/object-fit) in CSS3. By
default, it creates `RatioConstraint` with aspect ratio of 1:1.

Returns: `RatioConstraint` which is derived from `BaseConstraint`.

************************************************

### `RatioConstraint RatioConstraint:ratio(number ratio)`

### `RatioConstraint RatioConstraint:ratio(number numerator, number denominator)`

Set the size aspect ratio. The `ratio` is in format `numerator/denominator`, so for aspect ratio of 16:9, pass `16/9`.

Returns: itself

************************************************

### `RatioConstraint RatioConstraint:bias(number horizontalBias, number verticalBias, boolean unclamped)`

Set the constraint bias.

By default, for fixed width/height, the bias is 0.5 which means the position are centered.

If the parameter is `nil`, then it won't set the bias of such parameter.

Returns: itself

************************************************

### `FloatingConstraint NLay.floating(number x, number y, number w, number h)`

Create new free-floating constraint. This can serve as "alternaive" root for another constraints.

Returns: `FloatingConstraint` which is derived from `BaseConstraint`.

************************************************

### `void NLay.flushCache()`

### `void NLay.flushCache(BaseConstraint constraint)`

The 1st variant will invalidate all constraint cache. The 2nd variant will invalidate the cache of that specific
`constraint` along with all constraints that references `constraint`.

Nornally the 1st variant is called when calling `NLay.update()`.

************************************************

### `FloatingConstraint FloatingConstraint:pos(number x, number y)`

Set floating constraint position.

Returns: itself

************************************************

### `FloatingConstraint FloatingConstraint:size(number w, number h)`

Set floating constraint size. If negative value is passed, then its absolute value is taken.

Returns: itself

************************************************

### `FloatingConstraint FloatingConstraint:update(number x, number y, number w, number h)`

Shorthand of `FloatingConstraint:pos(x, y):size(w, h)`.

Returns: itself

************************************************

### `ForeignConstraint NLay.foreign(object object, boolean manualupdate)`

Create new foreign constraint. This is mainly used for interopability with other layouting library.

`object` must contain a function `get` which takes `object` and return 4 values: x coordinate, y coordinate, width,
and height of a rectangle, **in that order**.

If `manualupdate` is specified, then **you're responsible of invalidating the cache of this constraint yourself using
`NLay.flushCache()` if the underlying region/constraint value changes!** If `manualupdate` is not specified, then
calling `:get()` in this underlying `ForeignConstraint` will always assume the values were outdated. Since there's no
way NLay would know if the underlying object value changes, then this parameter is provided and it's up to user to
pick the best option.

Returns: `ForeignConstraint` which is derived from `BaseConstraint`.

************************************************

### `SelectableConstraint NLay.selectable(BaseConstraint...)`

Create a new constraint which can refer to another constraint, dynamically. At least 1 constraint must be specified.

This is mainly used to simulate "CSS breakpoints", bu picking different constraint index on specific conditions.

Returns: `SelectableConstraint` which is derived from `BaseConstraint`.

************************************************

### `SelectableConstraint SelectableConstraint:index(integer i)`

Select active constraint by specified index.

Returns: itself

************************************************

### `Constraint... NLay.split(BaseConstraint constraint, string direction, number...)`

Creates normal constraints by splitting `constraint`, either "horizontal" or "vertically" (the `direction` parameter)
with specified weights (rest of numbers specified).

For example, this will divide the `constraint` by 3 equal parts:
`c1, c2, c3 = NLay.split(constraint, direction, 1, 1, 1)`.

Returns: tuple of `Constraint`s.

************************************************

### `TransposedConstraint NLay.transposed(BaseConstraint constraint)`

Create a new transposed constraint. Transposed constraint swaps the width and the height value of its underlying
constraint.

Returns: `TransposedConstraint` which is derived from `BaseConstraint`.
