# ExIRC

[![Build Status](https://travis-ci.org/bitwalker/exirc.svg?branch=master)](https://travis-ci.org/bitwalker/exirc)
![.github/workflows/tests.yaml](https://github.com/bitwalker/exirc/workflows/.github/workflows/tests.yaml/badge.svg)
[![Hex.pm Version](http://img.shields.io/hexpm/v/exirc.svg?style=flat)](https://hex.pm/packages/exirc)

ExIRC is a IRC client library for Elixir projects. It aims to have a clear, well
documented API, with the minimal amount of code necessary to allow you to connect and
communicate with IRC servers effectively. It aims to implement the full RFC2812 protocol,
and relevant parts of RFC1459.

## Getting Started

Add ExIRC as a dependency to your project in mix.exs, and add it as an application:

```elixir
  defp deps do
    [{:exirc, "~> x.x.x"}]
  end

  defp application do
    [applications: [:exirc],
     ...]
  end
```

Then fetch it using `mix deps.get`.

To use ExIRC, you need to start a new client process, and add event handlers. An example event handler module
is located in `lib/exirc/example_handler.ex`. **The example handler is kept up to date with all events you can
expect to receive from the client**. A simple module is defined below as an example of how you might
use ExIRC in practice. ExampleHandler here is the one that comes bundled with ExIRC.

There is also a variety of examples in `examples`, the most up to date of which is `examples/bot`.

```elixir
defmodule ExampleSupervisor do
    defmodule State do
        defstruct host: "chat.freenode.net",
                  port: 6667,
                  pass: "",
                  nick: "bitwalker",
                  user: "bitwalker",
                  name: "Paul Schoenfelder",
                  client: nil,
                  handlers: []
    end

    def start_link(_) do
        :gen_server.start_link(__MODULE__, [%State{}])
    end

    def init(state) do
        # Start the client and handler processes, the ExIRC supervisor is automatically started when your app runs
        {:ok, client}  = ExIRC.start_link!()
        {:ok, handler} = ExampleHandler.start_link(nil)

        # Register the event handler with ExIRC
        ExIRC.Client.add_handler client, handler

        # Connect and logon to a server, join a channel and send a simple message
        ExIRC.Client.connect!   client, state.host, state.port
        ExIRC.Client.logon      client, state.pass, state.nick, state.user, state.name
        ExIRC.Client.join       client, "#elixir-lang"
        ExIRC.Client.msg        client, :privmsg, "#elixir-lang", "Hello world!"

        {:ok, %{state | :client => client, :handlers => [handler]}}
    end

    def terminate(_, state) do
        # Quit the channel and close the underlying client connection when the process is terminating
        ExIRC.Client.quit state.client, "Goodbye, cruel world."
        ExIRC.Client.stop! state.client
        :ok
    end
end
```

A more robust example usage will wait until connected before it attempts to logon and then wait until logged
on until it attempts to join a channel. Please see the `examples` directory for more in-depth examples cases.

```elixir

defmodule ExampleApplication do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @impl true
  def start(_type, _args) do
    {:ok, client} = ExIRC.start_link!

    children = [
      # Define workers and child supervisors to be supervised
      {ExampleConnectionHandler, client},
      # here's where we specify the channels to join:
      {ExampleLoginHandler, [client, ["#ohaibot-testing"]]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExampleApplication.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule ExampleConnectionHandler do
  defmodule State do
    defstruct host: "chat.freenode.net",
              port: 6667,
              pass: "",
              nick: "bitwalker",
              user: "bitwalker",
              name: "Paul Schoenfelder",
              client: nil
  end

  def start_link(client, state \\ %State{}) do
    GenServer.start_link(__MODULE__, [%{state | client: client}])
  end

  def init([state]) do
    ExIRC.Client.add_handler state.client, self
    ExIRC.Client.connect! state.client, state.host, state.port
    {:ok, state}
  end

  def handle_info({:connected, server, port}, state) do
    debug "Connected to #{server}:#{port}"
    ExIRC.Client.logon state.client, state.pass, state.nick, state.user, state.name
    {:noreply, state}
  end

  # Catch-all for messages you don't care about
  def handle_info(msg, state) do
    debug "Received unknown messsage:"
    IO.inspect msg
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end

defmodule ExampleLoginHandler do
  @moduledoc """
  This is an example event handler that listens for login events and then
  joins the appropriate channels. We actually need this because we can't
  join channels until we've waited for login to complete. We could just
  attempt to sleep until login is complete, but that's just hacky. This
  as an event handler is a far more elegant solution.
  """
  def start_link(client, channels) do
    GenServer.start_link(__MODULE__, [client, channels])
  end

  def init([client, channels]) do
    ExIRC.Client.add_handler client, self
    {:ok, {client, channels}}
  end

  def handle_info(:logged_in, state = {client, channels}) do
    debug "Logged in to server"
    channels |> Enum.map(&ExIRC.Client.join client, &1)
    {:noreply, state}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end
```

## Projects using ExIRC (in the wild!)

Below is a list of projects that we know of (if we've missed anything,
send a PR!) that use ExIRC in the wild.

- [Kuma][kuma] by @ryanwinchester
- [Offension][offension] by @shymega
- [hedwig_irc][hedwig_irc] by @jeffweiss
- [Hekateros][hekateros] by @tchoutri

[kuma]: https://github.com/ryanwinchester/kuma
[offension]: https://github.com/shymega/offension
[hedwig_irc]: https://github.com/jeffweiss/hedwig_irc
[hekateros]: https://github.com/friendshipismagic/hekateros
