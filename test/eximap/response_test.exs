defmodule ResponseTest do
  use ExUnit.Case
  alias Eximap.Imap.Response

  test "parsing bulk of lines" do
    lines = [
      "EX1 OK [READ-WRITE] SELECT Completed.\r\n",
      "* OK [UIDNEXT 1132] Ok\r\n",
      "* 983 RECENT\r\n",
      "* 1122 EXISTS\r\n"
    ]

    r = Response.build(lines)
    assert r.tag == "EX1"
    assert r.status == "OK"
    assert r.message == "[READ-WRITE] SELECT Completed.\r\n"
    assert length(r.body) == 3
    assert hd(r.body).content == lines |> Enum.at(-1)
  end
end
