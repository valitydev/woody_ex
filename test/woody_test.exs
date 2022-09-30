defmodule Thrift do
  import RecStruct
  require RecStruct
  defheader Test, "test/gen/woody_test_thrift.hrl" do
  end
end

defmodule WoodyTest do
  use ExUnit.Case
  # doctest Woody

  import Thrift.Test.Records
  require Thrift.Test.Records

  @thrift_service {:woody_test_thrift, :Weapons}
  @woody_options [event_handler: :woody_event_handler_default]

  defmodule Weapons do
    import Woody.Server.Builder
    require Woody.Server.Builder
    defservice Service, {:woody_test_thrift, :Weapons}

    defmodule Handler do
      use Weapons.Service

      @impl Weapons.Service
      def handle_switch_weapon(current, direction, shift, _data, _ctx, _hdlopts) do
        test_Weapon(slot_pos: pos) = current
        pos = if direction == :next, do: pos + shift, else: pos - shift
        if pos > 0 do
          test_Weapon(current, slot_pos: pos)
        else
          throw test_WeaponFailure(
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
        test_Weapon(name: name, slot_pos: 42, ammo: 9001)
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
    client = Woody.Client.Http.new(woody_ctx, context[:url], event_handler: :woody_event_handler_default)
    [client: client]
  end

  test "gets weapon", context do
    assert {:ok, test_Weapon(name: "blarg")} = Weapons.Client.get_weapon(context[:client], "blarg", "<data>")
  end

  test "switches weapon", context do
    weapon = test_Weapon(name: "blarg", slot_pos: 42, ammo: 9001)
    assert {:ok, test_Weapon(name: "blarg", slot_pos: 43, ammo: 9001)}
      = Weapons.Client.switch_weapon(context[:client], weapon, :next, 1, "<data>")
  end

  test "fails weapon switch", context do
    weapon = test_Weapon(name: "blarg", slot_pos: 42, ammo: 9001)
    assert {:exception, test_WeaponFailure(code: "invalid_shift")}
      = Weapons.Client.switch_weapon(context[:client], weapon, :prev, 50, "<data>")
  end

  test "receives unexpected error", context do
    assert_raise Woody.UnexpectedError, ~r/^received an unexpected error/, fn ->
      Weapons.Client.get_weapon(context[:client], "oops", "<data>")
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
