defmodule Woody.Context do

  alias :woody_context, as: WoodyContext

  @type t :: WoodyContext.ctx

  @spec new() :: t
  def new() do
    WoodyContext.new()
  end

  @spec new(keyword) :: t
  def new(opts) do
    rpc_id = Keyword.get(opts, :rpc_id) || new_rpc_id(Keyword.get(opts, :trace_id))
    meta = Keyword.get(opts, :meta) || :undefined
    deadline = Keyword.get(opts, :deadline) || :undefined
    WoodyContext.new(rpc_id, meta, deadline)
  end

  defp new_rpc_id(trace_id) when is_binary(trace_id) do
    WoodyContext.new_rpc_id("undefined", trace_id, WoodyContext.new_req_id())
  end
  defp new_rpc_id(nil) do
    WoodyContext.new_req_id() |> WoodyContext.new_rpc_id()
  end

  @spec child(t) :: t
  def child(ctx) do
    WoodyContext.new_child(ctx)
  end

end
