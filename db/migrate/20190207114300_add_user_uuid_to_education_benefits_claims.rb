class AddUserUuidToEducationBenefitsClaims < ActiveRecord::Migration
  def add
    add_column :education_benefits_claims, :user_uuid, :string
  end
end
