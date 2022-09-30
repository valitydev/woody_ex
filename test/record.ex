defmodule WoodyTest.Record do
  defmacro extract(from, names) do
    quote do
      require Record
      Enum.each(unquote(names), fn name ->
        Record.defrecord(name, Record.extract(name, from: unquote(from)))
      end)
    end
  end
end
