# frozen_string_literal: true

module Common
  module Exceptions
    # InvalidField - field is invalid
    class InvalidField < BaseError
      attr_reader :field, :type

      def initialize(field, type)
        @field = field
        @type = type
      end

      private

      def interpolated
        i18n_interpolated(detail: { field: @field, type: @type })
      end
    end
  end
end
