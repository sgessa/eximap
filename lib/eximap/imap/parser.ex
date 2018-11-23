defmodule Eximap.Imap.Parser do
  import Eximap.Imap.Parser.Utils
  alias Eximap.Imap.Parser.{Envelope, Body}

  def parse_fetch(string) do
    fetch_size = byte_size(string) - byte_size("FETCH (") - byte_size(")")
    <<"FETCH (", fetch::binary-size(fetch_size), ")">> = string
    parse_fetch_parts(fetch)
  end

  def parse_fetch_parts(s) do
    parse_fetch_parts(s, %{})
  end

  def parse_fetch_parts("", accum), do: accum

  def parse_fetch_parts(s, accum) do
    s = String.trim_leading(s, " ")
    [key, rest] = String.split(s, " ", parts: 2)

    {val, rest} =
      cond do
        key == "FLAGS" -> parse_flags(rest)
        key == "RFC822.SIZE" -> parse_number(rest)
        String.starts_with?(key, "RFC822") -> parse_nstring(rest)
        key == "ENVELOPE" -> Envelope.parse_envelope(rest)
        key == "INTERNALDATE" -> parse_date_time(rest)
        key == "UID" -> parse_uniqueid(rest)
        key == "BODY" -> Body.parse_body(rest)
        key == "BODYSTRUCTURE" -> raise "BODYSTRUCTURE parser not implemented"
        String.starts_with?(key, "BODY") -> raise "#{key} parser not implemented"
        true -> raise "invalid key? #{inspect(s)}"
      end

    accum = Map.put(accum, key, val)
    parse_fetch_parts(rest, accum)
  end

  def parse_flags("(" <> rest) do
    [val, rest] = String.split(rest, ")", parts: 2)
    {val, rest}
  end

  def parse_date_time(rest) do
    "\"" <> str = rest
    [dt, rest] = String.split(str, "\"", parts: 2)
    {"\"" <> dt, rest}
  end

  def parse_uniqueid(rest) do
    parse_nz_number(rest)
  end
end
