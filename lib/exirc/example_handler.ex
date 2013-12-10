defmodule ExampleHandler do
	@moduledoc """
	This is an example event handler that you can attach to the client using
	add_handler/add_handler_async. To remove, call remove_handler/remove_handler_async
	with the pid of the handler process.
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
		def handle_info({:login, pass, nick, user, name}, _state) do
			IO.puts "Logged in as nick: \#{nick}, user: \#{user}, name: \#{name}, using password \#{pass}"
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
	def handle_info({:login, pass, nick, user, name}, _state) do
		debug "Logged in as nick: #{nick}, user: #{user}, name: #{name}, using password #{pass}"
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