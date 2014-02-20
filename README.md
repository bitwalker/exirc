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

[![wercker status](https://app.wercker.com/status/236e4911da7c4575c49b1b20b9ec775d/m/ "wercker status")](https://app.wercker.com/project/bykey/236e4911da7c4575c49b1b20b9ec775d)

Alpha. The API is complete and everything is implemented, but little testing has been done (I've tested the API against my own local IRC server, but nothing robust enough to call this production ready). Any bugs you find, please report them in the issue tracker and I'll address them as soon as possible. If you have any questions, or if the documentation seems incomplete, let me know and I'll fill it in.

## Getting Started

If you use expm, the ExIrc package is available
[here](http://expm.co/exirc).

Add ExIrc as a dependency to your project in mix.exs, and add it as an application:

```elixir
  defp deps do
    [{:exirc, github: "bitwalker/exirc"}]
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
    defrecord State, 
        host: "chat.freenode.net",
        port: 6667,
        pass: "",
        nick: "bitwalker",
        user: "bitwalker",
        name: "Paul Schoenfelder",
        client: nil,
        handlers: []

    def start_link(_) do
        :gen_server.start_link(__MODULE__, [State.new()])
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

        {:ok, state.client(client).handlers([handler])}
    end

    def terminate(_, state) do
        # Quit the channel and close the underlying client connection when the process is terminating
        ExIrc.Client.quit state.client, "Goodbye, cruel world."
        ExIrc.Client.stop! state.client
        :ok
    end
end
```
