require "test_helper"

class Onboarding::CandidateProfilesControllerTest < ActionDispatch::IntegrationTest
  def build_document(parsing_status:)
    document = onboarding_candidate_profiles(:draft_profile).candidate_documents.build(document_type: :cv)
    document.file.attach(io: StringIO.new("%PDF-1.4\ncontent"), filename: "cv.pdf", content_type: "application/pdf")
    document.save!
    document.update!(parsing_status: parsing_status)
    document
  end

  test "show renders the processing state while parsing is pending" do
    build_document(parsing_status: :pending)

    get onboarding_candidate_profile_path(onboarding_candidate_profiles(:draft_profile))

    assert_response :success
    assert_select "#cv_status", /reading your CV/
  end

  test "show renders success with a link to continue once parsing completes" do
    build_document(parsing_status: :completed)
    profile = onboarding_candidate_profiles(:draft_profile)

    get onboarding_candidate_profile_path(profile)

    assert_response :success
    assert_select "#cv_status", /parsed successfully/
    assert_select "#cv_status a[href=?]", edit_onboarding_candidate_profile_path(profile)
  end

  test "show renders an error with a manual fallback link when parsing fails" do
    build_document(parsing_status: :failed)
    profile = onboarding_candidate_profiles(:draft_profile)

    get onboarding_candidate_profile_path(profile)

    assert_response :success
    assert_select "#cv_status", /couldn't read your CV/
    assert_select "#cv_status a", "Fill in the form manually"
  end

  test "edit renders the first form page by default" do
    profile = onboarding_candidate_profiles(:draft_profile)

    get edit_onboarding_candidate_profile_path(profile)

    assert_response :success
    assert_select "h1", "Let's finish your profile"
    assert_select "input[name='candidate_profile[phone]']"
  end

  test "edit renders every form page" do
    profile = onboarding_candidate_profiles(:draft_profile)

    Onboarding::Form::PAGES.each do |page|
      get edit_onboarding_candidate_profile_path(profile, page: page.key)

      assert_response :success, "expected #{page.key} to render"
    end
  end

  test "edit renders the candidate's existing language as a selected option, not just an empty picker" do
    profile = onboarding_candidate_profiles(:draft_profile)
    language = onboarding_candidate_languages(:candidate_language_one).language

    get edit_onboarding_candidate_profile_path(profile, page: "personal_details")

    assert_response :success
    assert_select "select[name='candidate_profile[candidate_languages_attributes][0][language_id]'] " \
                   "option[selected][value=?]", language.id.to_s
  end

  test "update saves the current page's fields and advances to the next page" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details",
                candidate_profile: { phone: "0612345678", city: "Amsterdam", country: "Netherlands",
                                      user_attributes: { first_name: "Jamie" } } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "job_details")
    profile.reload
    assert_equal "Jamie", profile.user.first_name
    assert_equal "0612345678", profile.phone
  end

  test "update re-renders the current page with errors when a required field is missing" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details",
                candidate_profile: { phone: "0612345678", city: "Amsterdam",
                                      user_attributes: { first_name: "Jamie" } } }

    assert_response :unprocessable_entity
    assert_select "li", "Country can't be blank"
    assert_not_equal "Jamie", profile.reload.user.first_name
  end

  test "update rejects a phone number with letters or too few digits" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details",
                candidate_profile: { phone: "not-a-number", city: "Amsterdam", country: "Netherlands" } }

    assert_response :unprocessable_entity
    assert_select "li", "Phone must be a valid phone number"
  end

  test "update accepts an internationally formatted phone number" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details",
                candidate_profile: { phone: "+31 (6) 1234-5678", city: "Amsterdam", country: "Netherlands" } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "job_details")
  end

  test "update blocks personal_details when no language is selected" do
    profile = onboarding_candidate_profiles(:draft_profile)
    profile.candidate_languages.destroy_all

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details",
                candidate_profile: { phone: "0612345678", city: "Amsterdam", country: "Netherlands" } }

    assert_response :unprocessable_entity
    assert_select "li", "Languages must have at least one selected"
  end

  test "update ignores a mismatched user id in user_attributes and updates the existing user" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details",
                candidate_profile: { phone: "0612345678", city: "Amsterdam", country: "Netherlands",
                                      user_attributes: { id: profile.user.id.to_s, first_name: "Jamie" } } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "job_details")
    assert_equal "Jamie", profile.reload.user.first_name
  end

  test "update with commit=Back goes to the previous page without losing the current page's edits" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation", commit: "Back", candidate_profile: { years_of_experience: 5 } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "job_details")
    assert_equal 5, profile.reload.years_of_experience
  end

  test "update on the last page has no next page to advance to" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "additional_information", candidate_profile: { suggested_summary: "Great candidate" } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "additional_information")
  end

  test "update re-renders job_details with errors when required fields are missing" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "job_details",
                candidate_profile: { job_function: "", regions: [], max_travel_time_minutes: "", search_status: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Job function can't be blank"
    assert_select "li", "Regions must have at least one selected"
    assert_select "li", "Max travel time minutes can't be blank"
    assert_select "li", "Search status can't be blank"
  end

  test "update saves job_details fields and advances to the next page" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "job_details",
                candidate_profile: { job_function: "dental_assistant",
                                      regions: [ "north" ], max_travel_time_minutes: 30,
                                      search_status: "active", transport_types: [ "car" ],
                                      reason_for_looking: "Looking for growth" } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "compensation")
    profile.reload
    assert_equal "active", profile.search_status
    assert_equal 30, profile.max_travel_time_minutes
    assert_equal [ "car" ], profile.transport_types
    assert_equal "Looking for growth", profile.reason_for_looking
  end

  test "update accepts a real browser submission with the job_details checkbox groups' blank hidden fallback field" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: URI.encode_www_form([
        [ "page", "job_details" ],
        [ "candidate_profile[job_function]", "dental_assistant" ],
        [ "candidate_profile[max_travel_time_minutes]", "30" ],
        [ "candidate_profile[search_status]", "active" ],
        [ "candidate_profile[regions][]", "north" ],
        [ "candidate_profile[regions][]", "" ],
        [ "candidate_profile[transport_types][]", "car" ],
        [ "candidate_profile[transport_types][]", "" ]
      ]),
      headers: { "Content-Type" => "application/x-www-form-urlencoded" }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "compensation")
    assert_equal [ "north" ], profile.reload.regions
    assert_equal [ "car" ], profile.transport_types
  end

  test "update re-renders compensation with errors when required fields are missing" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation", candidate_profile: { employment_types: [], years_of_experience: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Employment types must have at least one selected"
    assert_select "li", "Years of experience can't be blank"
  end

  test "update requires desired_gross_salary when an employed employment type is selected" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_types: [ "employed" ], years_of_experience: 5,
                                      desired_gross_salary: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Desired gross salary can't be blank"
  end

  test "update requires desired_percentage when a self-employed or freelance employment type is selected" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_types: [ "self_employed" ], years_of_experience: 5,
                                      desired_percentage: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Desired percentage can't be blank"
  end

  test "update requires average_daily_revenue for revenue-relevant job functions" do
    profile = onboarding_candidate_profiles(:draft_profile)
    profile.update!(job_function: "prevention_assistant")

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_types: [ "employed" ], years_of_experience: 5,
                                      desired_gross_salary: 3000, average_daily_revenue: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Average daily revenue can't be blank"
  end

  test "update requires big_registration_status for BIG-relevant job functions" do
    profile = onboarding_candidate_profiles(:draft_profile)
    profile.update!(job_function: "general_dentist")

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_types: [ "employed" ], years_of_experience: 5,
                                      desired_gross_salary: 3000, average_daily_revenue: 100,
                                      big_registration_status: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Big registration status can't be blank"
  end

  test "update requires big_number when big_registration_status is big_registered" do
    profile = onboarding_candidate_profiles(:draft_profile)
    profile.update!(job_function: "general_dentist")

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_types: [ "employed" ], years_of_experience: 5,
                                      desired_gross_salary: 3000, average_daily_revenue: 100,
                                      big_registration_status: "big_registered", big_number: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Big number can't be blank"
  end

  test "update saves compensation fields and advances to the next page" do
    profile = onboarding_candidate_profiles(:draft_profile)
    profile.update!(job_function: "general_dentist")

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_types: [ "employed" ], years_of_experience: 5,
                                      desired_gross_salary: 3000, average_daily_revenue: 100,
                                      big_registration_status: "not_applicable" } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "education")
  end

  test "update accepts a real browser submission with the compensation checkbox group's blank hidden fallback field" do
    profile = onboarding_candidate_profiles(:draft_profile)
    profile.update!(job_function: "dental_technician")

    patch onboarding_candidate_profile_path(profile),
      params: URI.encode_www_form([
        [ "page", "compensation" ],
        [ "candidate_profile[years_of_experience]", "5" ],
        [ "candidate_profile[desired_gross_salary]", "3000" ],
        [ "candidate_profile[employment_types][]", "employed" ],
        [ "candidate_profile[employment_types][]", "" ]
      ]),
      headers: { "Content-Type" => "application/x-www-form-urlencoded" }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "education")
    assert_equal [ "employed" ], profile.reload.employment_types
  end

  test "update saves education fields and advances to the next page" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "education",
                candidate_profile: { educations_attributes: {
                  "0" => { institution: "Hogeschool Utrecht", study: "Mondzorgkunde",
                            level: "hbo", location: "Utrecht, Netherlands" }
                } } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "work_experience")
    assert_includes profile.reload.educations.pluck(:study), "Mondzorgkunde"
  end

  test "update saves work_experience fields and advances to the next page" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "work_experience",
                candidate_profile: { work_experiences_attributes: {
                  "0" => { job_title: "Dentist", company_name: "Dental Clinic Utrecht" }
                } } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "skills")
    assert_includes profile.reload.work_experiences.pluck(:job_title), "Dentist"
  end

  test "update saves skills fields and advances to the next page" do
    profile = onboarding_candidate_profiles(:draft_profile)
    profile.update!(job_function: "dental_technician")
    skill = onboarding_skills(:dental_technician_prosthetics)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "skills",
                candidate_profile: { candidate_skills_attributes: {
                  "0" => { skill_id: skill.id },
                  "1" => { suggested_name: "Digital smile design" }
                } } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "availability")
    assert_includes profile.reload.skills, skill
    assert_includes profile.candidate_skills.map(&:suggested_name), "Digital smile design"
  end

  test "update re-renders availability with errors when required fields are missing" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "availability", candidate_profile: { working_days: [], available_from: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Working days must have at least one selected"
    assert_select "li", "Available from can't be blank"
  end

  test "update saves availability fields and advances to the next page" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: { page: "availability",
                candidate_profile: { working_days: [ "monday" ], available_from: Date.tomorrow } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "additional_information")
  end

  test "update accepts a real browser submission with the availability checkbox group's blank hidden fallback field" do
    profile = onboarding_candidate_profiles(:draft_profile)

    patch onboarding_candidate_profile_path(profile),
      params: URI.encode_www_form([
        [ "page", "availability" ],
        [ "candidate_profile[working_days][]", "monday" ],
        [ "candidate_profile[working_days][]", "" ],
        [ "candidate_profile[available_from]", Date.tomorrow.to_s ]
      ]),
      headers: { "Content-Type" => "application/x-www-form-urlencoded" }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "additional_information")
    assert_equal [ "monday" ], profile.reload.working_days
  end
end
