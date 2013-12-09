defmodule ExampleHandler do
	@moduledoc """
	This is an example event handler that you can attach to the client using
	add_handler/add_handler_async. To remove, call remove_handler/remove_handler_async
	with the pid of the handler process.
	"""
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
	Handle the connect event, which occurs when succesfully connected to a server
	"""
	def handle_info({:connect, server, port}, _state) do
		debug "Connected to #{server}:#{port}"
		{:noreply, nil}
	end
	@doc """
	Handle the login event, which occurs upon succesful login to a server
	"""
	def handle_info({:login, pass, nick, user, name}, _state) do
		debug "Logged in as nick: #{nick}, user: #{user}, name: #{name}, using password #{pass}"
		{:noreply, nil}
	end
	@doc """
	Catch all handler for IRC messages, you can define multiple of these with various critiera
	to handle specific messages, such as direct messages, joins, parts, etc.
	"""
	def handle_info(msg, _state) do
		debug "Received IrcMessage:"
		IO.inspect msg
		{:noreply, nil}
	end

	def debug(msg) do
		IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
	end
end