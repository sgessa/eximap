defmodule Eximap.Utils do
  def split_bytes(binary, location, drop_split_location \\ false) do
    {l, r} = binary |> :binary.bin_to_list() |> Enum.split(location)

    r =
      if drop_split_location do
        Enum.drop(r, 1)
      else
        r
      end

    {:binary.list_to_bin(l), :binary.list_to_bin(r)}
  end
end
