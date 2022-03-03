defmodule ExIRC.Client do
  @moduledoc """
  Maintains the state and behaviour for individual IRC client connections
  """
  use    ExIRC.Commands
  use    GenServer
  import ExIRC.Logger

  alias ExIRC.Channels
  alias ExIRC.Utils
  alias ExIRC.SenderInfo
  alias ExIRC.Client.Transport

  # Client internal state
  defmodule ClientState do
    defstruct event_handlers:   [],
              server:           "localhost",
              port:             6667,
              socket:           nil,
              nick:             "",
              pass:             "",
              user:             "",
              name:             "",
              ssl?:             false,
              connected?:       false,
              logged_on?:       false,
              autoping:         true,
              channel_prefixes: "",
              network:          "",
              user_prefixes:    "",
              login_time:       "",
              channels:         [],
              debug?:           false,
              retries:          0,
              inet:             :inet,
              owner:            nil,
              whois_buffers:    %{},
              who_buffers:      %{}
  end

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
  @spec start_link(options :: list() | nil, process_opts :: list() | nil) :: {:ok, pid} | {:error, term}
  def start_link(options \\ [], process_opts \\ []) do
    options = Keyword.put_new(options, :owner, self())
    GenServer.start_link(__MODULE__, options, process_opts)
  end
  @doc """
  Stop the IRC client process
  """
  @spec stop!(client :: pid) :: :ok
  def stop!(client) do
    GenServer.call(client, :stop)
  end
  @doc """
  Connect to a server with the provided server and port

  Example:
    Client.connect! pid, "localhost", 6667
  """
  @spec connect!(client :: pid, server :: binary, port :: non_neg_integer, options :: list() | nil) :: :ok
  def connect!(client, server, port, options \\ []) do
    GenServer.call(client, {:connect, server, port, options, false}, :infinity)
  end
  @doc """
  Connect to a server with the provided server and port via SSL

  Example:
    Client.connect! pid, "localhost", 6697
  """
  @spec connect_ssl!(client :: pid, server :: binary, port :: non_neg_integer, options :: list() | nil) :: :ok
  def connect_ssl!(client, server, port, options \\ []) do
    GenServer.call(client, {:connect, server, port, options, true}, :infinity)
  end
  @doc """
  Determine if the provided client process has an open connection to a server
  """
  @spec is_connected?(client :: pid) :: true | false
  def is_connected?(client) do
    GenServer.call(client, :is_connected?)
  end
  @doc """
  Logon to a server

  Example:
    Client.logon pid, "password", "mynick", "user", "My Name"
  """
  @spec logon(client :: pid, pass :: binary, nick :: binary, user :: binary, name :: binary) :: :ok | {:error, :not_connected}
  def logon(client, pass, nick, user, name) do
    GenServer.call(client, {:logon, pass, nick, user, name}, :infinity)
  end
  @doc """
  Determine if the provided client is logged on to a server
  """
  @spec is_logged_on?(client :: pid) :: true | false
  def is_logged_on?(client) do
    GenServer.call(client, :is_logged_on?)
  end
  @doc """
  Send a message to a nick or channel
  Message types are:
    :privmsg
    :notice
    :ctcp
  """
  @spec msg(client :: pid, type :: atom, nick :: binary, msg :: binary) :: :ok
  def msg(client, type, nick, msg) do
    GenServer.call(client, {:msg, type, nick, msg}, :infinity)
  end
  @doc """
  Send an action message, i.e. (/me slaps someone with a big trout)
  """
  @spec me(client :: pid, channel :: binary, msg :: binary) :: :ok
  def me(client, channel, msg) do
    GenServer.call(client, {:me, channel, msg}, :infinity)
  end
  @doc """
  Change the client's nick
  """
  @spec nick(client :: pid, new_nick :: binary) :: :ok
  def nick(client, new_nick) do
    GenServer.call(client, {:nick, new_nick}, :infinity)
  end
  @doc """
  Send a raw IRC command
  """
  @spec cmd(client :: pid, raw_cmd :: binary) :: :ok
  def cmd(client, raw_cmd) do
    GenServer.call(client, {:cmd, raw_cmd})
  end
  @doc """
  Join a channel, with an optional password
  """
  @spec join(client :: pid, channel :: binary, key :: binary | nil) :: :ok
  def join(client, channel, key \\ "") do
    GenServer.call(client, {:join, channel, key}, :infinity)
  end
  @doc """
  Leave a channel
  """
  @spec part(client :: pid, channel :: binary) :: :ok
  def part(client, channel) do
    GenServer.call(client, {:part, channel}, :infinity)
  end
  @doc """
  Kick a user from a channel
  """
  @spec kick(client :: pid, channel :: binary, nick :: binary, message :: binary | nil) :: :ok
  def kick(client, channel, nick, message \\ "") do
    GenServer.call(client, {:kick, channel, nick, message}, :infinity)
  end
  @spec names(client :: pid, channel :: binary) :: :ok
  def names(client, channel) do
    GenServer.call(client, {:names, channel}, :infinity)
  end

  @doc """
  Ask the server for the user's informations.
  """
  @spec whois(client :: pid, user :: binary) :: :ok
  def whois(client, user) do
    GenServer.call(client, {:whois, user}, :infinity)
  end

  @doc """
  Ask the server for the channel's users
  """
  @spec who(client :: pid, channel :: binary) :: :ok
  def who(client, channel) do
    GenServer.call(client, {:who, channel}, :infinity)
  end

  @doc """
  Change mode for a user or channel
  """
  @spec mode(client :: pid, channel_or_nick :: binary, flags :: binary, args :: binary | nil) :: :ok
  def mode(client, channel_or_nick, flags, args \\ "") do
    GenServer.call(client, {:mode, channel_or_nick, flags, args}, :infinity)
  end
  @doc """
  Invite a user to a channel
  """
  @spec invite(client :: pid, nick :: binary, channel :: binary) :: :ok
  def invite(client, nick, channel) do
    GenServer.call(client, {:invite, nick, channel}, :infinity)
  end
  @doc """
  Quit the server, with an optional part message
  """
  @spec quit(client :: pid, msg :: binary | nil) :: :ok
  def quit(client, msg \\ "Leaving..") do
    GenServer.call(client, {:quit, msg}, :infinity)
  end
  @doc """
  Get details about each of the client's currently joined channels
  """
  @spec channels(client :: pid) :: [binary]
  def channels(client) do
    GenServer.call(client, :channels)
  end
  @doc """
  Get a list of users in the provided channel
  """
  @spec channel_users(client :: pid, channel :: binary) :: [binary] | {:error, atom}
  def channel_users(client, channel) do
    GenServer.call(client, {:channel_users, channel})
  end
  @doc """
  Get the topic of the provided channel
  """
  @spec channel_topic(client :: pid, channel :: binary) :: binary | {:error, atom}
  def channel_topic(client, channel) do
    GenServer.call(client, {:channel_topic, channel})
  end
  @doc """
  Get the channel type of the provided channel
  """
  @spec channel_type(client :: pid, channel :: binary) :: atom | {:error, atom}
  def channel_type(client, channel) do
    GenServer.call(client, {:channel_type, channel})
  end
  @doc """
  Determine if a nick is present in the provided channel
  """
  @spec channel_has_user?(client :: pid, channel :: binary, nick :: binary) :: boolean | {:error, atom}
  def channel_has_user?(client, channel, nick) do
    GenServer.call(client, {:channel_has_user?, channel, nick})
  end
  @doc """
  Add a new event handler process
  """
  @spec add_handler(client :: pid, pid) :: :ok
  def add_handler(client, pid) do
    GenServer.call(client, {:add_handler, pid})
  end
  @doc """
  Add a new event handler process, asynchronously
  """
  @spec add_handler_async(client :: pid, pid) :: :ok
  def add_handler_async(client, pid) do
    GenServer.cast(client, {:add_handler, pid})
  end
  @doc """
  Remove an event handler process
  """
  @spec remove_handler(client :: pid, pid) :: :ok
  def remove_handler(client, pid) do
    GenServer.call(client, {:remove_handler, pid})
  end
  @doc """
  Remove an event handler process, asynchronously
  """
  @spec remove_handler_async(client :: pid, pid) :: :ok
  def remove_handler_async(client, pid) do
    GenServer.cast(client, {:remove_handler, pid})
  end
  @doc """
  Get the current state of the provided client
  """
  @spec state(client :: pid) :: [{atom, any}]
  def state(client) do
    state = GenServer.call(client, :state)
    [server:            state.server,
     port:              state.port,
     nick:              state.nick,
     pass:              state.pass,
     user:              state.user,
     name:              state.name,
     autoping:          state.autoping,
     ssl?:              state.ssl?,
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
  Called when GenServer initializes the client
  """
  @spec init(list(any) | []) :: {:ok, ClientState.t}
  def init(options \\ []) do
    autoping = Keyword.get(options, :autoping, true)
    debug    = Keyword.get(options, :debug, false)
    owner    = Keyword.fetch!(options, :owner)
    # Add event handlers
    handlers =
      Keyword.get(options, :event_handlers, [])
      |> List.foldl([], &do_add_handler/2)
    ref = Process.monitor(owner)
    # Return initial state
    {:ok, %ClientState{
      event_handlers: handlers,
      autoping:       autoping,
      logged_on?:     false,
      debug?:         debug,
      channels:       ExIRC.Channels.init(),
      owner:          {owner, ref}}}
  end
  @doc """
  Handle calls from the external API. It is not recommended to call these directly.
  """
  # Handle call to get the current state of the client process
  def handle_call(:state, _from, state), do: {:reply, state, state}
  # Handle call to stop the current client process
  def handle_call(:stop, _from, state) do
    # Ensure the socket connection is closed if stop is called while still connected to the server
    if state.connected?, do: Transport.close(state)
    {:stop, :normal, :ok, %{state | connected?: false, logged_on?: false, socket: nil}}
  end
  # Handles call to add a new event handler process
  def handle_call({:add_handler, pid}, _from, state) do
    handlers = do_add_handler(pid, state.event_handlers)
    {:reply, :ok, %{state | event_handlers: handlers}}
  end
  # Handles call to remove an event handler process
  def handle_call({:remove_handler, pid}, _from, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:reply, :ok, %{state | event_handlers: handlers}}
  end
  # Handle call to connect to an IRC server
  def handle_call({:connect, server, port, options, ssl}, _from, state) do
    # If there is an open connection already, close it.
    if state.socket != nil, do: Transport.close(state)
    # Set SSL mode
    state = %{state | ssl?: ssl}
    # Open a new connection
    case Transport.connect(state, String.to_charlist(server), port, [:list, {:packet, :line}, {:keepalive, true}] ++ options) do
      {:ok, socket} ->
        send_event {:connected, server, port}, state
        {:reply, :ok, %{state | connected?: true, server: server, port: port, socket: socket}}
      error ->
        {:reply, error, state}
    end
  end
  # Handle call to determine if the client is connected
  def handle_call(:is_connected?, _from, state), do: {:reply, state.connected?, state}
  # Prevents any of the following messages from being handled if the client is not connected to a server.
  # Instead, it returns {:error, :not_connected}.
  def handle_call(_, _from, %ClientState{connected?: false} = state), do: {:reply, {:error, :not_connected}, state}
  # Handle call to login to the connected IRC server
  def handle_call({:logon, pass, nick, user, name}, _from, %ClientState{logged_on?: false} = state) do
    Transport.send state, pass!(pass)
    Transport.send state, nick!(nick)
    Transport.send state, user!(user, name)
    {:reply, :ok, %{state | pass: pass, nick: nick, user: user, name: name} }
  end
  # Handles call to change the client's nick.
  def handle_call({:nick, new_nick}, _from, %ClientState{logged_on?: false} = state) do
    Transport.send state, nick!(new_nick)
    # Since we've not yet logged on, we won't get a nick change message, so we have to remember the nick here.
    {:reply, :ok, %{state | nick: new_nick}}
  end
  # Handle call to determine if client is logged on to a server
  def handle_call(:is_logged_on?, _from, state), do: {:reply, state.logged_on?, state}
  # Prevents any of the following messages from being handled if the client is not logged on to a server.
  # Instead, it returns {:error, :not_logged_in}.
  def handle_call(_, _from, %ClientState{logged_on?: false} = state), do: {:reply, {:error, :not_logged_in}, state}
  # Handles call to send a message
  def handle_call({:msg, type, nick, msg}, _from, state) do
    data = case type do
      :privmsg -> privmsg!(nick, msg)
      :notice  -> notice!(nick, msg)
      :ctcp    -> notice!(nick, ctcp!(msg))
    end
    Transport.send state, data
    {:reply, :ok, state}
  end
  # Handle /me messages
  def handle_call({:me, channel, msg}, _from, state) do
    data = me!(channel, msg)
    Transport.send state, data
    {:reply, :ok, state}
  end
  # Handles call to join a channel
  def handle_call({:join, channel, key}, _from, state) do
    Transport.send(state, join!(channel, key))
    {:reply, :ok, state}
  end
  # Handles a call to leave a channel
  def handle_call({:part, channel}, _from, state) do
    Transport.send(state, part!(channel))
    {:reply, :ok, state}
  end
  # Handles a call to kick a client
  def handle_call({:kick, channel, nick, message}, _from, state) do
    Transport.send(state, kick!(channel, nick, message))
    {:reply, :ok, state}
  end
  # Handles a call to send the NAMES command to the server
  def handle_call({:names, channel}, _from, state) do
    Transport.send(state, names!(channel))
    {:reply, :ok, state}
  end

  def handle_call({:whois, user}, _from, state) do
    Transport.send(state, whois!(user))
    {:reply, :ok, state}
  end

  def handle_call({:who, channel}, _from, state) do
    Transport.send(state, who!(channel))
    {:reply, :ok, state}
  end

  # Handles a call to change mode for a user or channel
  def handle_call({:mode, channel_or_nick, flags, args}, _from, state) do
    Transport.send(state, mode!(channel_or_nick, flags, args))
    {:reply, :ok, state}
  end
  # Handle call to invite a user to a channel
  def handle_call({:invite, nick, channel}, _from, state) do
    Transport.send(state, invite!(nick, channel))
    {:reply, :ok, state}
  end
  # Handle call to quit the server and close the socket connection
  def handle_call({:quit, msg}, _from, state) do
    if state.connected? do
      Transport.send state, quit!(msg)
      send_event(:disconnected, state)
      Transport.close state
    end
    {:reply, :ok, %{state | connected?: false, logged_on?: false, socket: nil}}
  end
  # Handles call to change the client's nick
  def handle_call({:nick, new_nick}, _from, state) do Transport.send(state, nick!(new_nick)); {:reply, :ok, state} end
  # Handles call to send a raw command to the IRC server
  def handle_call({:cmd, raw_cmd}, _from, state) do Transport.send(state, command!(raw_cmd)); {:reply, :ok, state} end
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
    {:noreply, %{state | event_handlers: handlers}}
  end
  @doc """
  Handles asynchronous messages from the external API. Not recommended to call these directly.
  """
  # Handles message to remove an event handler process asynchronously
  def handle_cast({:remove_handler, pid}, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:noreply, %{state | event_handlers: handlers}}
  end
  @doc """
  Handle messages from the TCP socket connection.
  """
  # Handles the client's socket connection 'closed' event
  def handle_info({:tcp_closed, _socket}, %ClientState{server: server, port: port} = state) do
    info "Connection to #{server}:#{port} closed!"
    send_event :disconnected, state
    new_state = %{state |
      socket:     nil,
      connected?: false,
      logged_on?: false,
      channels:   Channels.init()
    }
    {:noreply, new_state}
  end
  @doc """
  Handle messages from the SSL socket connection.
  """
  # Handles the client's socket connection 'closed' event
  def handle_info({:ssl_closed, socket}, state) do
    handle_info({:tcp_closed, socket}, state)
  end
  # Handles any TCP errors in the client's socket connection
  def handle_info({:tcp_error, socket, reason}, %ClientState{server: server, port: port} = state) do
    error "TCP error in connection to #{server}:#{port}:\r\n#{reason}\r\nClient connection closed."
    new_state = %{state |
      socket:     nil,
      connected?: false,
      logged_on?: false,
      channels:   Channels.init()
    }
    {:stop, {:tcp_error, socket}, new_state}
  end
  # Handles any SSL errors in the client's socket connection
  def handle_info({:ssl_error, socket, reason}, state) do
    handle_info({:tcp_error, socket, reason}, state)
  end
  # General handler for messages from the IRC server
  def handle_info({:tcp, _, data}, state) do
    debug? = state.debug?
    case Utils.parse(data) do
      %ExIRC.Message{ctcp: true} = msg ->
        handle_data msg, state
        {:noreply, state}
      %ExIRC.Message{ctcp: false} = msg ->
        handle_data msg, state
      %ExIRC.Message{ctcp: :invalid} = msg when debug? ->
        send_event msg, state
        {:noreply, state}
      _ ->
        {:noreply, state}
    end
  end
  # Wrapper for SSL socket messages
  def handle_info({:ssl, socket, data}, state) do
    handle_info({:tcp, socket, data}, state)
  end
  # If the owner process dies, we should die as well
  def handle_info({:DOWN, ref, _, pid, reason}, %{owner: {pid, ref}} = state) do
    {:stop, reason, state}
  end
  # If an event handler process dies, remove it from the list of event handlers
  def handle_info({:DOWN, _, _, pid, _}, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:noreply, %{state | event_handlers: handlers}}
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
      Transport.close state
      %{state | socket: nil}
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
  Handle ExIRC.Messages received from the server.
  """
  # Called upon successful login
  def handle_data(%ExIRC.Message{cmd: @rpl_welcome}, %ClientState{logged_on?: false} = state) do
    if state.debug?, do: debug "SUCCESFULLY LOGGED ON"
    new_state = %{state | logged_on?: true, login_time: :erlang.timestamp()}
    send_event :logged_in, new_state
    {:noreply, new_state}
  end
  # Called when trying to log in with a nickname that is in use
  def handle_data(%ExIRC.Message{cmd: @err_nick_in_use}, %ClientState{logged_on?: false} = state) do
    if state.debug?, do: debug "ERROR: NICK IN USE"
    send_event {:login_failed, :nick_in_use}, state
    {:noreply, state}
  end
  # Called when the server sends it's current capabilities
  def handle_data(%ExIRC.Message{cmd: @rpl_isupport} = msg, state) do
    if state.debug?, do: debug "RECEIVING SERVER CAPABILITIES"
    {:noreply, Utils.isup(msg.args, state)}
  end
  # Called when the client enters a channel

  def handle_data(%ExIRC.Message{nick: nick, cmd: "JOIN"} = msg, %ClientState{nick: nick} = state) do
    channel = msg.args |> List.first |> String.trim
    if state.debug?, do: debug "JOINED A CHANNEL #{channel}"
    channels  = Channels.join(state.channels, channel)
    new_state = %{state | channels: channels}
    send_event {:joined, channel}, new_state
    {:noreply, new_state}
  end
  # Called when another user joins a channel the client is in
  def handle_data(%ExIRC.Message{nick: user_nick, cmd: "JOIN", host: host, user: user} = msg, state) do
    sender = %SenderInfo{nick: user_nick, host: host, user: user}
    channel = msg.args |> List.first |> String.trim
    if state.debug?, do: debug "ANOTHER USER JOINED A CHANNEL: #{channel} - #{user_nick}"
    channels  = Channels.user_join(state.channels, channel, user_nick)
    new_state = %{state | channels: channels}
    send_event {:joined, channel, sender}, new_state
    {:noreply, new_state}
  end
  # Called on joining a channel, to tell us the channel topic
  # Message with three arguments is not RFC compliant but very common
  # Message with two arguments is RFC compliant
  # Message with a single argument is not RFC compliant, but is present
  # to handle poorly written IRC servers which send RPL_TOPIC with an empty
  # topic (such as Slack's IRC bridge), when they should be sending RPL_NOTOPIC
  def handle_data(%ExIRC.Message{cmd: @rpl_topic} = msg, state) do
    {channel, topic} = case msg.args do
      [_nick, channel, topic] -> {channel, topic}
      [channel, topic]        -> {channel, topic}
      [channel]               -> {channel, "No topic is set"}
    end
    if state.debug? do
      debug "INITIAL TOPIC MSG"
      debug "1. TOPIC SET FOR #{channel} TO #{topic}"
    end
    channels  = Channels.set_topic(state.channels, channel, topic)
    new_state = %{state | channels: channels}
    send_event {:topic_changed, channel, topic}, new_state
    {:noreply, new_state}
  end


  ## WHOIS

  def handle_data(%ExIRC.Message{cmd: @rpl_whoisuser, args: [_sender, nick, user, hostname, _, name]}, state) do
    user = %{nick: nick, user: user, hostname: hostname, name: name}
    {:noreply, %ClientState{state|whois_buffers: Map.put(state.whois_buffers, nick, user)}}
  end

  def handle_data(%ExIRC.Message{cmd: @rpl_whoiscertfp, args: [_sender, nick, "has client certificate fingerprint "<> fingerprint]}, state) do
    {:noreply, %ClientState{state|whois_buffers: put_in(state.whois_buffers, [nick, :certfp], fingerprint)}}
  end

  def handle_data(%ExIRC.Message{cmd: @rpl_whoisregnick, args: [_sender, nick, _message]}, state) do
    {:noreply, %ClientState{state|whois_buffers: put_in(state.whois_buffers, [nick, :registered_nick?], true)}}
  end

  def handle_data(%ExIRC.Message{cmd: @rpl_whoishelpop, args: [_sender, nick, _message]}, state) do
    {:noreply, %ClientState{state|whois_buffers: put_in(state.whois_buffers, [nick, :helpop?], true)}}
  end

  def handle_data(%ExIRC.Message{cmd: @rpl_whoischannels, args: [_sender, nick, channels]}, state) do
    chans = String.split(channels, " ")
    {:noreply, %ClientState{state|whois_buffers: put_in(state.whois_buffers, [nick, :channels], chans)}}
  end


  def handle_data(%ExIRC.Message{cmd: @rpl_whoisserver, args: [_sender, nick, server_addr, server_name]}, state) do
    new_buffer = state.whois_buffers
                 |> put_in([nick, :server_name], server_name)
                 |> put_in([nick, :server_address], server_addr)
    {:noreply, %ClientState{state|whois_buffers: new_buffer}}
  end

  def handle_data(%ExIRC.Message{cmd: @rpl_whoisoperator, args: [_sender, nick, _message]}, state) do
    {:noreply, %ClientState{state|whois_buffers: put_in(state.whois_buffers, [nick, :ircop?], true)}}
  end

  def handle_data(%ExIRC.Message{cmd: @rpl_whoisaccount, args: [_sender, nick, account_name, _message]}, state) do
    {:noreply, %ClientState{state|whois_buffers: put_in(state.whois_buffers, [nick, :account_name], account_name)}}
  end

  def handle_data(%ExIRC.Message{cmd: @rpl_whoissecure, args: [_sender, nick, _message]}, state) do
    {:noreply, %ClientState{state|whois_buffers: put_in(state.whois_buffers, [nick, :ssl?], true)}}
  end

  def handle_data(%ExIRC.Message{cmd: @rpl_whoisidle, args: [_sender, nick, idling_time, signon_time, _message]}, state) do
    new_buffer = state.whois_buffers
                 |> put_in([nick, :idling_time], idling_time)
                 |> put_in([nick, :signon_time], signon_time)
    {:noreply, %ClientState{state|whois_buffers: new_buffer}}
  end

  def handle_data(%ExIRC.Message{cmd: @rpl_endofwhois, args: [_sender, nick, _message]}, state) do
    buffer = struct(ExIRC.Whois, state.whois_buffers[nick])
    send_event {:whois, buffer}, state
    {:noreply, %ClientState{state|whois_buffers: Map.delete(state.whois_buffers, nick)}}
  end

  ## WHO

  def handle_data(%ExIRC.Message{:cmd => "352", :args => [_, channel, user, host, server, nick, mode, hop_and_realn]}, state) do
    [hop, name] = String.split(hop_and_realn, " ", parts: 2)

    :binary.compile_pattern(["@", "&", "+"])
    admin?              = String.contains?(mode, "&")
    away?               = String.contains?(mode, "G")
    founder?            = String.contains?(mode, "~")
    half_operator?      = String.contains?(mode, "%")
    operator?           = founder? || admin? || String.contains?(mode, "@")
    server_operator?    = String.contains?(mode, "*")
    voiced?             = String.contains?(mode, "+")

     nick = %{nick: nick, user: user, name: name, server: server, hops: hop, admin?: admin?,
              away?: away?, founder?: founder?, half_operator?: half_operator?, host: host,
              operator?: operator?, server_operator?: server_operator?, voiced?: voiced?
             }

    buffer = Map.get(state.who_buffers, channel, [])
    {:noreply, %ClientState{state | who_buffers: Map.put(state.who_buffers, channel, [nick|buffer])}}
  end

  def handle_data(%ExIRC.Message{:cmd => "315", :args => [_, channel, _]}, state) do
    buffer = state
             |> Map.get(:who_buffers)
             |> Map.get(channel)
             |> Enum.map(fn user -> struct(ExIRC.Who, user) end)

    send_event {:who, channel, buffer}, state
    {:noreply, %ClientState{state | who_buffers: Map.delete(state.who_buffers, channel)}}
  end

  def handle_data(%ExIRC.Message{cmd: @rpl_notopic, args: [channel]}, state) do
    if state.debug? do
      debug "INITIAL TOPIC MSG"
      debug "1. NO TOPIC SET FOR #{channel}}"
    end
    channels = Channels.set_topic(state.channels, channel, "No topic is set")
    new_state = %{state | channels: channels}
    {:noreply, new_state}
  end
  # Called when the topic changes while we're in the channel
  def handle_data(%ExIRC.Message{cmd: "TOPIC", args: [channel, topic]}, state) do
    if state.debug?, do: debug "TOPIC CHANGED FOR #{channel} TO #{topic}"
    channels  = Channels.set_topic(state.channels, channel, topic)
    new_state = %{state | channels: channels}
    send_event {:topic_changed, channel, topic}, new_state
    {:noreply, new_state}
  end
  # Called when joining a channel with the list of current users in that channel, or when the NAMES command is sent
  def handle_data(%ExIRC.Message{cmd: @rpl_namereply} = msg, state) do
    if state.debug?, do: debug "NAMES LIST RECEIVED"
    {_nick, channel_type, channel, names} = case msg.args do
      [nick, channel_type, channel, names]  -> {nick, channel_type, channel, names}
      [channel_type, channel, names]        -> {nil, channel_type, channel, names}
    end
    channels = Channels.set_type(
      Channels.users_join(state.channels, channel, String.split(names, " ", trim: true)),
      channel,
      channel_type)

    send_event({:names_list, channel, names}, state)

    {:noreply, %{state | channels: channels}}
  end
  # Called when our nick has succesfully changed
  def handle_data(%ExIRC.Message{cmd: "NICK", nick: nick, args: [new_nick]}, %ClientState{nick: nick} = state) do
    if state.debug?, do: debug "NICK CHANGED FROM #{nick} TO #{new_nick}"
    new_state = %{state | nick: new_nick}
    send_event {:nick_changed, new_nick}, new_state
    {:noreply, new_state}
  end
  # Called when someone visible to us changes their nick
  def handle_data(%ExIRC.Message{cmd: "NICK", nick: nick, args: [new_nick]}, state) do
    if state.debug?, do: debug "#{nick} CHANGED THEIR NICK TO #{new_nick}"
    channels  = Channels.user_rename(state.channels, nick, new_nick)
    new_state = %{state | channels: channels}
    send_event {:nick_changed, nick, new_nick}, new_state
    {:noreply, new_state}
  end
  # Called upon mode change
  def handle_data(%ExIRC.Message{cmd: "MODE", args: [channel, op, user]}, state) do
    if state.debug?, do: debug "MODE #{channel} #{op} #{user}"
    send_event {:mode, [channel, op, user]}, state
    {:noreply, state}
  end
  # Called when we leave a channel

  def handle_data(%ExIRC.Message{cmd: "PART", nick: nick} = msg, %ClientState{nick: nick} = state) do

    channel = msg.args |> List.first |> String.trim
    if state.debug?, do: debug "WE LEFT A CHANNEL: #{channel}"
    channels  = Channels.part(state.channels, channel)
    new_state = %{state | channels: channels}
    send_event {:parted, channel}, new_state
    {:noreply, new_state}
  end
  # Called when someone else in our channel leaves
  def handle_data(%ExIRC.Message{cmd: "PART", nick: from, host: host, user: user} = msg, state) do
    sender = %SenderInfo{nick: from, host: host, user: user}
    channel = msg.args |> List.first |> String.trim
    if state.debug?, do: debug "#{from} LEFT A CHANNEL: #{channel}"
    channels  = Channels.user_part(state.channels, channel, from)
    new_state = %{state | channels: channels}
    send_event {:parted, channel, sender}, new_state
    {:noreply, new_state}
  end
  def handle_data(%ExIRC.Message{cmd: "QUIT", nick: from, host: host, user: user} = msg, state) do
    sender = %SenderInfo{nick: from, host: host, user: user}
    reason = msg.args |> List.first
    if state.debug?, do: debug "#{from} QUIT"
    channels = Channels.user_quit(state.channels, from)
    new_state = %{state | channels: channels}
    send_event {:quit, reason, sender}, new_state
    {:noreply, new_state}
  end
  # Called when we receive a PING
  def handle_data(%ExIRC.Message{cmd: "PING"} = msg, %ClientState{autoping: true} = state) do
    if state.debug?, do: debug "RECEIVED A PING!"
    case msg do
      %ExIRC.Message{args: [from]} ->
        if state.debug?, do: debug("SENT PONG2")
        Transport.send(state, pong2!(from, msg.server))
      _ ->
        if state.debug?, do: debug("SENT PONG1")
        Transport.send(state, pong1!(state.nick))
    end
    {:noreply, state};
  end
  # Called when we are invited to a channel
  def handle_data(%ExIRC.Message{cmd: "INVITE", args: [nick, channel], nick: by, host: host, user: user} = msg, %ClientState{nick: nick} = state) do
    sender = %SenderInfo{nick: by, host: host, user: user}
    if state.debug?, do: debug "RECEIVED AN INVITE: #{msg.args |> Enum.join(" ")}"
    send_event {:invited, sender, channel}, state
    {:noreply, state}
  end
  # Called when we are kicked from a channel

  def handle_data(%ExIRC.Message{cmd: "KICK", args: [channel, nick, reason], nick: by, host: host, user: user} = _msg, %ClientState{nick: nick} = state) do

    sender = %SenderInfo{nick: by, host: host, user: user}
    if state.debug?, do: debug "WE WERE KICKED FROM #{channel} BY #{by}"
    send_event {:kicked, sender, channel, reason}, state
    {:noreply, state}
  end
  # Called when someone else was kicked from a channel

  def handle_data(%ExIRC.Message{cmd: "KICK", args: [channel, nick, reason], nick: by, host: host, user: user} = _msg, state) do

    sender = %SenderInfo{nick: by, host: host, user: user}
    if state.debug?, do: debug "#{nick} WAS KICKED FROM #{channel} BY #{by}"
    send_event {:kicked, nick, sender, channel, reason}, state
    {:noreply, state}
  end
  # Called when someone sends us a message
  def handle_data(%ExIRC.Message{nick: from, cmd: "PRIVMSG", args: [nick, message], host: host, user: user} = _msg, %ClientState{nick: nick} = state) do
    sender = %SenderInfo{nick: from, host: host, user: user}
    if state.debug?, do: debug "#{from} SENT US #{message}"
    send_event {:received, message, sender}, state
    {:noreply, state}
  end
  # Called when someone sends a message to a channel we're in, or a list of users
  def handle_data(%ExIRC.Message{nick: from, cmd: "PRIVMSG", args: [to, message], host: host, user: user} = _msg, %ClientState{nick: nick} = state) do
    sender = %SenderInfo{nick: from, host: host, user: user}
    if state.debug?, do: debug "#{from} SENT #{message} TO #{to}"
    send_event {:received, message, sender, to}, state
    # If we were mentioned, fire that event as well
    if String.contains?(String.downcase(message), String.downcase(nick)), do: send_event({:mentioned, message, sender, to}, state)
    {:noreply, state}
  end
  # Called when someone uses ACTION, i.e. `/me dies`
  def handle_data(%ExIRC.Message{nick: from, cmd: "ACTION", args: [channel, message], host: host, user: user} = _msg, state) do
    sender = %SenderInfo{nick: from, host: host, user: user}
    if state.debug?, do: debug "* #{from} #{message} in #{channel}"
    send_event {:me, message, sender, channel}, state
    {:noreply, state}
  end

  # Called when a NOTICE is received by the client.
  def handle_data(%ExIRC.Message{nick: from, cmd: "NOTICE", args: [_target, message], host: host, user: user} = _msg, state) do

    sender = %SenderInfo{nick: from,
                         host: host,
                         user: user}

    if String.contains?(message, "identify") do
        if state.debug?, do: debug("* Told to identify by #{from}: #{message}")
        send_event({:identify, message, sender}, state)
    else
      if state.debug?, do: debug("* #{message} from #{sender}")
      send_event({:notice, message, sender}, state)
    end

    {:noreply, state}
  end

  # Called any time we receive an unrecognized message
  def handle_data(msg, state) do
    if state.debug? do debug "UNRECOGNIZED MSG: #{msg.cmd}"; IO.inspect(msg) end
    send_event {:unrecognized, msg.cmd, msg}, state
    {:noreply, state}
  end

  ###############
  # Internal API
  ###############
  defp send_event(msg, %ClientState{event_handlers: handlers}) when is_list(handlers) do
    Enum.each(handlers, fn({pid, _}) -> Kernel.send(pid, msg) end)
  end

  defp do_add_handler(pid, handlers) do
    case Enum.member?(handlers, pid) do
      false ->
        ref = Process.monitor(pid)
        [{pid, ref} | handlers]
      true ->
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
