require "rails_helper"

RSpec.describe "Admin::Imports" do
  before { sign_in }

  let(:fixture) { Rails.root.join("spec/fixtures/wordpress/techandfi_sample.xml") }

  def upload
    Rack::Test::UploadedFile.new(fixture, "text/xml")
  end

  it "queues an import and stores the uploaded export" do
    expect {
      post admin_imports_path, params: { file: upload }
    }.to change(Import, :count).by(1)

    import = Import.last
    expect(import).to be_pending
    expect(File.exist?(import.source_path)).to be(true)
    expect(Wordpress::ImportJob).to have_been_enqueued.with(import.id)
  end

  it "rejects a submission with no file" do
    expect { post admin_imports_path }.not_to change(Import, :count)

    expect(response).to redirect_to(new_admin_import_path)
  end

  it "runs the import end to end through the job" do
    post admin_imports_path, params: { file: upload }
    perform_enqueued_jobs(only: Wordpress::ImportJob)

    import = Import.last.reload
    expect(import).to be_completed
    expect(import.stats["posts"]["created"]).to eq(4)
    expect(Post.count).to eq(4)
  end

  it "shows the summary once finished" do
    post admin_imports_path, params: { file: upload }
    perform_enqueued_jobs(only: Wordpress::ImportJob)

    get admin_import_path(Import.last)

    expect(response.body).to include("Completed")
  end

  after do
    FileUtils.rm_rf(Admin::ImportsController::UPLOAD_DIR)
  end
end

RSpec.describe "Admin::MediaItems" do
  before { sign_in }

  it "shows fetch progress broken down by status" do
    create(:media_item, :stored)
    create(:media_item, :failed)
    create(:media_item)

    get admin_media_items_path

    expect(response.body).to include("Stored", "Failed", "Pending")
  end

  it "re-queues a single failed image" do
    item = create(:media_item, :failed)

    post retry_fetch_admin_media_item_path(item)

    expect(item.reload).to be_pending
    expect(item.fetch_error).to be_nil
    expect(Wordpress::FetchMediaJob).to have_been_enqueued.with(item.id)
  end

  it "re-queues every failed image at once" do
    create_list(:media_item, 3, :failed)
    create(:media_item, :stored)

    post retry_all_failed_admin_media_items_path

    expect(MediaItem.failed.count).to eq(0)
    expect(Wordpress::FetchMediaJob).to have_been_enqueued.exactly(3).times
  end

  it "removes the object from storage when deleting a stored image" do
    item = create(:media_item, :stored)
    ObjectStore.current.upload(key: item.key, io: StringIO.new("data"), content_type: "image/png")

    delete admin_media_item_path(item)

    expect(ObjectStore.current.exist?(item.key)).to be(false)
    expect(MediaItem.find_by(id: item.id)).to be_nil
  end
end
