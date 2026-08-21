require "rails_helper"

RSpec.describe SiteSetting do
  before { described_class.reset_cache! }

  describe ".get and .set" do
    it "stores and reads a value" do
      described_class.set(:site_title, "Tech and FI")

      expect(described_class.get(:site_title)).to eq("Tech and FI")
    end

    it "updates in place rather than adding a second row" do
      described_class.set(:site_title, "First")
      described_class.set(:site_title, "Second")

      expect(described_class.count).to eq(1)
      expect(described_class.get(:site_title)).to eq("Second")
    end

    it "returns nil for a key that was never set" do
      expect(described_class.get(:nope)).to be_nil
    end

    it "treats a blank value as unset, so it falls through to ENV" do
      described_class.set(:site_title, "  ")

      expect(described_class.get(:site_title)).to be_nil
    end

    it "accepts symbol and string keys alike" do
      described_class.set("site_title", "Tech and FI")

      expect(described_class.get(:site_title)).to eq("Tech and FI")
    end
  end

  describe "caching" do
    it "loads every setting once, not once per key" do
      described_class.set(:site_title, "Tech and FI")
      described_class.set(:site_description, "Notes")
      described_class.reset_cache!
      allow(described_class).to receive(:load_all).and_call_original

      described_class.get(:site_title)
      described_class.get(:site_description)

      expect(described_class).to have_received(:load_all).once
    end

    it "sees a write straight away" do
      described_class.get(:site_title)
      described_class.set(:site_title, "Changed")

      expect(described_class.get(:site_title)).to eq("Changed")
    end
  end

  describe "when the table is not there yet" do
    it "returns nil instead of raising, so boot-time config still works" do
      allow(described_class).to receive(:pluck).and_raise(ActiveRecord::StatementInvalid.new("no such table"))

      described_class.reset_cache!

      expect(described_class.get(:site_title)).to be_nil
    end
  end
end
