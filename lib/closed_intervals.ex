defmodule ClosedIntervals do
  @moduledoc """
  A ClosedIntervals datastructure.

  `ClosedIntervals` represents a set of closed intervals and provides functions to
  retrieve the interval to which a given value belongs to. `ClosedIntervals` can
  handle arbitrary data, as long as it can be ordered in a sensible way. Users
  can either use the default term order `&<=/2` if that suits their needs, or
  provide an explicit order function.

  """
  require Record

  @enforce_keys [:tree, :order, :eq]
  defstruct @enforce_keys

  @type t(data) :: %__MODULE__{
          tree: tree(data),
          order: (data, data -> boolean()),
          eq: (data, data -> boolean())
        }

  @doc """
  This is the internal tree representation. It is not intended to be used publicly.
  """
  Record.defrecord(:closed_intervals, [
    :left,
    :right,
    :left_bound,
    :right_bound,
    :cut
  ])

  @type tree(data) ::
          record(:closed_intervals,
            left: nil | tree(data),
            right: nil | tree(data),
            left_bound: data,
            right_bound: data,
            cut: nil | data
          )

  @doc """
  Create a new `ClosedIntervals` from points.

  This function creates a new `ClosedIntervals` from an `Enum` of points. The points
  can be of any form, as long as they can be ordered sensibly. For types where the
  term order does not order them in a way such that the resulting order represents
  a linear ordering along the interval range, a custom order can be applied using the
  `order` parameter. `order` defaults to `&<=/2`. Note that a custom order should return
  true for equal points, if the resulting order has to be stable.

  Additionally, an explicit equality function can be provided which is used in
  `ClosedIntervals.get_interval/2` and `ClosedIntervals.get_all_intervals/2`.

  ## Errors

  The function expects that the `enum` contains at least two points. If that is not the case,
  an `ArgumentError` is raised.

      iex> from([1])
      ** (ArgumentError) Need at least two points to construct a ClosedIntervals

  ## Examples

  `from/1,2` can handle plain types:

      iex> from([1, 2, 3]) |> leaf_intervals()
      [{1, 2}, {2, 3}]

  It can also handle nested types, if a suitable `order` is defined:

      iex> points = [%{idx: 3}, %{idx: 7}, %{idx: 1}]
      iex> points |> from(order: &(&1.idx <= &2.idx)) |> leaf_intervals()
      [{%{idx: 1}, %{idx: 3}}, {%{idx: 3}, %{idx: 7}}]

  ## Arguments

  * `:order`: A custom order defined on the points used to construct the `ClosedIntervals`
  * `:eq`: A custom equality defined on the points used to construct the `ClosedIntervals`

  """
  @spec from(Enum.t(), Keyword.t()) :: t(term())
  def from(enum, args \\ []) do
    {order, eq} = parse_args!(args)

    case Enum.sort(enum, order) do
      points = [_, _ | _] ->
        %__MODULE__{
          tree: construct(points),
          order: order,
          eq: eq
        }

      _ ->
        raise ArgumentError, "Need at least two points to construct a ClosedIntervals"
    end
  end

  defp parse_args!(args) do
    order = Keyword.get(args, :order, &<=/2)
    eq = Keyword.get(args, :eq)

    if !is_function(order, 2) do
      raise ArgumentError, "Expecting :order to be a function of arity 2"
    end

    if eq && !is_function(eq, 2) do
      raise ArgumentError, "Expecting :eq to be a function of arity 2"
    end

    {order, eq}
  end

  @doc """
  Reconstruct a `ClosedInterval` from the output of `leaf_intervals/1`.

  Note that the `args` must match the arguments used when originally constructing the
  `ClosedInterval` with `from/1,2`.

  ## Errors

  If the least of leaf intervals is not the result of `leaf_intervals/1`, this can result
  in an `ArgumentError`.

  ## Example

      iex> closed_intervals = from([1, 2, 3])
      iex> leaf_intervals = leaf_intervals(closed_intervals)
      iex> from_leaf_intervals(leaf_intervals)
      iex> closed_intervals == from_leaf_intervals(leaf_intervals)
      true

  """
  def from_leaf_intervals(leaf_intervals = [_ | _], args \\ []) do
    tree =
      leaf_intervals
      |> Enum.map(fn {left, right} ->
        closed_intervals(
          left_bound: left,
          right_bound: right
        )
      end)
      |> from_leaf_intervals1()

    {order, eq} = parse_args!(args)

    %__MODULE__{
      tree: tree,
      order: order,
      eq: eq
    }
  end

  defp from_leaf_intervals1([leaf]) do
    leaf
  end

  defp from_leaf_intervals1([
         left = closed_intervals(left_bound: left_bound, right_bound: cut),
         right = closed_intervals(left_bound: cut, right_bound: right_bound)
       ]) do
    closed_intervals(
      left: left,
      right: right,
      left_bound: left_bound,
      right_bound: right_bound,
      cut: cut
    )
  end

  defp from_leaf_intervals1(leafs) do
    len = length(leafs)
    middle = round(len / 2)
    {left, right} = Enum.split(leafs, middle)

    left_right_bound = left |> List.last() |> right_bound()
    right_left_bound = right |> List.first() |> left_bound()

    if left_right_bound != right_left_bound do
      raise ArgumentError, "Expected cut element between the middle two elements"
    end

    cut = left_right_bound

    left = from_leaf_intervals1(left)
    right = from_leaf_intervals1(right)

    closed_intervals(
      left: left,
      right: right,
      left_bound: closed_intervals(left, :left_bound),
      right_bound: closed_intervals(right, :right_bound),
      cut: cut
    )
  end

  @doc """
  Retrieve a list of all leaf intervals.

  A leaf interval is an interval which has been constructed from two adjacent
  points. It does not expand to `:"-inf"` or `:"+inf"`.

  See `from_leaf_intervals/1,2`. We can reconstruct the original `ClosedInterval`
  from a list of leaf intervals.

  ## Example

      iex> from([1, 2, 3]) |> leaf_intervals()
      [{1, 2}, {2, 3}]

  """
  @spec leaf_intervals(t(data)) :: [{data, data}] when data: var
  def leaf_intervals(%__MODULE__{tree: tree}) do
    tree |> leaf_intervals1() |> List.flatten()
  end

  defp leaf_intervals1(
         closed_intervals(cut: nil, left_bound: left_bound, right_bound: right_bound)
       ) do
    [{left_bound, right_bound}]
  end

  defp leaf_intervals1(closed_intervals(left: left, right: right)) do
    [leaf_intervals1(left), leaf_intervals1(right)]
  end

  @doc """
  Get the interval to which a value belongs to.

  ## Example

      iex> closed_intervals = from([1, 2, 5])
      iex> get_interval(closed_intervals, 3)
      {2, 5}
  """
  @spec get_interval(t(data), data) :: {data, data} | {:"-inf", data} | {data, :"+inf"}
        when data: var
  def get_interval(closed_intervals = %__MODULE__{}, value) do
    case get_all_intervals(closed_intervals, value) do
      [interval] ->
        interval

      [inf = {:"-inf", _} | _] ->
        inf

      [inf = {_, :"+inf"} | _] ->
        inf
    end
  end

  @doc """
  Retrieve all intervals which cover `value`.

  This function is useful if the index points used to define the `ClosedIntervals` are not
  unique. For example, when defining a step-function, it might make sense to use the same
  point multiple times but with different data in order to represent a sharp step. Values
  which are placed right at the interval bounds can then belong to multiple closed intervals.

  """
  @spec get_all_intervals(t(data), data) :: [{data, data}] | [{:"-inf", data}] | [{data, :"+inf"}]
        when data: var
  def get_all_intervals(%__MODULE__{tree: tree, eq: eq, order: order}, value) do
    eq = eq || fn _, _ -> false end

    left_bound = closed_intervals(tree, :left_bound)
    right_bound = closed_intervals(tree, :right_bound)

    cond do
      order.(value, left_bound) ->
        neg_inf = [{:"-inf", closed_intervals(tree, :left_bound)}]

        if eq.(value, left_bound) do
          neg_inf ++ get_all_intervals1(tree, value, eq, order)
        else
          neg_inf
        end

      order.(right_bound, value) ->
        pos_inf = [{closed_intervals(tree, :right_bound), :"+inf"}]

        if eq.(value, right_bound) do
          pos_inf ++ get_all_intervals1(tree, value, eq, order)
        else
          pos_inf
        end

      true ->
        get_all_intervals1(tree, value, eq, order)
    end
    |> List.flatten()
  end

  defp get_all_intervals1(closed_intervals = closed_intervals(cut: nil), _value, _eq, _order) do
    [
      {closed_intervals(closed_intervals, :left_bound),
       closed_intervals(closed_intervals, :right_bound)}
    ]
  end

  defp get_all_intervals1(closed_intervals = closed_intervals(), value, eq, order) do
    cut = closed_intervals(closed_intervals, :cut)

    cond do
      eq.(value, cut) ->
        [
          get_all_intervals1(closed_intervals(closed_intervals, :left), value, eq, order),
          get_all_intervals1(closed_intervals(closed_intervals, :right), value, eq, order)
        ]

      order.(value, cut) ->
        get_all_intervals1(closed_intervals(closed_intervals, :left), value, eq, order)

      true ->
        get_all_intervals1(closed_intervals(closed_intervals, :right), value, eq, order)
    end
  end

  defp construct([x, y]) do
    closed_intervals(
      left_bound: x,
      right_bound: y
    )
  end

  defp construct(sorted_list = [_, _ | _]) do
    len = length(sorted_list)
    middle = floor(len / 2)
    cut = Enum.at(sorted_list, middle)
    {left, right} = Enum.split(sorted_list, middle)
    left = left ++ [cut]
    left = construct(left)
    right = construct(right)

    closed_intervals(
      left: left,
      right: right,
      left_bound: closed_intervals(left, :left_bound),
      right_bound: closed_intervals(right, :right_bound),
      cut: cut
    )
  end

  @doc """
  Serialize `ClosedIntervals` into a list.

  ## Example

      iex> closed_intervals = from([1, 2, 3])
      iex> to_list(closed_intervals)
      [1, 2, 3]

  We can construct the original `ClosedInterval` from a list
  generated by `to_list/1`:

      iex> closed_intervals = from([1, 2, 3])
      iex> to_list(closed_intervals)
      iex> closed_intervals == closed_intervals |> to_list() |> from()
      true

  """
  @spec to_list(t(data)) :: [data] when data: var
  def to_list(closed_intervals = %__MODULE__{}) do
    closed_intervals
    |> leaf_intervals()
    |> to_list1([])
    |> Enum.reverse()
  end

  defp to_list1([{left, right}], acc) do
    [right, left | acc]
  end

  defp to_list1([{left, _right} | rest], acc) do
    to_list1(rest, [left | acc])
  end

  @doc """
  Map a function over all intervals.

  ## Example

      iex> closed_intervals = from([1, 2, 3])
      iex> map(closed_intervals, & &1 + 1) |> to_list()
      [2, 3, 4]
  """
  @spec map(t(data), (data -> data)) :: t(data) when data: var
  def map(closed_intervals = %__MODULE__{}, mapper) when is_function(mapper, 1) do
    %__MODULE__{closed_intervals | tree: map1(closed_intervals.tree, mapper)}
  end

  defp map1(closed_intervals = closed_intervals(cut: nil), mapper) do
    closed_intervals(left_bound: left_bound, right_bound: right_bound) = closed_intervals

    closed_intervals(closed_intervals,
      left_bound: mapper.(left_bound),
      right_bound: mapper.(right_bound)
    )
  end

  defp map1(closed_intervals = closed_intervals(), mapper) do
    closed_intervals(
      left: left,
      right: right,
      left_bound: left_bound,
      right_bound: right_bound,
      cut: cut
    ) = closed_intervals

    closed_intervals(closed_intervals,
      left: map1(left, mapper),
      right: map1(right, mapper),
      left_bound: mapper.(left_bound),
      right_bound: mapper.(right_bound),
      cut: mapper.(cut)
    )
  end

  @doc """
  Retrieve the left bound of a `ClosedIntervals`.

  ## Example

      iex> [1, 2, 3] |> from() |> left_bound()
      1

  """
  def left_bound(%__MODULE__{tree: tree}) do
    left_bound(tree)
  end

  def left_bound(tree = closed_intervals()) do
    closed_intervals(tree, :left_bound)
  end

  @doc """
  Retrieve the right bound of a `ClosedIntervals`.

  ## Example

      iex> [1, 2, 3] |> from() |> right_bound()
      3
  """
  def right_bound(%__MODULE__{tree: tree}) do
    right_bound(tree)
  end

  def right_bound(tree = closed_intervals()) do
    closed_intervals(tree, :right_bound)
  end

  defimpl Inspect, for: ClosedIntervals do
    import Inspect.Algebra

    def inspect(closed_intervals, opts) do
      concat([
        "#ClosedIntervals<",
        to_doc(ClosedIntervals.leaf_intervals(closed_intervals), opts),
        ">"
      ])
    end
  end
end
