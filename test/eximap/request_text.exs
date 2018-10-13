defmodule RequestTest do
  use ExUnit.Case
  alias Eximap.Imap.Request

  test "NOOP shouldnt have trailing whitespace before CRLF" do
    noop = Request.noop()
    assert Request.raw(noop) == "#{noop.tag} NOOP\r\n"
  end
end
