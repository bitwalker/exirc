# ExIrc

ExIrc is a IRC client library for Elixir projects. It aims to have a clear, well
documented API, with the minimal amount of code necessary to allow you to connect and
communicate with IRC servers effectively. It aims to implement the full RFC2812 protocol,
and relevant parts of RFC1459.

## Why?

I had need of this in another project of mine, and found that there were no good libraries available, 
documentation was always missing, it wasn't clear how to use, and in general were not easy to work
with.

## Status

[![Build Status](https://travis-ci.org/bitwalker/exirc.svg?branch=master)](https://travis-ci.org/bitwalker/exirc)

Alpha. The API is complete and everything is implemented, but little testing has been done (I've tested the API against my own local IRC server, but nothing robust enough to call this production ready). Any bugs you find, please report them in the issue tracker and I'll address them as soon as possible. If you have any questions, or if the documentation seems incomplete, let me know and I'll fill it in.

## Getting Started

Add ExIrc as a dependency to your project in mix.exs, and add it as an application:

```elixir
  defp deps do
    [{:exirc, "~> 0.9.1"}]
  end

  defp application do
    [applications: [:exirc],
     ...]
  end
```

Then fetch it using `mix deps.get`.

To use ExIrc, you need to start a new client process, and add event handlers. An example event handler module
is located in `lib/exirc/example_handler.ex`. **The example handler is kept up to date with all events you can
expect to receive from the client**. A simple module is defined below as an example of how you might
use ExIrc in practice. ExampleHandler here is the one that comes bundled with ExIrc.

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
        # Start the client and handler processes, the ExIrc supervisor is automatically started when your app runs
        {:ok, client}  = ExIrc.start_client!()
        {:ok, handler} = ExampleHandler.start_link(nil)

        # Register the event handler with ExIrc
        ExIrc.Client.add_handler client, handler

        # Connect and logon to a server, join a channel and send a simple message
        ExIrc.Client.connect!   client, state.host, state.port
        ExIrc.Client.logon      client, state.pass, state.nick, state.user, state.name
        ExIrc.Client.join       client, "#elixir-lang"
        ExIrc.Client.msg        client, :privmsg, "#elixir-lang", "Hello world!"

        {:ok, %{state | :client => client, :handlers => [handler]}}
    end

    def terminate(_, state) do
        # Quit the channel and close the underlying client connection when the process is terminating
        ExIrc.Client.quit state.client, "Goodbye, cruel world."
        ExIrc.Client.stop! state.client
        :ok
    end
end
```

A more robust example usage will wait until connected before it attempts to logon and then wait until logged
on until it attempts to join a channel. Please see the `examples` directory for more in-depth examples cases.

```elixir

defmodule ExampleApplication do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    {:ok, client} = ExIrc.start_client!

    children = [
      # Define workers and child supervisors to be supervised
      worker(ExampleConnectionHandler, [client]),
      # here's where we specify the channels to join:
      worker(ExampleLoginHandler, [client, ["#ohaibot-testing"]])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
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
    ExIrc.Client.add_handler state.client, self
    ExIrc.Client.connect! state.client, state.host, state.port
    {:ok, state}
  end

  def handle_info({:connected, server, port}, state) do
    debug "Connected to #{server}:#{port}"
    ExIrc.Client.logon state.client, state.pass, state.nick, state.user, state.name
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
    ExIrc.Client.add_handler client, self
    {:ok, {client, channels}}
  end

  def handle_info(:logged_in, state = {client, channels}) do
    debug "Logged in to server"
    channels |> Enum.map(&ExIrc.Client.join client, &1)
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
