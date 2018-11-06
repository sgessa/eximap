defmodule Eximap.Imap.BufferParser do
  @literal ~r/{(\d+)}\r\n/s

  def extract_responses("", responses) do
    {"", responses}
  end

  def extract_responses(buff, responses) do
    current_resp = current_response(responses)
    {buff, new_resp} = extract_response(buff, current_resp)

    new_responses = if partial?(current_resp) do
      [new_resp | Enum.drop(responses, 1)]
    else
      [new_resp | responses]
    end
    extract_responses(buff, new_responses)
  end

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

  defp current_response([]), do: %{body: "", bytes_left: 0}

  defp current_response([resp | _]) do
    case partial?(resp) do
      true -> resp
      false -> %{body: "", bytes_left: 0}
    end
  end

  defp partial?(%{bytes_left: b}), do: b > 0
end
