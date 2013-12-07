defmodule Irc.Commands do

  defmacro __using__(_) do

    quote do
      import Irc.Commands

      ####################
      # IRC Numeric Codes
      ####################

      @rpl_welcome '001'
      @rpl_yourhost '002'
      @rpl_created '003'
      @rpl_myinfo '004'
      @rpl_isupport '005' # Defacto standard for server support
      @rpl_bounce '010'   # Defacto replacement of '005' in RFC2812
      @rpl_statsdline '250'
      #@doc """
      #":There are <integer> users and <integer> invisible on <integer> servers"
      #"""
      @rpl_luserclient '251'
      #@doc """
      # "<integer> :operator(s) online"
      #"""
      @rpl_luserop '252'
      #@doc """
      #"<integer> :unknown connection(s)"
      #"""
      @rpl_luserunknown '253'
      #@doc """
      #"<integer> :channels formed"
      #"""
      @rpl_luserchannels '254'
      #@doc """
      #":I have <integer> clients and <integer> servers"
      #"""
      @rpl_luserme '255'
      #@doc """
      #Local/Global user stats
      #"""
      @rpl_localusers '265'
      @rpl_globalusers '266'
      #@doc """
      #When sending a TOPIC message to determine the channel topic, 
      #one of two replies is sent. If the topic is set, RPL_TOPIC is sent back else
      #RPL_NOTOPIC.
      #"""
      @rpl_notopic '331'
      @rpl_topic '332'
      #@doc """
      #To reply to a NAMES message, a reply pair consisting
      #of RPL_NAMREPLY and RPL_ENDOFNAMES is sent by the
      #server back to the client. If there is no channel
      #found as in the query, then only RPL_ENDOFNAMES is
      #returned. The exception to this is when a NAMES
      #message is sent with no parameters and all visible
      #channels and contents are sent back in a series of
      #RPL_NAMEREPLY messages with a RPL_ENDOFNAMES to mark
      #the end.

      #Format: "<channel> :[[@|+]<nick> [[@|+]<nick> [...]]]"
      #"""
      @rpl_namereply '353'
      @rpl_endofnames '366'
      #@doc """
      #When responding to the MOTD message and the MOTD file
      #is found, the file is displayed line by line, with
      #each line no longer than 80 characters, using
      #RPL_MOTD format replies. These should be surrounded
      #by a RPL_MOTDSTART (before the RPL_MOTDs) and an
      #RPL_ENDOFMOTD (after).
      #"""
      @rpl_motd '372'
      @rpl_motdstart '375'
      @rpl_endofmotd '376'

      ################
      # Error Codes
      ################

      #@doc """
      #Used to indicate the nickname parameter supplied to a command is currently unused.
      #"""
      @err_no_such_nick '401'
      #@doc """
      #Used to indicate the server name given currently doesn't exist.
      #"""
      @err_no_such_server '402'
      #@doc """
      #Used to indicate the given channel name is invalid.
      #"""
      @err_no_such_channel '403'
      #@doc """
      #Sent to a user who is either (a) not on a channel which is mode +n or (b),
      #not a chanop (or mode +v) on a channel which has mode +m set, and is trying 
      #to send a PRIVMSG message to that channel.
      #"""
      @err_cannot_send_to_chan '404'
      #@doc """
      #Sent to a user when they have joined the maximum number of allowed channels 
      #and they try to join another channel.
      #"""
      @err_too_many_channels '405'
      #@doc """
      #Returned to a registered client to indicate that the command sent is unknown by the server.
      #"""
      @err_unknown_command '421'
      #@doc """
      #Returned when a nickname parameter expected for a command and isn't found.
      #"""
      @err_no_nickname_given '431'
      #@doc """
      #Returned after receiving a NICK message which contains characters which do not fall in the defined set.
      #"""
      @err_erroneus_nickname '432'
      #@doc """
      #Returned when a NICK message is processed that results in an attempt to 
      #change to a currently existing nickname.
      #"""
      @err_nickname_in_use '433'
      #@doc """
      #Returned by a server to a client when it detects a nickname collision
      #(registered of a NICK that already exists by another server).
      #"""
      @err_nick_collision '436'
      #@doc """
      #"""
      @err_unavail_resource '437'
      #@doc """
      #Returned by the server to indicate that the client must be registered before 
      #the server will allow it to be parsed in detail.
      #"""
      @err_not_registered '451'
      #"""
      # Returned by the server by numerous commands to indicate to the client that 
      # it didn't supply enough parameters.
      #"""
      @err_need_more_params '461'
      #@doc """
      #Returned by the server to any link which tries to change part of the registered 
      #details (such as password or user details from second USER message).
      #"""
      @err_already_registered '462'
      #@doc """
      #Returned by the server to the client when the issued command is restricted
      #"""
      @err_restricted '484'

      ###############
      # Code groups
      ###############

      @logon_errors [ unquote(@err_no_nickname_given),   unquote(@err_erroneus_nickname),
                      unquote(@err_nickname_in_use),     unquote(@err_nick_collision),
                      unquote(@err_unavail_resource),    unquote(@err_need_more_params),
                      unquote(@err_already_registered),  unquote(@err_restricted) ]
    end

  end

  # Helpers
  @crlf '\r\n'
  defmacro command!(cmd) do
    quote do: [unquote(cmd), @crlf]
  end
  defmacro ctcp!(cmd) do
    quote do: [1, unquote(cmd), 1]
  end
  defmacro send!(socket, data) do
    quote do: :gen_tcp.send(unquote(socket), unquote(data))
  end

  # IRC Commands
  defmacro pass!(pwd) do
    quote do: command! ['PASS ', unquote(pwd)]
  end
  defmacro nick!(nick) do
    quote do: command! ['NICK ', unquote(nick)]
  end
  defmacro user!(user, name) do
    quote do: command! ['USER ', unquote(user), ' 0 * :', unquote(name)]
  end
  defmacro pong1!(nick) do
    quote do: command! ['PONG ', unquote(nick)]
  end
  defmacro pong2!(nick, to) do
    quote do: command! ['PONG ', unquote(nick), ' ', unquote(to)]
  end
  defmacro privmsg!(nick, msg) do
    quote do: command! ['PRIVMSG ', unquote(nick), ' :', unquote(msg)]
  end
  defmacro notice!(nick, msg) do
    quote do: command! ['NOTICE ', unquote(nick), ' :', unquote(msg)]
  end
  defmacro join!(channel, key) do
    quote do: command! ['JOIN ', unquote(channel), ' ', unquote(key)]
  end
  defmacro part!(channel) do
    quote do: command! ['PART ', unquote(channel)]
  end
  defmacro quit!(msg // 'Leaving') do
    quote do: command! ['QUIT :', unquote(msg)]
  end

end