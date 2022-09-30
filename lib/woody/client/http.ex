defmodule Woody.Client.Http do
  @moduledoc """
  A Woody RPC client over HTTP/1.1 transport protocol.
  """

  alias Woody.Thrift
  alias :woody_client, as: WoodyClient

  @enforce_keys [:ctx]
  defstruct ctx: nil, opts: %{}

  @type t :: %__MODULE__{ctx: Woody.Context.t, opts: WoodyClient.options}

  @type url :: String.t
  @type args :: tuple

  @doc """
  Creates a fresh Woody client given [context](`Woody.Context`) and URL where the server could be
  reached.
  """
  @spec new(Woody.Context.t, url, Keyword.t) :: t
  def new(ctx, url, options \\ []) do
    opts = %{
      protocol: :thrift,
      transport: :http,
      event_handler: [],
      url: url
    }
    opts = options |> Enum.reduce(opts, fn
      {:event_handler, evh}, opts -> %{opts | event_handler: List.wrap(evh)}
      {:transport, transport_opts}, opts -> %{opts | transport_opts: transport_opts}
      {:resolver, resolver_opts}, opts -> %{opts | resolver_opts: resolver_opts}
    end)
    %__MODULE__{
      ctx: ctx,
      opts: opts
    }
  end

  @spec call(t, Thrift.service, Thrift.tfunction, args) :: {:ok, any} | {:exception, any}
  def call(%__MODULE__{} = client, service, function, args) do
    request = {service, function, args}
    try do
      WoodyClient.call(request, client.opts, client.ctx)
    catch
      :error, {:woody_error, {source, :result_unexpected, details}} ->
        raise Woody.UnexpectedError, source: source, details: details
      :error, {:woody_error, {source, class, details}} when class in [
        :resource_unavailable,
        :result_unknown
      ] ->
        raise Woody.BadResultError, source: source, class: class, details: details
    end
end

end
