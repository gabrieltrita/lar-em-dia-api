class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Pundit::Authorization
  include Pagy::Method
  include ErrorHandling
  include Authenticatable
  include TokenResponder

  wrap_parameters false

  prepend_before_action :set_current_request

  private

  def append_info_to_payload(payload)
    super
    payload[:request_id] = request.request_id
    payload[:user_id] = current_user&.id
  end

  def set_current_request
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent
    Current.request_id = request.request_id
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value) == true
  end

  def require_reauthentication!(provider_token: true)
    return require_current_password! if current_user.password_set?
    return require_provider_token! if provider_token && params[:id_token].present?

    unless current_user.two_factor_enabled?
      raise Auth::ReauthenticationFailed.new("Reauthentication is not available for this account", code: "reauthentication_unavailable")
    end

    require_second_factor!
  end

  def provider_param
    params[:provider].presence || Auth::Oauth::Providers::DEFAULT
  end

  def require_provider_token!
    provider = provider_param
    raise Auth::Unauthorized unless Auth::Oauth::Providers.supported?(provider)

    claims = Auth::Oauth::Providers.verify(provider, params[:id_token])
    return if current_user.identities.exists?(provider: provider, provider_uid: claims.sub)

    raise Auth::ReauthenticationFailed.new("The provider token does not match a linked account", code: "invalid_provider_token")
  rescue Auth::Unauthorized
    raise Auth::ReauthenticationFailed.new("Invalid provider token", code: "invalid_provider_token")
  rescue Auth::ProviderUnavailable
    raise Auth::ReauthenticationFailed.new("The provider could not be reached. Try again shortly.", code: "provider_unavailable")
  end

  def require_current_password!
    return if current_user.authenticate(params.require(:current_password).to_s)

    raise Auth::ReauthenticationFailed.new("Current password is incorrect", code: "invalid_current_password")
  end

  def require_second_factor!
    return unless current_user.two_factor_enabled?
    return if @second_factor_verified

    unless current_user.verify_second_factor(params[:code])
      raise Auth::ReauthenticationFailed.new("Invalid verification code", code: "invalid_two_factor_code")
    end

    @second_factor_verified = true
  end
end
