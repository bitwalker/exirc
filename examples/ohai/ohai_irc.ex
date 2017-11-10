defmodule OhaiIrc do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    {:ok, client} = ExIRC.start_client!

    children = [
      # Define workers and child supervisors to be supervised
      worker(ConnectionHandler, [client]),
      worker(LoginHandler, [client, ["#ohaibot-testing"]]),
      worker(OhaiHandler, [client])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OhaiIrc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
