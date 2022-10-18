defmodule WoodyServiceTest do
  use ExUnit.Case

  alias Woody.Generated.WoodyTest.Weapons, as: Service
  alias Woody.Server.Http, as: Server

  alias WoodyTest.Direction
  alias WoodyTest.Weapon
  alias WoodyTest.WeaponFailure

  require Direction

  defmodule TestHandler do
    @moduledoc false

    @behaviour Service.Handler

    def new(http_path, options \\ []) do
      Service.Handler.new(__MODULE__, http_path, options)
    end

    @impl true
    def get_weapon("oops", _data, _ctx, _hdlopts) do
      42 = 1337
    end

    def get_weapon(name, _data, _ctx, _hdlopts) do
      {:ok, %Weapon{name: name, slot_pos: 42, ammo: 9001}}
    end

    @impl true
    def switch_weapon(%Weapon{slot_pos: pos} = current, direction, shift, _data, _ctx, _hdlopts) do
      pos =
        if direction == Direction.next() do
          pos + shift
        else
          pos - shift
        end

      if pos > 0 do
        {:ok, %Weapon{current | slot_pos: pos}}
      else
        {:error, %WeaponFailure{code: "invalid_shift", reason: "Shifted into #{pos} position"}}
      end
    end

    @impl true
    def get_stuck_looping_weapons(_ctx, _hdlops) do
      :ok
    end
  end

  setup_all do
    {:ok, pid} =
      Server.child_spec(
        __MODULE__,
        Server.Endpoint.loopback(),
        TestHandler.new("/weapons", event_handler: Woody.EventHandler.Default)
      )
      |> List.wrap()
      |> Supervisor.start_link(strategy: :one_for_one)

    endpoint = Server.endpoint(__MODULE__)

    [
      supervisor: pid,
      endpoint: endpoint,
      url: "http://#{endpoint}/weapons"
    ]
  end

  setup context do
    trace_id = context[:test] |> Atom.to_string() |> String.slice(0, 64)
    woody_ctx = Woody.Context.new(trace_id: trace_id)
    client = Service.Client.new(woody_ctx, context.url, event_handler: Woody.EventHandler.Default)
    [client: client]
  end

  test "gets weapon", context do
    assert {:ok, %Weapon{name: "blarg"}} =
             Service.Client.get_weapon(context.client, "blarg", "<data>")
  end

  test "switches weapon", context do
    weapon = %Weapon{name: "blarg", slot_pos: 42, ammo: 9001}

    assert {:ok, %Weapon{name: "blarg", slot_pos: 43, ammo: 9001}} =
             Service.Client.switch_weapon(context.client, weapon, Direction.next(), 1, "<data>")
  end

  test "fails weapon switch", context do
    weapon = %Weapon{name: "blarg", slot_pos: 42, ammo: 9001}

    assert {:exception, %WeaponFailure{code: "invalid_shift"}} =
             Service.Client.switch_weapon(context.client, weapon, Direction.prev(), 50, "<data>")
  end

  test "receives unexpected error", context do
    assert_raise Woody.UnexpectedError, ~r/^received an unexpected error/, fn ->
      Service.Client.get_weapon(context.client, "oops", "<data>")
    end
  end

  test "receives unavailable resource", context do
    url = "http://there.should.be.no.such.domain/"

    client =
      Service.Client.new(context.client.ctx, url, event_handler: Woody.EventHandler.Default)

    assert_raise Woody.BadResultError, ~r/^got no result, resource unavailable/, fn ->
      Service.Client.get_weapon(client, "blarg", "<data>")
    end
  end

  test "void return", context do
    assert {:ok, nil} = Service.Client.get_stuck_looping_weapons(context.client)
  end
end
