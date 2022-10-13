defmodule Woody.Thrift.Generator.Typespec do
  alias Thrift.Parser.FileGroup

  alias Thrift.AST.{
    Exception,
    Struct,
    TEnum,
    TypeRef,
    Union
  }

  def from(:void, _), do: quote(do: nil)
  def from(:bool, _), do: quote(do: boolean())
  def from(:string, _), do: quote(do: String.t())
  def from(:binary, _), do: quote(do: binary)
  def from(:i8, _), do: quote(do: Thrift.i8())
  def from(:i16, _), do: quote(do: Thrift.i16())
  def from(:i32, _), do: quote(do: Thrift.i32())
  def from(:i64, _), do: quote(do: Thrift.i64())
  def from(:double, _), do: quote(do: Thrift.double())

  def from(%TypeRef{} = ref, file_group) do
    file_group
    |> FileGroup.resolve(ref)
    |> from(file_group)
  end

  def from(%TEnum{}, _) do
    quote do
      non_neg_integer
    end
  end

  def from(%Union{name: name}, file_group) do
    dest_module = FileGroup.dest_module(file_group, name)

    quote do
      %unquote(dest_module){}
    end
  end

  def from(%Exception{name: name}, file_group) do
    dest_module = FileGroup.dest_module(file_group, name)

    quote do
      %unquote(dest_module){}
    end
  end

  def from(%Struct{name: name}, file_group) do
    dest_module = FileGroup.dest_module(file_group, name)

    quote do
      %unquote(dest_module){}
    end
  end

  def from({:set, t}, file_group) do
    quote do
      MapSet.t(unquote(from(t, file_group)))
    end
  end

  def from({:list, t}, file_group) do
    quote do
      [unquote(from(t, file_group))]
    end
  end

  def from({:map, {k, v}}, file_group) do
    key_type = from(k, file_group)
    val_type = from(v, file_group)

    quote do
      %{unquote(key_type) => unquote(val_type)}
    end
  end
end
