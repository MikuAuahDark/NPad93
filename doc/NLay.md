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

### `number, number, number, number BaseConstraint:get()`

Retrieve the positions and the dimensions of specified constraint. Note that `BaseConstraint` is the base class for all constraint in this library.

Returns: x coordinate, y coordinate, width, and height of the constraint, **in that order**.

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

### `Constraint:margin({number marginTop, number marginLeft, number marginBottom, number marginRight})`

Sets the constraint margin.

If margin is `nil`, then it's 0. If margin is a number, then it sets the margin for all sides. Otherwise it sets the margin
for sides according to the 2nd overload (any absent or `nil` field means 0).

Returns: itself

************************************************

### `Constraint Constraint:size(number width, number height)`

Sets the constraint width and height.

If width/height is 0, it will calculate it based on the other connected constraint. If it's -1, then it will use parent's width/height minus padding.
Otherwise it will try to place the constraint based on the bias (see below)

Returns: itself

************************************************

### `Constraint:bias(number horizontalBias, number verticalBias)`

Set the constraint bias.

By default, for fixed width/height, the bias is 0.5 which means the position are centered.

If the parameter is `nil`, then it won't set the bias of such parameter.

Returns: itself
