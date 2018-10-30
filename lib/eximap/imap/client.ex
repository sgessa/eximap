defmodule Eximap.Imap.Client do
  use GenServer
  alias Eximap.Imap.Request
  alias Eximap.Imap.Response
  alias Eximap.Imap.BufferParser, as: Parser
  alias Eximap.Socket

  @moduledoc """
  Imap Client GenServer
  """

  @initial_state %{
    socket: nil,
    tag_number: 1,
    buff: "",
    responses: [],
    tagged_calls: %{}
  }
  @tag_prefix "EX"

  def start_link(host, port, account, pass) do
    host = host |> to_charlist
    GenServer.start_link(__MODULE__, %{host: host, port: port, account: account, pass: pass})
  end

  def execute(pid, req) do
    GenServer.call(pid, {:command, req})
  end

  def handle_call(
        {:command, %Request{} = req},
        from,
        %{socket: socket, tag_number: tag_number, tagged_calls: tagged_calls} = state
      ) do
    tag = "#{@tag_prefix}#{tag_number}"
    req = %Request{req | tag: tag}
    imap_send(socket, req)

    tagged_calls = Map.put(tagged_calls, tag, %{from: from, request: req})
    {:noreply, %{state | tag_number: tag_number + 1, tagged_calls: tagged_calls}}
  end

  def init(%{host: host, port: port, account: account, pass: pass} = params) do
    opts = build_opts(host)

    state = Map.merge(@initial_state, params)
    {:ok, socket} = Socket.connect(true, host, port, opts)
    imap_send(socket, Request.login(account, pass))

    {:ok, %{state | socket: socket}}
  end

  defp build_opts('imap.yandex.ru'), do: [:binary, active: true, ciphers: ['AES256-GCM-SHA384']]
  defp build_opts(_), do: [:binary, active: true]

  def handle_info({:ssl, _socket, data}, %{buff: buff} = state) do
    buff = buff <> data
    send(self(), {:buff_update})
    {:noreply, %{state | buff: buff}}
  end

  def handle_info({:ssl_closed, _socket}, state) do
    IO.inspect("########## SSL SOCKET CLOSED")
    {:noreply, state}
  end

  def handle_info({:ssl_error, _socket, reason}, state) do
    IO.inspect("########## SSL SOCKET ERROR: #{inspect(reason)}")
    {:noreply, state}
  end

  def handle_info({:buff_update}, %{buff: ""} = state) do
    {:noreply, state}
  end

  def handle_info(
        {:buff_update},
        %{buff: buff, responses: responses} = state
      ) do
    resp = current_response(responses)

    {buff, resp} = Parser.extract_response(buff, resp)

    responses =
      if partial?(resp) do
        [resp | tl(responses)]
      else
        [resp | responses]
      end

    send(self(), {:buff_update})

    if tagged_response_arrived?(resp) do
      send(self(), {:new_tagged_response})
    end

    {:noreply, %{state | buff: buff, responses: responses}}
  end

  def handle_info(
        {:new_tagged_response},
        %{responses: responses, tagged_calls: tagged_calls} = state
      ) do
    result =
      responses
      |> parse_response()
      |> find_response_caller(tagged_calls)

    case result do
      {:ok, {from, response}} -> GenServer.reply(from, response)
      {:error, _reason} -> nil
    end

    {:noreply, %{state | responses: []}}
  end

  def handle_info(resp, state) do
    IO.inspect("Unhandled info: #{inspect(resp)}")
    {:noreply, state}
  end

  defp imap_send(socket, %Request{tag: nil, command: "LOGIN"} = req) do
    req = %Request{req | tag: "#{@tag_prefix}_LGN"}
    message = Request.raw(req)
    imap_send_raw(socket, message)
  end

  defp imap_send(socket, %Request{} = req) do
    message = Request.raw(req)
    imap_send_raw(socket, message)
  end

  defp imap_send_raw(socket, msg) do
    Socket.send(socket, msg)
  end

  defp parse_response(responses) do
    responses
    |> Enum.map(fn %{body: b} -> b end)
    |> Response.build()
  end

  defp find_response_caller(response, tagged_calls) do
    case Map.fetch(tagged_calls, response.tag) do
      {:ok, %{from: from}} -> {:ok, {from, response}}
      :error -> {:error, :no_call_found}
    end
  end

  defp partial?(%{bytes_left: b}), do: b > 0

  defp current_response([]), do: %{body: "", bytes_left: 0}

  defp current_response([resp | _]) do
    case partial?(resp) do
      true -> resp
      false -> %{body: "", bytes_left: 0}
    end
  end

  defp tagged_response_arrived?(resp) do
    !partial?(resp) && String.starts_with?(resp.body, @tag_prefix)
  end
end
