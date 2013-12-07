defmodule ExIrc.Utils do

  alias ExIrc.Client.IrcMessage, as: IrcMessage

  ######################
  # IRC Message Parsing
  ######################

  @doc """
  Parse an IRC message
  """
  def parse(raw_data) do
    [[?: | from] | rest] = :string.tokens(raw_data, ' ')
    get_cmd rest, parse_from(from, IrcMessage.new(ctcp: false))
  end

  defp parse_from(from, msg) do
    case Regex.split(%r/(!|@|\.)/, from) do
      [nick, '!', user, '@', host | host_rest] ->
        msg.nick(nick).user(user).host(host ++ host_rest)
      [nick, '@', host | host_rest] ->
        msg.nick(nick).host(host ++ host_rest)
      [_, '.' | _] ->
        # from is probably a server name
        msg.server(from)
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
        msg.cmd(ctcp_cmd).args(args).ctcp(true)
      _ ->
        msg.cmd(cmd).ctcp(:invalid)
    end
  end

  defp get_cmd([cmd | rest], msg) do
    get_args(rest, msg.cmd(cmd))
  end


  # Parse command args from message
  defp get_args([], msg) do
    msg.args
    |> Enum.reverse 
    |> Enum.filter(fn(arg) -> arg != [] end)
    |> msg.args
  end

  defp get_args([[':' | first_arg] | rest], msg) do
    args = lc arg inlist [first_arg | rest], do: ' ' ++ arg |> Enum.flatten
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

  def isup([], state), do: state
  def isup([param | rest], state) do
    try do
      isup(rest, isup_param(param, state))
    rescue
      _ -> isup(rest, state)
    end
  end

  def isup_param('CHANTYPES=' ++ channel_prefixes, state) do
    state.channel_prefixes(channel_prefixes)
  end
  def isup_param('NETWORK=' ++ network, state) do
    state.network(network)
  end
  def isup_param('PREFIX=' ++ user_prefixes, state) do
    prefixes = Regex.run(%r/\((.*)\)(.*)/, user_prefixes, capture: :all_but_first) |> List.zip
    state.user_prefixes(prefixes)
  end
  def isup_param(_, state) do
    state
  end

  ###################
  # Helper Functions
  ###################

  @days_of_week   ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
  @months_of_year ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
  def ctcp_time({{y, m, d}, {h, n, s}}) do
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
     integer_to_list(y)] |> List.flatten
  end

end