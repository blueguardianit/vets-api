# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA0994 < SavedClaim::EducationBenefits
  attr_accessor :user_uuid

  add_form_and_validation('22-0994')

  # def initialize(form, user_uuid)

  #   binding.pry

  #   @user_uuid = user_uuid

  #   super(form)
  # end

  # def user_uuid
  #   @user_uuid
  # end
end
