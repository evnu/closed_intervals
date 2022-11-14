defmodule Indexed do
  defstruct [:idx, :data]
end

defimpl Compare, for: Indexed do
  def compare(lhs, rhs) do
    Compare.compare(lhs.idx, rhs.idx)
  end
end
