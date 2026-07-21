# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Onboarding::CvExtractionAlias — starter dictionary the rule-based CV FieldExtractor consults for
# job_function/country/city matching. "exact" entries are precise job-title/name matches (high
# extraction confidence); "keyword" entries are looser substrings (low confidence). Grow this over
# time rather than hardcoding new terms into the extractor itself.
job_function_aliases = {
  exact: {
    "tandarts" => "general_dentist",
    "mondhygiënist" => "dental_hygienist",
    "mondhygieniste" => "dental_hygienist",
    "tandartsassistent" => "dental_assistant",
    "tandartsassistente" => "dental_assistant",
    "preventieassistent" => "prevention_assistant",
    "preventieassistente" => "prevention_assistant",
    "praktijkmanager" => "practice_manager",
    "tandtechnicus" => "dental_technician",
    "orthodontist" => "specialist",
    "kaakchirurg" => "specialist"
  },
  keyword: {
    "dentist" => "general_dentist",
    "dental hygienist" => "dental_hygienist",
    "dental assistant" => "dental_assistant",
    "prevention assistant" => "prevention_assistant",
    "paro preventieassistent" => "paro_prevention_assistant",
    "parodontologie" => "paro_prevention_assistant",
    "orthodontie assistent" => "orthodontic_assistant",
    "orthodontic assistant" => "orthodontic_assistant",
    "baliemedewerker" => "front_office_receptionist",
    "receptionist" => "front_office_receptionist",
    "front office" => "front_office_receptionist",
    "practice manager" => "practice_manager",
    "dental technician" => "dental_technician",
    "parodontoloog" => "specialist",
    "endodontoloog" => "specialist"
  }
}

job_function_aliases.each do |match_type, aliases|
  aliases.each do |pattern, value|
    Onboarding::CvExtractionAlias.find_or_create_by!(field: "job_function", pattern: pattern, match_type: match_type) do |alias_record|
      alias_record.value = value
    end
  end
end

country_aliases = {
  "netherlands" => "Netherlands",
  "nederland" => "Netherlands",
  "the netherlands" => "Netherlands",
  "holland" => "Netherlands"
}

country_aliases.each do |pattern, value|
  Onboarding::CvExtractionAlias.find_or_create_by!(field: "country", pattern: pattern, match_type: :exact) do |alias_record|
    alias_record.value = value
  end
end

dutch_cities = %w[
  Amsterdam Rotterdam Utrecht Eindhoven Groningen Tilburg Almere Breda Nijmegen Enschede
  Haarlem Arnhem Zaanstad Amersfoort Apeldoorn Hoofddorp Maastricht Leiden Dordrecht Zoetermeer
  Zwolle Deventer Delft Alkmaar Heerlen Venlo Leeuwarden Ede
]
dutch_cities += [ "Den Haag", "'s-Hertogenbosch" ]

dutch_cities.each do |city|
  Onboarding::CvExtractionAlias.find_or_create_by!(field: "city", pattern: city.downcase, match_type: :exact) do |alias_record|
    alias_record.value = city
  end
end

big_registration_status_aliases = {
  "big-geregistreerd" => "big_registered",
  "big geregistreerd" => "big_registered",
  "big registered" => "big_registered",
  "big-registratie" => "big_registered",
  "in opleiding tot big" => "in_progress",
  "big in aanvraag" => "in_progress",
  "big registration in progress" => "in_progress",
  "onder supervisie" => "under_supervision",
  "onder toezicht" => "under_supervision",
  "under supervision" => "under_supervision"
}

big_registration_status_aliases.each do |pattern, value|
  Onboarding::CvExtractionAlias.find_or_create_by!(field: "big_registration_status", pattern: pattern, match_type: :exact) do |alias_record|
    alias_record.value = value
  end
end

# Onboarding::Language — starter platform language list, shown as a picker on the candidate's
# Personal details page and matched against by CvParsing::ProfileMapper when a CV lists languages.
languages = %w[Dutch English German French Spanish Italian Portuguese Polish Turkish Arabic Romanian]

languages.each do |name|
  Onboarding::Language.find_or_create_by!(name: name)
end

# NL/EN spellings of the languages above, canonicalized to the Onboarding::Language#name FieldExtractor
# matches against for a CV's "Talen"/"Languages" section.
language_aliases = {
  "dutch" => "Dutch",
  "nederlands" => "Dutch",
  "english" => "English",
  "engels" => "English",
  "german" => "German",
  "duits" => "German",
  "french" => "French",
  "frans" => "French",
  "spanish" => "Spanish",
  "spaans" => "Spanish",
  "italian" => "Italian",
  "italiaans" => "Italian",
  "portuguese" => "Portuguese",
  "portugees" => "Portuguese",
  "polish" => "Polish",
  "pools" => "Polish",
  "turkish" => "Turkish",
  "turks" => "Turkish",
  "arabic" => "Arabic",
  "arabisch" => "Arabic",
  "romanian" => "Romanian",
  "roemeens" => "Romanian"
}

language_aliases.each do |pattern, value|
  Onboarding::CvExtractionAlias.find_or_create_by!(field: "language", pattern: pattern, match_type: :exact) do |alias_record|
    alias_record.value = value
  end
end

# Onboarding::Skill — starter platform skill list, grouped by job_function, shown as a checklist on
# the candidate's Skills page and consulted by CvParsing::ProfileMapper to match skills found on an
# uploaded CV. Not exhaustive: job functions not listed here (specialist, prevention_assistant,
# paro_prevention_assistant, orthodontic_assistant) simply have no seeded skills yet, so candidates in
# those functions fall back to the free-text "suggested_name" field until a list is added for them.
skills_by_job_function = {
  general_dentist: [ "Endodontics", "Restorative dentistry", "Pediatric dentistry", "Surgery", "Aligners" ],
  dental_hygienist: [ "Periodontology", "Prevention", "Scaling", "Patient education" ],
  dental_assistant: [ "Chairside assistance", "Sterilization", "Orthodontics", "Prevention" ],
  front_office_receptionist: [ "Planning", "Phone handling", "Invoicing", "Patient communication" ],
  practice_manager: [ "Team management", "Scheduling", "HR", "Practice operations" ],
  dental_technician: [ "Prosthetics", "CAD/CAM", "Crown and bridge work" ]
}

skills_by_job_function.each do |job_function, names|
  names.each do |name|
    Onboarding::Skill.find_or_create_by!(name: name, job_function: job_function)
  end
end
