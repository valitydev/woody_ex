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
      @spec to_string(Endpoint.t()) :: String.t()
      def to_string(%Endpoint{ip: ip, port: port, family: family}) do
        "#{:inet.ntoa(:inet.translate_ip(ip, family))}:#{port}"
      end
    end
  end

  defmodule Handler do
    @moduledoc """
    A single Woody RPC handler for a Thrift service. This module defines
    a behaviour your modules have to implement. Using `Handler` modules generated with
    (woody generator)[Woody.Thrift.Generator.Handler] implement this behaviour automatically.
    """

    @type handler :: module | {module, hdlopts}
    @type hdlopts :: any
    @type args :: struct | tuple
    @type throws(_exception) :: no_return

    @type t :: WoodyServer.route(map)

    @callback handle_function(atom, args, Woody.Context.t(), hdlopts) ::
                any | throws(any)

    defmodule Adapter do
      @moduledoc false

      alias :woody_error, as: WoodyError

      @behaviour WoodyHandler

      @impl true
      def handle_function(function, args, ctx, {innermod, hdlopts}) do
        innermod.handle_function(function, args, ctx, hdlopts)
      else
        :ok ->
          {:ok, nil}

        {:ok, success} ->
          {:ok, success}

        {:error, %type{} = ex} ->
          {:exception, type, ex}
      rescue
        error in [Woody.UnexpectedError, Woody.BadResultError] ->
          WoodyError.raise(:system, error |> Woody.Errors.to_woody_error())
      catch
        :throw, %type{} = ex ->
          {:exception, type, ex}
      end
    end

    @spec new(handler, String.t(), any, module, Keyword.t()) :: t
    def new(handler, http_path, service, codec, options \\ []) do
      adapter = {Adapter, expand(handler)}

      opts = %{
        protocol: :thrift,
        transport: :http,
        handlers: [{http_path, {service, adapter}}],
        event_handler: []
      }

      opts =
        if codec do
          opts |> Map.put(:codec, codec)
        else
          opts
        end

      opts =
        options
        |> Enum.reduce(opts, fn
          {:event_handler, evh}, opts ->
            %{opts | event_handler: List.wrap(evh)}

          {:read_body_opts, read_body_opts}, opts when is_map(read_body_opts) ->
            %{opts | read_body_opts: read_body_opts}

          {:limits, limits}, opts when is_map(limits) ->
            %{opts | handler_limits: limits}
        end)

      opts
      |> WoodyServer.get_routes()
      |> List.first()
    end

    @spec expand(handler) :: handler
    def expand({module, _} = handler) when is_atom(module), do: handler
    def expand(module) when is_atom(module), do: {module, nil}
  end

  @spec child_spec(id, Endpoint.t(), Handler.t() | [Handler.t()], Keyword.t()) ::
          Supervisor.child_spec()
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

    opts =
      options
      |> Enum.reduce(opts, fn
        {:transport_opts, transport_opts}, opts when is_map(transport_opts) ->
          %{opts | transport_opts: transport_opts}

        {:protocol_opts, protocol_opts}, opts when is_map(protocol_opts) ->
          %{opts | protocol_opts: protocol_opts}

        {:shutdown_timeout, timeout}, opts when is_integer(timeout) and timeout >= 0 ->
          %{opts | shutdown_timeout: timeout}
      end)

    WoodyServer.child_spec(id, opts)
  end

  @spec endpoint(id) :: Endpoint.t()
  def endpoint(id) do
    {ip, port} = WoodyServer.get_addr(id)
    %Endpoint{ip: ip, port: port}
  end
end
