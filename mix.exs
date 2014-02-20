defmodule ExIrc.Mixfile do
  use Mix.Project

  def project do
    [ app: :exirc,
      version: "0.2.2",
      name: "ExIrc",
      source_url: "https://github.com/bitwalker/exirc",
      homepage_url: "http://bitwalker.github.io/exirc",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [mod: {ExIrc.App, []}]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, git: "https://github.com/elixir-lang/foobar.git", tag: "0.1" }
  #
  # To specify particular versions, regardless of the tag, do:
  # { :barbat, "~> 0.1", github: "elixir-lang/barbat.git" }
  defp deps do
    []
  end
end
