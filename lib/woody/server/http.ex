defmodule Woody.Server.Http do
  @moduledoc """
  A Woody RPC HTTP/1.1 transport protocol server.
  """

  alias :woody_server_thrift_v2, as: WoodyServer
  alias :woody_server_thrift_handler, as: WoodyHandler

  @type id :: atom

  defmodule Endpoint do
    @moduledoc """
    An IP endpoint consisting of socket address and port number.
    """

    @type family :: :inet.address_family()

    @type t :: %__MODULE__{
      ip: :inet.socket_address(),
      port: :inet.port_number(),
      family: family
    }

    defstruct ip: {0, 0, 0, 0}, port: 0, family: :inet

    @doc "Creates a local endpoint to listen on. Port will be assigned by the host system."
    @spec loopback(family) :: t
    def loopback(family \\ :inet), do: %__MODULE__{ip: :loopback, port: 0, family: family}

    @doc "Creates an endpoint to listen on all network interfaces. Port will be assigned by the host system."
    @spec any(family) :: t
    def any(family), do: %__MODULE__{ip: :any, port: 0, family: family}

    defimpl String.Chars do
      @spec to_string(Endpoint.t) :: String.t
      def to_string(%Endpoint{ip: ip, port: port, family: family}) do
        "#{:inet.ntoa(:inet.translate_ip(ip, family))}:#{port}"
      end
    end

  end

  defmodule Handler do
    @moduledoc """
    A single Woody RPC handler for a [Thrift service](`Woody.Thrift.service`). This module defines
    a behaviour your modules have to implement. Using modules generated with
    (`defservice/2`)[`Woody.Server.Builder.defservice/2`] macro implement this behaviour
    automatically.
    """

    @type args :: tuple
    @type hdlopts :: any
    @type throws(_exception) :: no_return

    @type t :: WoodyServer.route(map)

    @callback service() :: Woody.Thrift.service
    @callback handle_function(Woody.Thrift.tfunction, args, Woody.Context.t, hdlopts) ::
      any | throws(any)

    defmodule Adapter do
      @moduledoc false

      @behaviour WoodyHandler

      @impl true
      def handle_function(function, args, ctx, {innermod, hdlopts}) do
        {:ok, innermod.handle_function(function, args, ctx, hdlopts)}
      end
      def handle_function(function, args, ctx, innermod) do
        handle_function(function, args, ctx, {innermod, nil})
      end
    end

    @spec new(module | {module, hdlopts}, String.t, Keyword.t) :: t
    def new(module, http_path, options \\ []) do
      adapter = {Adapter, module}
      opts = %{
        protocol: :thrift,
        transport: :http,
        handlers: [{http_path, {module.service(), adapter}}],
        event_handler: []
      }
      opts = options |> Enum.reduce(opts, fn
        ({:event_handler, evh}, opts) ->
          %{opts | event_handler: List.wrap(evh)}
        ({:read_body_opts, read_body_opts}, opts) when is_map(read_body_opts) ->
          %{opts | read_body_opts: read_body_opts}
        ({:limits, limits}, opts) when is_map(limits) ->
          %{opts | handler_limits: limits}
      end)
      opts
        |> WoodyServer.get_routes()
        |> List.first()
    end

  end

  @spec endpoint(id) :: Endpoint.t
  def endpoint(id) do
    {ip, port} = WoodyServer.get_addr(id)
    %Endpoint{ip: ip, port: port}
  end

end
