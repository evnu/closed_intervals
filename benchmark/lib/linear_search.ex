defmodule LinearSearch do
  @moduledoc false

  def from(enum) do
    Enum.zip(enum, Enum.drop(enum, 1))
  end

  def get_interval([{first_bound, _} | _], value) when value <= first_bound do
    {:"-inf", first_bound}
  end

  def get_interval(intervals, value) do
    get_interval1(intervals, value)
  end

  def to_list(intervals) do
    Enum.map(intervals, fn {left, _} -> left end)
  end

  defp get_interval1([{_, last_bound}], _) do
    {last_bound, :"+inf"}
  end

  defp get_interval1([interval = {left, right} | rest], value) do
    if value >= left && value <= right do
      interval
    else
      get_interval1(rest, value)
    end
  end
end
