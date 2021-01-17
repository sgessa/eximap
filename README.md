# Eximap

Elixir IMAP Client

## Motivation

Currently there is no Elixir IMAP client library actively maintained.
This project is a fork of [khodzha/eximap](https://github.com/khodzha/eximap)

## Roadmap

Completed:
- open a TLS connection to an IMAP server
- login using an email account and password (PLAIN AUTH over TLS)
- Execute commands and return the result

Under development:
- Handle binary responses

Planned:
- Handle requests and responses asyncronously

## Development

In order to test and develop the library locally you will need an IMAP server.
One easy way of getting an IMAP server up and running is with Docker.

Make sure you have Docker installed and that the following ports are open and then run this command:
```sh
docker run -d -p 25:25 -p 80:80 -p 443:443 -p 110:110 -p 143:143 -p 465:465 -p 587:587 -p 993:993 -p 995:995 -v /etc/localtime:/etc/localtime:ro -t analogic/poste.io
curl --insecure --request POST --url https://localhost/admin/install/server --form install[hostname]=127.0.0.1 --form install[superAdmin]=admin@127.0.0.1 --form install[superAdminPassword]=admin
```

Once the container is up and running you can create a new email address.
The credentials used in testing this library are:
Host: localhost.dev
Port: 993
User: admin@localhost.dev
Pass: secret

You can run the tests using:
```
mix deps.get
mix test
```

## Usage

Start the connection to the server by calling the start_link method and execute commands.

```bash
iex> opts = %{account: email, password: pass, host: host, port: port}
iex> {:ok, pid} = Eximap.Imap.Client.start_link(opts)
iex> req = Eximap.Imap.Request.noop()
iex> Eximap.Imap.Client.execute(pid, req) |> Map.from_struct()
%{body: [%{}], error: nil,
         message: "NOOP completed (0.000 + 0.000 secs).", partial: false,
         request: %Eximap.Imap.Request{command: "NOOP", params: [],
          tag: "EX1"}, status: "OK"}
```

## Installation

Soon on Hex.pm, meanwhile:

```elixir
def deps do
  [
    {:eximap, github: "sgessa/eximap"}
  ]
end
```