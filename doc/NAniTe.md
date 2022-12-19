NAniTe Documentation
=====

If you don't know what NAniTe is, please go back to https://github.com/MikuAuahDark/NPad93#nanite

Functions in v1.0.0
-----

************************************************

### `nanite animation = nanite(table source, Timeline[] timelines)`

Creates a new `nanite` object.

`source` is the source table containing values to tween. `timelines` are list of timeline definitions.

`Timeline` is defined as table with following fields:
* `id` - Identifier of this timeline (optional). If specified, it must be a valid Lua variable identifier.
* `start` - When to start this timeline. This can be a number or string containing formula on how to calculate this value.
* `duration` - How long this timeline lasts. This can be a number or string containing formula on how to calculate this value.
* `stop` - When to stop this timeline. This can be a number or string containing formula on how to calculate this value. Mutually exclusive with `duration`!
* `easing` - Custom easing function to use (optional). The default easing is "linear".
* `variables` - List of key-value pairs of variables to tween from `source`. Also accept custom easing with easing function as key and value as key-value pairs of variables to tween from `source` with specified easing.
* `updateHook` - List of function that are called when this timeline is being updated. The function signature is `function updatehook(any userdata, number dt)` (optional).
* `userdata` - Additional userdata to pass when calling update hook function (optional).

Here's a few example of timeline definition:

#### Simplest
```lua
local animation = nanite(source, {
	{
		start = 0,
		duration = 20,
		variables = {foo = 123}
	}
})
```

#### Referencing Other Timeline Values
```lua
local animation = nanite(source, {
	{
		id = "foo"
		start = 0,
		duration = 20,
		variables = {foo = 123}
	},
	{
		id = "bar",
		start = "finish(foo)",
		duration = "duration(foo) + 123",
		variables = {foo = 2}
	}
})
```

When `start`, `duration`, and `stop` are string, it's assumed to be a formula to calculate said values, parsed by Lua itself. All Lua `math` functions are valid functions, additionally:
* `start` - Return start value of said timeline identifier.
* `duration` - Return duration of said timeline identifier.
* `finish` - Return end value of said timeline identifier.

Note: Timeline without identifier (`id`) can't be referenced in formula evaluation!

Note: Having timeline identifier that conflicts with Lua [`math`](https://www.lua.org/manual/5.1/manual.html#5.6) functions
or functions above result in those functions overwritten!

**CAUTION**: Using Lua [reserved keyword](https://www.lua.org/manual/5.1/manual.html#2.1) as timeline identifier will result in error!

#### Referencing Other Timeline Values With Complex Formula
```lua
local animation = nanite(source, {
	{
		id = "foo"
		start = 0,
		duration = 20,
		variables = {foo = 123}
	},
	{
		id = "bar",
		start = "finish(foo)",
		duration = "floor(duration(foo) / 2) + sin(pi / 2) * sqrt(finish(foo))",
		variables = {foo = 2}
	}
})
```

**Returns**: new `nanite` object.

************************************************

### `nanite:update(number dt)`

Update the `nanite` object. Unlike other functions that accepts delta time, `dt` in NAniTe can both be positive (forward update) or negative (backward update).

**Returns**: `true` if the timeline has finished (forward update) or has been fully rewound (backward update), `false` otherwise.

************************************************

### `nanite:add(Timeline timeline)`

Add new timeline definition to existing `nanite` object.

**Returns**: None.
