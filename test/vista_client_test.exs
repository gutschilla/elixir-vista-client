defmodule VistaClientTest do
  use ExUnit.Case, async: true
  doctest VistaClient

  test "get returns raw maps" do
    {:ok, cinemas} = VistaClient.get(:cinemas, output: :raw_maps)
    assert is_list(cinemas)
    cinemas
    |> Enum.all?(fn %{"ID" => _, "Name" => _} -> true; _ -> false end)
    |> assert()
  end
end
