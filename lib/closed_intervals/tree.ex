defmodule ClosedIntervals.Tree do
  @moduledoc """
  Functions to manipulate a tree of closed intervals.

  Library users will often use the `ClosedIntervals` struct,
  which contains a tree together with matching order and equality comparison functions.
  This module contains utilities for direct manipulations on the tree structure,
  many of which are reexported in `ClosedIntervals`.
  """

  require Record

  @doc """
  This is the internal tree representation. It is not intended to be used publicly.
  """
  Record.defrecord(:tree, [
    :left,
    :right,
    :left_bound,
    :right_bound,
    :cut
  ])

  @type t(data) ::
          record(:tree,
            left: nil | t(data),
            right: nil | t(data),
            left_bound: data,
            right_bound: data,
            cut: nil | data
          )

  @doc """
  Construct a tree from a sorted list of data.

  See `ClosedIntervals.from/2`.
  """
  def construct([x, y]) do
    tree(
      left_bound: x,
      right_bound: y
    )
  end

  def construct(sorted_list = [_, _ | _]) do
    len = length(sorted_list)
    middle = floor(len / 2)
    cut = Enum.at(sorted_list, middle)
    {left, right} = Enum.split(sorted_list, middle)
    left = left ++ [cut]
    left = construct(left)
    right = construct(right)

    tree(
      left: left,
      right: right,
      left_bound: tree(left, :left_bound),
      right_bound: tree(right, :right_bound),
      cut: cut
    )
  end

  @doc """
  Create a tree with two leaves from the left and right bounds.
  """
  @spec from_bounds({data, data}) :: t(data) when data: var
  def from_bounds({left, right}) do
    tree(
      left_bound: left,
      right_bound: right
    )
  end

  @doc """
  See `ClosedIntervals.from_leaf_intervals/1`.
  """
  def from_leaf_intervals([leaf]) do
    leaf
  end

  def from_leaf_intervals([
        left = tree(left_bound: left_bound, right_bound: cut),
        right = tree(left_bound: cut, right_bound: right_bound)
      ]) do
    tree(
      left: left,
      right: right,
      left_bound: left_bound,
      right_bound: right_bound,
      cut: cut
    )
  end

  def from_leaf_intervals(leafs) do
    len = length(leafs)
    middle = round(len / 2)
    {left, right} = Enum.split(leafs, middle)

    left_right_bound = left |> List.last() |> right_bound()
    right_left_bound = right |> List.first() |> left_bound()

    if left_right_bound != right_left_bound do
      raise ArgumentError, "Expected cut element between the middle two elements"
    end

    cut = left_right_bound

    left = from_leaf_intervals(left)
    right = from_leaf_intervals(right)

    tree(
      left: left,
      right: right,
      left_bound: tree(left, :left_bound),
      right_bound: tree(right, :right_bound),
      cut: cut
    )
  end

  @doc """
  See `ClosedIntervals.leaf_intervals/1`.
  """
  def leaf_intervals(tree(cut: nil, left_bound: left_bound, right_bound: right_bound)) do
    [{left_bound, right_bound}]
  end

  def leaf_intervals(tree(left: left, right: right)) do
    [leaf_intervals(left), leaf_intervals(right)]
    |> List.flatten()
  end

  @doc """
  See `ClosedIntervals.get_all_intervals/2`.
  """
  def get_all_intervals(tree = tree(cut: nil), _value, _eq, _order) do
    [
      {tree(tree, :left_bound), tree(tree, :right_bound)}
    ]
  end

  def get_all_intervals(tree = tree(), value, eq, order) do
    cut = tree(tree, :cut)

    cond do
      eq.(value, cut) ->
        [
          get_all_intervals(tree(tree, :left), value, eq, order),
          get_all_intervals(tree(tree, :right), value, eq, order)
        ]

      order.(value, cut) ->
        get_all_intervals(tree(tree, :left), value, eq, order)

      true ->
        get_all_intervals(tree(tree, :right), value, eq, order)
    end
  end

  @doc """
  See `ClosedIntervals.to_list/1`.
  """
  def to_list(tree = tree()) do
    tree
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
  See `ClosedIntervals.map/2`.
  """
  @spec map(t(data1), (data1 -> data2)) :: t(data2) when data1: var, data2: var
  def map(tree = tree(cut: nil), mapper) do
    tree(left_bound: left_bound, right_bound: right_bound) = tree

    tree(tree,
      left_bound: mapper.(left_bound),
      right_bound: mapper.(right_bound)
    )
  end

  def map(tree = tree(), mapper) do
    tree(
      left: left,
      right: right,
      left_bound: left_bound,
      right_bound: right_bound,
      cut: cut
    ) = tree

    tree(tree,
      left: map(left, mapper),
      right: map(right, mapper),
      left_bound: mapper.(left_bound),
      right_bound: mapper.(right_bound),
      cut: mapper.(cut)
    )
  end

  @doc """
  See `ClosedIntervals.left_bound/1`.
  """
  def left_bound(tree = tree()) do
    tree(tree, :left_bound)
  end

  @doc """
  See `ClosedIntervals.right_bound/1`.
  """
  def right_bound(tree = tree()) do
    tree(tree, :right_bound)
  end
end
