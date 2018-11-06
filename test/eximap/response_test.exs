defmodule ResponseTest do
  use ExUnit.Case
  alias Eximap.Imap.Response
  alias Eximap.Imap.Request

  test "parsing bulk of lines" do
    lines = [
      "EX1 OK [READ-WRITE] SELECT Completed.\r\n",
      "* OK [UIDNEXT 1132] Ok\r\n",
      "* 983 RECENT\r\n",
      "* 1122 EXISTS\r\n"
    ]

    r = Response.parse(%Response{request: %Request{tag: "EX1"}}, lines)
    assert r.status == "OK"
    assert r.message == "[READ-WRITE] SELECT Completed.\r\n"
    assert length(r.body) == 3
    assert hd(r.body) == %{message: "EXISTS", type: "1122"}
  end
end
