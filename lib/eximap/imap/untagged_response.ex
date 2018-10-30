defmodule Eximap.Imap.UntaggedResponse do
  @moduledoc ~S"""
  Parse responses starting with * returned by the IMAP server and convert them to a structured format
  """
  alias Eximap.Imap.UntaggedResponse
  @enforce_keys [:type, :content]
  defstruct [:type, :content]

  @untagged_fetch ~r/\A\* (\d+) FETCH /

  def build(line) do
    cond do
      line =~ @untagged_fetch ->
        [_, rest] = Regex.split(@untagged_fetch, line, parts: 2)
        content_size = byte_size(rest) - byte_size("()\r\n")
        <<"(", content::binary-size(content_size), ")\r\n">> = rest
        %UntaggedResponse{type: "FETCH", content: content}

      true ->
        %UntaggedResponse{type: "RAW", content: line}
    end
  end
end
