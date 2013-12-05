defmodule ExIrc.App do
  @moduledoc """
  Entry point for the ExIrc application.
  """
  use Application.Behaviour

  def start(_type, _args) do
    ExIrc.start!
  end
end