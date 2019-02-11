class AddUserUuidToEducationBenefitsSubmissions < ActiveRecord::Migration
  def change
    add_column :education_benefits_submissions, :user_uuid, :string
  end
end
