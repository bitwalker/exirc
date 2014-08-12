defmodule ExIrc.UtilsTest do
  use ExUnit.Case, async: true

  use Irc.Commands

  alias ExIrc.Utils, as: Utils
  alias ExIrc.Client.ClientState, as: ClientState

  doctest ExIrc.Utils

  test "Given a local date/time as a tuple, can retrieve get the CTCP formatted time" do
  	local_time = {{2013,12,6},{14,5,0}} # Mimics output of :calendar.local_time()
  	assert Utils.ctcp_time(local_time) == "Fri Dec 06 14:05:00 2013"
  end

  test "Can parse a CTCP command" do
    message = ':pschoenf NOTICE #testchan :' ++ '#{<<0o001>>}' ++ 'ACTION mind explodes!!' ++ '#{<<0o001>>}'
  	expected = %IrcMessage{
      nick: "pschoenf",
      cmd:  "ACTION",
      ctcp: true,
      args: ["#testchan", "mind explodes!!"]
    }
    result = Utils.parse(message)
    assert expected == result
  end

  test "Parse INVITE message" do
    message = ':pschoenf INVITE testuser #awesomechan'
    assert %IrcMessage{
      :nick => "pschoenf",
      :cmd =>  "INVITE",
      :args => ["testuser", "#awesomechan"]
    } = Utils.parse(message)
  end

  test "Parse KICK message" do
    message = ':pschoenf KICK #testchan lameuser'
    assert %IrcMessage{
      :nick => "pschoenf",
      :cmd =>  "KICK",
      :args => ["#testchan", "lameuser"]
    } = Utils.parse(message)
  end

  test "Can parse RPL_ISUPPORT commands" do
    message = ':irc.example.org 005 nick NETWORK=Freenode PREFIX=(ov)@+ CHANTYPES=#&'
    parsed  = Utils.parse(message)
    state   = %ClientState{}
    assert %ClientState{
      :channel_prefixes => ["#", "&"],
      :user_prefixes =>    [{?o, ?@}, {?v, ?+}],
      :network =>          "Freenode"
    } = Utils.isup(parsed.args, state)
  end

end
