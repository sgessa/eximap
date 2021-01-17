use Mix.Config

config :eximap,
  account: "admin@127.0.0.1",
  password: "admin",
  use_ssl: true,
  incoming_mail_server: "localhost",
  # TLS
  incoming_port: 993,
  #  incoming_port: 143,

  # unused for IMAP
  outgoing_mail_server: "127.0.0.1",
  outgoing_port: 465

config :eximap, :parser_enabled, false
