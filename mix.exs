defmodule ExIrc.Mixfile do
  use Mix.Project

  def project do
    [ app: :exirc,
      version: "0.10.0",
      elixir: "~> 1.0",
      description: "An IRC client library for Elixir.",
      package: package,
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [mod: {ExIrc.App, []}]
  end

  defp package do
    [ files: ["lib", "mix.exs", "README.md", "LICENSE"],
      contributors: ["Paul Schoenfelder"],
      licenses: ["MIT"],
      links: %{ "GitHub" => "https://github.com/bitwalker/exirc",
                "Home Page" => "http://bitwalker.org/exirc"} ]
  end

  defp deps do
    [{:ex_doc, "~> 0.5", only: :dev}]
  end

end
