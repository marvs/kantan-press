require "rails_helper"

RSpec.describe "the sign-in page" do
  before { allow(KantanPress::Config).to receive(:site_title).and_return("The Stoic Engineer") }

  # The public ERB layout is what a site owner meets at /session/new, so it has
  # to say whose site this is rather than what software runs it.
  it "wears the site's own title, not the product name" do
    get new_session_path

    expect(response.body).to include('<p class="site-title"><a href="/">The Stoic Engineer</a></p>')
  end

  it "keeps the masthead to the title and tagline, with no category nav" do
    allow(KantanPress::Config).to receive(:site_description).and_return("Notes on code and servers")
    create(:post, categories: [ create(:category, name: "Stoicism", slug: "stoicism") ])

    get new_session_path

    expect(response.body).to include("Notes on code and servers")
    expect(response.body).not_to include('class="site-nav"', "/category/stoicism")
  end

  it "renders a labelled form rather than the scaffold" do
    get new_session_path

    expect(response.body).to include('class="auth-card"')
    expect(response.body).to include("Email address", "Password")
    expect(response.body).not_to include("<br>")
  end

  # Password reset was removed: the mailer had no SMTP settings, no real from
  # address and a placeholder host, so the app promised an email it could not
  # send. A locked-out owner resets from the console instead.
  it "offers no password reset, because there is nothing behind it" do
    get new_session_path

    expect(response.body).not_to include("Forgot", "password reset")
    expect { passwords_path }.to raise_error(NameError)
  end

  it "shows a failed sign-in as a styled flash, not an inline style attribute" do
    post session_path, params: { email_address: "nobody@example.com", password: "wrong" }
    follow_redirect!

    expect(response.body).to include("flash-alert")
    expect(response.body).not_to include('style="color:red"')
  end
end
