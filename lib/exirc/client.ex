defmodule ExIrc.Client do
  @moduledoc """
  Maintains the state and behaviour for individual IRC client connections
  """
  use    Irc.Commands
  import ExIrc.Logger

  alias ExIrc.Channels, as: Channels
  alias ExIrc.Utils,    as: Utils

  # Records
  defrecord ClientState,
    event_handlers:   [],
    server:           'localhost',
    port:             6667,
    socket:           nil,
    nick:             '',
    pass:             '',
    user:             '',
    name:             '',
    logged_on?:       false,
    autoping:         true,
    channel_prefixes: '',
    network:          '',
    user_prefixes:    '',
    login_time:       '',
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
  # Module API
  #################
  def start!(options // []) do
    start_link(options)
  end

  def start_link(options // []) do
    :gen_server.start_link(__MODULE__, options, [])
  end

  def stop!(client) do
    :gen_server.call(client, :stop)
  end

  def connect!(client, server, port) do
    :gen_server.call(client, {:connect, server, port}, :infinity)
  end

  def logon(client, pass, nick, user, name) do
    :gen_server.call(client, {:logon, pass, nick, user, name}, :infinity)
  end

  def msg(client, type, nick, msg) do
    :gen_server.call(client, {:msg, type, nick, msg}, :infinity)
  end

  def nick(client, new_nick) do
    :gen_server.call(client, {:nick, new_nick}, :infinity)
  end

  def cmd(client, raw_cmd) do
    :gen_server.call(client, {:cmd, raw_cmd})
  end

  def join(client, channel, key) do
    :gen_server.call(client, {:join, channel, key}, :infinity)
  end

  def part(client, channel) do
    :gen_server.call(client, {:part, channel}, :infinity)
  end

  def quit(client, msg // 'Leaving..') do
    :gen_server.call(client, {:quit, msg}, :infinity)
  end

  def is_logged_on?(client) do
    :gen_server.call(client, :is_logged_on?)
  end

  def channels(client) do
    :gen_server.call(client, :channels)
  end

  def channel_users(client, channel) do
    :gen_server.call(client, {:channel_users, channel})
  end

  def channel_topic(client, channel) do
    :gen_server.call(client, {:channel_topic, channel})
  end

  def channel_type(client, channel) do
    :gen_server.call(client, {:channel_type, channel})
  end

  def channel_has_user?(client, channel, nick) do
    :gen_server.call(client, {:channel_has_user?, channel, nick})
  end

  def add_handler(client, pid) do
    :gen_server.call(client, {:add_handler, pid})
  end

  def remove_handler(client, pid) do
    :gen_server.call(client, {:remove_handler, pid})
  end

  def add_handler_async(client, pid) do
    :gen_server.cast(client, {:add_handler, pid})
  end

  def remove_handler_async(client, pid) do
    :gen_server.cast(client, {:remove_handler, pid})
  end

  def state(client) do
    state = :gen_server.call(client, :state)
    [server:            state.server,
     port:              state.port,
     nick:              state.nick,
     pass:              state.pass,
     user:              state.user,
     name:              state.name,
     autoping:          state.autoping,
     logged_on?:        state.logged_on?,
     channel_prefixes:  state.channel_prefixes,
     user_prefixes:     state.user_prefixes,
     channels:          Channels.to_proplist,
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
      |> Enum.foldl(&do_add_handler/2)
    # Return initial state
    {:ok, ClientState.new(
      event_handlers: handlers,
      autoping:       autoping,
      logged_on?:     false,
      debug:          debug,
      channels:       ExIrc.Channels.init())}
  end


  def handle_call({:add_handler, pid}, _from, state) do
    handlers = do_add_handler(pid, state.event_handlers)
    {:reply, :ok, state.event_handlers(handlers)}
  end

  def handle_call({:remove_handler, pid}, _from, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:reply, :ok, state.event_handlers(handlers)}
  end

  def handle_call(:state, _from, state), do: {:reply, state, state}
  def handle_call(:stop, _from, state),  do: {:stop, :normal, :ok, state}

  def handle_call({:connect, server, port}, _from, state) do
    case :gen_tcp.connect(server, port, [:list, {:packet, :line}]) do
      {:ok, socket} ->
        send_event {:connect, server, port}, state
        {:reply, :ok, state.server(server).port(port).socket(socket)}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:logon, pass, nick, user, name}, _from, ClientState[logged_on?: false] = state) do
    send! state.socket, pass!(pass)
    send! state.socket, nick!(nick)
    send! state.socket, user!(user, name)
    send_event({:login, pass, nick, user, name}, state)
    {:reply, :ok, state.pass(pass).nick(nick).user(user).name(name)}
  end

  def handle_call(:is_logged_on?, _from, state),                     do: {:reply, state.is_logged_on?, state}
  def handle_call(_, _from, ClientState[logged_on?: false] = state), do: {:reply, {:error, :not_connected}, state}

  def handle_call({:msg, type, nick, msg}, _from, state) do
    data = case type do
      :privmsg -> privmsg!(nick, msg)
      :notice  -> notice!(nick, msg)
      :ctcp    -> notice!(nick, ctcp!(msg))
    end
    send! state.stocket, data
    {:reply, :ok, state}
  end

  def handle_call({:quit, msg}, _from, state),           do: send!(state.socket, quit!(msg)) and {:reply, :ok, state}
  def handle_call({:join, channel, key}, _from, state),  do: send!(state.socket, join!(channel, key)) and {:reply, :ok, state}
  def handle_call({:part, channel}, _from, state),       do: send!(state.socket, part!(channel)) and {:reply, :ok, state}
  def handle_call({:nick, new_nick}, _from, state),      do: send!(state.socket, nick!(new_nick)) and {:reply, :ok, state}
  def handle_call({:cmd, raw_cmd}, _from, state),        do: send!(state.socket, command!(raw_cmd)) and {:reply, :ok, state}

  def handle_call(:channels, _from, state),                 do: {:reply, Channels.channels(state.channels), state}
  def handle_call({:channel_users, channel}, _from, state), do: {:reply, Channels.channel_users(state.channels, channel), state}
  def handle_call({:channel_topic, channel}, _from, state), do: {:reply, Channels.channel_topic(state.channels, channel), state}
  def handle_call({:channel_type, channel}, _from, state),  do: {:reply, Channels.channel_type(state.channels, channel), state}
  def handle_call({:channel_has_user?, channel, nick}, _from, state) do
    {:reply, Channels.channel_has_user?(state.channels, channel, nick), state}
  end

  def handle_cast({:add_handler, pid}, state) do
    handlers = do_add_handler(pid, state.event_handlers)
    {:noreply, state.event_handlers(handlers)}
  end

  def handle_cast({:remove_handler, pid}, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:noreply, state.event_handlers(handlers)}
  end

  def handle_info({:tcp_closed, _socket}, ClientState[server: server, port: port] = state) do
    info "Connection to #{server}:#{port} closed!"
    {:noreply, state.channels(Channels.init())}
  end

  def handle_info({:tcp_error, socket}, state) do
    {:stop, {:tcp_error, socket}, state}
  end

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

  def handle_info({'DOWN', _, _, pid, _}, state) do
    handlers = do_remove_handler(pid, state.event_handlers)
    {:noreply, state.event_handlers(handlers)}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  # Handle termination
  def terminate(_reason, _state), do: :ok
  # Handle code changes
  def code_change(_old, state, _extra), do: {:ok, state}

  ###############
  # Data handling
  ###############

  # Sucessfully logged in
  def handle_data(IrcMessage[cmd: @rpl_welcome] = _msg, ClientState[logged_on?: false] = state) do
    {:noreply, state.logged_on?(true).login_time(:erlang.now())}
  end

  # Server capabilities
  def handle_data(IrcMessage[cmd: @rpl_isupport] = msg, state) do
    {:noreply, Utils.isup(msg.args, state)}
  end

  # Client entered a channel
  def handle_data(IrcMessage[nick: nick, cmd: 'JOIN'] = msg, ClientState[nick: nick] = state) do
    channels = Channels.join(state.channels, Enum.first(msg.args))
    {:noreply, state.channels(channels)}
  end

  # Someone joined the client's channel
  def handle_data(IrcMessage[nick: user_nick, cmd: 'JOIN'] = msg, state) do
    channels = Channels.user_join(state.channels, Enum.first(msg.args), user_nick)
    {:noreply, state.channels(channels)}
  end

  # Topic message on join
  # 3 arguments is not RFC compliant but _very_ common
  # 2 arguments is RFC compliant
  def handle_data(IrcMessage[cmd: @rpl_topic] = msg, state) do
    {channel, topic} = case msg.args do
      [_nick, channel, topic] -> {channel, topic}
      [channel, topic]        -> {channel, topic}
    end
    channels = Channels.set_topic(state.channels, channel, topic)
    {:noreply, state.channels(channels)}
  end

  # Topic message while in channel
  def handle_data(IrcMessage[cmd: 'TOPIC', args: [channel, topic]], state) do
    channels = Channels.set_topic(state.channels, channel, topic)
    {:noreply, state.channels(channels)}
  end

  # NAMES reply
  def handle_data(IrcMessage[cmd: @rpl_namereply] = msg, state) do
    {channel_type, channel, names} = case msg.args do
      [_nick, channel_type, channel, names] -> {channel_type, channel, names}
      [channel_type, channel, names]        -> {channel_type, channel, names}
    end
    channels = Channels.set_type(
      Channels.users_join(state.channels, channel, String.split(names, ' '),
      channel,
      channel_type))
    {:noreply, state.channels(channels)}
  end

  # We successfully changed name 
  def handle_data(IrcMessage[cmd: 'NICK', nick: nick, args: [new_nick]], ClientState[nick: nick] = state) do
    {:noreply, state.nick(new_nick)}
  end

  # Someone we know (or can see) changed name
  def handle_data(IrcMessage[cmd: 'NICK', nick: nick, args: [new_nick]], state) do
    channels = Channels.user_rename(state.channels, nick, new_nick)
    {:noreply, state.channels(channels)}
  end

  # We left a channel
  def handle_data(IrcMessage[cmd: 'PART', nick: nick] = msg, ClientState[nick: nick] = state) do
    channels = Channels.part(state.channels, Enum.first(msg.args))
    {:noreply, state.channels(channels)}
  end

  # Someone left a channel we are in
  def handle_data(IrcMessage[cmd: 'PART', nick: user_nick] = msg, state) do
    channels = Channels.user_part(state.channels, Enum.first(msg.args), user_nick)
    {:noreply, state.channels(channels)}
  end
      
  # We got a ping, reply if autoping is on.
  def handle_data(IrcMessage[cmd: 'PING'] = msg, ClientState[autoping: true] = state) do
    case msg do
      IrcMessage[args: [from]] -> send!(state.socket, pong2!(state.nick, from))
                             _ -> send!(state.socket, pong1!(state.nick))
    end
    {:noreply, state};
  end

  # "catch-all" (probably should remove this)
  def handle_data(_msg, state) do
    {:noreply, state}
  end

  ###############
  # Internal API
  ###############
  def send_event(msg, ClientState[event_handlers: handlers]) when is_list(handlers) do
    Enum.each(handlers, fn({pid, _}) -> pid <- msg end)
  end

  def gv(key, options),          do: :proplists.get_value(key, options)
  def gv(key, options, default), do: :proplists.get_value(key, options, default)

  def do_add_handler(pid, handlers) do
    case Process.alive?(pid) and not Enum.member?(handlers, pid) do
      true ->
        ref = Process.monitor(pid)
        [{pid, ref} | handlers]
      false ->
        handlers
    end
  end

  def do_remove_handler(pid, handlers) do
    case List.keyfind(handlers, pid, 1) do
      {pid, ref} ->
        Process.demonitor(ref)
        List.keydelete(handlers, pid, 1)
      false ->
          handlers
    end
  end

end