defmodule VistaClientTest do
  use ExUnit.Case, async: true
  doctest VistaClient

  test "get returns raw maps" do
    {:ok, cinemas} = VistaClient.get(:cinemas, output_raw_maps: true)
    assert is_list(cinemas)
    cinemas
    |> Enum.all?(fn %{"ID" => _, "Name" => _} -> true; _ -> false end)
    |> assert()
  end
end
