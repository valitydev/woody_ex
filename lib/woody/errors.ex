defmodule Woody.UnexpectedError do
  @moduledoc """
  This error tells the client that handling an RPC ended unexpectedly, usually as a result of some
  logic error.
  """

  @typedoc """
  Source of the error.
   * _internal_ means that this service instance failed to handle an RPC,
   * _external_ means that some external system failed to do it.
  """
  @type source :: :internal | :external

  @type t :: %__MODULE__{
    source: source,
    details: String.t
  }

  defexception [:source, :details]

  @impl true
  @spec message(t) :: String.t
  def message(ex) do
    verb = case ex.source do
      :internal -> "got"
      :external -> "received"
    end
    "#{verb} an unexpected error: #{ex.details}"
  end

end

defmodule Woody.BadResultError do
  @moduledoc """
  This error tells the client that the result of RPC is unknown, meaning that the client should
  now deal with uncertainty in the system, by retrying it for example.
  """

  @typedoc """
  Source of the error.
   * `:internal` means that this service instance failed to handle an RPC.
   * `:external` means that some external system failed to do it.
  """
  @type source :: :internal | :external

  @typedoc """
  Uncertainty class of the error.
   * `:resource_unavailable` means that the system didn't even attempt to handle an RPC, which in
   turn means that state of the system _definitely_ hasn't changed. This usually happens when the
   server is unreachable or the deadline is already in the past.
   * `:result_unknown` means that RPC has _probably_ reached the server but it didn't respond, the
   system now in the state of uncertainty: the client do not know for sure if RPC has been handled
   or not. This usually happens when the server goes offline or the deadline is reached before
   getting a response.
  """
  @type class :: :resource_unavailable | :result_unknown

  @type t :: %__MODULE__{
    source: source,
    class: class,
    details: String.t
  }

  defexception [:source, :class, :details]

  @impl true
  @spec message(t) :: String.t
  def message(ex) do
    verb = case ex.source do
      :internal -> "got"
      :external -> "received"
    end
    summary = case ex.class do
      :resource_unavailable -> "resource unavailable"
      :result_unknown -> "result is unknown"
    end
    "#{verb} no result, #{summary}: #{ex.details}"
  end

end
