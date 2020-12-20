defmodule Eximap.Mixfile do
  use Mix.Project

  @version "0.1.1-dev"

  def project do
    [
      app: :eximap,
      version: @version,
      elixir: "~> 1.7",
      package: package(),
      deps: deps(),
      description: "A simple library to interact with an IMAP server",
      name: "Eximap",
      source_url: "https://github.com/sgessa/eximap",
      homepage_url: "https://github.com/sgessa/eximap",
      docs: docs()
    ]
  end

  defp package do
    [
      name: "eximap",
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Stefano Gessa <stefano@gessa.net>"],
      licenses: ["BSD"],
      links: %{"GitHub" => "https://github.com/sgessa/eximap"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ssl]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.16", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      # The main page in the docs
      main: "readme",
      extras: ["README.md", "DEVELOPER.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md"]
    ]
  end
end
