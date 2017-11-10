defmodule ExIRC.Message do
  defstruct server:  '',
            nick:    '',
            user:    '',
            host:    '',
            ctcp:    nil,
            cmd:     '',
            args:    []
end
