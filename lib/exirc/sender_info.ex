defmodule ExIRC.SenderInfo do
  @moduledoc """
  This struct represents information available about the sender of a message.
  """
  defstruct nick: nil,
            host: nil,
            user: nil
end
