defmodule ExIrc.Mixfile do
  use Mix.Project

  def project do
    [ app: :exirc,
      version: "0.10.0",
      elixir: "~> 1.0.0",
      description: "An IRC client library for Elixir.",
      package: package,
      deps: [] ]
  end

  def application do
    [mod: {ExIrc.App, []},
     applications: [:logger]]
  end

  defp package do
    [ files: ["lib", "mix.exs", "README.md", "LICENSE"],
      contributors: ["Paul Schoenfelder"],
      description: "An IRC client library for Elixir.",
      licenses: ["MIT"],
      links: %{ "GitHub" => "https://github.com/bitwalker/exirc"} ]
  end

end
