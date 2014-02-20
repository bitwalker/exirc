defmodule ExIrc.Utils do

  alias ExIrc.Client.IrcMessage, as: IrcMessage

  import String, only: [from_char_list!: 1]

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
  @spec parse(raw_data :: char_list) :: ExIrc.Client.IrcMessage.t
  def parse(raw_data) do
    data = :string.substr(raw_data, 1, length(raw_data))
    case data do
      [?:|_] ->
          [[?:|from]|rest] = :string.tokens(data, ' ')
          get_cmd(rest, parse_from(from, IrcMessage[ctcp: false]))
      data ->
          get_cmd(:string.tokens(data, ' '), IrcMessage[ctcp: false])
    end
  end

  defp parse_from(from, msg) do
    case Regex.split(~r/(!|@|\.)/, iolist_to_binary(from)) do
      [nick, "!", user, "@", host | host_rest] ->
        msg.nick(nick).user(user).host(host <> host_rest)
      [nick, "@", host | host_rest] ->
        msg.nick(nick).host(host <> host_rest)
      [_, "." | _] ->
        # from is probably a server name
        msg.server(from_char_list!(from))
      [nick] ->
        msg.nick(nick)
    end
  end

  # Parse command from message
  defp get_cmd([cmd, arg1, [?:, 1 | ctcp_trail] | restargs], msg) when cmd == 'PRIVMSG' or cmd == 'NOTICE' do
    get_cmd([cmd, arg1, [1 | ctcp_trail] | restargs], msg)
  end

  defp get_cmd([cmd, _arg1, [1 | ctcp_trail] | restargs], msg) when cmd == 'PRIVMSG' or cmd == 'NOTICE' do
    args = ctcp_trail ++ lc arg inlist restargs, do: ' ' ++ arg
      |> Enum.flatten
      |> Enum.reverse
    case args do
      [1 | ctcp_rev] ->
        [ctcp_cmd | args] = ctcp_rev |> Enum.reverse |> :string.tokens(' ')
        msg.cmd(from_char_list!(ctcp_cmd)).args(args).ctcp(true)
      _ ->
        msg.cmd(from_char_list!(cmd)).ctcp(:invalid)
    end
  end

  defp get_cmd([cmd | rest], msg) do
    get_args(rest, msg.cmd(from_char_list!(cmd)))
  end


  # Parse command args from message
  defp get_args([], msg) do
    msg.args
    |> Enum.reverse 
    |> Enum.filter(fn(arg) -> arg != [] end)
    |> Enum.map(&String.from_char_list!/1)
    |> msg.args
  end

  defp get_args([[?: | first_arg] | rest], msg) do
    args = (lc arg inlist [first_arg | rest], do: ' ' ++ trim_crlf(arg)) |> List.flatten
    case args do
      [_ | []] ->
          get_args([], msg.args([msg.args]))
      [_ | full_trail] ->
          get_args([], msg.args([full_trail | msg.args]))
    end
  end

  defp get_args([arg | []], msg) do
    get_args([], msg.args([arg | msg.args]))
  end

  defp get_args([arg | rest], msg) do
    get_args(rest, msg.args([arg | msg.args]))
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
    state.channel_prefixes(prefixes)
  end
  defp isup_param("NETWORK=" <> network, state) do
    state.network(network)
  end
  defp isup_param("PREFIX=" <> user_prefixes, state) do
    prefixes = Regex.run(~r/\((.*)\)(.*)/, user_prefixes, capture: :all_but_first)
               |> Enum.map(&String.to_char_list!/1)
               |> List.zip
    state.user_prefixes(prefixes)
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

      iex> local_time = {{2013,12,6},{14,5,00}}
      {{2013,12,6},{14,5,00}}
      iex> ExIrc.Utils.ctcp_time local_time
      "Fri Dec 06 14:05:00 2013"
  """
  @spec ctcp_time(datetime :: {{integer, integer, integer}, {integer, integer, integer}}) :: binary
  def ctcp_time({{y, m, d}, {h, n, s}} = _datetime) do
    [:lists.nth(:calendar.day_of_the_week(y,m,d), @days_of_week),
     ' ',
     :lists.nth(m, @months_of_year),
     ' ',
     :io_lib.format("~2..0s", [integer_to_list(d)]),
     ' ',
     :io_lib.format("~2..0s", [integer_to_list(h)]),
     ':',
     :io_lib.format("~2..0s", [integer_to_list(n)]),
     ':',
     :io_lib.format("~2..0s", [integer_to_list(s)]),
     ' ',
     integer_to_list(y)] |> List.flatten |> String.from_char_list!
  end

  defp trim_crlf(charlist) do
    case Enum.reverse(charlist) do
      [?\n, ?\r | text] -> Enum.reverse(text)
      _ -> charlist
    end
  end

end