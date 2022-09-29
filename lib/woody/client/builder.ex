defmodule Woody.Client.Builder do
  alias Woody.Thrift

  defmacro __using__(options) do
    service = Keyword.fetch!(options, :service)
    for function <- Thrift.get_service_functions(service) do
      def_name = underscore(function)
      variable_names = gen_variable_names(service, function, __MODULE__)
      variable_types = gen_variable_types(service, function)
      return_type = {:ok, gen_return_type(service, function)}
      exception_types = gen_exception_types(service, function)
      result_type = if Enum.empty?(exception_types) do
        return_type
      else
        Enum.reduce(exception_types, return_type, fn type, acc ->
          {:|, [], [{:exception, type}, acc]}
        end)
      end

      quote location: :keep do
        @spec unquote(def_name) (Woody.Client.Http.t, unquote_splicing(variable_types)) ::
          unquote(result_type)
        def unquote(def_name) (client, unquote_splicing(variable_names)) do
          Woody.Client.Http.call(
            client,
            unquote(service),
            unquote(function),
            {unquote_splicing(variable_names)}
          )
        end
      end

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

  defp gen_exception_types(service, function) do
    for type <- Thrift.get_function_exceptions(service, function) do
      Thrift.MacroHelpers.map_type(type)
    end
  end

  defp gen_return_type(service, function) do
    Thrift.get_function_reply(service, function)
      |> Thrift.MacroHelpers.map_type()
  end

  @spec underscore(atom) :: atom
  defp underscore(atom) do
    atom |> to_string() |> Macro.underscore() |> String.to_atom()
  end

end
