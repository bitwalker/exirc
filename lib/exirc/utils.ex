defmodule ExIrc.Utils do

  ######################
  # IRC Message Parsing
  ######################

  @doc """
  Parse an IRC message

  Example:

      data    = ':irc.example.org 005 nick NETWORK=Freenode PREFIX=(ov)@+ CHANTYPES=#&'
      message = ExIrc.Utils.parse data
      assert "irc.example.org" = message.server
  """
  @spec parse(raw_data :: char_list) :: IrcMessage.t
  def parse(raw_data) do
    data = :string.substr(raw_data, 1, length(raw_data))
    case data do
      [?:|_] ->
          [[?:|from]|rest] = :string.tokens(data, ' ')
          get_cmd(rest, parse_from(from, %IrcMessage{ctcp: false}))
      data ->
          get_cmd(:string.tokens(data, ' '), %IrcMessage{ctcp: false})
    end
  end

  @split_pattern ~r/(!|@|\.)/
  defp parse_from(from, msg) do
    from_str = IO.iodata_to_binary(from)
    splits   = Regex.scan(@split_pattern, from_str, return: :index) 
               |> Enum.map(fn [{start, len},_] -> binary_part(from_str, start, len) end)
    parts    = Regex.split(@split_pattern, from_str)
    woven    = weave(splits, parts)
    case woven do
      [nick, "!", user, "@" | host] ->
        %{msg | :nick => nick, :user => user, :host => Enum.join(host)}
      [nick, "@" | host] ->
        %{msg | :nick => nick, :host => Enum.join(host)}
      [_, "." | _] ->
        # from is probably a server name
        %{msg | :server => to_string(from)}
      [nick] ->
        %{msg | :nick => nick}
    end
  end

  # Parse command from message
  defp get_cmd([cmd, arg1, [?:, 1 | ctcp_trail] | restargs], msg) when cmd == 'PRIVMSG' or cmd == 'NOTICE' do
    get_cmd([cmd, arg1, [1 | ctcp_trail] | restargs], msg)
  end

  defp get_cmd([cmd, target, [1 | ctcp_cmd] | cmd_args], msg) when cmd == 'PRIVMSG' or cmd == 'NOTICE' do
    args = cmd_args
      |> Enum.map(&Enum.take_while(&1, fn c -> c != 0o001 end))
      |> Enum.map(&List.to_string/1)
    case args do
      args when args != [] ->
        %{msg | 
          :cmd  => to_string(ctcp_cmd),
          :args => [to_string(target), args |> Enum.join(" ")],
          :ctcp => true
        }
      _ ->
        %{msg | :cmd => to_string(cmd), :ctcp => :invalid}
    end
  end

  defp get_cmd([cmd | rest], msg) do
    get_args(rest, %{msg | :cmd => to_string(cmd)})
  end


  # Parse command args from message
  defp get_args([], msg) do
    args = msg.args
      |> Enum.reverse
      |> Enum.filter(fn(arg) -> arg != [] end)
      |> Enum.map(&trim_crlf/1)
      |> Enum.map(&List.to_string/1)
    %{msg | :args => args}
  end

  defp get_args([[?: | first_arg] | rest], msg) do
    args = (for arg <- [first_arg | rest], do: ' ' ++ trim_crlf(arg)) |> List.flatten
    case args do
      [_ | []] ->
          get_args [], %{msg | :args => [msg.args]}
      [_ | full_trail] ->
          get_args [], %{msg | :args => [full_trail | msg.args]}
    end
  end

  defp get_args([arg | []], msg) do
    get_args [], %{msg | :args => [arg | msg.args]}
  end

  defp get_args([arg | rest], msg) do
    get_args rest, %{msg | :args => [arg | msg.args]}
  end

  ############################
  # Parse RPL_ISUPPORT (005)
  ############################

  @doc """
  Parse RPL_ISUPPORT message.

  If an empty list is provided, do nothing, otherwise parse CHANTYPES,
  NETWORK, and PREFIX parameters for relevant data.
  """
  @spec isup(parameters :: list(binary), state :: ExIrc.Client.ClientState.t) :: ExIrc.Client.ClientState.t
  def isup([], state), do: state
  def isup([param | rest], state) do
    try do
      isup(rest, isup_param(param, state))
    rescue
      _ -> isup(rest, state)
    end
  end

  defp isup_param("CHANTYPES=" <> channel_prefixes, state) do
    prefixes = channel_prefixes |> String.split("", trim: true)
    %{state | :channel_prefixes => prefixes}
  end
  defp isup_param("NETWORK=" <> network, state) do
    %{state | :network => network}
  end
  defp isup_param("PREFIX=" <> user_prefixes, state) do
    prefixes = Regex.run(~r/\((.*)\)(.*)/, user_prefixes, capture: :all_but_first)
               |> Enum.map(&String.to_char_list/1)
               |> List.zip
    %{state | :user_prefixes => prefixes}
  end
  defp isup_param(_, state) do
    state
  end

  ###################
  # Helper Functions
  ###################

  @days_of_week   ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
  @months_of_year ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
  @doc """
  Get CTCP formatted time from a tuple representing the current calendar time:

  Example:

      iex> local_time = {{2013,12,6},{14,5,0}}
      {{2013,12,6},{14,5,0}}
      iex> ExIrc.Utils.ctcp_time local_time
      "Fri Dec 06 14:05:00 2013"
  """
  @spec ctcp_time(datetime :: {{integer, integer, integer}, {integer, integer, integer}}) :: binary
  def ctcp_time({{y, m, d}, {h, n, s}} = _datetime) do
    [:lists.nth(:calendar.day_of_the_week(y,m,d), @days_of_week),
     ' ',
     :lists.nth(m, @months_of_year),
     ' ',
     :io_lib.format("~2..0s", [Integer.to_char_list(d)]),
     ' ',
     :io_lib.format("~2..0s", [Integer.to_char_list(h)]),
     ':',
     :io_lib.format("~2..0s", [Integer.to_char_list(n)]),
     ':',
     :io_lib.format("~2..0s", [Integer.to_char_list(s)]),
     ' ',
     Integer.to_char_list(y)] |> List.flatten |> List.to_string
  end

  defp trim_crlf(charlist) do
    case Enum.reverse(charlist) do
      [?\n, ?\r | text] -> Enum.reverse(text)
      _ -> charlist
    end
  end

  defp weave(xs, ys), do: do_weave(xs, ys, [])
  defp do_weave([], ys, result),           do: (ys ++ result) |> Enum.reverse
  defp do_weave(xs, [], result),           do: (xs ++ result) |> Enum.reverse
  defp do_weave([hx|xs], [hy|ys], result), do: do_weave(xs, ys, [hx, hy | result])

end
