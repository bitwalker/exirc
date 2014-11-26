defmodule OhaiHandler do
  @moduledoc """
  This is an example event handler that greets users when they join a channel
  """
  def start_link(client) do
    GenServer.start_link(__MODULE__, [client])
  end

  def init([client]) do
    ExIrc.Client.add_handler client, self
    {:ok, client}
  end

  def handle_info({:joined, channel}, client) do
    debug "Joined #{channel}"
    {:noreply, client}
  end

  def handle_info({:joined, channel, user}, client) do
    # ExIrc currently has a bug that doesn't remove the \r\n from the end
    # of the channel name with it sends along this kind of message
    # so we ensure any trailing or leading whitespace is explicitly removed
    channel = String.strip(channel)
    debug "#{user} joined #{channel}"
    ExIrc.Client.msg(client, :privmsg, channel, "ohai #{user}")
    {:noreply, client}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end
