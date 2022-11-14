defmodule ClosedIntervalsTest do
  use ExUnit.Case
  doctest ClosedIntervals, import: true

  import ClosedIntervals, except: [map: 2]
  alias ClosedIntervals.Tree
  require Tree

  use PropCheck

  describe "default order" do
    test "from" do
      assert_raise ArgumentError, fn -> from([1]) end

      assert from([1, 2]) == %ClosedIntervals{
               tree: Tree.tree(left: nil, right: nil, left_bound: 1, right_bound: 2, cut: nil)
             }

      assert from([1, 2, 3]) == %ClosedIntervals{
               tree:
                 Tree.tree(
                   left:
                     Tree.tree(
                       left: nil,
                       right: nil,
                       left_bound: 1,
                       right_bound: 2,
                       cut: nil
                     ),
                   right:
                     Tree.tree(
                       left: nil,
                       right: nil,
                       left_bound: 2,
                       right_bound: 3,
                       cut: nil
                     ),
                   left_bound: 1,
                   right_bound: 3,
                   cut: 2
                 )
             }

      assert %{tree: Tree.tree()} = from([1, 2, 3, 4, 5])
      assert from([1, 2, 3, 4, 5]) == from([5, 4, 3, 2, 1])
    end

    test "get_interval" do
      tree = from([1, 2, 3, 4])
      assert {1, 2} == get_interval(tree, 2)
      assert {1, 2} == get_interval(tree, 1.5)
      assert {2, 3} == get_interval(tree, 2.5)
    end

    test "+/- inf" do
      tree = from([1, 2, 3, 4])
      assert {:"-inf", 1} == get_interval(tree, 0)
      assert {:"-inf", 1} == get_interval(tree, 1)
      assert {4, :"+inf"} == get_interval(tree, 5)
    end
  end

  describe "custom order" do
    test "get_interval" do
      points =
        [a, b, c, _d] = [
          %Indexed{idx: 1, data: :a},
          %Indexed{idx: 2, data: :b},
          %Indexed{idx: 3, data: :c},
          %Indexed{idx: 4, data: :d}
        ]

      tree = from(points)
      assert {a, b} == get_interval(tree, %Indexed{idx: 1})
      assert {b, c} == get_interval(tree, %Indexed{idx: 2})
      assert {a, b} == get_interval(tree, %Indexed{idx: 1.5})
    end
  end

  test "get_all_intervals" do
    points =
      [a, b, c, d, e] = [
        %Indexed{idx: 1, data: :a},
        %Indexed{idx: 2, data: :b},
        %Indexed{idx: 3, data: :c},
        %Indexed{idx: 3, data: :x},
        %Indexed{idx: 4, data: :d}
      ]

    tree = from(points)

    assert [{:"-inf", a}] == get_all_intervals(tree, %Indexed{idx: 0})
    assert [{:"-inf", a}, {a, b}] == get_all_intervals(tree, %Indexed{idx: 1})
    assert [{a, b}, {b, c}] == get_all_intervals(tree, %Indexed{idx: 2})
    assert [{a, b}] == get_all_intervals(tree, %Indexed{idx: 1.5})

    assert [{e, :"+inf"}] == get_all_intervals(tree, %Indexed{idx: 5})
    assert [{e, :"+inf"}, {d, e}] == get_all_intervals(tree, %Indexed{idx: 4})

    # non-unique idx
    assert [{b, c}, {c, d}, {d, e}] == get_all_intervals(tree, %Indexed{idx: 3})
    assert [{d, e}] == get_all_intervals(tree, %Indexed{idx: 3.5})
  end

  property "can reconstruct ClosedIntervals with from_leaf_intervals/1,2" do
    numtests(
      10_000,
      forall numbers <- gen_list_with_at_least_two_elements() do
        closed_intervals = from(numbers)
        leaf_intervals = leaf_intervals(closed_intervals)
        from_leaf_intervals = from_leaf_intervals(leaf_intervals)

        equals(closed_intervals, from_leaf_intervals)
      end
    )
  end

  property "can reconstruct ClosedIntervals with from/1,2" do
    numtests(
      10_000,
      forall numbers <- gen_list_with_at_least_two_elements() do
        closed_intervals = from(numbers)
        points = to_list(closed_intervals)
        from_points = from(points)

        equals(closed_intervals, from_points)
      end
    )
  end

  test "inspect" do
    assert "#ClosedIntervals<[{-1, 0}, {0, 0}]>" == [0, 0, -1] |> from() |> inspect()
  end

  defp gen_list_with_at_least_two_elements do
    let [
      a <- integer(),
      b <- integer(),
      rest <- list(integer())
    ] do
      [a, b | rest]
    end
  end
end
