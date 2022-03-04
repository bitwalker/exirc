defmodule ExIRC.Message do
  @moduledoc false

  defstruct server: '',
            nick: '',
            user: '',
            host: '',
            ctcp: nil,
            cmd: '',
            args: []

  @type t :: %__MODULE__{
          server: String.t() | charlist(),
          nick: String.t() | charlist(),
          user: String.t() | charlist(),
          host: String.t() | charlist(),
          ctcp: boolean() | :invalid | nil,
          cmd: String.t() | charlist(),
          args: [String.t() | charlist()]
        }
end
