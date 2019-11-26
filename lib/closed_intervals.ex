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
      ** (ArgumentError) Need at least two points to construct an ClosedIntervals

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
    order = Keyword.get(args, :order, &<=/2)
    eq = Keyword.get(args, :eq)

    if !is_function(order, 2) do
      raise ArgumentError, "Expecting :order to be a function of arity 2"
    end

    if eq && !is_function(eq, 2) do
      raise ArgumentError, "Expecting :eq to be a function of arity 2"
    end

    case Enum.sort(enum, order) do
      points = [_, _ | _] ->
        %__MODULE__{
          tree: construct(points),
          order: order,
          eq: eq
        }

      _ ->
        raise ArgumentError, "Need at least two points to construct an ClosedIntervals"
    end
  end

  @doc """
  Retrieve a list of all leaf intervals.

  A leaf interval is an interval which has been constructed from two adjacent
  points. It does not expand to `:"-inf"` or `:"+inf"`.

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

    infinity_interval =
      cond do
        order.(value, closed_intervals(tree, :left_bound)) ->
          [{:"-inf", closed_intervals(tree, :left_bound)}]

        order.(closed_intervals(tree, :right_bound), value) ->
          [{closed_intervals(tree, :right_bound), :"+inf"}]

        true ->
          []
      end

    (infinity_interval ++ get_all_intervals1(tree, value, eq, order))
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
      iex> closed_intervals == closed_intervals |> to_list() |> from()
      true

  """
  @spec to_list(t(data)) :: [data] when data: var
  def to_list(closed_intervals = %__MODULE__{}) do
    closed_intervals
    |> leaf_intervals()
    |> Enum.map(fn {left, right} -> [left, right] end)
    |> Enum.concat()
    |> Enum.uniq()
  end
end
