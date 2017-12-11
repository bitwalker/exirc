defmodule ExIrc.Mixfile do
  use Mix.Project

  def project do
    [app: :exirc,
      version: "1.0.1",
      elixir: "~> 1.3",
      description: "An IRC client library for Elixir.",
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.html": :test, "coveralls.post": :test],
      deps: deps()]
  end

  # Configuration for the OTP application
  def application do
    [mod: {ExIrc.App, []},
     applications: [:ssl, :crypto, :inets]]
  end

  defp package do
    [ files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Paul Schoenfelder"],
      licenses: ["MIT"],
      links: %{ "GitHub" => "https://github.com/bitwalker/exirc",
                "Home Page" => "http://bitwalker.org/exirc"} ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.14", only: :dev},
      {:excoveralls, "~> 0.5", only: :test},
    ]
  end

end
