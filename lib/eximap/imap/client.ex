defmodule Eximap.Imap.Client do
  use GenServer
  alias Eximap.Imap.Request
  alias Eximap.Imap.Response
  alias Eximap.Socket
  alias Eximap.Imap.BufferParser, as: Parser

  @moduledoc """
  Imap Client GenServer
  """

  @initial_state %{socket: nil, tag_number: 1, buff: "", conn_opts: nil}
  @recv_timeout 10_000
  @total_timeout 20_000

  def start_link(conn_opts, opts \\ []) do
    GenServer.start_link(__MODULE__, conn_opts, name: Keyword.get(opts, :name))
  end

  def init(%{host: host, port: _, account: _, password: _} = conn_opts) do
    host = to_charlist(host)
    conn_opts = Map.put(conn_opts, :host, host)

    sock_opts = Map.get(conn_opts, :socket_options, [])
    conn_opts = Map.put(conn_opts, :socket_options, build_opts(sock_opts))

    {:ok, %{@initial_state | conn_opts: conn_opts}}
  end

  def connect(pid) do
    GenServer.call(pid, :connect)
  end

  def execute(pid, req) do
    GenServer.call(pid, {:command, req}, @total_timeout)
  end

  def handle_call(:connect, _from, %{buff: buff, conn_opts: options} = state) do
    %{host: host, port: port, account: account, password: password, socket_options: sock_opts} = options

    {result, new_state} = case Socket.connect(true, host, port, sock_opts) do
      {:error, _} = err -> {err, state}

      {:ok, socket} ->
        req = Request.login(account, password) |> Request.add_tag("EX_LGN")
        {buff, resp} = imap_send(buff, socket, req)
        {resp, %{state | buff: buff, socket: socket}}
    end


    {:reply, result, new_state}
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
  defp build_opts(user_opts) do
    allowed_opts = :proplists.unfold(user_opts) |> Enum.reject(fn {k, _} -> (k == :binary || k == :active) end)
    [:binary, active: false] ++ allowed_opts
  end

  defp imap_send(buff, socket, req) do
    message = Request.raw(req)
    case imap_send_raw(socket, message) do
      :ok -> imap_receive(buff, socket, req)
      {:error, _} = v -> {buff, v}
    end
  end

  defp imap_send_raw(socket, msg) do
    # IO.inspect "C: #{msg}"
    Socket.send(socket, msg)
  end

  defp imap_receive(buff, socket, req) do
    {buff, result} = fill_responses(buff, socket, req.tag, [])

    result = case result do
      {:ok, responses} ->
        responses = responses |> Enum.map(fn %{body: b} -> b end)
        {:ok, Response.parse(%Response{request: req}, responses)}

      {:error, _} = v -> v
    end

    {buff, result}
  end

  defp fill_responses(buff, socket, tag, responses) do
    {buff, result} = if tagged_response_arrived?(tag, responses) do
      {buff, {:ok, responses}}
    else
      case Socket.recv(socket, 0, @recv_timeout) do
        {:ok, data} ->
          buff = buff <> data
          {buff, responses} = case String.contains?(buff, "\r\n") do
            true -> Parser.extract_responses(buff, responses)
            false -> {buff, responses}
          end
          fill_responses(buff, socket, tag, responses)

        {:error, _} = v ->
          {buff, v}
      end
    end

    {buff, result}
  end


  defp tagged_response_arrived?(_tag, []), do: false
  defp tagged_response_arrived?(tag, [resp | _]) do
    !partial?(resp) && String.starts_with?(resp.body, tag)
  end

  defp partial?(%{bytes_left: b}), do: b > 0
end
