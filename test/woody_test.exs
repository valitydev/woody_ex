defmodule WoodyTest do
  use ExUnit.Case
  # doctest Woody

  alias Woody.Thrift.Header
  require Header
  Header.import_records("test/gen/woody_test_thrift.hrl", [
    {:test_Weapon, as: :weapon},
    {:test_WeaponFailure, as: :weaponFailure}
  ])

  defmodule Weapons do
    import Woody.Server.Builder
    require Woody.Server.Builder
    defservice Service, {:woody_test_thrift, :Weapons}

    defmodule Handler do
      use Weapons.Service

      require Header
      Header.import_records("test/gen/woody_test_thrift.hrl", [
        {:test_Weapon, as: :weapon},
        {:test_WeaponFailure, as: :weaponFailure}
      ])

      @impl Weapons.Service
      def handle_switch_weapon(weapon(slot_pos: pos) = current, direction, shift, _data, _ctx, _hdlopts) do
        pos = if direction == :next, do: pos + shift, else: pos - shift
        if pos > 0 do
          weapon(current, slot_pos: pos)
        else
          throw weaponFailure(
            code: "invalid_shift",
            reason: "Shifted into #{pos} position"
          )
        end
      end

      @impl Weapons.Service
      def handle_get_weapon("oops", _data, _ctx, _hdlopts) do
        42 = 1337
      end
      def handle_get_weapon(name, _data, _ctx, _hdlopts) do
        weapon(name: name, slot_pos: 42, ammo: 9001)
      end

      @impl Weapons.Service
      def handle_get_stuck_looping_weapons(_ctx, _hdlopts) do
        :ok
      end
    end

    defmodule Server do
      alias Woody.Server.Http
      def child_spec(id) do
        handler = Http.Handler.new(Handler, "/weapons", event_handler: :woody_event_handler_default)
        Http.child_spec(id, Http.Endpoint.loopback(), handler)
      end
    end

    defmodule Client do
      use Woody.Client.Builder, service: {:woody_test_thrift, :Weapons}
    end

  end

  setup_all do
    {:ok, pid} = Supervisor.start_link([{Weapons.Server, __MODULE__}], strategy: :one_for_one)
    endpoint = Woody.Server.Http.endpoint(__MODULE__)
    url = "http://#{endpoint}/weapons"
    [
      supervisor: pid,
      endpoint: Woody.Server.Http.endpoint(__MODULE__),
      url: url
    ]
  end

  setup context do
    trace_id = context[:test] |> to_string() |> String.slice(0, 64)
    woody_ctx = Woody.Context.new(trace_id: trace_id)
    client = Woody.Client.Http.new(woody_ctx, context.url, event_handler: :woody_event_handler_default)
    [client: client]
  end

  test "gets weapon", context do
    assert {:ok, weapon(name: "blarg")}
      = Weapons.Client.get_weapon(context.client, "blarg", "<data>")
  end

  test "switches weapon", context do
    weapon = weapon(name: "blarg", slot_pos: 42, ammo: 9001)
    assert {:ok, weapon(name: "blarg", slot_pos: 43, ammo: 9001)}
      = Weapons.Client.switch_weapon(context.client, weapon, :next, 1, "<data>")
  end

  test "fails weapon switch", context do
    weapon = weapon(name: "blarg", slot_pos: 42, ammo: 9001)
    assert {:exception, weaponFailure(code: "invalid_shift")}
      = Weapons.Client.switch_weapon(context.client, weapon, :prev, 50, "<data>")
  end

  test "receives unexpected error", context do
    assert_raise Woody.UnexpectedError, ~r/^received an unexpected error/, fn ->
      Weapons.Client.get_weapon(context.client, "oops", "<data>")
    end
  end

  test "receives unavailable resource", context do
    trace_id = context[:test] |> to_string() |> String.slice(0, 64)
    woody_ctx = Woody.Context.new(trace_id: trace_id)
    url = "http://there.should.be.no.such.domain/"
    client = Woody.Client.Http.new(woody_ctx, url, event_handler: :woody_event_handler_default)
    assert_raise Woody.BadResultError, ~r/^got no result, resource unavailable/, fn ->
      Weapons.Client.get_weapon(client, "blarg", "<data>")
    end
  end

  test "void return", context do
    assert {:ok, :ok} = Weapons.Client.get_stuck_looping_weapons(context[:client])
  end

end
