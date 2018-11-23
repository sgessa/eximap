defmodule Eximap.Imap.Parser.Envelope do
  import Eximap.Imap.Parser.Utils

  def parse_envelope(rest) do
    "(" <> str = rest

    {str, result} = parse_env_date(str, %{})
    str = String.trim_leading(str, " ")

    {str, result} = parse_env_subject(str, result)
    str = String.trim_leading(str, " ")

    {str, result} = parse_env_from(str, result)
    str = String.trim_leading(str, " ")

    {str, result} = parse_env_sender(str, result)
    str = String.trim_leading(str, " ")

    {str, result} = parse_env_reply_to(str, result)
    str = String.trim_leading(str, " ")

    {str, result} = parse_env_to(str, result)
    str = String.trim_leading(str, " ")

    {str, result} = parse_env_cc(str, result)
    str = String.trim_leading(str, " ")

    {str, result} = parse_env_bcc(str, result)
    str = String.trim_leading(str, " ")

    {str, result} = parse_env_in_reply_to(str, result)
    str = String.trim_leading(str, " ")

    {str, result} = parse_env_message_id(str, result)
    str = String.trim_leading(str, " ")
    ")" <> str = str

    {result, str}
  end

  def parse_env_bcc(str, accum) do
    {val, rest} = parse_env_naddress_list(str)
    {rest, Map.put(accum, :bcc, val)}
  end
  def parse_env_cc(str, accum) do
    {val, rest} = parse_env_naddress_list(str)
    {rest, Map.put(accum, :cc, val)}
  end
  def parse_env_date(str, accum) do
    {val, rest} = parse_nstring(str)
    {rest, Map.put(accum, :date, val)}
  end
  def parse_env_from(str, accum) do
    {val, rest} = parse_env_naddress_list(str)
    {rest, Map.put(accum, :from, val)}
  end
  def parse_env_in_reply_to(str, accum) do
    {val, rest} = parse_nstring(str)
    {rest, Map.put(accum, :in_reply_to, val)}
  end
  def parse_env_message_id(str, accum) do
    {val, rest} = parse_nstring(str)
    {rest, Map.put(accum, :message_id, val)}
  end
  def parse_env_reply_to(str, accum) do
    {val, rest} = parse_env_naddress_list(str)
    {rest, Map.put(accum, :reply_to, val)}
  end
  def parse_env_sender(str, accum) do
    {val, rest} = parse_env_naddress_list(str)
    {rest, Map.put(accum, :sender, val)}
  end
  def parse_env_subject(str, accum) do
    {val, rest} = parse_nstring(str)
    {rest, Map.put(accum, :subject, val)}
  end
  def parse_env_to(str, accum) do
    {val, rest} = parse_env_naddress_list(str)
    {rest, Map.put(accum, :to, val)}
  end

  def parse_env_naddress_list(str) do
    case str do
      "NIL" <> rest -> {"NIL", rest}
      "(" <> rest -> parse_env_address_list(rest, [])
    end
  end

  def parse_env_address_list(rest, accum) do
    rest = String.trim_leading(rest, " ")
    case rest do
      ")" <> rest -> {accum, rest}
      "(" <> rest ->
        {name, rest} = parse_nstring(rest)
        rest = String.trim_leading(rest, " ")
        {adl, rest} = parse_nstring(rest)
        rest = String.trim_leading(rest, " ")
        {mailbox, rest} = parse_nstring(rest)
        rest = String.trim_leading(rest, " ")
        {host, rest} = parse_nstring(rest)
        rest = String.trim_leading(rest, " ")

        ")" <> rest = rest
        addr = %{name: name, adl: adl, mailbox: mailbox, host: host}
        parse_env_address_list(rest, accum ++ [addr])
    end
  end
end
