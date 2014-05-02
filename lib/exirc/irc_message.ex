defmodule IrcMessage do
  defstruct server:  '',
            nick:    '',
            user:    '',
            host:    '',
            ctcp:    nil,
            cmd:     '',
            args:    []
end
