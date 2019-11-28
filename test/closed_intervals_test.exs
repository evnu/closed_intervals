defmodule ClosedIntervalsTest do
  use ExUnit.Case
  doctest ClosedIntervals, import: true

  import ClosedIntervals, except: [map: 2]

  use PropCheck

  describe "default order" do
    test "from" do
      assert_raise ArgumentError, fn -> from([1]) end

      assert from([1, 2]) == %ClosedIntervals{
               tree:
                 closed_intervals(left: nil, right: nil, left_bound: 1, right_bound: 2, cut: nil),
               order: &<=/2,
               eq: nil
             }

      assert from([1, 2, 3]) == %ClosedIntervals{
               tree:
                 closed_intervals(
                   left:
                     closed_intervals(
                       left: nil,
                       right: nil,
                       left_bound: 1,
                       right_bound: 2,
                       cut: nil
                     ),
                   right:
                     closed_intervals(
                       left: nil,
                       right: nil,
                       left_bound: 2,
                       right_bound: 3,
                       cut: nil
                     ),
                   left_bound: 1,
                   right_bound: 3,
                   cut: 2
                 ),
               order: &<=/2,
               eq: nil
             }

      assert %{tree: closed_intervals()} = from([1, 2, 3, 4, 5])
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
      order = fn a, b -> a.idx < b.idx end

      points =
        [a, b, c, _d] = [
          %{idx: 1, data: :a},
          %{idx: 2, data: :b},
          %{idx: 3, data: :c},
          %{idx: 4, data: :d}
        ]

      tree = from(points, order: order)
      assert {a, b} == get_interval(tree, %{idx: 1})
      assert {b, c} == get_interval(tree, %{idx: 2})
      assert {a, b} == get_interval(tree, %{idx: 1.5})
    end
  end

  test "get_all_intervals" do
    order = fn a, b -> a.idx <= b.idx end
    eq = fn a, b -> a.idx == b.idx end

    points =
      [a, b, c, d, e] = [
        %{idx: 1, data: :a},
        %{idx: 2, data: :b},
        %{idx: 3, data: :c},
        %{idx: 3, data: :x},
        %{idx: 4, data: :d}
      ]

    tree = from(points, order: order, eq: eq)

    assert [{:"-inf", a}] == get_all_intervals(tree, %{idx: 0})
    assert [{:"-inf", a}, {a, b}] == get_all_intervals(tree, %{idx: 1})
    assert [{a, b}, {b, c}] == get_all_intervals(tree, %{idx: 2})
    assert [{a, b}] == get_all_intervals(tree, %{idx: 1.5})

    assert [{e, :"+inf"}] == get_all_intervals(tree, %{idx: 5})
    assert [{e, :"+inf"}, {d, e}] == get_all_intervals(tree, %{idx: 4})

    # non-unique idx
    assert [{b, c}, {c, d}, {d, e}] == get_all_intervals(tree, %{idx: 3})
    assert [{d, e}] == get_all_intervals(tree, %{idx: 3.5})
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
