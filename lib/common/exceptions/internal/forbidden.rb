# frozen_string_literal: true

module Common
  module Exceptions
    # Forbidden - We may eventually want different variations on this with distinct MinorCodes
    class Forbidden < BaseError
      def initialize(options = {})
        @detail = options[:detail]
        @source = options[:source]
      end

      private

      def interpolated
        i18n_data.merge(detail: @detail, source: @source)
      end
    end
  end
end
