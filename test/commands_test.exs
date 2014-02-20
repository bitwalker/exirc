defmodule ExIrc.CommandsTest do
  use ExUnit.Case, async: true

  use Irc.Commands

  test "Commands are formatted properly" do
    assert [1, 'TESTCMD', 1] == ctcp! "TESTCMD"
    assert [['PASS ', 'testpass'], '\r\n'] == pass! "testpass"
    assert [['NICK ', 'testnick'], '\r\n'] == nick! "testnick"
    assert [['USER ', 'testuser', ' 0 * :', 'Test User'], '\r\n'] == user! "testuser", "Test User"
    assert [['PONG ', 'testnick'], '\r\n'] == pong1! "testnick"
    assert [['PONG ', 'testnick', ' ', 'othernick'], '\r\n'] == pong2! "testnick", "othernick"
    assert [['PRIVMSG ', 'testnick', ' :', 'Test message!'], '\r\n'] == privmsg! "testnick", "Test message!"
    assert [['NOTICE ', 'testnick', ' :', 'Test notice!'], '\r\n'] == notice! "testnick", "Test notice!"
    assert [['JOIN ', 'testchan', ' ', ''], '\r\n'] == join! "testchan"
    assert [['JOIN ', 'testchan', ' ', 'chanpass'], '\r\n'] == join! "testchan", "chanpass"
    assert [['PART ', 'testchan'], '\r\n'] == part! "testchan"
    assert [['QUIT :', 'Leaving'], '\r\n'] == quit!
    assert [['QUIT :', 'Goodbye, cruel world.'], '\r\n'] == quit! "Goodbye, cruel world."
    assert [['KICK ', '#testchan', ' ', 'testuser'], '\r\n'] == kick! "#testchan", "testuser"
    assert [['KICK ', '#testchan', ' ', 'testuser', ' ', 'Get outta here!'], '\r\n'] == kick! "#testchan", "testuser", "Get outta here!"
    # User modes
    assert [['MODE ', 'testuser', ' ', '-o'], '\r\n'] == mode! "testuser", "-o"
    # Channel modes
    assert [['MODE ', '#testchan', ' ', '+im'], '\r\n'] == mode! "#testchan", "+im"
    assert [['MODE ', '#testchan', ' ', '+o', ' ', 'testuser'], '\r\n'] = mode! "#testchan", "+o", "testuser"
  end
end