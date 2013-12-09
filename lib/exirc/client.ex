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
    debug:            false

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
  def start!(options // []) do
    start_link(options)
  end
  @doc """
  Start a new IRC client process.

  Returns either {:ok, pid} or {:error, reason}
  """
  @spec start!(options :: list() | nil) :: {:ok, pid} | {:error, term}
  def start_link(options // []) do
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
  def connect!(client, server, port) do
    :gen_server.call(client, {:connect, server, port}, :infinity)
  end
  @doc """
  Determine if the provided client process has an open connection to a server
  """
  def is_connected?(client) do
    :gen_server.call(client, :is_connected?)
  end
  @doc """
  Logon to a server

  Example:
    Client.logon pid, "password", "mynick", "username", "My Name"
  """
  def logon(client, pass, nick, user, name) do
    :gen_server.call(client, {:logon, pass, nick, user, name}, :infinity)
  end
  @doc """
  Determine if the provided client is logged on to a server
  """
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
  def msg(client, type, nick, msg) do
    :gen_server.call(client, {:msg, type, nick, msg}, :infinity)
  end
  @doc """
  Change the client's nick
  """
  def nick(client, new_nick) do
    :gen_server.call(client, {:nick, new_nick}, :infinity)
  end
  @doc """
  Send a raw IRC command
  """
  def cmd(client, raw_cmd) do
    :gen_server.call(client, {:cmd, raw_cmd})
  end
  @doc """
  Join a channel, with an optional password
  """
  def join(client, channel, key // "") do
    :gen_server.call(client, {:join, channel, key}, :infinity)
  end
  @doc """
  Leave a channel
  """
  def part(client, channel) do
    :gen_server.call(client, {:part, channel}, :infinity)
  end
  @doc """
  Quit the server, with an optional part message
  """
  def quit(client, msg // 'Leaving..') do
    :gen_server.call(client, {:quit, msg}, :infinity)
  end
  @doc """
  Get details about each of the client's currently joined channels
  """
  def channels(client) do
    :gen_server.call(client, :channels)
  end
  @doc """
  Get a list of users in the provided channel
  """
  def channel_users(client, channel) do
    :gen_server.call(client, {:channel_users, channel})
  end
  @doc """
  Get the topic of the provided channel
  """
  def channel_topic(client, channel) do
    :gen_server.call(client, {:channel_topic, channel})
  end
  @doc """
  Get the channel type of the provided channel
  """
  def channel_type(client, channel) do
    :gen_server.call(client, {:channel_type, channel})
  end
  @doc """
  Determine if a nick is present in the provided channel
  """
  def channel_has_user?(client, channel, nick) do
    :gen_server.call(client, {:channel_has_user?, channel, nick})
  end
  @doc """
  Add a new event handler process
  """
  def add_handler(client, pid) do
    :gen_server.call(client, {:add_handler, pid})
  end
  @doc """
  Add a new event handler process, asynchronously
  """
  def add_handler_async(client, pid) do
    :gen_server.cast(client, {:add_handler, pid})
  end
  @doc """
  Remove an event handler process
  """
  def remove_handler(client, pid) do
    :gen_server.call(client, {:remove_handler, pid})
  end
  @doc """
  Remove an event handler process, asynchronously
  """
  def remove_handler_async(client, pid) do
    :gen_server.cast(client, {:remove_handler, pid})
  end
  @doc """
  Get the current state of the provided client
  """
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
     debug:             state.debug,
     event_handlers:    state.event_handlers]
  end

  ###############
  # GenServer API
  ###############
  def init(options // []) do
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
      debug:          debug,
      channels:       ExIrc.Channels.init()]}
  end
  @doc """
  Handle call to get the current state of the client process
  """
  def handle_call(:state, _from, state), do: {:reply, state, state}
  @doc """
  Handle call to stop the current client process
  """
  def handle_call(:stop, _from, state) do
    # Ensure the socket connection is closed if stop is called while still connected to the server
    if state.connected?, do: :gen_tcp.close(state.socket)
    {:stop, :normal, :ok, state.connected?(false).logged_on?(false).socket(nil)}
  end
  @doc """
  Handle call to connect to an IRC server
  """
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
  @doc """
  Handle call to determine if the client is connected
  """
  def handle_call(:is_connected?, _from, state), do: {:reply, state.connected?, state}
  @doc """
  Prevents any of the following messages from being handled if the client is not connected to a server.
  Instead, it returns {:error, :not_connected}.
  """
  def handle_call(_, _from, ClientState[connected?: false] = state), do: {:reply, {:error, :not_connected}, state}
  @doc """
  Handle call to login to the connected IRC server
  """
  def handle_call({:logon, pass, nick, user, name}, _from, ClientState[logged_on?: false] = state) do
    send! state.socket, pass!(pass)
    send! state.socket, nick!(nick)
    send! state.socket, user!(user, name)
    send_event({:login, pass, nick, user, name}, state)
    {:reply, :ok, state.pass(pass).nick(nick).user(user).name(name)}
  end
  @doc """
  Handle call to determine if client is logged on to a server
  """
  def handle_call(:is_logged_on?, _from, state), do: {:reply, state.logged_on?, state}
  @doc """
  Prevents any of the following messages from being handled if the client is not logged on to a server.
  Instead, it returns {:error, :not_logged_in}.
  """
  def handle_call(_, _from, ClientState[logged_on?: false] = state), do: {:reply, {:error, :not_logged_in}, state}
  @doc """
  Handles call to send a message
  """
  def handle_call({:msg, type, nick, msg}, _from, state) do
    data = case type do
      :privmsg -> privmsg!(nick, msg)
      :notice  -> notice!(nick, msg)
      :ctcp    -> notice!(nick, ctcp!(msg))
    end
    send! state.socket, data
    {:reply, :ok, state}
  end
  @doc """
  Handles call to join a channel
  """
  def handle_call({:join, channel, key}, _from, state)      do send!(state.socket, join!(channel, key)); {:reply, :ok, state} end
  @doc """
  Handles a call to leave a channel
  """
  def handle_call({:part, channel}, _from, state)           do send!(state.socket, part!(channel)); {:reply, :ok, state} end
  @doc """
  Handle call to quit the server and close the socket connection
  """
  def handle_call({:quit, msg}, _from, state) do
    if state.connected? do
      send! state.socket, quit!(msg)
      :gen_tcp.close state.socket
    end
    {:reply, :ok, state.connected?(false).logged_on?(false).socket(nil)}
  end
  @doc """
  Handles call to change the client's nick
  """
  def handle_call({:nick, new_nick}, _from, state) do send!(state.socket, nick!(new_nick)); {:reply, :ok, state} end
  @doc """
  Handles call to send a raw command to the IRC server
  """
  def handle_call({:cmd, raw_cmd}, _from, state) do send!(state.socket, command!(raw_cmd)); {:reply, :ok, state} end
  @doc """
  Handles call to return the client's channel data
  """
  def handle_call(:channels, _from, state), do: {:reply, Channels.channels(state.channels), state}
  @doc """
  Handles call to return a list of users for a given channel
  """
  def handle_call({:channel_users, channel}, _from, state), do: {:reply, Channels.channel_users(state.channels, channel), state}
  @doc """
  Handles call to return the given channel's topic
  """
  def handle_call({:channel_topic, channel}, _from, state), do: {:reply, Channels.channel_topic(state.channels, channel), state}
  @doc """
  Handles call to return the type of the given channel
  """
  def handle_call({:channel_type, channel}, _from, state), do: {:reply, Channels.channel_type(state.channels, channel), state}
  @doc """
  Handles call to determine if a nick is present in the given channel
  """
  def handle_call({:channel_has_user?, channel, nick}, _from, state) do
    {:reply, Channels.channel_has_user?(state.channels, channel, nick), state}
  end
  @doc """
  Handles call to add a new event handler process
  """
  def handle_call({:add_handler, pid}, _from, state) do
    handlers = do_add_handler(pid, state.event_handlers)
    {:reply, :ok, state.event_handlers(handlers)}
  end
  @doc """
  Handles call to remove an event handler process
  """
  def handle_call({:remove_handler, pid}, _from, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:reply, :ok, state.event_handlers(handlers)}
  end
  @doc """
  Handles message to add a new event handler process asynchronously
  """
  def handle_cast({:add_handler, pid}, state) do
    handlers = do_add_handler(pid, state.event_handlers)
    {:noreply, state.event_handlers(handlers)}
  end
  @doc """
  Handles message to remove an event handler process asynchronously
  """
  def handle_cast({:remove_handler, pid}, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:noreply, state.event_handlers(handlers)}
  end
  @doc """
  Handles the client's socket connection 'closed' event
  """
  def handle_info({:tcp_closed, _socket}, ClientState[server: server, port: port] = state) do
    info "Connection to #{server}:#{port} closed!"
    {:noreply, state.socket(nil).connected?(false).logged_on?(false).channels(Channels.init())}
  end
  @doc """
  Handles any TCP errors in the client's socket connection
  """
  def handle_info({:tcp_error, socket, reason}, ClientState[server: server, port: port] = state) do
    error "TCP error in connection to #{server}:#{port}:\r\n#{reason}\r\nClient connection closed."
    {:stop, {:tcp_error, socket}, state.socket(nil).connected?(false).logged_on?(false).channels(Channels.init())}
  end
  @doc """
  General handler for messages from the IRC server
  """
  def handle_info({:tcp, _, data}, state) do
    debug? = state.debug
    case Utils.parse(data) do
      IrcMessage[ctcp: true] = msg ->
        send_event(msg, state)
        {:noreply, state}
      IrcMessage[ctcp: false] = msg ->
        send_event(msg, state)
        handle_data(msg, state)
      IrcMessage[ctcp: :invalid] = msg when debug? ->
        send_event(msg, state)
        {:noreply, state}
      _ ->
        {:noreply, state}
    end
  end
  @doc """
  If an event handler process dies, remove it from the list of event handlers
  """
  def handle_info({'DOWN', _, _, pid, _}, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:noreply, state.event_handlers(handlers)}
  end
  @doc """
  Catch-all for unrecognized messages (do nothing)
  """
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
  Called upon successful login
  """
  def handle_data(IrcMessage[cmd: @rpl_welcome] = _msg, ClientState[logged_on?: false] = state) do
    debug "SUCCESFULLY LOGGED ON"
    {:noreply, state.logged_on?(true).login_time(:erlang.now())}
  end
  @doc """
  Called when the server sends it's current capabilities
  """
  def handle_data(IrcMessage[cmd: @rpl_isupport] = msg, state) do
    debug "RECEIVING SERVER CAPABILITIES"
    {:noreply, Utils.isup(msg.args, state)}
  end
  @doc """
  Called when the client enters a channel
  """
  def handle_data(IrcMessage[nick: nick, cmd: "JOIN"] = msg, ClientState[nick: nick] = state) do
    debug "JOINED A CHANNEL #{Enum.first(msg.args)}"
    channels = Channels.join(state.channels, Enum.first(msg.args))
    {:noreply, state.channels(channels)}
  end
  @doc """
  Called when another user joins a channel the client is in
  """
  def handle_data(IrcMessage[nick: user_nick, cmd: "JOIN"] = msg, state) do
    debug "ANOTHER USER JOINED A CHANNEL: #{Enum.first(msg.args)} - #{user_nick}"
    channels = Channels.user_join(state.channels, Enum.first(msg.args), user_nick)
    {:noreply, state.channels(channels)}
  end
  @doc """
  Called on joining a channel, to tell us the channel topic
  Message with three arguments is not RFC compliant but very common
  Message with two arguments is RFC compliant
  """
  def handle_data(IrcMessage[cmd: @rpl_topic] = msg, state) do
    debug "INITIAL TOPIC MSG"
    {channel, topic} = case msg.args do
      [_nick, channel, topic] -> debug("1. TOPIC SET FOR #{channel} TO #{topic}"); {channel, topic}
      [channel, topic]        -> debug("2. TOPIC SET FOR #{channel} TO #{topic}"); {channel, topic}
    end
    channels = Channels.set_topic(state.channels, channel, topic)
    {:noreply, state.channels(channels)}
  end
  @doc """
  Called when the topic changes while we're in the channel
  """
  def handle_data(IrcMessage[cmd: "TOPIC", args: [channel, topic]], state) do
    debug "TOPIC CHANGED FOR #{channel} TO #{topic}"
    channels = Channels.set_topic(state.channels, channel, topic)
    {:noreply, state.channels(channels)}
  end
  @doc """
  Called when joining a channel with the list of current users in that channel, or when the NAMES command is sent
  """
  def handle_data(IrcMessage[cmd: @rpl_namereply] = msg, state) do
    debug "NAMES LIST RECEIVED"
    {_nick, channel_type, channel, names} = case msg.args do
      [nick, channel_type, channel, names]  -> debug("NAMES FORM 1"); IO.inspect({nick, channel_type, channel, names}); {nick, channel_type, channel, names}
      [channel_type, channel, names]        -> debug("NAMES FORM 2"); IO.inspect({nil, channel_type, channel, names}); {nil, channel_type, channel, names}
    end
    channels = Channels.set_type(
      Channels.users_join(state.channels, channel, String.split(names, " ", trim: true),
      channel,
      channel_type))
    {:noreply, state.channels(channels)}
  end
  @doc """
  Called when our nick has succesfully changed
  """
  def handle_data(IrcMessage[cmd: "NICK", nick: nick, args: [new_nick]], ClientState[nick: nick] = state) do
    debug "NICK CHANGED FROM #{nick} TO #{new_nick}"
    {:noreply, state.nick(new_nick)}
  end
  @doc """
  Called when someone visible to us changes their nick
  """
  def handle_data(IrcMessage[cmd: "NICK", nick: nick, args: [new_nick]], state) do
    debug "#{nick} CHANGED THEIR NICK TO #{new_nick}"
    channels = Channels.user_rename(state.channels, nick, new_nick)
    {:noreply, state.channels(channels)}
  end
  @doc """
  Called when we leave a channel
  """
  def handle_data(IrcMessage[cmd: "PART", nick: nick] = msg, ClientState[nick: nick] = state) do
    debug "WE LEFT A CHANNEL: #{Enum.first(msg.args)}"
    channels = Channels.part(state.channels, Enum.first(msg.args))
    {:noreply, state.channels(channels)}
  end
  @doc """
  Called when someone else in our channel leaves
  """
  def handle_data(IrcMessage[cmd: "PART", nick: user_nick] = msg, state) do
    debug "#{user_nick} LEFT A CHANNEL: #{Enum.first(msg.args)}"
    channels = Channels.user_part(state.channels, Enum.first(msg.args), user_nick)
    {:noreply, state.channels(channels)}
  end
  @doc """
  Called when we receive a PING
  """
  def handle_data(IrcMessage[cmd: "PING"] = msg, ClientState[autoping: true] = state) do
    debug "RECEIVED A PING!"
    case msg do
      IrcMessage[args: [from]] -> debug("SENT PONG2"); send!(state.socket, pong2!(state.nick, from))
                             _ -> debug("SENT PONG1"); send!(state.socket, pong1!(state.nick))
    end
    {:noreply, state};
  end
  @doc """
  Called any time we receive an unrecognized message
  """
  def handle_data(_msg, state) do
    debug "UNRECOGNIZED MSG: #{_msg.cmd}"
    IO.inspect _msg
    {:noreply, state}
  end

  ###############
  # Internal API
  ###############
  defp send_event(msg, ClientState[event_handlers: handlers]) when is_list(handlers) do
    Enum.each(handlers, fn({pid, _}) -> pid <- msg end)
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
    case List.keyfind(handlers, pid, 1) do
      {pid, ref} ->
        Process.demonitor(ref)
        List.keydelete(handlers, pid, 1)
      false ->
          handlers
    end
  end

  def debug(msg) do
    IO.puts(IO.ANSI.green() <> msg <> IO.ANSI.reset())
  end

end