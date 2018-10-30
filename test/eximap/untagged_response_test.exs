defmodule UntaggedResponseTest do
  use ExUnit.Case
  alias Eximap.Imap.UntaggedResponse

  test "raw untagged response" do
    line =
      "* OK [PERMANENTFLAGS (\\Answered \\Seen \\Draft \\Flagged \\Deleted $Forwarded \\*)] Limited\r\n"

    r = UntaggedResponse.build(line)
    assert r.type == "RAW"
    assert r.content == line
  end

  test "fetch untagged response" do
    line = "* 1082 FETCH (RFC822 {14}\r\nFOOBARFOOBAZ\r\n)\r\n"
    r = UntaggedResponse.build(line)
    assert r.type == "FETCH"
    assert r.content == "RFC822 {14}\r\nFOOBARFOOBAZ\r\n"
  end
end
