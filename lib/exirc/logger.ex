defmodule ExIrc.Logger do
  @moduledoc """
  A simple abstraction of :error_logger
  """

  @doc """
  Log an informational message report
  """
  @spec info(binary) :: :ok
  def info(msg) do
    :error_logger.info_report List.from_char_data!(msg)
  end

  @doc """
  Log a warning message report
  """
  @spec warning(binary) :: :ok
  def warning(msg) do
    :error_logger.warning_report List.from_char_data!("#{IO.ANSI.yellow()}#{msg}#{IO.ANSI.reset()}")
  end

  @doc """
  Log an error message report
  """
  @spec error(binary) :: :ok
  def error(msg) do
    :error_logger.error_report List.from_char_data!("#{IO.ANSI.red()}#{msg}#{IO.ANSI.reset()}")
  end
end