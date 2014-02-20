defmodule ExIrc.Client do
  @moduledoc """
  Maintains the state and behaviour for individual IRC client connections
  """
  use    Irc.Commands
  import ExIrc.Logger
  import String, only: [to_char_list!: 1, from_char_list!: 1]

  alias ExIrc.Channels, as: Channels
  alias ExIrc.Utils,    as: Utils

  # Records
  defrecord ClientState,
    event_handlers:   [],
    server:           "localhost",
    port:             6667,
    socket:           nil,
    nick:             "",
    pass:             "",
    user:             "",
    name:             "",
    connected?:       false,
    logged_on?:       false,
    autoping:         true,
    channel_prefixes: "",
    network:          "",
    user_prefixes:    "",
    login_time:       "",
    channels:         [],
    debug?:           false

  defrecord IrcMessage,
    server:  '',
    nick:    '',
    user:    '',
    host:    '',
    ctcp:    nil,
    cmd:     '',
    args:    []

  #################
  # External API
  #################

  @doc """
  Start a new IRC client process

  Returns either {:ok, pid} or {:error, reason}
  """
  @spec start!(options :: list() | nil) :: {:ok, pid} | {:error, term}
  def start!(options \\ []) do
    start_link(options)
  end
  @doc """
  Start a new IRC client process.

  Returns either {:ok, pid} or {:error, reason}
  """
  @spec start!(options :: list() | nil) :: {:ok, pid} | {:error, term}
  def start_link(options \\ []) do
    :gen_server.start_link(__MODULE__, options, [])
  end
  @doc """
  Stop the IRC client process
  """
  @spec stop!(client :: pid) :: {:stop, :normal, :ok, ClientState.t}
  def stop!(client) do
    :gen_server.call(client, :stop)
  end
  @doc """
  Connect to a server with the provided server and port

  Example:
    Client.connect! pid, "localhost", 6667
  """
  @spec connect!(client :: pid, server :: binary, port :: non_neg_integer) :: :ok
  def connect!(client, server, port) do
    :gen_server.call(client, {:connect, server, port}, :infinity)
  end
  @doc """
  Determine if the provided client process has an open connection to a server
  """
  @spec is_connected?(client :: pid) :: true | false
  def is_connected?(client) do
    :gen_server.call(client, :is_connected?)
  end
  @doc """
  Logon to a server

  Example:
    Client.logon pid, "password", "mynick", "username", "My Name"
  """
  @spec logon(client :: pid, pass :: binary, nick :: binary, user :: binary, name :: binary) :: :ok | {:error, :not_connected}
  def logon(client, pass, nick, user, name) do
    :gen_server.call(client, {:logon, pass, nick, user, name}, :infinity)
  end
  @doc """
  Determine if the provided client is logged on to a server
  """
  @spec is_logged_on?(client :: pid) :: true | false
  def is_logged_on?(client) do
    :gen_server.call(client, :is_logged_on?)
  end
  @doc """
  Send a message to a nick or channel
  Message types are:
    :privmsg
    :notice
    :ctcp
  """
  @spec msg(client :: pid, type :: atom, nick :: binary, msg :: binary) :: :ok | {:error, atom}
  def msg(client, type, nick, msg) do
    :gen_server.call(client, {:msg, type, nick, msg}, :infinity)
  end
  @doc """
  Change the client's nick
  """
  @spec nick(client :: pid, new_nick :: binary) :: :ok | {:error, atom}
  def nick(client, new_nick) do
    :gen_server.call(client, {:nick, new_nick}, :infinity)
  end
  @doc """
  Send a raw IRC command
  """
  @spec cmd(client :: pid, raw_cmd :: binary) :: :ok | {:error, atom}
  def cmd(client, raw_cmd) do
    :gen_server.call(client, {:cmd, raw_cmd})
  end
  @doc """
  Join a channel, with an optional password
  """
  @spec join(client :: pid, channel :: binary, key :: binary | nil) :: :ok | {:error, atom}
  def join(client, channel, key \\ "") do
    :gen_server.call(client, {:join, channel, key}, :infinity)
  end
  @doc """
  Leave a channel
  """
  @spec part(client :: pid, channel :: binary) :: :ok | {:error, atom}
  def part(client, channel) do
    :gen_server.call(client, {:part, channel}, :infinity)
  end
  @doc """
  Kick a user from a channel
  """
  @spec kick(client :: pid, channel :: binary, nick :: binary, message :: binary | nil) :: :ok | {:error, atom}
  def kick(client, channel, nick, message \\ "") do
    :gen_server.call(client, {:kick, channel, nick, message}, :infinity)
  end
  @doc """
  Quit the server, with an optional part message
  """
  @spec quit(client :: pid, msg :: binary | nil) :: :ok | {:error, atom}
  def quit(client, msg \\ "Leaving..") do
    :gen_server.call(client, {:quit, msg}, :infinity)
  end
  @doc """
  Get details about each of the client's currently joined channels
  """
  @spec channels(client :: pid) :: list(binary) | [] | {:error, atom}
  def channels(client) do
    :gen_server.call(client, :channels)
  end
  @doc """
  Get a list of users in the provided channel
  """
  @spec channel_users(client :: pid, channel :: binary) :: list(binary) | [] | {:error, atom}
  def channel_users(client, channel) do
    :gen_server.call(client, {:channel_users, channel})
  end
  @doc """
  Get the topic of the provided channel
  """
  @spec channel_topic(client :: pid, channel :: binary) :: binary | {:error, atom}
  def channel_topic(client, channel) do
    :gen_server.call(client, {:channel_topic, channel})
  end
  @doc """
  Get the channel type of the provided channel
  """
  @spec channel_type(client :: pid, channel :: binary) :: atom | {:error, atom}
  def channel_type(client, channel) do
    :gen_server.call(client, {:channel_type, channel})
  end
  @doc """
  Determine if a nick is present in the provided channel
  """
  @spec channel_has_user?(client :: pid, channel :: binary, nick :: binary) :: true | false | {:error, atom}
  def channel_has_user?(client, channel, nick) do
    :gen_server.call(client, {:channel_has_user?, channel, nick})
  end
  @doc """
  Add a new event handler process
  """
  @spec add_handler(client :: pid, pid) :: :ok
  def add_handler(client, pid) do
    :gen_server.call(client, {:add_handler, pid})
  end
  @doc """
  Add a new event handler process, asynchronously
  """
  @spec add_handler_async(client :: pid, pid) :: :ok
  def add_handler_async(client, pid) do
    :gen_server.cast(client, {:add_handler, pid})
  end
  @doc """
  Remove an event handler process
  """
  @spec remove_handler(client :: pid, pid) :: :ok
  def remove_handler(client, pid) do
    :gen_server.call(client, {:remove_handler, pid})
  end
  @doc """
  Remove an event handler process, asynchronously
  """
  @spec remove_handler_async(client :: pid, pid) :: :ok
  def remove_handler_async(client, pid) do
    :gen_server.cast(client, {:remove_handler, pid})
  end
  @doc """
  Get the current state of the provided client
  """
  @spec state(client :: pid) :: [{atom, any}]
  def state(client) do
    state = :gen_server.call(client, :state)
    [server:            state.server,
     port:              state.port,
     nick:              state.nick,
     pass:              state.pass,
     user:              state.user,
     name:              state.name,
     autoping:          state.autoping,
     connected?:        state.connected?,
     logged_on?:        state.logged_on?,
     channel_prefixes:  state.channel_prefixes,
     user_prefixes:     state.user_prefixes,
     channels:          Channels.to_proplist(state.channels),
     network:           state.network,
     login_time:        state.login_time,
     debug?:            state.debug?,
     event_handlers:    state.event_handlers]
  end

  ###############
  # GenServer API
  ###############

  @doc """
  Called when :gen_server initializes the client
  """
  @spec init(list(any) | []) :: {:ok, ClientState.t}
  def init(options \\ []) do
    autoping = Keyword.get(options, :autoping, true)
    debug    = Keyword.get(options, :debug, false)
    # Add event handlers
    handlers = 
      Keyword.get(options, :event_handlers, []) 
      |> List.foldl([], &do_add_handler/2)
    # Return initial state
    {:ok, ClientState[
      event_handlers: handlers,
      autoping:       autoping,
      logged_on?:     false,
      debug?:         debug,
      channels:       ExIrc.Channels.init()]}
  end
  @doc """
  Handle calls from the external API. It is not recommended to call these directly.
  """
  # Handle call to get the current state of the client process
  def handle_call(:state, _from, state), do: {:reply, state, state}
  # Handle call to stop the current client process
  def handle_call(:stop, _from, state) do
    # Ensure the socket connection is closed if stop is called while still connected to the server
    if state.connected?, do: :gen_tcp.close(state.socket)
    {:stop, :normal, :ok, state.connected?(false).logged_on?(false).socket(nil)}
  end
  # Handles call to add a new event handler process
  def handle_call({:add_handler, pid}, _from, state) do
    handlers = do_add_handler(pid, state.event_handlers)
    {:reply, :ok, state.event_handlers(handlers)}
  end
  # Handles call to remove an event handler process
  def handle_call({:remove_handler, pid}, _from, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:reply, :ok, state.event_handlers(handlers)}
  end
  # Handle call to connect to an IRC server
  def handle_call({:connect, server, port}, _from, state) do
    # If there is an open connection already, close it.
    if state.socket != nil, do: :gen_tcp.close(state.socket)
    # Open a new connection
    case :gen_tcp.connect(to_char_list!(server), port, [:list, {:packet, :line}, {:keepalive, true}]) do
      {:ok, socket} ->
        send_event {:connect, server, port}, state
        {:reply, :ok, state.connected?(true).server(server).port(port).socket(socket)}
      error ->
        {:reply, error, state}
    end
  end
  # Handle call to determine if the client is connected
  def handle_call(:is_connected?, _from, state), do: {:reply, state.connected?, state}
  # Prevents any of the following messages from being handled if the client is not connected to a server.
  # Instead, it returns {:error, :not_connected}.
  def handle_call(_, _from, ClientState[connected?: false] = state), do: {:reply, {:error, :not_connected}, state}
  # Handle call to login to the connected IRC server
  def handle_call({:logon, pass, nick, user, name}, _from, ClientState[logged_on?: false] = state) do
    send! state.socket, pass!(pass)
    send! state.socket, nick!(nick)
    send! state.socket, user!(user, name)
    {:reply, :ok, state.pass(pass).nick(nick).user(user).name(name)}
  end
  # Handle call to determine if client is logged on to a server
  def handle_call(:is_logged_on?, _from, state), do: {:reply, state.logged_on?, state}
  # Prevents any of the following messages from being handled if the client is not logged on to a server.
  # Instead, it returns {:error, :not_logged_in}.
  def handle_call(_, _from, ClientState[logged_on?: false] = state), do: {:reply, {:error, :not_logged_in}, state}
  # Handles call to send a message
  def handle_call({:msg, type, nick, msg}, _from, state) do
    data = case type do
      :privmsg -> privmsg!(nick, msg)
      :notice  -> notice!(nick, msg)
      :ctcp    -> notice!(nick, ctcp!(msg))
    end
    send! state.socket, data
    {:reply, :ok, state}
  end
  # Handles call to join a channel
  def handle_call({:join, channel, key}, _from, state)      do send!(state.socket, join!(channel, key)); {:reply, :ok, state} end
  # Handles a call to leave a channel
  def handle_call({:part, channel}, _from, state)           do send!(state.socket, part!(channel)); {:reply, :ok, state} end
  # Handles a call to kick a client
  def handle_call({:kick, channel, nick, message}, _from, state) do
    send!(state.socket, kick!(channel, nick, message))
    {:reply, :ok, state}
  end
  # Handle call to quit the server and close the socket connection
  def handle_call({:quit, msg}, _from, state) do
    if state.connected? do
      send! state.socket, quit!(msg)
      send_event :disconnected, state
      :gen_tcp.close state.socket
    end
    {:reply, :ok, state.connected?(false).logged_on?(false).socket(nil)}
  end
  # Handles call to change the client's nick
  def handle_call({:nick, new_nick}, _from, state) do send!(state.socket, nick!(new_nick)); {:reply, :ok, state} end
  # Handles call to send a raw command to the IRC server
  def handle_call({:cmd, raw_cmd}, _from, state) do send!(state.socket, command!(raw_cmd)); {:reply, :ok, state} end
  # Handles call to return the client's channel data
  def handle_call(:channels, _from, state), do: {:reply, Channels.channels(state.channels), state}
  # Handles call to return a list of users for a given channel
  def handle_call({:channel_users, channel}, _from, state), do: {:reply, Channels.channel_users(state.channels, channel), state}
  # Handles call to return the given channel's topic
  def handle_call({:channel_topic, channel}, _from, state), do: {:reply, Channels.channel_topic(state.channels, channel), state}
  # Handles call to return the type of the given channel
  def handle_call({:channel_type, channel}, _from, state), do: {:reply, Channels.channel_type(state.channels, channel), state}
  # Handles call to determine if a nick is present in the given channel
  def handle_call({:channel_has_user?, channel, nick}, _from, state) do
    {:reply, Channels.channel_has_user?(state.channels, channel, nick), state}
  end
  # Handles message to add a new event handler process asynchronously
  def handle_cast({:add_handler, pid}, state) do
    handlers = do_add_handler(pid, state.event_handlers)
    {:noreply, state.event_handlers(handlers)}
  end
  @doc """
  Handles asynchronous messages from the external API. Not recommended to call these directly.
  """
  # Handles message to remove an event handler process asynchronously
  def handle_cast({:remove_handler, pid}, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:noreply, state.event_handlers(handlers)}
  end
  @doc """
  Handle messages from the TCP socket connection.
  """
  # Handles the client's socket connection 'closed' event
  def handle_info({:tcp_closed, _socket}, ClientState[server: server, port: port] = state) do
    info "Connection to #{server}:#{port} closed!"
    send_event :disconnected, state
    {:noreply, state.socket(nil).connected?(false).logged_on?(false).channels(Channels.init())}
  end
  # Handles any TCP errors in the client's socket connection
  def handle_info({:tcp_error, socket, reason}, ClientState[server: server, port: port] = state) do
    error "TCP error in connection to #{server}:#{port}:\r\n#{reason}\r\nClient connection closed."
    {:stop, {:tcp_error, socket}, state.socket(nil).connected?(false).logged_on?(false).channels(Channels.init())}
  end
  # General handler for messages from the IRC server
  def handle_info({:tcp, _, data}, state) do
    debug? = state.debug?
    case Utils.parse(data) do
      IrcMessage[ctcp: true] = msg ->
        send_event msg, state
        {:noreply, state}
      IrcMessage[ctcp: false] = msg ->
        send_event msg, state
        handle_data msg, state
      IrcMessage[ctcp: :invalid] = msg when debug? ->
        send_event msg, state
        {:noreply, state}
      _ ->
        {:noreply, state}
    end
  end
  # If an event handler process dies, remove it from the list of event handlers
  def handle_info({'DOWN', _, _, pid, _}, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:noreply, state.event_handlers(handlers)}
  end
  # Catch-all for unrecognized messages (do nothing)
  def handle_info(_, state) do
    {:noreply, state}
  end
  @doc """
  Handle termination
  """
  def terminate(_reason, state) do
    if state.socket != nil do
      :gen_tcp.close state.socket
      state.socket(nil)
    end
    :ok
  end
  @doc """
  Transform state for hot upgrades/downgrades
  """
  def code_change(_old, state, _extra), do: {:ok, state}

  ################
  # Data handling
  ################

  @doc """
  Handle IrcMessages received from the server.
  """
  # Called upon successful login
  def handle_data(IrcMessage[cmd: @rpl_welcome] = _msg, ClientState[logged_on?: false] = state) do
    if state.debug?, do: debug "SUCCESFULLY LOGGED ON"
    new_state = state.logged_on?(true).login_time(:erlang.now())
    send_event :login, new_state
    {:noreply, new_state}
  end
  # Called when the server sends it's current capabilities
  def handle_data(IrcMessage[cmd: @rpl_isupport] = msg, state) do
    if state.debug?, do: debug "RECEIVING SERVER CAPABILITIES"
    {:noreply, Utils.isup(msg.args, state)}
  end
  # Called when the client enters a channel
  def handle_data(IrcMessage[nick: nick, cmd: "JOIN"] = msg, ClientState[nick: nick] = state) do
    channel = msg.args |> List.first
    if state.debug?, do: debug "JOINED A CHANNEL #{channel}"
    channels  = Channels.join(state.channels, channel)
    new_state = state.channels(channels)
    send_event {:joined, channel}, new_state
    {:noreply, state.channels(channels)}
  end
  # Called when another user joins a channel the client is in
  def handle_data(IrcMessage[nick: user_nick, cmd: "JOIN"] = msg, state) do
    channel = msg.args |> List.first
    if state.debug?, do: debug "ANOTHER USER JOINED A CHANNEL: #{channel} - #{user_nick}"
    channels  = Channels.user_join(state.channels, channel, user_nick)
    new_state = state.channels(channels)
    send_event {:joined, channel, user_nick}, new_state
    {:noreply, state.channels(channels)}
  end
  # Called on joining a channel, to tell us the channel topic
  # Message with three arguments is not RFC compliant but very common
  # Message with two arguments is RFC compliant
  def handle_data(IrcMessage[cmd: @rpl_topic] = msg, state) do
    if state.debug?, do: debug "INITIAL TOPIC MSG"
    {channel, topic} = case msg.args do
      [_nick, channel, topic] -> debug("1. TOPIC SET FOR #{channel} TO #{topic}"); {channel, topic}
      [channel, topic]        -> debug("2. TOPIC SET FOR #{channel} TO #{topic}"); {channel, topic}
    end
    channels  = Channels.set_topic(state.channels, channel, topic)
    new_state = state.channels(channels)
    send_event {:topic, channel, topic}, new_state
    {:noreply, new_state}
  end
  # Called when the topic changes while we're in the channel
  def handle_data(IrcMessage[cmd: "TOPIC", args: [channel, topic]], state) do
    if state.debug?, do: debug "TOPIC CHANGED FOR #{channel} TO #{topic}"
    channels  = Channels.set_topic(state.channels, channel, topic)
    new_state = state.channels(channels)
    send_event {:topic, channel, topic}, new_state
    {:noreply, state.channels(channels)}
  end
  # Called when joining a channel with the list of current users in that channel, or when the NAMES command is sent
  def handle_data(IrcMessage[cmd: @rpl_namereply] = msg, state) do
    if state.debug?, do: debug "NAMES LIST RECEIVED"
    {_nick, channel_type, channel, names} = case msg.args do
      [nick, channel_type, channel, names]  -> {nick, channel_type, channel, names}
      [channel_type, channel, names]        -> {nil, channel_type, channel, names}
    end
    channels = Channels.set_type(
      Channels.users_join(state.channels, channel, String.split(names, " ", trim: true)),
      channel,
      channel_type)
    {:noreply, state.channels(channels)}
  end
  # Called when our nick has succesfully changed
  def handle_data(IrcMessage[cmd: "NICK", nick: nick, args: [new_nick]], ClientState[nick: nick] = state) do
    if state.debug?, do: debug "NICK CHANGED FROM #{nick} TO #{new_nick}"
    new_state = state.nick(new_nick)
    send_event {:nick, new_nick}, new_state
    {:noreply, new_state}
  end
  # Called when someone visible to us changes their nick
  def handle_data(IrcMessage[cmd: "NICK", nick: nick, args: [new_nick]], state) do
    if state.debug?, do: debug "#{nick} CHANGED THEIR NICK TO #{new_nick}"
    channels  = Channels.user_rename(state.channels, nick, new_nick)
    new_state = state.channels(channels)
    send_event {:nick, nick, new_nick}, new_state
    {:noreply, new_state}
  end
  # Called when we leave a channel
  def handle_data(IrcMessage[cmd: "PART", nick: nick] = msg, ClientState[nick: nick] = state) do
    channel = msg.args |> List.first
    if state.debug?, do: debug "WE LEFT A CHANNEL: #{channel}"
    channels  = Channels.part(state.channels, channel)
    new_state = state.channels(channels)
    send_event {:part, channel}, new_state
    {:noreply, new_state}
  end
  # Called when someone else in our channel leaves
  def handle_data(IrcMessage[cmd: "PART", nick: user_nick] = msg, state) do
    channel = msg.args |> List.first
    if state.debug?, do: debug "#{user_nick} LEFT A CHANNEL: #{channel}"
    channels  = Channels.user_part(state.channels, channel, user_nick)
    new_state = state.channels(channels)
    send_event {:part, channel, user_nick}, new_state
    {:noreply, new_state}
  end
  # Called when we receive a PING
  def handle_data(IrcMessage[cmd: "PING"] = msg, ClientState[autoping: true] = state) do
    if state.debug?, do: debug "RECEIVED A PING!"
    case msg do
      IrcMessage[args: [from]] -> debug("SENT PONG2"); send!(state.socket, pong2!(state.nick, from))
                             _ -> debug("SENT PONG1"); send!(state.socket, pong1!(state.nick))
    end
    {:noreply, state};
  end
  # Called any time we receive an unrecognized message
  def handle_data(msg, state) do
    if state.debug? do debug "UNRECOGNIZED MSG: #{msg.cmd}"; IO.inspect(msg) end
    {:noreply, state}
  end

  ###############
  # Internal API
  ###############
  defp send_event(msg, ClientState[event_handlers: handlers]) when is_list(handlers) do
    Enum.each(handlers, fn({pid, _}) -> Kernel.send(pid, msg) end)
  end

  defp do_add_handler(pid, handlers) do
    case Process.alive?(pid) and not Enum.member?(handlers, pid) do
      true ->
        ref = Process.monitor(pid)
        [{pid, ref} | handlers]
      false ->
        handlers
    end
  end

  defp do_remove_handler(pid, handlers) do
    case List.keyfind(handlers, pid, 0) do
      {pid, ref} ->
        Process.demonitor(ref)
        List.keydelete(handlers, pid, 0)
      nil ->
          handlers
    end
  end

  defp debug(msg) do
    IO.puts(IO.ANSI.green() <> msg <> IO.ANSI.reset())
  end

end