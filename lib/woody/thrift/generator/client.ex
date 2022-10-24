defmodule Woody.Thrift.Generator.Client do
  alias Thrift.Generator.Service
  alias Thrift.Generator.Utils
  alias Woody.Thrift.Generator
  alias Woody.Thrift.Generator.Utils, as: WoodyUtils

  def dest_module(namespace, schema, service) do
    WoodyUtils.dest_module(namespace, schema, service, Client)
  end

  def generate(namespace, schema, service) do
    dest_module = dest_module(namespace, schema, service)

    aliases =
      service.functions
      |> Map.values()
      |> Enum.map(&Generator.Codec.generate_function_aliases(schema, service, &1))
      |> Utils.merge_blocks()

    codec = generate_codec(schema, service)

    constructor = generate_constructor(schema, service)

    functions =
      service.functions
      |> Map.values()
      |> Enum.map(&generate_client_function/1)

    functions =
      [constructor | functions]
      |> Utils.merge_blocks()

    {dest_module,
     quote do
       defmodule unquote(dest_module) do
         @moduledoc false

         alias Woody.Client.Http, as: Client

         unquote_splicing(aliases)

         unquote(codec)

         unquote_splicing(functions)
       end
     end}
  end

  defp generate_codec(schema, service) do
    service_module = WoodyUtils.service_module(schema, service)
    functions = service.functions |> Map.values()

    rpc_types =
      functions
      |> Enum.map(&Generator.Codec.generate_function_rpc_type(schema, service, &1))
      |> Utils.merge_blocks()

    write_call_codecs =
      functions
      |> Enum.map(&Generator.Codec.generate_write_call(schema, service, &1))
      |> Utils.merge_blocks()

    read_result_codecs =
      functions
      |> Enum.map(&Generator.Codec.generate_read_result(schema, service, &1))
      |> Utils.merge_blocks()

    quote do
      defmodule Codec do
        @moduledoc false
        @behaviour :woody_client_codec

        alias Woody.Thrift.Codec

        @impl true
        def get_service_name(unquote(service_module)) do
          unquote(WoodyUtils.unqualified_name(service))
        end

        @impl true
        unquote_splicing(rpc_types)

        @impl true
        unquote_splicing(write_call_codecs)

        @impl true
        unquote_splicing(read_result_codecs)
      end
    end
  end

  defp generate_constructor(schema, service) do
    service_module = WoodyUtils.service_module(schema, service)

    quote do
      @spec new(Woody.Context.t(), Client.url(), Keyword.t()) :: Client.t()
      def new(ctx, url, options \\ []) do
        Client.new(ctx, url, unquote(service_module), Codec, options)
      end
    end
  end

  defp generate_client_function(function) do
    args_module = Service.module_name(function, :args)

    # Make two Elixir-friendly function names: an underscored version of the
    # Thrift function name and a "bang!" exception-raising variant.
    function_name =
      function.name
      |> Atom.to_string()
      |> Macro.underscore()
      |> String.to_atom()

    bang_name = :"#{function_name}!"

    # Apply some macro magic to the names to avoid conflicts with Elixir
    # reserved symbols like "and".
    function_name =
      Macro.pipe(
        function_name,
        quote do
          unquote
        end,
        0
      )

    bang_name =
      Macro.pipe(
        bang_name,
        quote do
          unquote
        end,
        0
      )

    vars = Enum.map(function.params, &Macro.var(&1.name, nil))

    assignments =
      function.params
      |> Enum.zip(vars)
      |> Enum.map(fn {param, var} ->
        quote do
          {unquote(param.name), unquote(var)}
        end
      end)

    quote do
      def unquote(function_name)(client, unquote_splicing(vars)) do
        Client.call(
          client,
          unquote(function.name),
          %unquote(args_module){unquote_splicing(assignments)}
        )
      end

      def unquote(bang_name)(client, unquote_splicing(vars)) do
        case unquote(function_name)(client, unquote_splicing(vars)) do
          {:ok, rsp} ->
            rsp

          {:exception, ex} ->
            raise ex
        end
      end
    end
  end
end
