defmodule Eximap.Imap.Parser.Utils do
  def parse_number(rest) do
    [val, separator, rest] = String.split(rest, ~r{\d+(?<non_digit>[^\d])}, on: [:non_digit], parts: 2, include_captures: true)
    {val, separator<>rest}
  end

  def parse_nstring(rest) do
    case rest do
      "NIL" <> rest -> {"NIL", rest}
      _ -> parse_string(rest)
    end
  end

  def parse_string(rest) do
    case rest do
      "\"" <> _ -> parse_quoted(rest)
      "{" <> _ -> parse_literal(rest)
      _ -> raise "string parser failed at: #{inspect(rest)}"
    end
  end

  def parse_literal(rest) do
    "{" <> rest = rest
    [len, rest] = String.split(rest, "}\r\n", parts: 2)
    len = len |> String.to_integer()
    split_bytes(rest, len)
  end

  def parse_nz_number(rest) do
    [val, rest] = String.split(rest, ~r{[1-9]\d+(?<space>\s)}, on: [:space], parts: 2)
    {val, rest}
  end

  def parse_quoted(rest) do
    "\"" <> rest = rest

    split_location =
      rest
      |> :binary.bin_to_list()
      |> Enum.reduce_while(%{idx: 0, escape_seq: false}, fn ch,
                                                            %{idx: idx, escape_seq: escape_seq} ->
        cond do
          ch == ?" && escape_seq == false ->
            {:halt, %{idx: idx, escape_seq: false}}

          ch == ?\  && escape_seq == false ->
            {:cont, %{idx: idx + 1, escape_seq: true}}

          true ->
            {:cont, %{idx: idx + 1, escape_seq: false}}
        end
      end)
      |> Map.fetch!(:idx)

    split_bytes(rest, split_location, true)
  end

  def split_bytes(binary, location, drop_split_location \\ false) do
    {l, r} = binary |> :binary.bin_to_list() |> Enum.split(location)
    r = if drop_split_location do
      Enum.drop(r, 1)
    else
      r
    end
    {:binary.list_to_bin(l), :binary.list_to_bin(r)}
  end
end
