defmodule Eximap.Imap.Response do
  @moduledoc ~S"""
  Parse responses returned by the IMAP server and convert them to a structured format
  """
  alias Eximap.Imap.Response
  alias Eximap.Imap.UntaggedResponse
  defstruct tag: nil, body: [], status: "OK", error: nil, message: nil

  def build([]), do: nil

  def build([tagged_line | lines]) do
    {tag, status, message} = parse_tagged_line(tagged_line)

    %Response{
      tag: tag,
      status: status,
      message: message,
      body: parse_untagged_lines(lines)
    }
  end

  def parse_tagged_line(line) do
    [tag, status, body] = String.split(line, " ", parts: 3)
    {tag, status, body}
  end

  def parse_untagged_lines(lines) do
    lines
    |> Enum.reverse()
    |> Enum.map(&UntaggedResponse.build(&1))
  end
end
