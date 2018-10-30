defmodule Eximap.Imap.Client do
  use GenServer
  alias Eximap.Imap.Request
  alias Eximap.Imap.Response
  alias Eximap.Socket

  @moduledoc """
  Imap Client GenServer
  """

  @initial_state %{socket: nil, tag_number: 1}

  def start_link(host, port, account, pass) do
    host = host |> to_charlist
    state = Map.merge(@initial_state, %{host: host, port: port, account: account, pass: pass})
    GenServer.start_link(__MODULE__, state)
  end

  def init(%{host: host, port: port, account: account, pass: pass} = state) do
    opts = build_opts(host)

    # todo: Hardcoded SSL connection until I implement the Authentication algorithms to allow login over :gen_tcp
    {:ok, socket} = Socket.connect(true, host, port, opts)
    state = %{state | socket: socket}

    # todo: parse the server attributes and store them in the state
    imap_receive_raw(socket)

    # login using the account name and password
    req = Request.login(account, pass) |> Request.add_tag("EX_LGN")
    %Response{status: "OK"} = imap_send(socket, req)

    {:ok, %{state | socket: socket}}
  end

  def execute(pid, req) do
    GenServer.call(pid, {:command, req})
  end

  def handle_call({:command, %Request{} = req}, _from, %{socket: socket, tag_number: tag_number} = state) do
    resp = imap_send(socket, %Request{req | tag: "EX#{tag_number}"})
    {:reply, resp, %{state | tag_number: tag_number + 1}}
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

  defp imap_send(socket, req) do
    message = Request.raw(req)
    imap_send_raw(socket, message)
    imap_receive(socket, req)
  end

  defp imap_send_raw(socket, msg) do
   # IO.inspect "C: #{msg}"
    Socket.send(socket, msg)
  end

  defp imap_receive(socket, req) do
    msg = assemble_msg(socket, req.tag)
    # IO.inspect("R: #{msg}")
    Response.parse(%Response{request: req}, msg)
  end

  # assemble a complete message
  defp assemble_msg(socket, tag), do: assemble_msg(socket, tag, "")

  defp assemble_msg(socket, tag, msg) do
    {:ok, recv} = Socket.recv(socket, 0)
    msg = msg <> recv
    if Regex.match?(~r/^.*#{tag} .*\r\n$/s, msg),
      do: msg,
      else: assemble_msg(socket, tag, msg)
  end

  defp imap_receive_raw(socket) do
    {:ok, msg} = Socket.recv(socket, 0)
    msgs = String.split(msg, "\r\n", parts: 2)
    msgs = Enum.drop msgs, -1
#    Enum.map(msgs, &(IO.inspect "S: #{&1}"))
    msgs
  end

end
