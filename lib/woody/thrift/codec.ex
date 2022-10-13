defmodule Woody.Thrift.Codec do
  alias Thrift.Protocol.Binary

  def read_call(buffer, then) do
    case Binary.deserialize(:message_begin, buffer) do
      {:ok, {type, seqid, function_name, rest}} when type in [:call, :oneway] ->
        then.(rest, type, function_name, seqid)

      {:ok, mismatch} ->
        # raise Thrift.InvalidValueError, "Unexpected call received: #{inspect(mismatch)}"
        {:error, {:unexpected_call, mismatch}}

      {:error, reason} ->
        # raise Thrift.InvalidValueError, "Unexpected data received: #{inspect(reason)}"
        {:error, reason}
    end
  end

  def write_result(buffer, function_name, resp_serial, seqid) do
    {:ok,
     [
       buffer,
       Binary.serialize(:message_begin, {:reply, seqid, function_name}),
       resp_serial
     ]}
  end

  def write_call(buffer, oneway?, function_name, args_serial, seqid) do
    type = if oneway?, do: :oneway, else: :call

    {:ok,
     [
       buffer,
       Binary.serialize(:message_begin, {type, seqid, function_name}),
       args_serial
     ]}
  end

  def read_result(buffer, function_name, resp_module, seqid) do
    case Binary.deserialize(:message_begin, buffer) do
      {:ok, {:reply, ^seqid, ^function_name, rest}} ->
        read_response(rest, resp_module)

      {:ok, {:exception, _, _, rest}} ->
        ex = Binary.deserialize(:application_exception, rest)
        {:ok, {:exception, {:TApplicationException, ex.message, ex.type}}, ""}

      {:ok, mismatch} ->
        # raise Thrift.InvalidValueError, "Unexpected call result received: #{inspect(mismatch)}"
        {:error, {:unexpected_response, mismatch}}

      {:error, reason} ->
        # raise Thrift.InvalidValueError, "Unexpected data received: #{inspect(reason)}"
        {:error, reason}
    end
  end

  defp read_response(rest, resp_module) do
    case resp_module.deserialize(rest) do
      {resp, rest} ->
        {:ok, unwrap_response(resp), rest}

      :error ->
        {:error, {:invalid_response, rest}}
    end
  end

  defp unwrap_response(resp) do
    if resp.success do
      {:reply, resp.success}
    else
      case resp |> Map.from_struct() |> Enum.filter(fn {_, value} -> value end) do
        [] ->
          {:reply, resp.success}

        [{_, exception}] ->
          {:exception, exception}
      end
    end
  end
end
