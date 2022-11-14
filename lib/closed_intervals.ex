defmodule ClosedIntervals do
  @moduledoc """
  A ClosedIntervals datastructure.

  `ClosedIntervals` represents a set of closed intervals and provides functions to
  retrieve the interval to which a given value belongs to. `ClosedIntervals` can
  handle arbitrary data, as long as it can be ordered in a sensible way. Users
  can either use the default term order `&<=/2` if that suits their needs, or
  provide an explicit order function.

  """

  alias ClosedIntervals.Tree
  require Tree

  @enforce_keys [:tree]
  defstruct @enforce_keys

  @type t(data) :: %__MODULE__{
          tree: Tree.t(data)
        }

  @type interval(data) :: {data, data} | {:"-inf", data} | {data, :"+inf"}

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
      iex> points |> from() |> leaf_intervals()
      [{%{idx: 1}, %{idx: 3}}, {%{idx: 3}, %{idx: 7}}]

  ## Arguments

  * `:order`: A custom order defined on the points used to construct the `ClosedIntervals`
  * `:eq`: A custom equality defined on the points used to construct the `ClosedIntervals`

  """
  @spec from(Enum.t()) :: t(term())
  def from(enum) do
    case Enum.sort(enum, Compare) do
      points = [_, _ | _] ->
        %__MODULE__{
          tree: Tree.construct(points)
        }

      _ ->
        raise ArgumentError, "Need at least two points to construct a ClosedIntervals"
    end
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
  def from_leaf_intervals(leaf_intervals = [_ | _]) do
    tree =
      leaf_intervals
      |> Enum.map(&Tree.from_bounds/1)
      |> Tree.from_leaf_intervals()

    %__MODULE__{
      tree: tree
    }
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
    tree |> Tree.leaf_intervals()
  end

  @doc """
  Get the interval to which a value belongs to.

  ## Example

      iex> closed_intervals = from([1, 2, 5])
      iex> get_interval(closed_intervals, 3)
      {2, 5}
  """
  @spec get_interval(t(data), data) :: interval(data)
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
  @spec get_all_intervals(t(data), data) :: [interval(data)]
        when data: var
  def get_all_intervals(%__MODULE__{tree: tree}, value) do
    left_bound = Tree.tree(tree, :left_bound)
    right_bound = Tree.tree(tree, :right_bound)

    IO.inspect(
      value: value,
      tree: tree,
      left_bound: left_bound,
      right_bound: right_bound
    )

    cond do
      Compare.compare(value, left_bound) in [:lt, :eq] ->
        neg_inf = [{:"-inf", Tree.tree(tree, :left_bound)}]

        if Compare.compare(value, left_bound) == :eq do
          neg_inf ++ Tree.get_all_intervals(tree, value)
        else
          neg_inf
        end
        |> IO.inspect(label: "first cond")

      Compare.compare(right_bound, value) in [:lt, :eq] ->
        pos_inf = [{Tree.tree(tree, :right_bound), :"+inf"}]

        if Compare.compare(right_bound, value) == :eq do
          pos_inf ++ Tree.get_all_intervals(tree, value)
        else
          pos_inf
        end
        |> IO.inspect(label: "second cond")

      true ->
        Tree.get_all_intervals(tree, value)
        |> IO.inspect(label: "third cond")
    end
    |> List.flatten()
    |> IO.inspect(label: "got all intervals")
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
    Tree.to_list(closed_intervals.tree)
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
    %__MODULE__{closed_intervals | tree: Tree.map(closed_intervals.tree, mapper)}
  end

  @doc """
  Retrieve the left bound of a `ClosedIntervals`.

  ## Example

      iex> [1, 2, 3] |> from() |> left_bound()
      1

  """
  def left_bound(%__MODULE__{tree: tree}) do
    Tree.left_bound(tree)
  end

  @doc """
  Retrieve the right bound of a `ClosedIntervals`.

  ## Example

      iex> [1, 2, 3] |> from() |> right_bound()
      3
  """
  def right_bound(%__MODULE__{tree: tree}) do
    Tree.right_bound(tree)
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
