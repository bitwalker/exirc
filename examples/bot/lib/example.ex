defmodule Example do
  use Application

  alias Example.Bot

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @impl true
  def start(_type, _args) do
    children =
      Application.get_env(:exirc_example, :bots)
      |> Enum.map(fn bot -> worker(Bot, [bot]) end)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
