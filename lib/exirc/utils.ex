defmodule ExIrc.Utils do

  alias ExIrc.Client.IrcMessage, as: IrcMessage

  @doc """
  Parse IRC message data
  """
  def parse(raw_data) do
    data = String.slice(raw_data, 1, String.length(raw_data) - 2)
    case data do
      <<":", _ :: binary>> ->
        [<<":", from :: binary>>, rest] = String.split(data, " ")
        get_cmd rest, parse_from(from, IrcMessage.new(ctcp: false)
      data ->
        get_cmd String.split(data, " "), IrcMessage.new(ctcp: false)
    end.
  end

  def parse_from(from, msg) do
    case Regex.split(%r/(!|@|\.)/, from) do
      [nick, "!", user, "@", host | host_rest] ->
        IrcMessage.new(nick: nick, user: user, host: host <> host_rest)
      [nick, "@", host | host_rest] ->
        IrcMessage.new(nick: nick, host: host <> host_rest)
      [_, "." | _] ->
        # from is probably a server name
        IrcMessage.new(server: from)
      [nick] ->
        IrcMessage.new(nick: nick)
    end
  end

  def get_cmd([cmd, arg1, [':', 1 | ctcp_trail] | rest], msg) when cmd == 'PRIVMSG' or cmd == 'NOTICE' do
    get_cmd([cmd, arg1, [1 | ctcp_trail] | rest], msg)
  end
  def get_cmd([cmd, _arg1, [1 | ctcp_trail] | rest], msg) when cmd == 'PRIVMSG' or cmd == 'NOTICE' do
    list = (ctcp_trail ++ (lc arg inlist rest, do: ' ' ++ arg))
            |> Enum.flatten
            |> Enum.reverse
    case list do
      [1 | ctcp_rev] ->
        [ctcp_cmd | args] = Enum.reverse(ctcp_rev) |> String.split(' ')
        msg[cmd: ctcp_cmd, args: args, ctcp: true]
      _ ->
        msg[cmd: cmd, ctcp: :invalid]
    end
  end
  def get_cmd([cmd | rest], msg) do
    get_args(rest, msg.cmd(cmd))
  end

  def get_args([], msg) do
    msg.args(Enum.reverse(msg.args))
  end
  def get_args([[':' | first_arg] | rest], msg) do
    list = lc arg inlist [first_arg | rest], do: ' ' ++ arg
    case Enum.flatten(list) do
      [_ | []] ->
          get_args([], msg.args(['' | msg.args]))
      [_ | full_trail] ->
          get_args([], msg.args([full_trail | msg.args]))
    end
  end
  def get_args([arg | []], msg) do
    get_args([], msg.args(['', arg | msg.args]))
  end
  def get_args([arg | rest], msg) do
    get_args(rest, msg.args([arg | msg.args]))
  end

  ##########################
  # Parse RPL_ISUPPORT (005)
  ##########################
  def isup([], state) do: state
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
    result = Regex.run(%r/\((.*)\)(.*)/, user_prefixes, [:capture, :all_but_first])
    {match, [{p1, l1}, {p2, l2}]} = result
    group1 = String.slice(user_prefixes, p1 + 1, l1)
    group2 = String.slice(user_prefixes, p2 + 1, l2)
    state.user_prefixes(Enum.zip(group1, group2))
  end
  def isup_param(_, state) do
    state
  end

  @days_of_week   ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
  @months_of_year ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
  def ctcp_time({{y, m, d}, {h, n, s}}) ->
    [:lists.nth(:calendar.day_of_the_week(y,m,d), @days_of_week),
     " ",
     :lists:nth(m, @months_of_year),
     " ",
     :io_lib.format('~2..0s',[integer_to_list(d)]),
     " ",
     :io_lib.format('~2..0s',[integer_to_list(h)]),
     ":",
     :io_lib.format('~2..0s',[integer_to_list(n)]),
     ":",
     :io_lib.format('~2..0s',[integer_to_list(s)]),
     " ",
     integer_to_list(y)]
  end

end