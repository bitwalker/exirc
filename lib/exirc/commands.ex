defmodule ExIRC.Commands do
  @moduledoc """
  Defines IRC command constants, and methods for generating valid commands to send to an IRC server.
  """

  defmacro __using__(_) do

    quote do
      import ExIRC.Commands

      ####################
      # IRC Numeric Codes
      ####################

      @rpl_welcome "001"
      @rpl_yourhost "002"
      @rpl_created "003"
      @rpl_myinfo "004"
      @rpl_isupport "005" # Defacto standard for server support
      @rpl_bounce "010"   # Defacto replacement of "005" in RFC2812
      @rpl_statsdline "250"
      #@doc """
      #":There are <integer> users and <integer> invisible on <integer> servers"
      #"""
      @rpl_luserclient "251"
      #@doc """
      # "<integer> :operator(s) online"
      #"""
      @rpl_luserop "252"
      #@doc """
      #"<integer> :unknown connection(s)"
      #"""
      @rpl_luserunknown "253"
      #@doc """
      #"<integer> :channels formed"
      #"""
      @rpl_luserchannels "254"
      #@doc """
      #":I have <integer> clients and <integer> servers"
      #"""
      @rpl_luserme "255"
      #@doc """
      #Local/Global user stats
      #"""
      @rpl_localusers "265"
      @rpl_globalusers "266"
      #@doc """
      #When sending a TOPIC message to determine the channel topic, 
      #one of two replies is sent. If the topic is set, RPL_TOPIC is sent back else
      #RPL_NOTOPIC.
      #"""
      @rpl_whoiscertfp "276"
      @rpl_whoisregnick "307"
      @rpl_whoishelpop "310"
      @rpl_whoisuser "311"
      @rpl_whoisserver "312"
      @rpl_whoisoperator "313"
      @rpl_whoisidle "317"
      @rpl_endofwhois "318"
      @rpl_whoischannels "319"
      @rpl_whoisaccount "330"
      @rpl_notopic "331"
      @rpl_topic "332"
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
      @rpl_namereply "353"
      @rpl_endofnames "366"
      #@doc """
      #When responding to the MOTD message and the MOTD file
      #is found, the file is displayed line by line, with
      #each line no longer than 80 characters, using
      #RPL_MOTD format replies. These should be surrounded
      #by a RPL_MOTDSTART (before the RPL_MOTDs) and an
      #RPL_ENDOFMOTD (after).
      #"""
      @rpl_motd "372"
      @rpl_motdstart "375"
      @rpl_endofmotd "376"
      @rpl_whoishost "378"
      @rpl_whoismodes "379"

      ################
      # Error Codes
      ################

      #@doc """
      #Used to indicate the nick parameter supplied to a command is currently unused.
      #"""
      @err_no_such_nick "401"
      #@doc """
      #Used to indicate the server name given currently doesn"t exist.
      #"""
      @err_no_such_server "402"
      #@doc """
      #Used to indicate the given channel name is invalid.
      #"""
      @err_no_such_channel "403"
      #@doc """
      #Sent to a user who is either (a) not on a channel which is mode +n or (b),
      #not a chanop (or mode +v) on a channel which has mode +m set, and is trying 
      #to send a PRIVMSG message to that channel.
      #"""
      @err_cannot_send_to_chan "404"
      #@doc """
      #Sent to a user when they have joined the maximum number of allowed channels 
      #and they try to join another channel.
      #"""
      @err_too_many_channels "405"
      #@doc """
      #Returned to a registered client to indicate that the command sent is unknown by the server.
      #"""
      @err_unknown_command "421"
      #@doc """
      #Returned when a nick parameter expected for a command and isn"t found.
      #"""
      @err_no_nick_given "431"
      #@doc """
      #Returned after receiving a NICK message which contains characters which do not fall in the defined set.
      #"""
      @err_erroneus_nick "432"
      #@doc """
      #Returned when a NICK message is processed that results in an attempt to 
      #change to a currently existing nick.
      #"""
      @err_nick_in_use "433"
      #@doc """
      #Returned by a server to a client when it detects a nick collision
      #(registered of a NICK that already exists by another server).
      #"""
      @err_nick_collision "436"
      #@doc """
      #"""
      @err_unavail_resource "437"
      #@doc """
      #Returned by the server to indicate that the client must be registered before 
      #the server will allow it to be parsed in detail.
      #"""
      @err_not_registered "451"
      #"""
      # Returned by the server by numerous commands to indicate to the client that 
      # it didn"t supply enough parameters.
      #"""
      @err_need_more_params "461"
      #@doc """
      #Returned by the server to any link which tries to change part of the registered 
      #details (such as password or user details from second USER message).
      #"""
      @err_already_registered "462"
      #@doc """
      #Returned by the server to the client when the issued command is restricted
      #"""
      @err_restricted "484"

      @rpl_whoissecure "671"

      ###############
      # Code groups
      ###############

      @logon_errors [ @err_no_nick_given,   @err_erroneus_nick,
                      @err_nick_in_use,     @err_nick_collision,
                      @err_unavail_resource,    @err_need_more_params,
                      @err_already_registered,  @err_restricted ]

      @whois_rpls [ @rpl_whoisuser,  @rpl_whoishost,
                    @rpl_whoishost,  @rpl_whoisserver,
                    @rpl_whoismodes, @rpl_whoisidle,
                    @rpl_endofwhois
                  ]
    end

  end

  ############
  # Helpers
  ############
  @ctcp_delimiter 0o001

  @doc """
  Builds a valid IRC command.
  """
  def command!(cmd), do: [cmd, '\r\n']
  @doc """
  Builds a valid CTCP command.
  """
  def ctcp!(cmd),       do: command! [@ctcp_delimiter, cmd, @ctcp_delimiter]
  def ctcp!(cmd, args) do
    expanded = args |> Enum.intersperse(' ')
    command! [@ctcp_delimiter, cmd, expanded, @ctcp_delimiter]
  end

  # IRC Commands

  @doc """
  Send a WHOIS request about a user
  """
  def whois!(user), do: command! ['WHOIS ', user]

  @doc """
  Send a WHO request about a channel
  """
  def who!(channel), do: command! ['WHO ', channel]

  @doc """
  Send password to server
  """
  def pass!(pwd), do: command! ['PASS ', pwd]
  @doc """
  Send nick to server. (Changes or sets your nick)
  """
  def nick!(nick), do: command! ['NICK ', nick]
  @doc """
  Send username to server. (Changes or sets your username)
  """
  def user!(user, name) do
    command! ['USER ', user, ' 0 * :', name]
  end
  @doc """
  Send PONG in response to PING
  """
  def pong1!(nick), do: command! ['PONG ', nick]
  @doc """
  Send a targeted PONG in response to PING
  """
  def pong2!(nick, to), do: command! ['PONG ', nick, ' ', to]
  @doc """
  Send message to channel or user
  """
  def privmsg!(nick, msg), do: command! ['PRIVMSG ', nick, ' :', msg]
  @doc """
  Send a `/me <msg>` CTCP command to t
  """
  def me!(channel, msg), do: command! ['PRIVMSG ', channel, ' :', @ctcp_delimiter, 'ACTION ', msg, @ctcp_delimiter]
  @doc """
  Sends a command to the server to get the list of names back
  """
  def names!(_channel), do: command! ['NAMES']
  @doc """
  Send notice to channel or user
  """
  def notice!(nick, msg), do: command! ['NOTICE ', nick, ' :', msg]
  @doc """
  Send join command to server (join a channel)
  """
  def join!(channel), do: command! ['JOIN ', channel]
  def join!(channel, key), do: command! ['JOIN ', channel, ' ', key]
  @doc """
  Send part command to server (leave a channel)
  """
  def part!(channel), do: command! ['PART ', channel]
  @doc """
  Send quit command to server (disconnect from server)
  """
  def quit!(msg \\ "Leaving"), do: command! ['QUIT :', msg]
  @doc """
  Send kick command to server
  """
  def kick!(channel, nick, message \\ "") do
    case "#{message}" |> String.length do
      0 -> command! ['KICK ', channel, ' ', nick]
      _ -> command! ['KICK ', channel, ' ', nick, ' ', message]
    end
  end
  @doc """
  Send mode command to server
  MODE <nick> <flags>
  MODE <channel> <flags> [<args>]
  """
  def mode!(channel_or_nick, flags, args \\ "") do
    case "#{args}" |> String.length do
      0 -> command! ['MODE ', channel_or_nick, ' ', flags]
      _ -> command! ['MODE ', channel_or_nick, ' ', flags, ' ', args]
    end
  end
  @doc """
  Send an invite command
  """
  def invite!(nick, channel) do
    command! ['INVITE ', nick, ' ', channel]
  end

end
