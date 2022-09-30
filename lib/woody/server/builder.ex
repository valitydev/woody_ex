defmodule Woody.Server.Builder do
  @moduledoc """
  This module provides macro facilities to automatically generate handler behaviours and handler
  boilerplate for some [Thrift service](`Woody.Thrift.service()`).
  """

  alias Woody.Server.Builder
  alias Woody.Server.Http.Handler
  alias Woody.Thrift

  @spec defservice(module, Woody.Thrift.service) :: Macro.output
  defmacro defservice(modname, service) do

    callbacks = for function <- Thrift.get_service_functions(service) do
      def_name = gen_function_name(function)
      var_types = gen_variable_types(service, function)
      return_type = gen_return_type(service, function)

      quote do
        @callback unquote(def_name) (unquote_splicing(var_types), Woody.Context.t, Handler.hdlopts) ::
        unquote(return_type) | Handler.throws(any)
      end

    end

    macro = {:quote, [context: Builder], [
      [do: quote do
        require Builder
        Builder.__impl_service__(unquote(modname), unquote(service))
      end]
    ]}

    quote location: :keep do

      defmodule unquote(modname) do

        defmacro __using__(options \\ []) do
          unquote(macro)
        end

        unquote_splicing(callbacks)

      end

    end

  end

  defmacro __impl_service__(modname, service) do
    functions = Thrift.get_service_functions(service)
    handler = for function <- functions do
      def_name = gen_function_name(function)
      var_names = gen_variable_names(service, function, __MODULE__)

      quote do
        defp __handle__(unquote(function), {unquote_splicing(var_names)}, ctx, hdlopts) do
          unquote(def_name)(unquote_splicing(var_names), ctx, hdlopts)
        end
      end

    end

    quote location: :keep do

      @behaviour unquote(modname)

      @behaviour Woody.Server.Http.Handler

      @spec service() :: Woody.Thrift.service
      def service, do: unquote(service)

      @impl Woody.Server.Http.Handler
      def handle_function(function_name, args, context, hdlopts) do
        __handle__(function_name, args, context, hdlopts)
      end

      unquote_splicing(handler)

    end
  end

  defp gen_variable_names(service, function, context) do
    for field <- Thrift.get_function_params(service, function) do
      field
        |> Thrift.get_field_name()
        |> underscore()
        |> Macro.var(context)
    end
  end

  defp gen_variable_types(service, function) do
    for field <- Thrift.get_function_params(service, function) do
      field
        |> Thrift.get_field_type()
        |> Thrift.MacroHelpers.map_type()
    end
  end

  defp gen_return_type(service, function) do
    Thrift.get_function_reply(service, function)
      |> Thrift.MacroHelpers.map_type()
  end

  @spec gen_function_name(atom) :: atom
  defp gen_function_name(function) do
    idiomatic_name = function |> Atom.to_string() |> Macro.underscore()
    String.to_atom("handle_#{idiomatic_name}")
  end

  @spec underscore(atom) :: atom
  defp underscore(atom) do
    atom |> Atom.to_string() |> Macro.underscore() |> String.to_atom()
  end

end
