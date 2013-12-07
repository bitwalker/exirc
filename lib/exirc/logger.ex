defmodule ExIrc.Logger do
  def info(msg) do
    :error_logger.info_report String.to_char_list!(msg)
  end

  def warning(msg) do
    :error_logger.warning_report String.to_char_list!("#{IO.ANSI.yellow()}#{msg}#{IO.ANSI.reset()}")
  end

  def error(msg) do
    :error_logger.error_report String.to_char_list!("#{IO.ANSI.red()}#{msg}#{IO.ANSI.reset()}")
  end
end