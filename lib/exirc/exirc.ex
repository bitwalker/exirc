defmodule ExIrc do
  @moduledoc """
  Supervises IRC client processes

  Usage:
    # Start the supervisor (started automatically when ExIrc is run as an application)
    ExIrc.start_link
    # Start a new IRC client
    {:ok, client} = ExIrc.start_client!

  """
  use Supervisor.Behaviour

  ##############
  # Public API
  ##############

  @doc """
  Start the ExIrc supervisor.
  """
  @spec start! :: {:ok, pid} | {:error, term}
  def start! do
    :supervisor.start_link({:local, :ircsuper}, __MODULE__, [])
  end

  @doc """
  Start a new ExIrc client
  """
  @spec start_client! :: {:ok, pid} | {:error, term}
  def start_client! do
    # Start the client worker
    :supervisor.start_child(:ircsuper, worker(ExIrc.Client, []))
  end

  ##############
  # Supervisor API
  ##############

  def init(_) do
    supervise [], strategy: :one_for_one
  end

end
