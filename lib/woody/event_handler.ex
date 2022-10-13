defmodule Woody.EventHandler do
  @moduledoc false

  alias :woody_event_handler, as: WoodyEventHandler

  @type event :: WoodyEventHandler.event()
  @type meta :: WoodyEventHandler.meta()

  defmodule Formatter do
    def format(rpc_id, event, meta) do
      "#{format_rpc_id(rpc_id)} #{format(event, meta)}"
    end

    def format(:"call service", meta) do
      "[client] calling #{meta.service}:#{meta.function} #{inspect(meta.args)}"
    end

    def format(:"service result", %{status: :ok} = meta) do
      "[client] request handled successfully: #{inspect(meta.result)}"
    end

    def format(:"service result", %{status: :error} = meta) do
      "[client] request handling error: #{format_error(meta)}"
    end

    def format(:"invoke service handler", meta) do
      "[server] handling #{meta.service}:#{meta.function} #{inspect(meta.args)}"
    end

    def format(:"service handler result", %{status: :ok} = meta) do
      "[server] handling result: #{inspect(meta.result)}"
    end

    def format(:"service handler result", %{status: :error, class: :business} = meta) do
      "[server] handling exception: #{inspect(meta.result)}"
    end

    def format(:"service handler result", %{status: :error, class: :system} = meta) do
      "[server] handling system error: #{format_error(meta)}"
    end

    def format(:"internal error", meta) do
      "[#{meta.role}] internal error: #{format_error(meta)}"
    end

    def format(event, meta) do
      {fmt, args} = WoodyEventHandler.format_event(event, meta, %{})
      :io_lib.format(fmt, args)
    end

    def format_error(%{result: {:system, error}, class: :system} = meta) do
      stack = Map.get(meta, :stack, [])
      Exception.format(:error, Woody.Errors.from_woody_error(error), stack)
    end

    def format_error(%{result: error} = meta) do
      # class = Map.get(meta, :class, :error)
      stack = Map.get(meta, :stack, [])
      Exception.format(:error, error, stack)
    end

    def format_rpc_id(%{span_id: span, trace_id: trace, parent_id: parent}) do
      "[#{trace} #{parent} #{span}]"
    end

    def format_rpc_id(_) do
      "[undefined]"
    end
  end

  defmodule Default do
    alias Woody.EventHandler
    require Logger

    @behaviour WoodyEventHandler

    @exposed_meta [
      :event,
      :service,
      :function,
      :type,
      :metadata,
      :url,
      :deadline,
      :execution_duration_ms
    ]

    @spec handle_event(EventHandler.event(), Woody.Context.rpc_id(), EventHandler.meta(), any) ::
            any
    def handle_event(event, rpc_id, meta, _opts) do
      level = WoodyEventHandler.get_event_severity(event, meta)

      Logger.log(
        level,
        Formatter.format(rpc_id, event, meta),
        WoodyEventHandler.format_meta(event, meta, @exposed_meta)
      )
    end
  end
end
