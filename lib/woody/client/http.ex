defmodule Woody.Client.Http do
  @moduledoc """
  A Woody RPC client over HTTP/1.1 transport protocol.
  """

  alias :woody_client, as: WoodyClient

  @enforce_keys [:service, :ctx]
  defstruct service: nil, codec: nil, ctx: nil, opts: %{}

  @type t :: %__MODULE__{
          service: any,
          codec: module,
          ctx: Woody.Context.t(),
          opts: WoodyClient.options()
        }

  @type url :: String.t()
  @type args :: struct | tuple

  @doc """
  Creates a fresh Woody client given [context](`Woody.Context`) and URL where the server could be
  reached.
  """
  @spec new(Woody.Context.t(), url, any, module, Keyword.t()) :: t
  def new(ctx, url, service, codec, options \\ []) do
    opts = %{
      protocol: :thrift,
      transport: :http,
      event_handler: [],
      url: url
    }

    opts =
      options
      |> Enum.reduce(opts, fn
        {:event_handler, evh}, opts -> %{opts | event_handler: List.wrap(evh)}
        {:transport, transport_opts}, opts -> %{opts | transport_opts: transport_opts}
        {:resolver, resolver_opts}, opts -> %{opts | resolver_opts: resolver_opts}
      end)

    %__MODULE__{
      service: service,
      codec: codec,
      ctx: ctx,
      opts: opts
    }
  end

  @spec call(t, atom, args) :: {:ok, any} | {:exception, any}
  def call(%__MODULE__{} = client, function, args) do
    request = {client.service, function, args}

    opts =
      if client.codec do
        Map.put(client.opts, :codec, client.codec)
      else
        client.opts
      end

    try do
      WoodyClient.call(request, opts, client.ctx)
    catch
      :error, {:woody_error, error} ->
        raise Woody.Errors.from_woody_error(error)
    end
  end
end
