defmodule Irc.Commands do

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
    quote do: command! ['QUITE :', unquote(msg)]
  end

  ####################
  # IRC Numeric Codes
  ####################
  @rpl_WELCOME          '001'
  @rpl_YOURHOST         '002'
  @rpl_CREATED          '003'
  @rpl_MYINFO           '004'
  # @rpl_BOUNCE         '005' # RFC2812
  @rpl_ISUPPORT         '005' # Defacto standard for server support
  @rpl_BOUNCE           '010' # Defacto replacement of '005' in RFC2812
  @rpl_STATSDLINE       '250'
  @rpl_LUSERCLIENT      '251'
  @rpl_LUSEROP          '252'
  @rpl_LUSERUNKNOWN     '253'
  @rpl_LUSERCHANNELS    '254'
  @rpl_LUSERME          '255'
  @rpl_LOCALUSERS       '265'
  @rpl_GLOBALUSERS      '266'
  @rpl_TOPIC            '332'
  @rpl_NAMREPLY         '353'
  @rpl_ENDOFNAMES       '366'
  @rpl_MOTD             '372'
  @rpl_MOTDSTART        '375'
  @rpl_ENDOFMOTD        '376'
  # Error Codes
  @err_NONICKNAMEGIVEN  '431'
  @err_ERRONEUSNICKNAME '432'
  @err_NICKNAMEINUSE    '433'
  @err_NICKCOLLISION    '436'
  @err_UNAVAILRESOURCE  '437'
  @err_NEEDMOREPARAMS   '461'
  @err_ALREADYREGISTRED '462'
  @err_RESTRICTED       '484'

  # Code groups
  @logon_errors [@err_NONICKNAMEGIVEN,  @err_ERRONEUSNICKNAME,
                 @err_NICKNAMEINUSE,    @err_NICKCOLLISION,
                 @err_UNAVAILRESOURCE,  @err_NEEDMOREPARAMS,
                 @err_ALREADYREGISTRED, @err_RESTRICTED]

end