defmodule ExampleHandler do
	@moduledoc """
	This is an example event handler that you can attach to the client using
	`add_handler` or `add_handler_async`. To remove, call `remove_handler` or
	`remove_handler_async` with the pid of the handler process.
	"""
	alias ExIrc.Client.IrcMessage, as: IrcMessage

	def start! do
		start_link([])
	end

	def start_link(_) do
	    :gen_server.start_link(__MODULE__, nil, [])
	end

	def init(_) do
		{:ok, nil}
	end

	@doc """
	Handle messages from the client

	Examples:

		def handle_info({:connect, server, port}, _state) do
			IO.puts "Connected to \#{server}:\#{port}"
		end
		def handle_info(:login, _state) do
			IO.puts "Logged in!"
		end
		def handle_info(IrcMessage[nick: from, cmd: "PRIVMSG", args: ["mynick", msg]], _state) do
			IO.puts "Received a private message from \#{from}: \#{msg}"
		end
		def handle_info(IrcMessage[nick: from, cmd: "PRIVMSG", args: [to, msg]], _state) do
			IO.puts "Received a message in \#{to} from \#{from}: \#{msg}"
		end

	"""
	def handle_info({:connect, server, port}, _state) do
		debug "Connected to #{server}:#{port}"
		{:noreply, nil}
	end
	def handle_info(:login, _state) do
		debug "Logged in to server"
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
	def handle_info({:topic, channel, topic}, _state) do
		debug "#{channel} topic changed to #{topic}"
		{:noreply, nil}
	end
	def handle_info({:nick, nick}, _state) do
		debug "We changed our nick to #{nick}"
		{:noreply, nil}
	end
	def handle_info({:nick, old_nick, new_nick}, _state) do
		debug "#{old_nick} changed their nick to #{new_nick}"
		{:noreply, nil}
	end
	def handle_info({:part, channel}, _state) do
		debug "We left #{channel}"
		{:noreply, nil}
	end
	def handle_info({:part, channel, nick}, _state) do
		debug "#{nick} left #{channel}"
		{:noreply, nil}
	end
	def handle_info(IrcMessage[nick: from, cmd: "PRIVMSG", args: ["testnick", msg]], _state) do
		debug "Received a private message from #{from}: #{msg}"
		{:noreply, nil}
	end
	def handle_info(IrcMessage[nick: from, cmd: "PRIVMSG", args: [to, msg]], _state) do
		debug "Received a message in #{to} from #{from}: #{msg}"
		{:noreply, nil}
	end
	def handle_info(msg, _state) do
		debug "Received IrcMessage:"
		IO.inspect msg
		{:noreply, nil}
	end

	defp debug(msg) do
		IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
	end
end