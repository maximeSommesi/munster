# frozen_string_literal: true

class ReceiveWebhooksController < ActionController::API
  class HandlerRefused < StandardError
  end

  def create
    handler = lookup_handler(params[:service_id])
    return render_error("Webhook handler is inactive", :service_unavailable) unless handler.active?

    raise HandlerRefused unless handler.valid?(request)

    handler.handle(request)
    head :ok
  rescue => e
    # TODO: add exception handler here
    # Appsignal.add_exception(e)

    if handler&.expose_errors_to_sender?
      error_for_sender_from_exception(e)
    else
      head :ok
    end
  end

  def error_for_sender_from_exception(e)
    case e
    when HandlerRefused
      render_error("Webhook handler did not validate the request (signature or authentication may be invalid)", :forbidden)
    when JSON::ParserError, KeyError
      render_error("Required parameters were not present in the request or the request body was not valid JSON", :bad_request)
    else
      render_error("Internal error", :internal_server_error)
    end
  end

  def render_error(message_str, status_sym)
    json = {error: message_str}.to_json
    render(json:, status: status_sym)
  end

  def lookup_handler(service_id_str)
    Munster.configuration.active_handlers.index_by(&:service_id).fetch(service_id_str.to_sym)
  end
end
