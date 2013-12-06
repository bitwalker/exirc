defmodule Irc.Commands do

  # Helpers
  @CRLF '\r\n'
  defmacro CMD(cmd) do
    quote do: [unquote(cmd), @CRLF]
  end
  defmacro CTCP(cmd) do
    quote do: [1, unquote(cmd), 1]
  end
  defmacro send!(socket, data) do
    quote do: :gen_tcp.send(unquote(socket), unquote(data))
  end

  # IRC Commands
  defmacro PASS(pwd) do
    quote do: CMD(['PASS ', unquote(pwd)])
  end
  defmacro NICK(nick) do
    quote do: CMD ['NICK ', unquote(nick)]
  end
  defmacro USER(user, name) do
    quote do: CMD ['USER ', unquote(user), ' 0 * :', unquote(name)]
  end
  defmacro PONG1(nick) do
    quote do: CMD ['PONG ', unquote(nick)]
  end
  defmacro PONG2(nick, to) do
    quote do: CMD ['PONG ', unquote(nick), ' ', unquote(to)]
  end
  defmacro PRIVMSG(nick, msg) do
    quote do: CMD ['PRIVMSG ', unquote(nick), ' :', unquote(msg)]
  end
  defmacro NOTICE(nick, msg) do
    quote do: CMD ['NOTICE ', unquote(nick), ' :', unquote(msg)]
  end
  defmacro JOIN(channel, key) do
    quote do: CMD ['JOIN ', unquote(channel), ' ', unquote(key)]
  end
  defmacro PART(channel) do
    quote do: CMD ['PART ', unquote(channel)]
  end
  defmacro QUIT(msg // 'Leaving') do
    quote do: CMD ['QUITE :', unquote(msg)]
  end

  ####################
  # IRC Numeric Codes
  ####################
  @RPL_WELCOME          '001'
  @RPL_YOURHOST         '002'
  @RPL_CREATED          '003'
  @RPL_MYINFO           '004'
  # @RPL_BOUNCE         '005' # RFC2812
  @RPL_ISUPPORT         '005' # Defacto standard for server support
  @RPL_BOUNCE           '010' # Defacto replacement of '005' in RFC2812
  @RPL_STATSDLINE       '250'
  @RPL_LUSERCLIENT      '251'
  @RPL_LUSEROP          '252'
  @RPL_LUSERUNKNOWN     '253'
  @RPL_LUSERCHANNELS    '254'
  @RPL_LUSERME          '255'
  @RPL_LOCALUSERS       '265'
  @RPL_GLOBALUSERS      '266'
  @RPL_TOPIC            '332'
  @RPL_NAMREPLY         '353'
  @RPL_ENDOFNAMES       '366'
  @RPL_MOTD             '372'
  @RPL_MOTDSTART        '375'
  @RPL_ENDOFMOTD        '376'
  # Error Codes
  @ERR_NONICKNAMEGIVEN  '431'
  @ERR_ERRONEUSNICKNAME '432'
  @ERR_NICKNAMEINUSE    '433'
  @ERR_NICKCOLLISION    '436'
  @ERR_UNAVAILRESOURCE  '437'
  @ERR_NEEDMOREPARAMS   '461'
  @ERR_ALREADYREGISTRED '462'
  @ERR_RESTRICTED       '484'

  # Code groups
  @LOGON_ERRORS [@ERR_NONICKNAMEGIVEN,  @ERR_ERRONEUSNICKNAME,
                 @ERR_NICKNAMEINUSE,    @ERR_NICKCOLLISION,
                 @ERR_UNAVAILRESOURCE,  @ERR_NEEDMOREPARAMS,
                 @ERR_ALREADYREGISTRED, @ERR_RESTRICTED]

end