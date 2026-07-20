module Base
  class User < ApplicationRecord
    enum :role, { guest: 0, candidate: 1, admin: 2 }, default: :guest

    normalizes :email, with: ->(email) { email.strip.downcase }

    validates :first_name, :last_name, presence: true
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  end
end
