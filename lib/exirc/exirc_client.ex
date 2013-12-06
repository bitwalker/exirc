defmodule ExIrc.Client do
  use GenServer.Behaviour
  import Logger

  # Maintains client state
  defrecord ClientState, events: nil, socket: nil
  # Defines the connection to an IRC server
  defrecord IrcConnection, host: 'localhost', port: 6667, password: ''

  #####################
  # Public API
  #####################

  @doc """
  Add a new event handler (i.e bot) to a client
  """
  def add_handler(client, handler, args // []) do
    :gen_server.cast(client, {:add_handler, handler, args})
  end

  @doc """
  Connect a client to the provided IRC server
  """
  def connect!(client, connection) do
    :gen_server.cast client, {:connect, connection}
  end

  @doc """
  Disconnect a client
  """
  def disconnect!(client) do
    :gen_server.cast client, :disconnect
  end

  @doc """
  Send an event to a client's event handlers
  """
  def notify!(pid, event) do
    :gen_server.cast pid, {:notify, event}
  end

  #####################
  # GenServer API
  #####################

  def start_link() do
    :gen_server.start_link(__MODULE__, nil, [])
  end

  def init(_) do
    # Start the event handler
    {:ok, events} = :gen_event.start_link()
    {:ok, ClientState.new([events: events])}
  end

  @doc """
  Handles connecting the client to the provided IRC server
  """
  def handle_cast({:connect, connection}, state) do
    {:noreply, state}
  end

  @doc """
  Handles adding a new event handler (i.e bot) to the client
  """
  def handle_cast({:add_handler, handler, args}, state) do
    :gen_event.add_sup_handler(state.events, handler, args)
    {:noreply, state}
  end

  @doc """
  Handles event notifications
  """
  def handle_cast({:notify, event}, state) do
    :gen_event.notify(state.events, event)
    {:noreply, state}
  end

  @doc """
  Handles event handler termination. Specifically, it restarts handlers which have crashed.
  """
  def handle_info({:gen_event_EXIT, handler, reason}, state) do
    case reason do
      :normal          -> {:noreply, state.events}
      :shutdown        -> {:noreply, state.events}
      {:swapped, _, _} -> {:noreply, state.events}
      _ ->
        :gen_server.cast(self, {:add_handler, handler, []})
        warning "Handler #{atom_to_binary(handler)} crashed. Restarting..."
        {:noreply, state}
    end
  end
end