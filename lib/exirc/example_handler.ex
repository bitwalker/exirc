defmodule ExampleHandler do
  @moduledoc """
  This is an example event handler that you can attach to the client using
  `add_handler` or `add_handler_async`. To remove, call `remove_handler` or
  `remove_handler_async` with the pid of the handler process.
  """
  def start! do
    start_link([])
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, [])
  end

  def init(_) do
    {:ok, nil}
  end

  @doc """
  Handle messages from the client

  Examples:

    def handle_info({:connected, server, port}, _state) do
      IO.puts "Connected to \#{server}:\#{port}"
    end
    def handle_info(:logged_in, _state) do
      IO.puts "Logged in!"
    end
    def handle_info(%ExIRC.Message{nick: from, cmd: "PRIVMSG", args: ["mynick", msg]}, _state) do
      IO.puts "Received a private message from \#{from}: \#{msg}"
    end
    def handle_info(%ExIRC.Message{nick: from, cmd: "PRIVMSG", args: [to, msg]}, _state) do
      IO.puts "Received a message in \#{to} from \#{from}: \#{msg}"
    end
  """
  def handle_info({:connected, server, port}, _state) do
    debug "Connected to #{server}:#{port}"
    {:noreply, nil}
  end
  def handle_info(:logged_in, _state) do
    debug "Logged in to server"
    {:noreply, nil}
  end
  def handle_info({:login_failed, :nick_in_use}, _state) do
    debug "Login failed, nickname in use"
    {:noreply, nil}
  end
  def handle_info(:disconnected, _state) do
    debug "Disconnected from server"
    {:noreply, nil}
  end
  def handle_info({:joined, channel}, _state) do
    debug "Joined #{channel}"
    {:noreply, nil}
  end
  def handle_info({:joined, channel, user}, _state) do
    debug "#{user} joined #{channel}"
    {:noreply, nil}
  end
  def handle_info({:topic_changed, channel, topic}, _state) do
    debug "#{channel} topic changed to #{topic}"
    {:noreply, nil}
  end
  def handle_info({:nick_changed, nick}, _state) do
    debug "We changed our nick to #{nick}"
    {:noreply, nil}
  end
  def handle_info({:nick_changed, old_nick, new_nick}, _state) do
    debug "#{old_nick} changed their nick to #{new_nick}"
    {:noreply, nil}
  end
  def handle_info({:parted, channel}, _state) do
    debug "We left #{channel}"
    {:noreply, nil}
  end
  def handle_info({:parted, channel, sender}, _state) do
    nick = sender.nick
    debug "#{nick} left #{channel}"
    {:noreply, nil}
  end
  def handle_info({:invited, sender, channel}, _state) do
    by = sender.nick
    debug "#{by} invited us to #{channel}"
    {:noreply, nil}
  end
  def handle_info({:kicked, sender, channel}, _state) do
    by = sender.nick
    debug "We were kicked from #{channel} by #{by}"
    {:noreply, nil}
  end
  def handle_info({:kicked, nick, sender, channel}, _state) do
    by = sender.nick
    debug "#{nick} was kicked from #{channel} by #{by}"
    {:noreply, nil}
  end
  def handle_info({:received, message, sender}, _state) do
    from = sender.nick
    debug "#{from} sent us a private message: #{message}"
    {:noreply, nil}
  end
  def handle_info({:received, message, sender, channel}, _state) do
    from = sender.nick
    debug "#{from} sent a message to #{channel}: #{message}"
    {:noreply, nil}
  end
  def handle_info({:mentioned, message, sender, channel}, _state) do
    from = sender.nick
    debug "#{from} mentioned us in #{channel}: #{message}"
    {:noreply, nil}
  end
  def handle_info({:me, message, sender, channel}, _state) do
    from = sender.nick
    debug "* #{from} #{message} in #{channel}"
    {:noreply, nil}
  end
  # This is an example of how you can manually catch commands if ExIRC.Client doesn't send a specific message for it
  def handle_info(%ExIRC.Message{nick: from, cmd: "PRIVMSG", args: ["testnick", msg]}, _state) do
    debug "Received a private message from #{from}: #{msg}"
    {:noreply, nil}
  end
  def handle_info(%ExIRC.Message{nick: from, cmd: "PRIVMSG", args: [to, msg]}, _state) do
    debug "Received a message in #{to} from #{from}: #{msg}"
    {:noreply, nil}
  end
  # Catch-all for messages you don't care about
  def handle_info(msg, _state) do
    debug "Received ExIRC.Message:"
    IO.inspect msg
    {:noreply, nil}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end
