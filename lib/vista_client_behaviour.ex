defmodule VistaClient.Behaviour do
  @callback get_cinemas()                     :: {:ok, [%VistaClient.Cinema{}]}            | {:error, any()}
  @callback get_scheduled_films()             :: {:ok, [%VistaClient.Film{}]}              | {:error, any()}
  @callback get_sessions()                    :: {:ok, [%VistaClient.Session{}]}           | {:error, any()}
  @callback get_session_availabilty(binary()) :: {:ok, %VistaClient.SessionAvailability{}} | {:error, any()}
end
