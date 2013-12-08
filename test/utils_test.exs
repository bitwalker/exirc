defmodule ExIrc.UtilsTest do
  use ExUnit.Case

  use Irc.Commands

  alias ExIrc.Utils, as: Utils
  alias ExIrc.Client.IrcMessage, as: IrcMessage
  alias ExIrc.Client.ClientState, as: ClientState

  doctest ExIrc.Utils

  test "Given a local date/time as a tuple, can retrieve get the CTCP formatted time" do
  	local_time = {{2013,12,6},{14,5,00}} # Mimics output of :calendar.local_time()
  	assert Utils.ctcp_time(local_time) == 'Fri Dec 06 14:05:00 2013'
  end

  test "Can parse an IRC message" do
  	message = ':irc.example.org 005 nick NETWORK=Freenode PREFIX=(ov)@+ CHANTYPES=#&'
  	assert IrcMessage[
      server: 'irc.example.org',
      cmd:    @rpl_isupport,
      args:   ['nick', 'NETWORK=Freenode', 'PREFIX=(ov)@+', 'CHANTYPES=#&']
    ] = Utils.parse(message)
  end

  test "Can parse RPL_ISUPPORT commands" do
    message = ':irc.example.org 005 nick NETWORK=Freenode PREFIX=(ov)@+ CHANTYPES=#&'
    parsed  = Utils.parse(message)
    state   = ClientState.new()
    assert ClientState[
      channel_prefixes: [?#, ?&],
      user_prefixes:    [{?o, ?@}, {?v, ?+}],
      network:          'Freenode'
    ] = Utils.isup(parsed.args, state)
  end

end
