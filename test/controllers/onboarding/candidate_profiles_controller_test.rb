require "test_helper"

class Onboarding::CandidateProfilesControllerTest < ActionDispatch::IntegrationTest
  # Authorization is now session-token-based (see Onboarding::CandidateAuthorization) — the token is
  # only ever set server-side by CandidatesController#create, so tests establish it through a real
  # upload rather than poking `session` directly (integration-test session mutations outside a real
  # request/response cycle don't persist to the next request).
  setup do
    post onboarding_candidates_path,
      params: { consent: "1", cv: uploaded_file("sample_cv.pdf", content_type: "application/pdf") }
    @profile = Onboarding::CandidateProfile.last
    @profile.update!(job_function: onboarding_job_functions(:general_dentist),
                      region_ids: [ onboarding_regions(:north).id ],
                      employment_type_ids: [ onboarding_employment_types(:employed).id ],
                      working_days: [ "monday" ])
    @profile.candidate_languages.create!(language: onboarding_languages(:english), proficiency: "native")
  end

  def uploaded_file(fixture_name, content_type:)
    Rack::Test::UploadedFile.new(file_fixture(fixture_name), content_type)
  end

  def build_document(parsing_status:)
    document = @profile.candidate_documents.build(document_type: :cv)
    document.file.attach(io: StringIO.new("%PDF-1.4\ncontent"), filename: "cv.pdf", content_type: "application/pdf")
    document.save!
    document.update!(parsing_status: parsing_status)
    document
  end

  test "show renders the processing state while parsing is pending" do
    build_document(parsing_status: :pending)

    get onboarding_candidate_profile_path(@profile)

    assert_response :success
    assert_select "#cv_status", /reading your CV/
  end

  test "show renders success with a link to continue once parsing completes" do
    build_document(parsing_status: :completed)
    profile = @profile

    get onboarding_candidate_profile_path(profile)

    assert_response :success
    assert_select "#cv_status", /parsed successfully/
    assert_select "#cv_status a[href=?]", edit_onboarding_candidate_profile_path(profile)
  end

  test "show renders an error with a manual fallback link when parsing fails" do
    build_document(parsing_status: :failed)
    profile = @profile

    get onboarding_candidate_profile_path(profile)

    assert_response :success
    assert_select "#cv_status", /couldn't read your CV/
    assert_select "#cv_status a", "Fill in the form manually"
  end

  test "edit renders the first form page by default" do
    profile = @profile

    get edit_onboarding_candidate_profile_path(profile)

    assert_response :success
    assert_select "h1", "Let's finish your profile"
    assert_select "input[name='candidate_profile[phone]']"
  end

  test "edit renders every form page" do
    profile = @profile

    Onboarding::Form::PAGES.each do |page|
      get edit_onboarding_candidate_profile_path(profile, page: page.key)

      assert_response :success, "expected #{page.key} to render"
    end
  end

  test "edit renders the candidate's existing language as a selected option, not just an empty picker" do
    profile = @profile
    language = onboarding_languages(:english)

    get edit_onboarding_candidate_profile_path(profile, page: "personal_details")

    assert_response :success
    assert_select "select[name='candidate_profile[candidate_languages_attributes][0][language_id]'] " \
                   "option[selected][value=?]", language.id.to_s
  end

  test "update saves the current page's fields and advances to the next page" do
    profile = @profile

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
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details",
                candidate_profile: { phone: "0612345678", city: "Amsterdam",
                                      user_attributes: { first_name: "Jamie" } } }

    assert_response :unprocessable_entity
    assert_select "li", "Country can't be blank"
    assert_not_equal "Jamie", profile.reload.user.first_name
  end

  test "update rejects a phone number with letters or too few digits" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details",
                candidate_profile: { phone: "not-a-number", city: "Amsterdam", country: "Netherlands" } }

    assert_response :unprocessable_entity
    assert_select "li", "Phone must be a valid phone number"
  end

  test "update accepts an internationally formatted phone number" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details",
                candidate_profile: { phone: "+31 (6) 1234-5678", city: "Amsterdam", country: "Netherlands" } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "job_details")
  end

  test "update blocks personal_details when no language is selected" do
    profile = @profile
    profile.candidate_languages.destroy_all

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details",
                candidate_profile: { phone: "0612345678", city: "Amsterdam", country: "Netherlands" } }

    assert_response :unprocessable_entity
    assert_select "li", "Languages must have at least one selected"
  end

  test "update ignores a mismatched user id in user_attributes and updates the existing user" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "personal_details",
                candidate_profile: { phone: "0612345678", city: "Amsterdam", country: "Netherlands",
                                      user_attributes: { id: profile.user.id.to_s, first_name: "Jamie" } } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "job_details")
    assert_equal "Jamie", profile.reload.user.first_name
  end

  test "update with direction=back goes to the previous page without losing the current page's edits" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation", direction: "back", candidate_profile: { years_of_experience: 5 } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "job_details")
    assert_equal 5, profile.reload.years_of_experience
  end

  test "update on the last page redirects to the thank-you page" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "additional_information", candidate_profile: { suggested_summary: "Great candidate" } }

    assert_redirected_to complete_onboarding_candidate_profile_path(profile)
  end

  test "update on the last page marks the profile submitted" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "additional_information", candidate_profile: { suggested_summary: "Great candidate" } }

    assert_predicate profile.reload, :submitted?
  end

  test "update with direction=back on the last page does not mark the profile submitted" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "additional_information", direction: "back", candidate_profile: { suggested_summary: "Great candidate" } }

    assert_predicate profile.reload, :draft?
  end

  test "update re-renders job_details with errors when required fields are missing" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "job_details",
                candidate_profile: { job_function_id: "", region_ids: [], max_travel_time_minutes: "", search_status: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Job function can't be blank"
    assert_select "li", "Regions must have at least one selected"
    assert_select "li", "Max travel time minutes can't be blank"
    assert_select "li", "Search status can't be blank"
  end

  test "update saves job_details fields and advances to the next page" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "job_details",
                candidate_profile: { job_function_id: onboarding_job_functions(:dental_assistant).id,
                                      region_ids: [ onboarding_regions(:north).id ], max_travel_time_minutes: 30,
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
    profile = @profile
    north = onboarding_regions(:north)
    dental_assistant = onboarding_job_functions(:dental_assistant)

    patch onboarding_candidate_profile_path(profile),
      params: URI.encode_www_form([
        [ "page", "job_details" ],
        [ "candidate_profile[job_function_id]", dental_assistant.id ],
        [ "candidate_profile[max_travel_time_minutes]", "30" ],
        [ "candidate_profile[search_status]", "active" ],
        [ "candidate_profile[region_ids][]", north.id ],
        [ "candidate_profile[region_ids][]", "" ],
        [ "candidate_profile[transport_types][]", "car" ],
        [ "candidate_profile[transport_types][]", "" ]
      ]),
      headers: { "Content-Type" => "application/x-www-form-urlencoded" }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "compensation")
    assert_equal [ "North" ], profile.reload.regions.pluck(:name)
    assert_equal [ "car" ], profile.transport_types
  end

  test "update re-renders compensation with errors when required fields are missing" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation", candidate_profile: { employment_type_ids: [], years_of_experience: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Employment types must have at least one selected"
    assert_select "li", "Years of experience can't be blank"
  end

  test "update requires desired_gross_salary when an employed employment type is selected" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_type_ids: [ onboarding_employment_types(:employed).id ], years_of_experience: 5,
                                      desired_gross_salary: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Desired gross salary can't be blank"
  end

  test "update requires desired_percentage when a self-employed or freelance employment type is selected" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_type_ids: [ onboarding_employment_types(:self_employed).id ], years_of_experience: 5,
                                      desired_percentage: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Desired percentage can't be blank"
  end

  test "update requires average_daily_revenue for revenue-relevant job functions" do
    profile = @profile
    profile.update!(job_function: onboarding_job_functions(:general_dentist))

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_type_ids: [ onboarding_employment_types(:employed).id ], years_of_experience: 5,
                                      desired_gross_salary: 3000, average_daily_revenue: "",
                                      big_registration_status: "not_applicable" } }

    assert_response :unprocessable_entity
    assert_select "li", "Average daily revenue can't be blank"
  end

  test "update does not require average_daily_revenue for non-revenue-relevant job functions" do
    profile = @profile
    profile.update!(job_function: onboarding_job_functions(:prevention_assistant))

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_type_ids: [ onboarding_employment_types(:employed).id ], years_of_experience: 5,
                                      desired_gross_salary: 3000, average_daily_revenue: "" } }

    assert_response :found
  end

  test "update rejects a non-numeric average_daily_revenue instead of silently saving 0" do
    profile = @profile
    profile.update!(job_function: onboarding_job_functions(:general_dentist))

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_type_ids: [ onboarding_employment_types(:employed).id ], years_of_experience: 5,
                                      desired_gross_salary: 3000, average_daily_revenue: "abc",
                                      big_registration_status: "not_applicable" } }

    assert_response :unprocessable_entity
    assert_select "li", "Average daily revenue is not a number"
    assert_nil profile.reload.average_daily_revenue
  end

  test "update requires desired_percentage when percentage_based employment type is selected" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_type_ids: [ onboarding_employment_types(:percentage_based).id ], years_of_experience: 5,
                                      desired_percentage: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Desired percentage can't be blank"
  end

  test "update requires big_registration_status for BIG-relevant job functions" do
    profile = @profile
    profile.update!(job_function: onboarding_job_functions(:general_dentist))

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_type_ids: [ onboarding_employment_types(:employed).id ], years_of_experience: 5,
                                      desired_gross_salary: 3000, average_daily_revenue: 100,
                                      big_registration_status: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Big registration status can't be blank"
  end

  test "update requires big_number when big_registration_status is big_registered" do
    profile = @profile
    profile.update!(job_function: onboarding_job_functions(:general_dentist))

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_type_ids: [ onboarding_employment_types(:employed).id ], years_of_experience: 5,
                                      desired_gross_salary: 3000, average_daily_revenue: 100,
                                      big_registration_status: "big_registered", big_number: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Big number can't be blank"
  end

  test "update saves compensation fields and advances to the next page" do
    profile = @profile
    profile.update!(job_function: onboarding_job_functions(:general_dentist))

    patch onboarding_candidate_profile_path(profile),
      params: { page: "compensation",
                candidate_profile: { employment_type_ids: [ onboarding_employment_types(:employed).id ], years_of_experience: 5,
                                      desired_gross_salary: 3000, average_daily_revenue: 100,
                                      big_registration_status: "not_applicable" } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "education")
  end

  test "update accepts a real browser submission with the compensation checkbox group's blank hidden fallback field" do
    profile = @profile
    profile.update!(job_function: onboarding_job_functions(:dental_technician))
    employed = onboarding_employment_types(:employed)

    patch onboarding_candidate_profile_path(profile),
      params: URI.encode_www_form([
        [ "page", "compensation" ],
        [ "candidate_profile[years_of_experience]", "5" ],
        [ "candidate_profile[desired_gross_salary]", "3000" ],
        [ "candidate_profile[employment_type_ids][]", employed.id ],
        [ "candidate_profile[employment_type_ids][]", "" ]
      ]),
      headers: { "Content-Type" => "application/x-www-form-urlencoded" }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "education")
    assert_equal [ "Employed" ], profile.reload.employment_types.pluck(:name)
  end

  test "update saves education fields and advances to the next page" do
    profile = @profile

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
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "work_experience",
                candidate_profile: { work_experiences_attributes: {
                  "0" => { job_title: "Dentist", company_name: "Dental Clinic Utrecht" }
                } } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "skills")
    assert_includes profile.reload.work_experiences.pluck(:job_title), "Dentist"
  end

  test "update saves skills fields and advances to the next page" do
    profile = @profile
    profile.update!(job_function: onboarding_job_functions(:dental_technician))
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
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "availability", candidate_profile: { working_days: [], available_from: "" } }

    assert_response :unprocessable_entity
    assert_select "li", "Working days must have at least one selected"
    assert_select "li", "Available from can't be blank"
  end

  test "update saves availability fields and advances to the next page" do
    profile = @profile

    patch onboarding_candidate_profile_path(profile),
      params: { page: "availability",
                candidate_profile: { working_days: [ "monday" ], available_from: Date.tomorrow } }

    assert_redirected_to edit_onboarding_candidate_profile_path(profile, page: "additional_information")
  end

  test "update accepts a real browser submission with the availability checkbox group's blank hidden fallback field" do
    profile = @profile

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

  test "show 404s for a candidate profile that isn't the current session's" do
    other_profile = Onboarding::CreateGuestCandidateProfileService.new.call.candidate_profile

    get onboarding_candidate_profile_path(other_profile)

    assert_response :not_found
  end

  test "edit 404s for a candidate profile that isn't the current session's" do
    other_profile = Onboarding::CreateGuestCandidateProfileService.new.call.candidate_profile

    get edit_onboarding_candidate_profile_path(other_profile)

    assert_response :not_found
  end

  test "update 404s for a candidate profile that isn't the current session's, and does not save the change" do
    other_profile = Onboarding::CreateGuestCandidateProfileService.new.call.candidate_profile

    patch onboarding_candidate_profile_path(other_profile),
      params: { page: "personal_details", candidate_profile: { phone: "0612345678" } }

    assert_response :not_found
    assert_nil other_profile.reload.phone
  end

  test "a different browser session with no candidate token cannot view the profile" do
    open_session do |guest|
      guest.get guest.onboarding_candidate_profile_path(@profile)
      assert_equal 404, guest.response.status
    end
  end

  test "complete renders the thank-you page once the profile is submitted" do
    profile = @profile
    profile.update!(onboarding_status: :submitted)

    get complete_onboarding_candidate_profile_path(profile)

    assert_response :success
    assert_select "p", /Thank you/
  end

  test "complete redirects back to edit when the profile hasn't been submitted yet" do
    profile = @profile

    get complete_onboarding_candidate_profile_path(profile)

    assert_redirected_to edit_onboarding_candidate_profile_path(profile)
  end

  test "complete 404s for a candidate profile that isn't the current session's" do
    other_profile = Onboarding::CreateGuestCandidateProfileService.new.call.candidate_profile

    get complete_onboarding_candidate_profile_path(other_profile)

    assert_response :not_found
  end
end
