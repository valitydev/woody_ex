defmodule Woody.Thrift.Generator.Utils do
  alias Thrift.Parser.FileGroup

  def dest_module(namespace, schema, service, suffix) do
    service_module = FileGroup.dest_module(schema.file_group, service)
    Module.concat([namespace, service_module | List.wrap(suffix)])
  end

  def service_module(schema, service, suffix \\ nil) do
    service_module = FileGroup.dest_module(schema.file_group, service)
    Module.concat([service_module | List.wrap(suffix)])
  end

  def unqualified_name(service) do
    service.name
    |> Atom.to_string()
    |> String.split(".", parts: 2)
    |> Enum.at(1)
    |> String.to_atom()
  end
end
