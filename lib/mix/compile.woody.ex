defmodule Mix.Tasks.Compile.Woody do
  use Mix.Task.Compiler
  alias Mix.Task.Compiler.Diagnostic
  alias Thrift.Parser.FileGroup
  alias Woody.Thrift.Generator

  @recursive true
  @manifest ".compile.woody"

  @shortdoc "Generates Woody RPC ready Elixir code from Thrift IDL files"

  @defaults [
    namespace: "Woody.Generated",
    output_path: "lib",
    verbose: false
  ]

  @impl true
  def run(args) do
    {opts, _} =
      OptionParser.parse!(
        args,
        switches: [verbose: :boolean],
        aliases: [v: :verbose]
      )

    config =
      @defaults
      |> Keyword.merge(Keyword.get(Mix.Project.config(), :woody, []))
      |> Keyword.merge(opts)

    thrift_config = Keyword.get(Mix.Project.config(), :thrift, [])

    case parse_thrift_files(thrift_config) do
      {:ok, []} ->
        :noop

      {:ok, groups} ->
        artifacts = Enum.flat_map(groups, &generate(&1, config))
        timestamp = :calendar.universal_time()
        sync_manifest(manifest_path(), artifacts, timestamp, config)

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

  defp generate(group, config) do
    artifacts = artifacts(group, config)

    if stale?(group, artifacts) do
      info("Generating artifacts from #{inspect(group.initial_file)}", config)
      paths = Generator.generate!(group, config[:namespace], config[:output_path])

      for path <- paths do
        info("Generated artifact: #{inspect(path)}", config)
      end
    end

    artifacts
  end

  @spec stale?(FileGroup.t(), [Path.t()]) :: boolean
  defp stale?(group, targets) do
    Mix.Utils.stale?([group.initial_file], targets)
  end

  @spec artifacts(FileGroup.t(), Keyword.t()) :: [Path.t()]
  defp artifacts(group, config) do
    Generator.targets(group, config[:namespace], config[:output_path])
  end

  @impl true
  def manifests, do: [manifest_path()]

  @impl true
  def clean do
    manifest = manifest_path()
    Enum.each(read_manifest(manifest), &File.rm/1)
    File.rm(manifest)
  end

  @spec manifest_path() :: Path.t()
  defp manifest_path do
    Path.join(Mix.Project.manifest_path(), @manifest)
  end

  @spec sync_manifest(Path.t(), [Path.t()], File.erlang_time(), Keyword.t()) :: :ok
  defp sync_manifest(path, artifacts, timestamp, config) do
    artifacts =
      artifacts
      |> Enum.uniq()
      |> Enum.sort()

    previous = read_manifest(path, config)
    remove_orphans(previous -- artifacts, config)
    write_manifest(path, artifacts, timestamp)
  end

  @spec remove_orphans([Path.t()], Keyword.t()) :: nil
  defp remove_orphans(orphans, config) do
    remove_orphans(orphans, &remove_artifact/2, config)
  end

  defp remove_orphans([], _rm, _config), do: nil

  defp remove_orphans(orphans, rm, config) do
    orphans
    |> Enum.flat_map(fn orphan ->
      case rm.(orphan, config) do
        :ok -> [Path.dirname(orphan)]
        _error -> []
      end
    end)
    |> Enum.uniq()
    |> remove_orphans(&remove_directory/2, config)
  end

  defp remove_artifact(path, config) do
    result = File.rm(path)
    info("Removing orphaned artifact #{inspect(path)}: #{inspect(result)}", config)
    result
  end

  defp remove_directory(path, config) do
    result = File.rmdir(path)
    info("Removing orphaned directory #{inspect(path)}: #{inspect(result)}", config)
    result
  end

  @spec read_manifest(Path.t(), Keyword.t()) :: [Path.t()]
  defp read_manifest(path, config \\ []) do
    vsn = version()

    try do
      path
      |> File.read!()
      |> :erlang.binary_to_term()
    rescue
      File.Error ->
        []

      ArgumentError ->
        warning("Manifest #{inspect(path)} looks corrupted, discarding it")
        []
    else
      [{:v1, ^vsn} | artifacts] ->
        artifacts

      [header | _rest] ->
        info("Manifest #{inspect(path)} looks outdated: #{inspect(header)}, ignoring it", config)
        []

      _ ->
        info("Manifest #{inspect(path)} looks invalid, discarding it", config)
        []
    end
  end

  @spec write_manifest(Path.t(), [Path.t()], File.erlang_time()) :: :ok
  defp write_manifest(manifest, paths, timestamp) do
    serial = :erlang.term_to_binary([{:v1, version()} | paths])
    File.mkdir_p!(Path.dirname(manifest))
    File.write!(manifest, serial)
    File.touch!(manifest, timestamp)
  end

  @spec version() :: String.t()
  defp version do
    Keyword.get(Mix.Project.config(), :version, "0")
  end

  defp info(message, config) do
    if config[:verbose] do
      Mix.shell().info(message)
    end
  end

  defp warning(message) do
    Mix.shell().warning(message)
  end
end
