defmodule Woody.Thrift.Generator do
  alias Thrift.AST.Schema
  alias Thrift.Parser.FileGroup
  alias Woody.Thrift.Generator.Client
  alias Woody.Thrift.Generator.Codec
  alias Woody.Thrift.Generator.Handler

  def generate!(%FileGroup{} = file_group, namespace, output_path) do
    flat_map(file_group, fn schema ->
      schema
      |> generate_services(namespace)
      |> write_elixir_files(output_path)
    end)
  end

  def targets(%FileGroup{} = file_group, namespace, output_path) do
    flat_map(file_group, fn schema ->
      schema
      |> enumerate_modules(namespace)
      |> Enum.map(&target_path(output_path, &1))
    end)
  end

  defp flat_map(%FileGroup{} = file_group, mapper) do
    Enum.flat_map(file_group.schemas, fn {_, schema} ->
      file_group = FileGroup.set_current_module(file_group, schema.module)
      schema = %Schema{schema | file_group: file_group}
      mapper.(schema)
    end)
  end

  def generate_services(schema, namespace) do
    schema.services
    |> Enum.flat_map(fn {_, service} ->
      [
        Codec.generate(namespace, schema, service),
        Client.generate(namespace, schema, service),
        Handler.generate(namespace, schema, service)
      ]
    end)
  end

  def enumerate_modules(schema, namespace) do
    schema.services
    |> Enum.flat_map(fn {_, service} ->
      [
        Codec.dest_module(namespace, schema, service),
        Client.dest_module(namespace, schema, service),
        Handler.dest_module(namespace, schema, service)
      ]
    end)
  end

  defp write_elixir_files(modules, output_path) do
    modules |> Enum.map(&write_elixir_file(&1, output_path))
  end

  defp write_elixir_file({module_name, ast}, output_path) do
    path = target_path(output_path, module_name)
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, Macro.to_string(ast))
    path
  end

  @spec target_path(Path.t(), module) :: Path.t()
  def target_path(output_path, module_name) do
    path =
      module_name
      |> inspect
      |> String.split(".")
      |> Enum.map(&Macro.underscore/1)
      |> Path.join()

    Path.join(output_path, path <> ".ex")
  end
end
