# frozen_string_literal: true

require 'base64'
require 'saml/url_service'

module V0
  class SessionsController < ApplicationController
    REDIRECT_URLS = %w[signup mhv dslogon idme mfa verify slo].freeze

    STATSD_SSO_CALLBACK_KEY = 'api.auth.saml_callback'
    STATSD_SSO_CALLBACK_TOTAL_KEY = 'api.auth.login_callback.total'
    STATSD_SSO_CALLBACK_FAILED_KEY = 'api.auth.login_callback.failed'
    STATSD_LOGIN_NEW_USER_KEY = 'api.auth.new_user'

    # Collection Action: auth is required for certain types of requests
    # @type is set automatically by the routes in config/routes.rb
    # For more details see SAML::SettingsService and SAML::URLService
    def new
      type = params[:signup] ? 'signup' : params[:type]
      if REDIRECT_URLS.include?(type)
        url = url_service.send("#{type}_url")
        if type == 'slo'
          Rails.logger.info('SSO: LOGOUT', sso_logging_info)
          reset_session
        end
        redirect_to url
      else
        raise Common::Exceptions::RoutingError, params[:path]
      end
    end

    def saml_logout_callback
      logout_response = OneLogin::RubySaml::Logoutresponse.new(params[:SAMLResponse], saml_settings,
                                                               raw_get_params: params)
      logout_request  = SingleLogoutRequest.find(logout_response&.in_response_to)

      errors = build_logout_errors(logout_response, logout_request)

      if errors.size.positive?
        extra_context = { in_response_to: logout_response&.in_response_to }
        log_message_to_sentry("SAML Logout failed!\n  " + errors.join("\n  "), :error, extra_context)
      end
    rescue => e
      log_exception_to_sentry(e, {}, {}, :error)
    ensure
      logout_request&.destroy

      # In the future, the FE shouldn't count on ?success=true.
      if Settings.session_cookie.enabled
        redirect_to url_service.logout_redirect_url
      else
        redirect_to url_service.logout_redirect_url(success: true)
      end
    end

    def saml_callback
      saml_response = SAML::Response.new(params[:SAMLResponse], settings: saml_settings)
      @sso_service = SSOService.new(saml_response)
      if @sso_service.persist_authentication!
        @current_user = @sso_service.new_user
        @session_object = @sso_service.new_session

        set_cookies
        after_login_actions
        redirect_to saml_login_redirect_url
        stats(:success)
      else
        redirect_to url_service.login_redirect_url(auth: 'fail', code: auth_error_code)
        stats(:failure)
      end
    rescue NoMethodError
      log_message_to_sentry('NoMethodError', :error, base64_params_saml_response: params[:SAMLResponse])
      redirect_to url_service.login_redirect_url(auth: 'fail', code: 7) unless performed?
      stats(:failed_unknown)
    ensure
      stats(:total)
    end

    private

    def auth_error_code
      if @sso_service.auth_error_code == '005' && validate_session
        SSOService::ERRORS[:saml_replay_valid_session][:code]
      else
        @sso_service.auth_error_code
      end
    end

    def authenticate
      return unless action_name == 'new'
      if %w[mfa verify slo].include?(params[:type])
        super
      else
        reset_session
      end
    end

    def stats(status)
      case status
      when :success
        StatsD.increment(STATSD_LOGIN_NEW_USER_KEY) if @sso_service.new_login?
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:success', "context:#{@sso_service.saml_response.authn_context}"])
      when :failure
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:failure', "context:#{@sso_service.saml_response.authn_context}"])
        StatsD.increment(STATSD_SSO_CALLBACK_FAILED_KEY, tags: [@sso_service.failure_instrumentation_tag])
      when :failed_unknown
        StatsD.increment(STATSD_SSO_CALLBACK_KEY,
                         tags: ['status:failure', 'context:unknown'])
        StatsD.increment(STATSD_SSO_CALLBACK_FAILED_KEY, tags: ['error:unknown'])
      when :total
        StatsD.increment(STATSD_SSO_CALLBACK_TOTAL_KEY)
      end
    end

    def set_cookies
      Rails.logger.info('SSO: LOGIN', sso_logging_info)
      set_api_cookie!
      set_sso_cookie! # Sets a cookie "vagov_session_<env>" with attributes needed for SSO.
    end

    def saml_login_redirect_url
      if current_user.loa[:current] < current_user.loa[:highest]
        url_service.verify_url
      elsif Settings.session_cookie.enabled
        url_service.login_redirect_url
      else
        url_service.login_redirect_url(token: @session_object.token)
      end
    end

    def after_login_actions
      AfterLoginJob.perform_async('user_uuid' => @current_user&.uuid)
      log_persisted_session_and_warnings
    end

    def log_persisted_session_and_warnings
      obscure_token = Session.obscure_token(@session_object.token)
      Rails.logger.info("Logged in user with id #{@session_object.uuid}, token #{obscure_token}")
      # We want to log when SSNs do not match between MVI and SAML Identity. And might take future
      # action if this appears to be happening frquently.
      if current_user.ssn_mismatch?
        additional_context = StringHelpers.heuristics(current_user.identity.ssn, current_user.va_profile.ssn)
        log_message_to_sentry('SSNS DO NOT MATCH!!', :warn, identity_compared_with_mvi: additional_context)
      end
    end

    def build_logout_errors(logout_response, logout_request)
      errors = []
      errors.concat(logout_response.errors) unless logout_response.validate(true)
      errors << 'inResponseTo attribute is nil!' if logout_response&.in_response_to.nil?
      errors << 'Logout Request not found!' if logout_request.nil?
      errors
    end

    def url_service
      SAML::URLService.new(saml_settings, session: @session_object, user: current_user)
    end
  end
end
