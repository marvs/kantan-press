require "rails_helper"

RSpec.describe Wordpress::MediaVerifier do
  # A row can say "stored" while its object is gone — the store was swapped
  # after the fetch, or the object was deleted. Nothing else notices, and the
  # only symptom is a broken image on the public site.
  def store = ObjectStore.current

  def stored_item(key)
    create(:media_item, :stored, key: key).tap { store.upload(key: key, io: StringIO.new("x")) }
  end

  it "passes when every stored object is present" do
    stored_item("wp-content/uploads/2026/05/a.png")
    stored_item("wp-content/uploads/2026/05/b.png")

    result = described_class.call

    expect(result.checked).to eq(2)
    expect(result.missing).to be_empty
  end

  it "finds a row whose object is not in the store" do
    present = stored_item("wp-content/uploads/2026/05/a.png")
    absent = create(:media_item, :stored, key: "wp-content/uploads/2026/05/gone.png")

    result = described_class.call

    expect(result.checked).to eq(2)
    expect(result.missing.map(&:id)).to eq([ absent.id ])
    expect(result.missing).not_to include(present)
  end

  it "ignores rows that never claimed to be stored" do
    create(:media_item, key: "wp-content/uploads/2026/05/pending.png")
    create(:media_item, :failed, key: "wp-content/uploads/2026/05/failed.png")

    result = described_class.call

    expect(result.checked).to eq(0)
    expect(result.missing).to be_empty
  end

  it "leaves the rows alone unless asked to reset them" do
    absent = create(:media_item, :stored, key: "wp-content/uploads/2026/05/gone.png")

    described_class.call

    expect(absent.reload).to be_stored
  end

  describe "with reset" do
    it "puts a missing object back in the fetch queue" do
      absent = create(:media_item, :stored, key: "wp-content/uploads/2026/05/gone.png",
                      uploaded_at: 1.day.ago, fetch_attempts: 3)

      result = described_class.call(reset: true)

      expect(result.reset).to be(true)
      expect(absent.reload).to have_attributes(status: "pending", uploaded_at: nil, fetch_attempts: 0)
      expect(MediaItem.awaiting_fetch).to include(absent)
    end

    it "does not disturb the rows that are fine" do
      present = stored_item("wp-content/uploads/2026/05/a.png")
      create(:media_item, :stored, key: "wp-content/uploads/2026/05/gone.png")

      described_class.call(reset: true)

      expect(present.reload).to be_stored
    end
  end
end
