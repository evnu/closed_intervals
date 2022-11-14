defprotocol Compare do
  @spec compare(t, t) :: :eq | :lt | :gt when t: any()
  def compare(lhs, rhs)
end

defimpl Compare, for: Integer do
  def compare(lhs, rhs) when is_number(rhs) do
    cond do
      lhs < rhs -> :lt
      lhs == rhs -> :eq
      lhs > rhs -> :gt
    end
    # |> IO.inspect(label: "comparing integers #{lhs} #{rhs}")
  end
end

defimpl Compare, for: Float do
  def compare(lhs, rhs) when is_number(rhs) do
    cond do
      lhs < rhs -> :lt
      lhs == rhs -> :eq
      lhs > rhs -> :gt
    end
  end
end
