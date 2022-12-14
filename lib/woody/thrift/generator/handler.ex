defmodule Woody.Thrift.Generator.Handler do
  alias Thrift.AST.Field
  alias Thrift.AST.Function
  alias Thrift.Generator.Utils
  alias Thrift.Parser.FileGroup
  alias Woody.Thrift.Generator
  alias Woody.Thrift.Generator.Typespec
  alias Woody.Thrift.Generator.Utils, as: WoodyUtils

  def dest_module(namespace, schema, service) do
    WoodyUtils.dest_module(namespace, schema, service, Handler)
  end

  def generate(namespace, schema, service) do
    dest_module = dest_module(namespace, schema, service)

    constructor =
      generate_constructor(schema, service)
      |> List.wrap()
      |> Utils.merge_blocks()

    codec = generate_codec(schema, service)

    handlers =
      service.functions
      |> Map.values()
      |> Enum.map(&generate_handler(&1))

    callbacks =
      service.functions
      |> Map.values()
      |> Enum.map(&generate_callback(schema, &1))

    {dest_module,
     quote do
       defmodule unquote(dest_module) do
         @moduledoc false
         alias Woody.Server.Http.Handler

         unquote_splicing(callbacks)

         defmodule Dispatcher do
           @moduledoc false
           unquote_splicing(handlers)
         end

         unquote(codec)

         unquote_splicing(constructor)
       end
     end}
  end

  defp generate_codec(schema, service) do
    service_module = WoodyUtils.service_module(schema, service)
    functions = service.functions |> Map.values()

    aliases =
      functions
      |> Enum.map(&Generator.Codec.generate_function_aliases(schema, service, &1))
      |> Utils.merge_blocks()

    read_call_codecs =
      functions
      |> Enum.map(&Generator.Codec.generate_read_call/1)
      |> Utils.merge_blocks()

    write_result_codecs =
      functions
      |> Enum.map(&Generator.Codec.generate_write_result(schema, service, &1))
      |> Utils.merge_blocks()

    quote do
      defmodule Codec do
        @moduledoc false

        @behaviour :woody_server_codec

        alias Woody.Thrift.Codec
        unquote_splicing(aliases)

        @impl true
        def get_service_name(unquote(service_module)) do
          unquote(WoodyUtils.unqualified_name(service))
        end

        @impl true
        def read_call(buffer, unquote(service_module)) do
          Codec.read_call(buffer, &read_call/4)
        end

        unquote_splicing(read_call_codecs)

        @impl true
        unquote_splicing(write_result_codecs)
      end
    end
  end

  defp generate_constructor(schema, service) do
    service_module = WoodyUtils.service_module(schema, service)

    quote do
      @spec new(Handler.handler(), String.t(), Keyword.t()) :: Handler.t()
      def new(handler, http_path, options \\ []) do
        Handler.new(
          {Dispatcher, Handler.expand(handler)},
          http_path,
          unquote(service_module),
          Codec,
          options
        )
      end
    end
  end

  defp generate_handler(%Function{name: name, params: []}) do
    quote do
      def handle_function(unquote(name), _args, ctx, {handler, hdlopts}) do
        handler.unquote(Utils.underscore(name))(ctx, hdlopts)
      end
    end
  end

  defp generate_handler(%Function{name: name, params: params}) do
    vars =
      Enum.map(params, fn field ->
        quote do
          args.unquote(field.name)
        end
      end)

    quote do
      def handle_function(unquote(name), args, ctx, {handler, hdlopts}) do
        handler.unquote(Utils.underscore(name))(unquote_splicing(vars), ctx, hdlopts)
      end
    end
  end

  defp generate_callback(schema, function) do
    file_group = schema.file_group
    callback_name = Utils.underscore(function.name)

    params =
      function.params
      |> Enum.map(&FileGroup.resolve(file_group, &1))
      |> Enum.map(&generate_arg_spec(&1, file_group))

    reply_type = generate_reply_spec(function.return_type, file_group)

    exception_types =
      function.exceptions
      |> Enum.map(&generate_exception_spec(&1, file_group))

    return_type = Typespec.sum([reply_type | exception_types])

    quote do
      @callback unquote(callback_name)(
                  unquote_splicing(params),
                  ctx :: Woody.Context.t(),
                  hdlops :: Handler.hdlopts()
                ) :: unquote(return_type)
    end
  end

  defp generate_arg_spec(%Field{name: name, type: type}, file_group) do
    quote do
      unquote(Macro.var(name, nil)) :: unquote(Typespec.from(type, file_group))
    end
  end

  defp generate_reply_spec(:void, _file_group) do
    :ok
  end

  defp generate_reply_spec(type, file_group) do
    {:ok, Typespec.from(type, file_group)}
  end

  defp generate_exception_spec(%Field{type: type}, file_group) do
    {:error, Typespec.from(type, file_group)}
  end
end
