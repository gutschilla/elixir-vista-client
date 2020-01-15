# defmodule VistaClient.Pluggable do
#   use Tesla

#   @moduledoc """
#   TODO: evaluate/use Tesla to make HTTP requests for usage of simple plugs for
#   composability.
#   """

#   plug Tesla.Middleware.BaseUrl, VistaClient.Config.get().api_url
#   plug Tesla.Middleware.Headers, [{"connectapitoken", VistaClient.Config.get().api_token},{"Content-Type", "application/json"}]
#   plug Tesla.Middleware.JSON

#   def get_session_availabilty(id), do: get("OData.svc/Sessions?$select=ID,SeatsAvailable&$filter=ID+eq+'#{id}'")

# end
