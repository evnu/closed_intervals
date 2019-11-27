defmodule Benchmark do
  @moduledoc false

  def run do
    benchmarks =
      "BENCHMARKS"
      |> System.get_env()
      |> case do
        nil -> :all
        str ->
          String.split(str, ",")
      end

    points = 1..1000
    inputs = points |> Enum.shuffle() |> Enum.take(3)

    closed_intervals = ClosedIntervals.from(points)
    intervals = LinearSearch.from(points)

    # Sanity Check that we measure something comparable
    for point <- points do
      p1 = ClosedIntervals.get_interval(closed_intervals, point)
      p2 = LinearSearch.get_interval(intervals, point)

      if p1 != p2 do
        raise "#{point} results in #{p1} for ClosedIntervals, but #{p2} for LinearSerarch"
      end
    end

    #
    # Measure constructing an interval tree versus a simple list
    #
    ranges = [1..10, 1..100, 1..1000]

    if benchmarks == :all or "from" in benchmarks do
      Benchee.run(
        %{
          "ClosedIntervals.from/1" => &ClosedIntervals.from(&1),
          "LinearSearch.from/2" => &LinearSearch.from(&1)
        },
        inputs: ranges |> Enum.map(&inspect/1) |> Enum.zip(ranges) |> Map.new(),
        memory_time: 2
      )
    end

    #
    # Measure retrieving an interval for a given value
    #
    if benchmarks == :all or "get_interval" in benchmarks do
      Benchee.run(
        %{
          "ClosedIntervals.get_interval/2" => &ClosedIntervals.get_interval(closed_intervals, &1),
          "LinearSearch.get_interval/2" => &LinearSearch.get_interval(intervals, &1)
        },
        inputs: inputs |> Enum.zip(inputs) |> Map.new(),
        memory_time: 2
      )
    end

    #
    # How costly is turning such a tree into a list?
    #
    if benchmarks == :all or "to_list" in benchmarks do
      Benchee.run(
        %{
          "ClosedIntervals.to_list/1" => fn -> ClosedIntervals.to_list(closed_intervals) end,
          "ClosedIntervals.leaf_intervals/1" => fn ->
            ClosedIntervals.leaf_intervals(closed_intervals)
          end,
          "LinearSearch.to_list/1" => fn -> LinearSearch.to_list(intervals) end
        },
        memory_time: 2
      )
    end
  end
end
