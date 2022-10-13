defmodule Woody.Thrift.Generator.Codec do
  alias Thrift.AST.Function
  alias Thrift.Generator.Service
  alias Thrift.Generator.Utils
  alias Thrift.Parser.FileGroup
  alias Woody.Thrift.Generator.Utils, as: WoodyUtils

  def generate(namespace, schema, service) do
    dest_module = WoodyUtils.dest_module(namespace, schema, service, Codec)
    service_module = WoodyUtils.service_module(schema, service)

    aliases =
      service.functions
      |> Map.values()
      |> Enum.map(&generate_function_aliases(schema, service, &1))
      |> Utils.merge_blocks()

    rpc_types =
      service.functions
      |> Map.values()
      |> Enum.map(&generate_rpc_type_function(service_module, &1))
      |> Utils.merge_blocks()

    codecs =
      service.functions
      |> Map.values()
      |> Enum.map(&generate_codec_functions(schema, service_module, &1))
      |> Utils.merge_blocks()
      |> Utils.sort_defs()

    {dest_module,
     quote do
       defmodule unquote(dest_module) do
         @moduledoc false

         alias Woody.Thrift.Codec
         unquote_splicing(aliases)

         def get_service_name(unquote(service_module)) do
           unquote(WoodyUtils.unqualified_name(service))
         end

         unquote_splicing(rpc_types)

         def read_call(buffer, unquote(service_module)) do
           Codec.read_call(buffer, &read_call/4)
         end

         unquote_splicing(codecs)
       end
     end}
  end

  defp generate_function_aliases(schema, service, %Function{oneway: false} = function) do
    args_module = Service.module_name(function, :args)
    resp_module = Service.module_name(function, :response)

    quote do
      alias unquote(WoodyUtils.service_module(schema, service, args_module))
      alias unquote(WoodyUtils.service_module(schema, service, resp_module))
    end
  end

  defp generate_function_aliases(schema, service, %Function{oneway: true} = function) do
    args_module = Service.module_name(function, :args)

    quote do
      alias unquote(WoodyUtils.service_module(schema, service, args_module))
    end
  end

  defp generate_rpc_type_function(service_module, function) do
    type =
      case function.oneway do
        false -> :call
        true -> :cast
      end

    quote do
      def get_rpc_type(unquote(service_module), unquote(function.name)) do
        unquote(type)
      end
    end
  end

  defp generate_codec_functions(schema, service_module, function) do
    quote do
      unquote(generate_write_call(service_module, function))
      unquote(generate_read_call(function))
      unquote(generate_write_result(schema, service_module, function))
      unquote(generate_read_result(service_module, function))
    end
  end

  defp generate_write_call(service_module, %Function{name: name, oneway: oneway?} = function) do
    args_module = Service.module_name(function, :args)

    quote do
      def write_call(
            buffer,
            unquote(service_module),
            unquote(name),
            %unquote(args_module){} = args,
            seqid
          ) do
        Codec.write_call(
          buffer,
          unquote(oneway?),
          unquote(Atom.to_string(name)),
          unquote(args_module).serialize(args),
          seqid
        )
      end
    end
  end

  defp generate_read_call(%Function{name: name} = function) do
    args_module = Service.module_name(function, :args)

    quote do
      def read_call(buffer, type, unquote(Atom.to_string(name)), seqid) do
        case unquote(args_module).deserialize(buffer) do
          {args, rest} ->
            {:ok, seqid, {type, unquote(name), args}, rest}

          :error ->
            {:error, {:invalid_args, buffer}}
        end
      end
    end
  end

  defp generate_write_result(
         schema,
         service_module,
         %Function{name: name, oneway: false} = function
       ) do
    resp_module = Service.module_name(function, :response)

    exceptions =
      function.exceptions
      |> Enum.map(&FileGroup.resolve(schema.file_group, &1))
      |> Enum.map(&generate_write_exception(schema, service_module, function, &1))

    quote do
      def write_result(buffer, unquote(service_module), unquote(name), {:reply, success}, seqid) do
        Codec.write_result(
          buffer,
          unquote(Atom.to_string(name)),
          unquote(resp_module).serialize(%unquote(resp_module){success: success}),
          seqid
        )
      end

      unquote_splicing(exceptions)
    end
  end

  defp generate_write_result(_schema, service_module, %Function{name: name, oneway: true}) do
    quote do
      def write_result(buffer, unquote(service_module), unquote(name), _resp, _seqid) do
        {:ok, buffer}
      end
    end
  end

  defp generate_write_exception(schema, service_module, function, exception) do
    resp_module = Service.module_name(function, :response)
    exception_module = FileGroup.dest_module(schema.file_group, exception.type)

    quote do
      def write_result(
            buffer,
            unquote(service_module),
            unquote(function.name),
            {:exception, unquote(exception_module), %unquote(exception_module){} = ex},
            seqid
          ) do
        Codec.write_result(
          buffer,
          unquote(Atom.to_string(function.name)),
          unquote(resp_module).serialize(%unquote(resp_module){unquote(exception.name) => ex}),
          seqid
        )
      end
    end
  end

  defp generate_read_result(service_module, %Function{name: name, oneway: false} = function) do
    resp_module = Service.module_name(function, :response)

    quote do
      def read_result(buffer, unquote(service_module), unquote(name), seqid) do
        Codec.read_result(
          buffer,
          unquote(Atom.to_string(name)),
          unquote(resp_module),
          seqid
        )
      end
    end
  end

  defp generate_read_result(service_module, %Function{name: name, oneway: true}) do
    quote do
      def read_result(_buffer, unquote(service_module), unquote(name), _seqid) do
        :ok
      end
    end
  end
end
