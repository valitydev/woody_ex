defmodule Woody.Server.Http do
  alias :woody_server_thrift_v2, as: WoodyServer

  @type id :: atom

  defmodule Endpoint do
    @type t :: %__MODULE__{}
    defstruct ip: {0, 0, 0, 0}, port: 0

    @spec loopback() :: t
    def loopback(), do: %__MODULE__{ip: {127, 0, 0, 1}, port: 0}

    @spec any() :: t
    def any(), do: %__MODULE__{ip: {0, 0, 0, 0}, port: 0}

    defimpl String.Chars do
      @spec to_string(Endpoint.t) :: String.t
      def to_string(%Endpoint{ip: ip, port: port}) do
        "#{:inet.ntoa(ip)}:#{port}"
      end
    end

  end

  @spec child_spec(id, Endpoint.t, Handler.t | [Handler.t], Keyword.t) :: Supervisor.child_spec
  def child_spec(id, endpoint, handlers, options \\ []) do
    opts = %{
      protocol: :thrift,
      transport: :http,
      handlers: [],
      event_handler: [],
      ip: endpoint.ip,
      port: endpoint.port,
      additional_routes: List.wrap(handlers)
    }
    opts = options |> Enum.reduce(opts, fn
      ({:transport_opts, transport_opts}, opts) when is_map(transport_opts) ->
        %{opts | transport_opts: transport_opts};
      ({:protocol_opts, protocol_opts}, opts) when is_map(protocol_opts) ->
        %{opts | protocol_opts: protocol_opts};
      ({:shutdown_timeout, timeout}, opts) when is_integer(timeout) and timeout >= 0 ->
        %{opts | shutdown_timeout: timeout}
    end)
    WoodyServer.child_spec(id, opts)
  end

  defmodule Handler do

    @type args :: tuple
    @type hdlopts :: any
    @type throws(_exception) :: no_return

    @type t :: WoodyServer.route(map)

    @callback handle_function(Woody.Thrift.tfunction, args, Woody.Context.t, hdlopts) ::
      any | throws(any)

    defmodule Adapter do
      @behaviour :woody_server_thrift_handler

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
        handlers: [{http_path, {module.__service__(), adapter}}],
        event_handler: []
      }
      opts = options |> Enum.reduce(opts, fn
        ({:event_handler, evh}, opts) ->
          %{opts | event_handler: List.wrap(evh)}
        ({:read_body_opts, read_body_opts}, opts) when is_map(read_body_opts) ->
          %{opts | read_body_opts: read_body_opts};
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
