defmodule Eximap.Imap.Response do
  @moduledoc ~S"""
  Parse responses returned by the IMAP server and convert them to a structured format
  """
  defstruct request: nil, body: [], status: "OK", error: nil, message: nil, partial: false

  @literal ~r/{([0-9]*)}\r\n/s

#  @response_codes [
#    "ALERT", "BADCHARSET", "CAPABILITY", "PARSE", "PERMANENTFLAGS", "READ-ONLY", "READ-WRITE",
#    "TRYCREATE", "UIDNEXT", "UIDVALIDITY", "UNSEEN"
#  ]


  def parse(resp, ""), do: resp
  def parse(resp, msg) do
    [part, other_parts] = get_msg_part(msg)
    {:ok, resp, other_parts} = parse_line(resp, part, other_parts)
    if resp.partial, do: parse(resp, other_parts), else: resp
  end

  defp get_msg_part(msg), do: get_msg_part("", msg)
  defp get_msg_part(part, other_parts) do
    if other_parts =~ @literal do
      [_match | [size]] = Regex.run(@literal, other_parts)
      size = String.to_integer(size)
      [head, tail] = String.split(other_parts, @literal, parts: 2)

      cp = :binary.bin_to_list(tail)
      {literal, [?) | post_literal_cp]} = Enum.split(cp, size)
      literal = :binary.list_to_bin(literal)
      post_literal = :binary.list_to_bin(post_literal_cp)

      case post_literal do
        "\r\n" <> next -> [part <> head <> literal, next]
        _ -> get_msg_part(part <> head <> literal, post_literal)
      end
    else
      [h, t] = String.split(other_parts, "\r\n", parts: 2)
      [part <> h, t]
    end
  end

  defp parse_line(resp, line, rest) do
    parse_tag(resp, line, rest)
  end

  defp parse_tag(resp, line, rest) do
    tag = resp.request.tag
    tag_size = byte_size(tag)
    case line do
      "* " <> message ->
        parse_message("untagged", resp, message, rest)
      <<^tag::bytes-size(tag_size)>> <> " " <> message ->
        parse_message("tagged", resp, message, rest)
    end
  end

  defp parse_message("untagged", resp, msg, rest) do
    # handle one term msg, eg Request.search(["ALL"]) on an empty mailbox returns "* SEARCH\r\n"
    {type, msg} =
      case String.split(msg, " ", parts: 2) do
        [type | [msg]] -> {type, msg}
        [type] -> {type, nil}
      end
    {:ok, append_to_response(resp, item: %{type: type, message: msg}), rest}
  end

  defp parse_message("tagged", resp, "NO " <> msg, rest), do: {:ok, append_to_response(resp, status: "NO", partial: false, message: msg), rest}
  defp parse_message("tagged", resp, "BAD " <> msg, rest), do: {:ok, append_to_response(resp, status: "BAD", partial: false, message: msg), rest}
  defp parse_message("tagged", resp, "OK " <> msg, rest), do: {:ok, append_to_response(resp, status: "OK", partial: false, message: msg), rest}
  defp parse_message("tagged", resp, msg, rest), do: {:ok, append_to_response(resp, status: "UNKNOWN", partial: false, message: msg), rest}

  defp append_to_response(resp, opts) do
    status = Keyword.get(opts, :status, "OK")
    item = Keyword.get(opts, :item, %{})
    message = Keyword.get(opts, :message, "")
    partial = Keyword.get(opts, :partial, true)
    %Eximap.Imap.Response{resp | body: [item | resp.body], message: message, status: status, partial: partial}
  end
end
