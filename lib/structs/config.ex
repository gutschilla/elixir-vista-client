defmodule VistaClient.Config do

  defstruct [
    api_token: nil,
    api_url: nil,
  ]

  @doc """
  Returns a VistaClient.Config struct. It's here to have a place for retrieving
  the config from the environment. Until now, it' hard-coded though.

  ## Examples

  iex> VistaClient.Config.get()
  %VistaClient.Config{api_token: '…', api_url: '…'}
  """
  def get do
    api_token =
      case System.get_env("VISTA_API_TOKEN") || Application.get_env(:vista_client, :api_token) do
        string when is_binary(string) -> string
        _ -> raise("VISTA_API_TOKEN environment variable needs to be set")
      end
    api_url =
      case System.get_env("VISTA_API_URL") || Application.get_env(:vista_client, :api_url) do
        string = "https://" <> _any when is_binary(string) -> string
        _ -> raise("VISTA_API_URL environment variable needs to be set and start with \"https://\"")
      end
    %VistaClient.Config{
      api_token: api_token,
      api_url: api_url
    }
  end

end
