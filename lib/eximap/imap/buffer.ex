defmodule Eximap.Imap.Buffer do
  import Eximap.Utils

  @literal ~r/{(\d+)}\r\n/s

  def extract_responses(buff, responses) do
    case String.contains?(buff, "\r\n") do
      true ->
        current_resp = current_response(responses)
        {buff, new_resp} = extract_response(buff, current_resp)

        new_responses =
          if partial?(current_resp) do
            [new_resp | Enum.drop(responses, 1)]
          else
            [new_resp | responses]
          end

        extract_responses(buff, new_responses)

      false ->
        {buff, responses}
    end
  end

  def extract_response("", response), do: {"", response}

  def extract_response(buff, %{body: body, bytes_left: :unknown, last_line: line}) do
    extract_response(line <> buff, %{body: body, bytes_left: 0})
  end

  def extract_response(buff, %{body: body, bytes_left: 0}) do
    case String.split(buff, "\r\n", parts: 2) do
      [line, rest] ->
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

      [line] ->
        {"", %{body: body, bytes_left: :unknown, last_line: line}}
    end
  end

  def extract_response(buff, %{body: body, bytes_left: bytes_left}) do
    {taken, rest} = split_bytes(buff, bytes_left)

    bytes_left = bytes_left - byte_size(taken)

    if bytes_left == 0 do
      extract_response(rest, %{body: body <> taken, bytes_left: :unknown, last_line: ""})
    else
      extract_response(rest, %{body: body <> taken, bytes_left: bytes_left})
    end
  end

  defp current_response([]), do: %{body: "", bytes_left: 0}

  defp current_response([resp | _]) do
    case partial?(resp) do
      true -> resp
      false -> %{body: "", bytes_left: 0}
    end
  end

  defp partial?(%{bytes_left: b}), do: b == :unknown || b > 0
end
