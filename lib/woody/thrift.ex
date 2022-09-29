defmodule Woody.Thrift do

  @type service :: {module, atom}
  @type tfunction :: atom

  @type field :: {tag, requiredness, ttype, name, _default :: any}
  @type tag :: pos_integer
  @type requiredness :: :required | :optional | :undefined
  @type name :: atom

  @type ttyperef :: {module, atom}
  @type ttype ::
    :bool |
    :byte |
    :i16 |
    :i32 |
    :i64 |
    :string |
    :double |
    {:enum, ttyperef} |
    {:struct, :struct | :union | :exception, ttyperef} |
    {:list, ttype} |
    {:set, ttype} |
    {:map, ttype, ttype}

  @spec get_service_functions(service) :: list(tfunction)
  def get_service_functions({mod, service}) do
    apply(mod, :functions, [service])
  end

  @spec get_function_params(service, tfunction) :: list(field)
  def get_function_params({mod, service}, function) do
    {:struct, _, params} = apply(mod, :function_info, [service, function, :params_type])
    params
  end

  @spec get_function_reply(service, tfunction) :: ttype
  def get_function_reply({mod, service}, function) do
    apply(mod, :function_info, [service, function, :reply_type])
  end

  @spec get_function_exceptions(service, tfunction) :: [ttype]
  def get_function_exceptions({mod, service}, function) do
    {:struct, _, fields} = apply(mod, :function_info, [service, function, :exceptions])
    for field <- fields do
      get_field_type(field)
    end
  end

  @spec get_field_name(field) :: name
  def get_field_name({_n, _req, _type, name, _default}), do: name

  @spec get_field_type(field) :: ttype
  def get_field_type({_n, _req, type, _name, _default}), do: type

  defmodule MacroHelpers do

    @spec map_type(Woody.Thrift.ttype) :: Macro.t
    def map_type(:byte), do: quote do: -0x80..0x7F
    def map_type(:i8), do: quote do: -0x80..0x7F
    def map_type(:i16), do: quote do: -0x8000..0x7FFF
    def map_type(:i32), do: quote do: -0x80000000..0x7FFFFFFF
    def map_type(:i64), do: quote do: -0x8000000000000000..0x7FFFFFFFFFFFFFFF
    def map_type(:double), do: quote do: float
    def map_type(:bool), do: quote do: bool
    def map_type(:string), do: quote do: String.t
    def map_type({:struct, _flavor, []}), do: :ok
    def map_type({:struct, _flavor, {mod, name}}) do
      quote do: unquote(mod).unquote(name)
    end
    def map_type({:enum, {mod, name}}) do
      quote do: unquote(mod).unquote(name)
    end
    def map_type({:list, eltype}) do
      quote do: [unquote(map_type(eltype))]
    end
    def map_type({:set, eltype}) do
      quote do: [unquote(map_type(eltype))]
    end
    def map_type({:map, ktype, vtype}) do
      quote do: %{unquote(map_type(ktype)) => unquote(map_type(vtype))}
    end

  end

end
