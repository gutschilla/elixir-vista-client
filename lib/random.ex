defmodule VistaClient.Random do
  @moduledoc """
  Helper to generate random strings.
  """
  @alphabet [hd('a')..hd('z'), hd('A')..hd('Z'), hd('0')..hd('9')] |> Enum.concat

  @doc """
  ## Example

      iex> VistaClient.Random.string()
      "a1wvjFLn6TQ4CTtz"
      iex> VistaClient.Random.string(32)
      "jLFFKQv4Gh9QtxIl4FCepoQJwGkI87RI"
  """
  @spec string(integer()) :: String.t()
  def string(length \\ 16) do
    1..length
    |> Enum.map(fn _ -> Enum.random(@alphabet) end)
    |> to_string()
  end
end
