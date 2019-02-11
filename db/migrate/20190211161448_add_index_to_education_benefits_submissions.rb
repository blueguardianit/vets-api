class AddIndexToEducationBenefitsSubmissions < ActiveRecord::Migration
  def change
    add_index "education_benefits_submissions", ["user_uuid", "form_type"], name: "index_edu_benefits_on_user_uuid_and_form_type", using: :btree
  end
end
