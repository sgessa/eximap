defmodule BufferTest do
  use ExUnit.Case
  alias Eximap.Imap.Buffer

  test "empty buff" do
    buff = ""
    {rest, resp} = Buffer.extract_response(buff, %{body: "", bytes_left: 0})
    assert resp.bytes_left == 0
    assert resp.body == ""
    assert rest == ""
  end

  test "parse one line of buff" do
    buff =
      "* OK Yandex IMAP4rev1 at imap43j.mail.yandex.net:993 ready to talk with ::ffff:95.143.215.164:47147, 2018-Oct-31 05:28:07, 7SNOF9FKn8c1\r\n"

    {rest, resp} = Buffer.extract_response(buff, %{body: "", bytes_left: 0})
    assert resp.bytes_left == 0
    assert resp.body == buff
    assert rest == ""
  end

  test "parse partial response" do
    buff =
      "* OK Yandex IMAP4rev1 at imap43j.mail.yandex.net:993\r\n ready to talk with ::ffff:95.143.215.164:47147, 2018-Oct-31 05:28:07, 7SNOF9FKn8c1\r\n"

    {rest, resp} = Buffer.extract_response(buff, %{body: "WHATEVER", bytes_left: 5})
    assert resp.bytes_left == 0
    assert resp.body == "WHATEVER* OK Yandex IMAP4rev1 at imap43j.mail.yandex.net:993\r\n"

    assert rest ==
             " ready to talk with ::ffff:95.143.215.164:47147, 2018-Oct-31 05:28:07, 7SNOF9FKn8c1\r\n"
  end

  test "parse partial response without enough bytes in buff" do
    buff =
      "* OK Yandex IMAP4rev1 at imap43j.mail.yandex.net:993 ready to talk with ::ffff:95.143.215.164:47147, 2018-Oct-31 05:28:07, 7SNOF9FKn8c1\r\n"

    {rest, resp} = Buffer.extract_response(buff, %{body: "WHATEVER", bytes_left: 1000})
    assert resp.bytes_left == 1000 - byte_size(buff)
    assert resp.body == "WHATEVER" <> buff
    assert rest == ""
  end

  test "parse partial response \\r\\n ending" do
    buff = "* 1082 FETCH (RFC822 {7}\r\n12345\r\n)\r\n"
    {rest, resp} = Buffer.extract_response(buff, %{body: "", bytes_left: 0})
    assert resp.bytes_left == 0
    assert resp.body == buff
    assert rest == ""
  end

  test "extra bytes are left in buffer after one extract_response" do
    buff = "345\r\n)\r\n* 1 REC"
    {rest, resp} = Buffer.extract_response(buff, %{body: "* 1082 FETCH (RFC822 {7}\r\n12", bytes_left: 5})
    assert resp.bytes_left == 0
    assert resp.body == "* 1082 FETCH (RFC822 {7}\r\n12345\r\n)\r\n"
    assert rest == "* 1 REC"
  end

  test "extract_responses stops iteraton and extra bytes are left as is if there is no separator in buff" do
    buff = "* 1082 FETCH (RFC822 {7}\r\n12345\r\n)\r\n* 1 REC"
    {rest, responses} = Buffer.extract_responses(buff, [])
    assert length(responses) == 1

    resp = hd(responses)
    assert resp.bytes_left == 0
    assert resp.body == "* 1082 FETCH (RFC822 {7}\r\n12345\r\n)\r\n"

    assert rest == "* 1 REC"
  end
end
