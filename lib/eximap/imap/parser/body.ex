defmodule Eximap.Imap.Parser.Body do
  import Eximap.Imap.Parser.Utils
  def parse_body(rest) do
    "(" <> rest = rest
    {result, rest} = parse_body(rest, %{parts: [], type: nil})
    {result, rest}
  end

  def parse_body(rest, accum) do
    case rest do
      "(\"" <> _ ->
        {part, rest} = parse_part(rest)
        accum = Map.put(accum, :parts, accum.parts ++ [part])
        parse_body(rest, accum)
      " " <> rest ->
        {type, rest} = parse_string(rest)
        ")" <> rest = rest
        accum = Map.put(accum, :type, type)
        {accum, rest}
      "(" <> rest ->
        {result, rest} = parse_body(rest, %{parts: [], type: nil})
        accum = Map.put(accum, :parts, accum.parts ++ [result])
        parse_body(rest, accum)
      ")" <> rest ->
        {accum, rest}
    end
  end

  def parse_part(rest) do
    "(" <> rest = rest
    {type, rest} = parse_quoted(rest)
    rest = String.trim_leading(rest, " ")
    {result, rest} = case String.downcase(type) do
      "text" -> parse_text_part(rest)
      "message" -> raise "MESSAGE type not implemented"
      _ -> parse_basic_part(rest)
    end
    result = Map.put(result, :media_type, type)
    {result, rest}
  end

  def parse_basic_part(rest) do
    {media_subtype, rest} = parse_quoted(rest)
    rest = String.trim_leading(rest, " ")

    {body_fields, rest} = parse_body_fields(rest)

    {ext, rest} = parse_body_ext(rest)

    part = %{
      media_subtype: media_subtype,
      body_fields: body_fields,
      ext: ext
    }
    {part, rest}
  end

  def parse_text_part(rest) do
    {media_subtype, rest} = parse_quoted(rest)
    rest = String.trim_leading(rest, " ")

    {body_fields, rest} = parse_body_fields(rest)
    rest = String.trim_leading(rest, " ")

    {fld_lines, rest} = parse_body_fld_lines(rest)

    {ext, rest} = parse_body_ext(rest)

    part = %{
      media_subtype: media_subtype,
      body_fields: body_fields,
      fld_lines: fld_lines,
      ext: ext
    }
    {part, rest}
  end

  def parse_body_fields(rest) do
    {fld_params, rest} = parse_body_fld_params(rest)
    rest = String.trim_leading(rest, " ")
    {fld_id, rest} = parse_body_fld_id(rest)
    rest = String.trim_leading(rest, " ")
    {fld_desc, rest} = parse_body_fld_desc(rest)
    rest = String.trim_leading(rest, " ")
    {fld_enc, rest} = parse_body_fld_enc(rest)
    rest = String.trim_leading(rest, " ")
    {fld_octets, rest} = parse_body_fld_octets(rest)
    rest = String.trim_leading(rest, " ")

    {
      %{
        body_fld_params: fld_params,
        body_fld_id: fld_id,
        body_fld_desc: fld_desc,
        body_fld_enc: fld_enc,
        body_fld_octets: fld_octets
      },
    rest}
  end

  def parse_body_ext(rest) do
    case rest do
      ")" <> rest -> {nil, rest}
      _ -> raise "body_ext parser failed at: #{inspect(rest)}"
    end
  end

  def parse_body_fld_params(rest, accum \\ []) do
    case rest do
      "NIL" <> rest -> {"NIL", rest}
      "(" <> rest ->
        {k, rest} = parse_string(rest)
        rest = String.trim_leading(rest, " ")
        {v, rest} = parse_string(rest)
        parse_body_fld_params(rest, accum ++ [{k, v}])

      ")" <> rest -> {accum, rest}
    end
  end

  def parse_body_fld_id(rest) do
    parse_nstring(rest)
  end

  def parse_body_fld_desc(rest) do
    parse_nstring(rest)
  end

  def parse_body_fld_enc(rest) do
    parse_string(rest)
  end

  def parse_body_fld_octets(rest) do
    parse_number(rest)
  end

  def parse_body_fld_lines(rest) do
    parse_number(rest)
  end
end


# (
#    (
#        (\"text\" \"plain\" (\"charset\" \"UTF-8\") NIL NIL \"7BIT\" 21 3)
#        (\"text\" \"html\" (\"charset\" \"UTF-8\") NIL NIL \"7BIT\" 60 1)
#        \"alternative\"
#    )
#    (\"image\" \"gif\" (\"name\" \"tumblr_owtba8hxJ31rg3vrmo1_500.gif\") \"<f_jn7al9d70>\" NIL \"base64\" 2211060)
#    \"mixed\"
# )


# (
#    (\"text\" \"html\" (\"charset\" \"utf-8\") NIL NIL \"base64\" 2456 32)
#    (\"image\" \"jpeg\" NIL \"<collector.jpg@parts.yandex.ru>\" NIL \"base64\" 7274)
#    \"related\"
# )

# (((\"text\" \"plain\" (\"charset\" \"UTF-8\") NIL NIL \"7BIT\" 21 3)(\"text\" \"html\" (\"charset\" \"UTF-8\") NIL NIL \"7BIT\" 60 1) \"alternative\")(\"image\" \"gif\" (\"name\" \"tumblr_owtba8hxJ31rg3vrmo1_500.gif\") \"<f_jn7al9d70>\" NIL \"base64\" 2211060) \"mixed\")


# ((\"text\" \"html\" (\"charset\" \"utf-8\") NIL NIL \"base64\" 2456 32)(\"image\" \"jpeg\" NIL \"<collector.jpg@parts.yandex.ru>\" NIL \"base64\" 7274) \"related\")
