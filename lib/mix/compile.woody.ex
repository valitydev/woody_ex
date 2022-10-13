defmodule Mix.Tasks.Compile.Woody do
  use Mix.Task.Compiler
  alias Mix.Task.Compiler.Diagnostic
  alias Thrift.Parser.FileGroup
  alias Woody.Thrift.Generator

  @shortdoc "Generates Woody RPC ready Elixir code from Thrift IDL files"

  @impl true
  def run(args) do
    {opts, _} =
      OptionParser.parse!(
        args,
        switches: [verbose: :boolean],
        aliases: [v: :verbose]
      )

    woody_config = Keyword.get(Mix.Project.config(), :woody, [])
    thrift_config = Keyword.get(Mix.Project.config(), :thrift, [])

    output_path = opts[:out] || Keyword.get(woody_config, :output_path, "lib")
    namespace = opts[:namespace] || Keyword.get(woody_config, :namespace, "Woody.Generated")

    case parse_thrift_files(thrift_config) do
      {:ok, []} ->
        :noop

      {:ok, groups} ->
        paths = Enum.flat_map(groups, &Generator.generate!(&1, namespace, output_path))

        if opts[:verbose] do
          Enum.each(paths, &Mix.shell().info("Compiled #{&1}"))
        end

        :ok

      {:error, diagnostics} ->
        {:error, diagnostics}
    end
  end

  @spec parse_thrift_files(Keyword.t()) :: {:ok, [FileGroup.t()]} | {:error, [Diagnostic.t()]}
  defp parse_thrift_files(config) do
    opts =
      config
      |> Keyword.take([:include_paths, :namespace])
      |> Keyword.put_new(:namespace, "Thrift.Generated")

    {groups, diagnostics} =
      Keyword.get(config, :files, [])
      |> Enum.map(fn file ->
        case Thrift.Parser.parse_file_group(file, opts) do
          {:ok, group} ->
            {[group], []}

          {:error, errors} ->
            {[], errors}
        end
      end)
      |> Enum.unzip()

    case {List.flatten(groups), List.flatten(diagnostics)} do
      {groups, []} ->
        {:ok, groups}

      {_, errors} ->
        {:error, Enum.map(errors, &diagnostic/1)}
    end
  end

  defp diagnostic({file, line, message}, severity \\ :error) do
    %Diagnostic{
      file: file,
      position: line,
      message: message,
      severity: severity,
      compiler_name: "Woody"
    }
  end
end
