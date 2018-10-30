defmodule Eximap.Imap.BufferParser do
  @literal ~r/{(\d+)}\r\n/s

  def extract_response("", response), do: {"", response}

  def extract_response(buff, %{body: body, bytes_left: 0}) do
    [line, rest] = String.split(buff, "\r\n", parts: 2)
    line = line <> "\r\n"

    if line =~ @literal do
      [_match | [size]] = Regex.run(@literal, line)
      size = String.to_integer(size)
      response = %{body: body <> line, bytes_left: size}
      extract_response(rest, response)
    else
      response = %{body: body <> line, bytes_left: 0}
      {rest, response}
    end
  end

  def extract_response(buff, %{body: body, bytes_left: bytes_left}) do
    {taken_list, rest_list} = buff |> :binary.bin_to_list() |> Enum.split(bytes_left)
    taken = :binary.list_to_bin(taken_list)
    rest = :binary.list_to_bin(rest_list)

    extract_response(rest, %{body: body <> taken, bytes_left: bytes_left - byte_size(taken)})
  end
end
