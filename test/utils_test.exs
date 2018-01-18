defmodule ExIRC.UtilsTest do
  use ExUnit.Case, async: true

  use ExIRC.Commands

  alias ExIRC.Utils, as: Utils
  alias ExIRC.Client.ClientState, as: ClientState

  doctest ExIRC.Utils

  test "Given a local date/time as a tuple, can retrieve get the CTCP formatted time" do
    local_time = {{2013,12,6},{14,5,0}} # Mimics output of :calendar.local_time()
    assert Utils.ctcp_time(local_time) == "Fri Dec 06 14:05:00 2013"
  end

  test "Can parse a CTCP command" do
    message = ':pschoenf NOTICE #testchan :' ++ '#{<<0o001>>}' ++ 'ACTION mind explodes!!' ++ '#{<<0o001>>}'
    expected = %ExIRC.Message{
      nick: "pschoenf",
      cmd:  "ACTION",
      ctcp: true,
      args: ["#testchan", "mind explodes!!"]
    }
    result = Utils.parse(message)
    assert expected == result
  end

  test "Parse cloaked user" do
    message = ':foo!foo@unaffiliated/foo PRIVMSG #bar Hiya.'
    expected = %ExIRC.Message{
      nick: "foo",
      cmd: "PRIVMSG",
      host: "unaffiliated/foo",
      ctcp: false,
      user: "foo",
      args: ["#bar", "Hiya."]
    }
    result = Utils.parse(message)
    assert expected == result
  end

  test "Parse uncloaked (normal) user" do
    message = ':foo!foo@80.21.56.43 PRIVMSG #bar Hiya.'
    expected = %ExIRC.Message{
      nick: "foo",
      cmd: "PRIVMSG",
      host: "80.21.56.43",
      ctcp: false,
      user: "foo",
      args: ["#bar", "Hiya."]
    }
    result = Utils.parse(message)
    assert expected == result
  end

  test "Parse INVITE message" do
    message = ':pschoenf INVITE testuser #awesomechan'
    assert %ExIRC.Message{
      :nick => "pschoenf",
      :cmd =>  "INVITE",
      :args => ["testuser", "#awesomechan"]
    } = Utils.parse(message)
  end

  test "Parse KICK message" do
    message = ':pschoenf KICK #testchan lameuser'
    assert %ExIRC.Message{
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

  test "Can parse full prefix in messages" do
    assert %ExIRC.Message{
      nick: "WiZ",
      user: "jto",
      host: "tolsun.oulu.fi",
    } = Utils.parse(':WiZ!jto@tolsun.oulu.fi NICK Kilroy')
  end

  test "Can parse prefix with only hostname in messages" do
    assert %ExIRC.Message{
      nick: "WiZ",
      host: "tolsun.oulu.fi",
    } = Utils.parse(':WiZ!tolsun.oulu.fi NICK Kilroy')
  end

  test "Can parse reduced prefix in messages" do
    assert %ExIRC.Message{
      nick: "Trillian",
    } = Utils.parse(':Trillian SQUIT cm22.eng.umd.edu :Server out of control')
  end

  test "Can parse server-only prefix in messages" do
    assert %ExIRC.Message{
      server: "ircd.stealth.net"
    } = Utils.parse(':ircd.stealth.net 302 yournick :syrk=+syrk@millennium.stealth.net')
  end

  test "Can parse FULL STOP in username in prefixes" do
    assert %ExIRC.Message{
      nick: "nick",
      user: "user.name",
      host: "irc.example.org"
    } = Utils.parse(':nick!user.name@irc.example.org PART #channel')
  end

  test "Can parse EXCLAMATION MARK in username in prefixes" do
    assert %ExIRC.Message{
      nick: "nick",
      user: "user!name",
      host: "irc.example.org"
    } = Utils.parse(':nick!user!name@irc.example.org PART #channel')
  end

  test "parse join message" do
    message = ':pschoenf JOIN #elixir-lang'
    assert %ExIRC.Message{
      nick: "pschoenf",
      cmd: "JOIN",
      args: ["#elixir-lang"]
    } = Utils.parse(message)
  end

  test "Parse Slack's inappropriate RPL_TOPIC message as if it were an RPL_NOTOPIC" do
    # NOTE: This is not a valid message per the RFC.  If there's no topic
    # (which is the case for Slack in this instance), they should instead send
    # us a RPL_NOTOPIC (331).
    #
    # Two things:
    #
    # 1) Bad slack!  Read your RFCs! (because my code has never had bugs yup obv)
    # 2) Don't care, still want to talk to them without falling over dead!
    #
    # Parsing this as if it were actually an RPL_NOTOPIC (331) seems especially like
    # a good idea when I realized that there's nothing in ExIRc that does anything
    # with 331 at all - they just fall on the floor, no crashes to be seen (ideally)
    message = ':irc.tinyspeck.com 332 jadams #elm-playground-news :'
    assert %ExIRC.Message{
      nick: "jadams",
      cmd:  "331",
      args: ["#elm-playground-news", "No topic is set"]
    } = Utils.parse(message)
  end

  test "Can parse simple unicode" do
    # ':foo!~user@172.17.0.1 PRIVMSG #bar :éáçíóö\r\n'
    message = [58, 102, 111, 111, 33, 126, 117, 115, 101, 114, 64, 49, 55, 50,
               46, 49, 55, 46, 48, 46, 49, 32, 80, 82, 73, 86, 77, 83, 71, 32,
               35, 98, 97, 114, 32, 58, 195, 169, 195, 161, 195, 167, 195, 173,
               195, 179, 195, 182, 13, 10]
    assert %ExIRC.Message{
      args: ["#bar", "éáçíóö"],
      cmd:  "PRIVMSG",
      ctcp: false,
      host: "172.17.0.1",
      nick: "foo",
      server: [],
      user: "~user"
    } = Utils.parse(message)
  end

  test "Can parse complex unicode" do
    # ':foo!~user@172.17.0.1 PRIVMSG #bar :Ĥélłø 차\r\n'
    message = [58, 102, 111, 111, 33, 126, 117, 115, 101, 114, 64, 49, 55, 50,
               46, 49, 55, 46, 48, 46, 49, 32, 80, 82, 73, 86, 77, 83, 71, 32,
               35, 98, 97, 114, 32, 58, 196, 164, 195, 169, 108, 197, 130, 195,
               184, 32, 236, 176, 168, 13, 10]
    assert %ExIRC.Message{
      args: ["#bar", "Ĥélłø 차"],
      cmd:  "PRIVMSG",
      ctcp: false,
      host: "172.17.0.1",
      nick: "foo",
      server: [],
      user: "~user"
    } = Utils.parse(message)
  end

  test "Can parse latin1" do
    # ':foo!~user@172.17.0.1 PRIVMSG #bar :ééé\r\n'
    message = [58, 102, 111, 111, 33, 126, 117, 115, 101, 114, 64, 49, 55, 50,
               46, 49, 55, 46, 48, 46, 49, 32, 80, 82, 73, 86, 77, 83, 71, 32,
               35, 98, 97, 114, 32, 58, 233, 233, 233, 13, 10]

    assert %ExIRC.Message{
      args: ["#bar", "ééé"],
      cmd:  "PRIVMSG",
      ctcp: false,
      host: "172.17.0.1",
      nick: "foo",
      server: [],
      user: "~user"
    } = Utils.parse(message)
  end

end
