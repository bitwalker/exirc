defmodule ExIrc.App do
  @moduledoc """
  Entry point for the ExIrc application.
  """
  use Application

  def start(_type, _args) do
    ExIrc.start!
  end
end
