defmodule Woody.UnexpectedError do

  @type t :: %__MODULE__{
    source: :internal | :external,
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

  @type t :: %__MODULE__{
    source: :internal | :external,
    class: :resource_unavailable | :result_unknown,
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
