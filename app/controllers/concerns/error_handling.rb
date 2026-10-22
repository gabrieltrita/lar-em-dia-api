# Formato padrão de erro:
#   { "error": { "code": "...", "message": "...", "details": {...} } }
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_internal_error unless Rails.env.local?
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_bad_request
    rescue_from Pundit::NotAuthorizedError, with: :handle_forbidden
    rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_bad_request
    rescue_from Auth::Unauthorized, with: :handle_unauthorized
    rescue_from Auth::ReauthenticationFailed, with: :handle_reauthentication_failed
  end

  private

  def render_error(status:, code:, message:, details: nil)
    body = { error: { code: code, message: message } }
    body[:error][:details] = details if details.present?
    render json: body, status: status
  end

  def render_validation_errors(record)
    render_error(
      status: :unprocessable_content,
      code: "validation_failed",
      message: "Dados inválidos",
      details: record.errors.to_hash(true)
    )
  end

  def handle_not_found(_error)
    render_error(status: :not_found, code: "not_found", message: "Recurso não encontrado")
  end

  def handle_record_invalid(error)
    render_validation_errors(error.record)
  end

  def handle_bad_request(error)
    render_error(status: :bad_request, code: "bad_request", message: error.message)
  end

  def handle_forbidden(_error)
    render_error(status: :forbidden, code: "forbidden", message: "Você não tem permissão para esta ação")
  end

  def handle_unauthorized(error)
    render_error(status: :unauthorized, code: "unauthorized", message: error.message)
  end

  def handle_reauthentication_failed(error)
    render_error(status: :unprocessable_content, code: "reauthentication_failed", message: error.message)
  end

  def handle_internal_error(error)
    Rails.logger.error("[#{error.class}] #{error.message}\n#{error.backtrace&.first(10)&.join("\n")}")
    Sentry.capture_exception(error) if Sentry.initialized?
    render_error(status: :internal_server_error, code: "internal_error", message: "Erro interno do servidor")
  end
end
