defmodule VistaClient do

  @behaviour VistaClient.Behaviour

  alias VistaClient.{Config, SessionAvailability, Session, Cinema, Film, Endpoint}

  @moduledoc ~s"""
  Documentation for VistaClient.

  ## Examples

      iex> {:ok, cinemas} = VistaClient.get_cinemas()
      iex> cinemas |> Enum.find(fn cinema -> cinema.id == 1001 end)
      %VistaClient.Cinema{id: 1001, name: "Delphi Lux"}
  """

  @type reason :: any()
  @type headers :: list({charlist(), charlist()})

  @doc "creates auth and content-type and accept headers"
  @spec make_basic_headers() :: {:ok, headers} | {:error, reason}
  def make_basic_headers do
    with %Config{api_token: api_token} <- Config.get() do
      {:ok, [
          {"connectapitoken", api_token},
          {"Content-Type", "application/json"}
        ]
      }
    else
      %Config{} -> {:error, :api_token_missing_in_config}
      _         -> {:error, :config_not_available}
    end
  end

  @type retrieved_entity :: :cinemas | :scheduled_films | :sessions | command
  @type url :: charlist()

  @spec url_for(retrieved_entity, keyword()) :: {:ok, url} | {:error, reason}
  def url_for(what, opts \\ []) do
    with %Config{api_url: api_url} <- Config.get(),
         {:p, params}              <- {:p, Keyword.get(opts, :params, [])},
         {:ok, url}                <- make_url_for(what, api_url, params) do
      {:ok, url}
    else
      %Config{}        -> {:error, :api_url_missing_in_config}
      {:error, reason} -> {:error, reason}
    end
  end

  def make_url_for(action, api_url) do
    make_url_for(action, api_url, [])
  end

  def make_url_for(:root, api_url, _opts) do
    {:ok, api_url <> "OData.svc"}
  end

  def make_url_for(:cinemas, api_url, _opts) do
    {:ok, api_url <> "OData.svc/Cinemas"}
  end

  def make_url_for(:scheduled_films, api_url, _opts) do
    # https://cine-web.yorck.de:42282/WSVistaWebClient/Odata.svc/GetScheduledFilms?cinemaid=1014&$format=json&$orderby=Title&$expand=Sessions
    {:ok, api_url <> "OData.svc/GetScheduledFilms"}
  end

  def make_url_for(:sessions, api_url, _opts) do
    {:ok, api_url <> "OData.svc/Sessions"}
  end

  def make_url_for(:seats_available, api_url, [session_id: id_string]) when is_binary id_string do
    {:ok, api_url <>  "OData.svc/Sessions?$select=ID,SeatsAvailable&$filter=ID+eq+'#{id_string}'"}
  end

  def make_url_for(:validate_member, api_url, _opts) do
    {:ok, api_url <> "RESTLoyalty.svc/member/validate"}
  end

  def make_url_for(:add_concessions, api_url, _opts) do
    {:ok, api_url <> "RESTTicketing.svc/order/concessions"}
  end

  def make_url_for(:start_external_payment, api_url, _opts) do
    {:ok, api_url <> "RESTTicketing.svc/order/startexternalpayment"}
  end

  def make_url_for(:complete_order, api_url, _opts) do
    {:ok, api_url <> "RESTTicketing.svc/order/payment"}
  end

  @type command :: :validate_member
                 | :add_concessions
                 | :start_external_payment
                 | :complete_order
  @type payload :: String.t()
  @spec payload_for(command, list()) :: {:ok, payload} | {:error, reason}

  @doc ~S"""
  Creates JSON post body (a string) to select API endpoints

  ## Examples

      iex> VistaClient.payload_for(:validate_member, member_card_number: 1234, user_session_id: 666)
      {:ok, "{\"MemberCardNumber\":\"1234\",\"ReturnMember\":true,\"UserSessionId\":\"666\"}"}
      iex> VistaClient.payload_for(:add_concessions, user_session_id: "me", head_office_item_code: "2019")
      {:error, {:missing, :cinema_id}}
      iex> VistaClient.payload_for :add_concessions, user_session_id: "abc", cinema_id: "123", head_office_item_code: "XYZ"
      {:ok, "{\"CinemaId\":\"123\",\"Concessions\":[{\"GetBarcodeFromVGC\":true,\"HeadOfficeItemCode\":\"XYZ\",\"Quantity\":1}],\"UserSessionId\":\"abc\"}"}
      iex> VistaClient.payload_for :start_external_payment
      {:error, {:missing, :user_session_id}}
      iex> VistaClient.payload_for(:start_external_payment, user_session_id: "7357")
      {:ok, "{\"AutoCompleteOrder\":false,\"UserSessionId\":\"7357\"}"}
      iex(23)> VistaClient.payload_for(:complete_order, user_session_id: "f00", customer_email: "customer@e.mail", payment_value: 1000, payment_reference: "1337")
      {:ok, "{\"BookingType\":0,\"CustomerEmail\":\"customer@e.mail\",\"CustomerName\":\"WEBSHOP\",\"CustomerPhone\":\"WEBSHOP\",\"GenerateConcessionVoucherPrintStream\":true,\"GeneratePrintStream\":true,\"PaymentInfo\":{\"BankReference\":\"1337\",\"BillFullOutstandingAmount\":true,\"BillingValueCents\":1000,\"CardType\":\"PAYPAL\",\"PaymentValueCents\":1000},\"PerformPayment\":false,\"PrintStreamType\":1,\"PrintTemplateName\":\"www_P@H\",\"ReturnPrintStream\":true,\"UserSessionId\":\"f00\"}"}
  """
  def payload_for(command, opts \\ []) do
    with {:ok, parameters}  <- extract_payload_parameters(command, opts),
         payload            <- make_payload(command, parameters),
         {:ok, json_string} <- Jason.encode(payload) do
      {:ok, json_string}
    end
  end

  @spec extract_payload_parameters(command, list()) :: {:ok, list()} | {:error, reason}
  @doc ~S"""
  Extracts and validates parameters from opts list for use with make_payload

  ## Examples

      iex> VistaClient.extract_payload_parameters(:validate_member, user_session_id: :atom, member_card_number: 23)
      {:error, {:invalid, [user_session_id: :atom]}}
      iex> VistaClient.extract_payload_parameters(:validate_member, user_session_id: "123", member_card_number: "555123456")
      {:ok, [member_card_number: "555123456", user_session_id: "123"]}
      iex> VistaClient.extract_payload_parameters(:add_concessions, user_session_id: "test", cinema_id: "007", head_office_item_code: "666")
      {:ok, [user_session_id: "test", cinema_id: "007", head_office_item_code: "666", variable_price: nil]}
      iex> VistaClient.extract_payload_parameters(:add_concessions, user_session_id: "000", head_office_item_code: "aaa", cinema_id: "123", variable_price: 500)
      {:ok, [user_session_id: "000", cinema_id: "123", head_office_item_code: "aaa", variable_price: 500]}
      iex> VistaClient.extract_payload_parameters(:start_external_payment, user_session_id: "777")
      {:ok, [user_session_id: "777"]}
      iex> VistaClient.extract_payload_parameters(:complete_order, user_session_id: "1", customer_email: "foo@bar.baz", payment_value: 2500, pament_reference: "1nc19-832-a83uhd")
      {:error, {:invalid, [payment_reference: nil]}}
      iex> VistaClient.extract_payload_parameters(:complete_order, user_session_id: "1", customer_email: "foo@bar.baz", payment_value: 2500, payment_reference: "1nc19-832-a83uhd")
      {:ok,[user_session_id: "1", customer_email: "foo@bar.baz", payment_value: 2500, payment_reference: "1nc19-832-a83uhd"]}
  """
  def extract_payload_parameters(:validate_member, opts) do
    with card_number when not is_nil(card_number)        <- opts[:member_card_number],
         user_session_id when is_binary(user_session_id) <- ensure_user_session_id(opts[:user_session_id]) do
      {:ok, member_card_number: to_string(card_number), user_session_id: user_session_id}
    else
      nil              -> {:error, {:missing, :member_card_number}}
      {:error, reason} -> {:error, reason}
    end
  end

  def extract_payload_parameters(:add_concessions, opts) do
    with {:user_session_id, session_id} when is_binary(session_id)                    <- {:user_session_id, ensure_user_session_id(opts[:user_session_id])},
         {:cinema_id, cinema_id} when not is_nil(cinema_id)                           <- {:cinema_id, opts[:cinema_id]},
         {:head_office_item_code, item_code} when not is_nil(item_code)               <- {:head_office_item_code, opts[:head_office_item_code]},
         {:variable_price, var_price} when is_integer(var_price) or is_nil(var_price) <- {:variable_price, opts[:variable_price]} do
      {:ok,[user_session_id: session_id, cinema_id: to_string(cinema_id), head_office_item_code: to_string(item_code), variable_price: var_price]}
    else
      {:variable_price, invalid} -> {:error, {:invalid, variable_price: invalid}}
      {type, nil}                -> {:error, {:missing, type}}
      {_type, {:error, reason}}  -> {:error, reason}
    end
  end

  def extract_payload_parameters(:start_external_payment, opts) do
    with user_session_id when is_binary(user_session_id) <- require_user_session_id(opts[:user_session_id]) do
      {:ok, user_session_id: user_session_id}
    end
  end

  def extract_payload_parameters(:complete_order, opts) do
    with session_id when is_binary(session_id)          <- require_user_session_id(opts[:user_session_id]),
         {:ok, cust_mail}                               <- quickcheck_email_address(opts[:customer_email]),
         {:value, pay_value} when is_integer(pay_value) <- {:value, opts[:payment_value]},
         {:pay_ref, pay_ref} when is_binary(pay_ref)    <- {:pay_ref, opts[:payment_reference]} do
      {:ok, user_session_id: session_id, customer_email: cust_mail, payment_value: pay_value, payment_reference: pay_ref}
    else
      {:value, value}     -> {:error, {:invalid, payment_value: value}}
      {:pay_ref, pay_ref} -> {:error, {:invalid, payment_reference: pay_ref}}
      {:error, reason}    -> {:error, reason}
    end
  end

  @doc ~S"""
  Builds a JSON map formatted to receive membership details. If no
  user_session_id is specified, a temporaray random one will be generated.

  ## Examples

      iex> VistaClient.make_payload(:validate_member, member_card_number: "1234", user_session_id: "temp_foo")
      %{"UserSessionId" => "temp_foo", "MemberCardNumber" => "1234", "ReturnMember" => true}
      iex> VistaClient.make_payload(:start_external_payment, user_session_id: "idontwannapay")
      %{"AutoCompleteOrder" => false, "UserSessionId" => "idontwannapay"}
      iex> VistaClient.make_payload(:complete_order, user_session_id: "idontwannapay", customer_email: "idont@wanna.pay", payment_value: 1234, payment_reference: "buttheypaidanyway")
      %{"BookingType" => 0, "CustomerEmail" => "idont@wanna.pay", "CustomerName" => "WEBSHOP", "CustomerPhone" => "WEBSHOP", "GenerateConcessionVoucherPrintStream" => true, "GeneratePrintStream" => true, "PaymentInfo" => %{"BankReference" => "buttheypaidanyway", "BillFullOutstandingAmount" => true, "BillingValueCents" => 1234, "CardType" => "PAYPAL", "PaymentValueCents" => 1234}, "PerformPayment" => false, "PrintStreamType" => 1, "PrintTemplateName" => "www_P@H", "ReturnPrintStream" => true, "UserSessionId" => "idontwannapay"}
  """
  def make_payload(:validate_member, member_card_number: card_num, user_session_id: id) do
    %{
      "UserSessionId"    => id,
      "MemberCardNumber" => card_num,
      "ReturnMember"     => true
    }
  end

  def make_payload(
    :add_concessions,
    user_session_id:       user_session_id,
    cinema_id:             cinema_id,
    head_office_item_code: head_office_item_code,
    variable_price:        variable_price
  )
  do
    %{
      "UserSessionId" => user_session_id,
      "CinemaId"      => cinema_id,
      "Concessions"   => [Map.merge(%{
        "HeadOfficeItemCode" => head_office_item_code,
        "GetBarcodeFromVGC"  => true, # VGC is the Vista Vouchers and Gift Cards module
        "Quantity"           => 1,
      }, (if is_nil(variable_price), do: %{}, else: %{"VariablePriceInCents" => variable_price}))]
    }
  end

  def make_payload(:start_external_payment, user_session_id: user_session_id) do
    %{
      "UserSessionId"     => user_session_id,
      "AutoCompleteOrder" => false
    }
  end

  def make_payload(
    :complete_order,
    user_session_id:   usid,
    customer_email:    cust_mail,
    payment_value:     pay_amount,
    payment_reference: pay_bankref
  )
  do
    %{
      "UserSessionId"                        => usid,
      "CustomerEmail"                        => cust_mail,
      "CustomerPhone"                        => "WEBSHOP",
      "CustomerName"                         => "WEBSHOP",
      "BookingType"                          => 0, # this is a paid booking
      "GeneratePrintStream"                  => true,
      "GenerateConcessionVoucherPrintStream" => true,
      "PrintStreamType"                      => 1,
      "PrintTemplateName"                    => "www_P@H",
      "ReturnPrintStream"                    => true,
      "PerformPayment"                       => false, # payment is processed externally
      "PaymentInfo"                          => %{
        "PaymentValueCents"                    => pay_amount,
        "BillingValueCents"                    => pay_amount,
        "BillFullOutstandingAmount"            => true,
        "BankReference"                        => pay_bankref,
        "CardType"                             => "PAYPAL"
      }
    }
  end

  defp require_user_session_id(nil), do: {:error, {:missing, :user_session_id}}
  defp require_user_session_id(id), do: ensure_user_session_id(id)

  defp ensure_user_session_id(nil), do: "temp_#{VistaClient.Random.string()}"
  defp ensure_user_session_id(id) when is_binary(id), do: id
  defp ensure_user_session_id(id) when is_integer(id), do: "#{id}"
  defp ensure_user_session_id(id), do: {:error, {:invalid, user_session_id: id}}

  @doc ~S"""
  Roughly checks if the given binary has the form of a valid e-mail address
  using a not fully RFC-compliant regular expression taken from
  https://html.spec.whatwg.org/multipage/input.html#e-mail-state-(type=email)

  ## Examples

      iex> VistaClient.quickcheck_email_address(123)
      {:error, {:invalid, [email: 123]}}
      iex> VistaClient.quickcheck_email_address("foo@bar.baz")
      {:ok, "foo@bar.baz"}
      iex> VistaClient.quickcheck_email_address("dash.is.not@-allowed.everywhere")
      {:error, {:invalid, [email: "dash.is.not@-allowed.everywhere"]}}
  """
  def quickcheck_email_address(address) when is_binary(address) do
    with match when is_list(match) <- Regex.run(~r/^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/, address) do
      Enum.fetch(match,0)
    else
      nil -> {:error, {:invalid, email: address}}
    end
  end
  def quickcheck_email_address(not_a_binary), do: {:error,{:invalid, email: not_a_binary}}

  def make_request(url) do
    with {:ok, headers}                       <- make_basic_headers(),
         {:ok, response = %Mojito.Response{}} <- Mojito.get(url, headers),
         # {:ok, status, _headers, client_ref} <- :hackney.request(:GET, url, headers),
         # {:ok, body}                         <- :hackney.body(client_ref),
         {:status, 200, body}                 <- {:status, response.status_code, response.body} do
      {:ok, body}
    else
      {:error, reason}     -> {:error, reason}
      {:status, 500, body} -> {:error, {:server_error, body}}
      reason               -> {:error, {:something_went_wrong, reason}}
    end
  end

  def post_request(url, payload) do
    with {:ok, headers}                       <- make_basic_headers(),
         {:ok, response = %Mojito.Response{}} <- Mojito.post(url, headers, payload),
         # {:ok, status, _headers, client_ref} <- :hackney.request(:POST, url, headers, payload),
         # {:ok, body}                         <- :hackney.body(client_ref),
         {:status, 200, body}                <- {:status, response.status_code, response.body} do
      {:ok, body}
    else
      {:error, reason}     -> {:error, reason}
      {:status, 500, body} -> {:error, {:server_error, body}}
    end
  end

  def make_structs(endpoints, :root),            do: Endpoint.from_map_list(endpoints)
  def make_structs(endpoints, :endpoints),       do: Endpoint.from_map_list(endpoints)
  def make_structs(films,     :scheduled_films), do: Film.from_map_list(films)
  def make_structs(sessions,  :sessions),        do: Session.from_map_list(sessions)
  def make_structs(cinemas,   :cinemas),         do: Cinema.from_map_list(cinemas)
  def make_structs(seats,     :seats_available), do: SessionAvailability.from_map_list(seats)

  @doc ~S"""
  Performs a HTTP-GET request and decodes the JSON response into a struct.
  Returns {:ok, <Cinema|Session|...>}.

  *Options*:
    - :output_raw_maps => set to true to get plain decoded JSON map
  """
  def get(what, opts \\ []) do
    with {:ok, url}       <- url_for(what, opts),
         {:ok, json_body} <- make_request(url),
         {:ok, map}       <- Jason.decode(json_body),
         {:ok, value}     <- Map.fetch(map, "value") do
      if opts[:output_raw_maps] do
        {:ok, value}
      else
        make_structs(value, what)
      end
    else
      {:error, reason} -> {:error, reason}
      reason           -> {:error, reason}
    end
  end

  def post(where, param_list, opts \\ []) do
    with {:ok, url}         <- url_for(where, opts),
         {:ok, payload}     <- payload_for(where, param_list),
         {:ok, json_body}   <- post_request(url, payload),
         {:ok, result_body} <- Jason.decode(json_body) do
      {:ok, result_body}
    else
      {:error, reason} -> {:error, reason}
      reason           -> {:error, reason}
    end
  end

  def get_cinemas,         do: get(:cinemas)
  def get_scheduled_films, do: get(:scheduled_films)
  def get_sessions,        do: get(:sessions)
  def get_endpoints,       do: get(:root)

  def get_session_availabilty(session_id) do
    case get(:seats_available, params: [session_id: session_id]) do
      {:ok, [s = %SessionAvailability{}]} -> {:ok, s}
      {:ok, []}                           -> {:error, {:session_not_found, session_id}}
      {:error, reason}                    -> {:error, reason}
    end
  end

  def validate_member(member_card_number, user_session_id \\ nil) do
    post(
      :validate_member,
      member_card_number: member_card_number,
      user_session_id: user_session_id
   )
  end

  def add_concession(head_office_item_code, cinema_id, user_session_id \\ nil) do
    post(
      :add_concessions,
      head_office_item_code: head_office_item_code,
      cinema_id: cinema_id,
      user_session_id: user_session_id
    )
  end

  def add_variable_price_concession(head_office_item_code, price_in_cents, cinema_id, user_session_id \\ nil) do
    post(
      :add_concessions,
      head_office_item_code: head_office_item_code,
      variable_price: price_in_cents,
      cinema_id: cinema_id,
      user_session_id: user_session_id
    )
  end

  def start_external_payment(user_session_id) do
    post(
      :start_external_payment,
      user_session_id: user_session_id
    )
  end

  def complete_order(user_session_id, customer_email, payment_value, payment_reference) do
    post(
      :complete_order,
      user_session_id:   user_session_id,
      customer_email:    customer_email,
      payment_value:     payment_value,
      payment_reference: payment_reference
    )
  end
  @doc """
  Returns
  - {:ok, true} if VISTA server seems up
  - {:ok, false} if not
  - {:error, reason} on config error

  ## EXAMPLES
      iex> VistaClient.online?()
      {:ok, true}
  """
  @spec online? :: {:ok, boolean()} | {:error, reason}
  def online? do
    with {:ok, url}                                            <- url_for(:root),
         {:ok, headers}                                        <- make_basic_headers(),
         {:ok, %Mojito.Response{body: body, status_code: 200}} <- Mojito.request(method: :get, url: url, headers: headers) do
         # {:ok, 200, _headers, client_ref} <- :hackney.request(:GET, url, headers) do
      {:ok, true}
    else
      {:ok, r = %{status_code: _}} -> {:error, {:status_code, r}}
      {:error, reason}             -> {:error, reason}
      _                            -> false
    end
  end
end
