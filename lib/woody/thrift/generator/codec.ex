defmodule Woody.Thrift.Generator.Codec do
  alias Thrift.AST.Function
  alias Thrift.AST.Schema
  alias Thrift.AST.Service
  alias Thrift.Generator.Service
  alias Thrift.Parser.FileGroup
  alias Woody.Thrift.Generator.Utils, as: WoodyUtils

  @spec generate_function_aliases(Schema.t(), Service.t(), Function.t()) :: Macro.t()
  def generate_function_aliases(schema, service, %Function{oneway: false} = function) do
    args_module = Service.module_name(function, :args)
    resp_module = Service.module_name(function, :response)

    quote do
      alias unquote(WoodyUtils.service_module(schema, service, args_module))
      alias unquote(WoodyUtils.service_module(schema, service, resp_module))
    end
  end

  def generate_function_aliases(schema, service, %Function{oneway: true} = function) do
    args_module = Service.module_name(function, :args)

    quote do
      alias unquote(WoodyUtils.service_module(schema, service, args_module))
    end
  end

  @spec generate_function_rpc_type(Schema.t(), Service.t(), Function.t()) :: Macro.t()
  def generate_function_rpc_type(schema, service, function) do
    service_module = WoodyUtils.service_module(schema, service)

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

  @spec generate_write_call(Schema.t(), Service.t(), Function.t()) :: Macro.t()
  def generate_write_call(schema, service, %Function{name: name, oneway: oneway?} = function) do
    service_module = WoodyUtils.service_module(schema, service)
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

  @spec generate_read_call(Function.t()) :: Macro.t()
  def generate_read_call(%Function{name: name} = function) do
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

  @spec generate_write_result(Schema.t(), Service.t(), Function.t()) :: Macro.output()
  def generate_write_result(schema, service, %Function{name: name, oneway: false} = function) do
    service_module = WoodyUtils.service_module(schema, service)
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

  def generate_write_result(_schema, _service, %Function{oneway: true}) do
    quote do
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

  @spec generate_read_result(Schema.t(), Service.t(), Function.t()) :: Macro.t()
  def generate_read_result(schema, service, %Function{name: name, oneway: false} = function) do
    service_module = WoodyUtils.service_module(schema, service)
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

  def generate_read_result(schema, service, %Function{name: name, oneway: true}) do
    service_module = WoodyUtils.service_module(schema, service)

    quote do
      def read_result(_buffer, unquote(service_module), unquote(name), _seqid) do
        :ok
      end
    end
  end
end
