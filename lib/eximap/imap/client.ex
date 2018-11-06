defmodule Eximap.Imap.Client do
  use GenServer
  alias Eximap.Imap.Request
  alias Eximap.Imap.Response
  alias Eximap.Socket
  alias Eximap.Imap.BufferParser, as: Parser

  @moduledoc """
  Imap Client GenServer
  """

  @initial_state %{socket: nil, tag_number: 1, buff: ""}

  def start_link(host, port, account, pass) do
    host = host |> to_charlist
    state = Map.merge(@initial_state, %{host: host, port: port, account: account, pass: pass})
    GenServer.start_link(__MODULE__, state)
  end

  def init(%{host: host, port: port, account: account, pass: pass, buff: buff} = state) do
    opts = build_opts(host)

    # todo: Hardcoded SSL connection until I implement the Authentication algorithms to allow login over :gen_tcp
    {:ok, socket} = Socket.connect(true, host, port, opts)

    # login using the account name and password
    req = Request.login(account, pass) |> Request.add_tag("EX_LGN")
    {buff, %Response{status: "OK"}} = imap_send(buff, socket, req)

    {:ok, %{state | socket: socket, buff: buff}}
  end

  def execute(pid, req) do
    GenServer.call(pid, {:command, req}, 20000)
  end

  def handle_call({:command, %Request{} = req}, _from, %{socket: socket, tag_number: tag_number, buff: buff} = state) do
    {buff, resp} = imap_send(buff, socket, %Request{req | tag: "EX#{tag_number}"})
    {:reply, resp, %{state | tag_number: tag_number + 1, buff: buff}}
  end

  def handle_info(resp, state) do
    IO.inspect resp
    {:noreply, state}
  end

  #
  # Private methods
  #

  defp build_opts('imap.yandex.ru'), do: [:binary, active: false, ciphers: ['AES256-GCM-SHA384']]
  defp build_opts(_), do: [:binary, active: false]

  defp imap_send(buff, socket, req) do
    message = Request.raw(req)
    imap_send_raw(socket, message)
    imap_receive(buff, socket, req)
  end

  defp imap_send_raw(socket, msg) do
   # IO.inspect "C: #{msg}"
    Socket.send(socket, msg)
  end

  defp imap_receive(buff, socket, req) do
    {buff, responses} = fill_responses(buff, socket, req.tag, [])

    responses = responses |> Enum.map(fn %{body: b} -> b end)
    result = Response.parse(%Response{request: req}, responses)

    {buff, result}
  end

  defp fill_responses(buff, socket, tag, responses) do
    {buff, responses} = if tagged_response_arrived?(tag, responses) do
      {buff, responses}
    else
      case Socket.recv(socket, 0, 20000) do
        {:ok, data} ->
          buff = buff <> data
          {buff, responses} = case String.contains?(buff, "\r\n") do
            true -> Parser.extract_responses(buff, responses)
            false -> {buff, responses}
          end
          fill_responses(buff, socket, tag, responses)

        {:error, reason} ->
          {buff, responses}
      end
    end

    {buff, responses}
  end


  defp tagged_response_arrived?(_tag, []), do: false
  defp tagged_response_arrived?(tag, [resp | _]) do
    !partial?(resp) && String.starts_with?(resp.body, tag)
  end

  defp partial?(%{bytes_left: b}), do: b > 0
end
