module AuthenticationHelpers
  PASSWORD = "password-that-is-long-enough".freeze

  def sign_in(user = nil)
    user ||= create(:user)
    post session_path, params: { email_address: user.email_address, password: PASSWORD }
    user
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
