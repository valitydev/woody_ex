defmodule Woody.Context do
  @moduledoc """
  Context holds few important bits information for a single RPC.

  1. A triple of identifiers required to identify a single request in a system and transitively
  correlate it to all other requests issued from a root request. This is called RPC ID and consists
  of _trace id_, _span id_ and _parent id_.

  2. A _ which marks the latest moment of time the caller expects RPC to be handled. If deadline is
  already in the past there's no point to handle it at all.
  """

  alias :woody_context, as: WoodyContext

  @type t :: WoodyContext.ctx

  @doc """
  Creates new root context with automatically generated unique RPC ID.
  """
  @spec new() :: t
  def new do
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

  @doc """
  Creates a child context which inherits `ctx`'s _trace id_ and takes `ctx`'s _span id_ as
  _parent id_.
  """
  @spec child(t) :: t
  def child(ctx) do
    WoodyContext.new_child(ctx)
  end

end
