# ClosedIntervals

[![Hex](https://img.shields.io/hexpm/v/closed_intervals.svg)](https://hex.pm/packages/closed_intervals)
![Build Status](https://github.com/evnu/closed_intervals/workflows/CI/badge.svg?branch=master)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

`ClosedIntervals` implements a tree storing a set of _closed_ intervals such that the
intervals cover a one-dimensional space completely. So for a set of points `{x1, x2, .., xN}`,
`ClosedIntervals` builds a new set `{(:"-inf", x1), (x1, x2), ..., (xN-1, xN), (xN, :"+inf")}` and
provides functions to retrieve the interval to which a value belongs.

## Installation

Add the `closed_intervals` dependency to your `mix.exs`:

```elixir
def deps do
  [
    {:closed_intervals, "~> 0.3"}
  ]
end
```

## Examples

As a simple example, consider the following set of points:

```elixir
[1, 10, 30]
```

With `ClosedIntervals`, the points above are placed on a number line. Now, for any
value on that number line, we can retrieve the interval to which that value
belongs:

    iex> import ClosedIntervals
    iex> closed_intervals = from([1, 10, 30])
    iex> get_interval(closed_intervals, 2)
    {1, 10}
    iex> get_interval(closed_intervals, 11)
    {10, 30}
    iex> get_interval(closed_intervals, -1)
    {:"-inf", 1}
    iex> get_interval(closed_intervals, 1)
    {:"-inf", 1}
    iex> get_interval(closed_intervals, 100)
    {30, :"+inf"}

So if we retrieve the interval for `2`, we receive `{1, 10}`, as the value `2`
is between `1` and `10`. If we query `-1`, we receive `{:"-inf", 1}`, as `-1`
is in front of all defined intervals. Similarly for `100`, we retrieve `{30,
:"+inf"}`.

Defining a linear space with plain numbers is boring, however. Where `ClosedIntervals`
shines is to define an order on multi-dimensional values, where an order in one dimension
makes sense. This is done by defining an explicit order on
`ClosedIntervals.from/2` and `ClosedIntervals.get_interval/2`:

    iex> import ClosedIntervals
    iex> points = [%Indexed{idx: 1, data: :hello}, %Indexed{idx: 5, data: :world}]
    iex> order = fn a, b -> a.idx <= b.idx end
    iex> closed_intervals = from(points, order: order)
    iex> get_interval(closed_intervals, %Indexed{idx: 3})
    {%Indexed{idx: 1, data: :hello}, %Indexed{idx: 5, data: :world}}

`ClosedIntervals` can also handle non-unique indices. This is useful when defining
a function step-wise. Note that in such a case, the intervals for a value should be retrieved
using `ClosedIntervals.get_all_intervals/2`, as a value may belong to more than one interval. For this,
we must define an equality function as well. Usually, this function compares the same fields as
the order function.

    iex> import ClosedIntervals
    iex> points = [%Indexed{idx: 1, data: :hello}, %Indexed{idx: 1, data: :between}, %Indexed{idx: 5, data: :world}]
    iex> order = fn a, b -> a.idx <= b.idx end
    iex> eq = fn a, b -> a.idx == b.idx end
    iex> closed_intervals = from(points, order: order, eq: eq)
    iex> get_all_intervals(closed_intervals, %Indexed{idx: 3})
    [{%Indexed{idx: 1, data: :between}, %Indexed{idx: 5, data: :world}}]
    iex> get_all_intervals(closed_intervals, %Indexed{idx: 1})
    [
	{:"-inf", %Indexed{idx: 1, data: :hello}},
	{%Indexed{idx: 1, data: :hello}, %Indexed{idx: 1, data: :between}},
	{%Indexed{idx: 1, data: :between}, %Indexed{idx: 5, data: :world}}
    ]

## Inspect

`ClosedIntervals` implements the `Inspect` protocol, as trees tend to be large.

    iex> import ClosedIntervals
    iex> from([0, 0, -1])
    #ClosedIntervals<[{-1, 0}, {0, 0}]>

## Internals

`ClosedIntervals` uses a tree of tuples to represent the set of intervals. Using
tuples is considerably faster than using maps, and it is faster than running a
simple linear search on a list of intervals. A linear search would outperform
the implementation here as long as the value queried for is at the beginning of
the list, but the performance degrades very fast for long lists. See the
`benchmark/` for a simple benchmark of a linear search compared to `ClosedIntervals`.

## LICENSE

`ClosedIntervals` is released under Apache License 2.0. See the `LICENSE` file for more information.
