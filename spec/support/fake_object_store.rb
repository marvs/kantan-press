# In-memory stand-in for ObjectStore backends. Records what was uploaded so
# specs can assert on keys and content types without a bucket or the disk.
class FakeObjectStore
  attr_reader :uploads

  def initialize
    @uploads = {}
  end

  def upload(key:, io:, content_type: nil)
    @uploads[key] = { body: io.read, content_type: content_type }
    key
  end

  def exist?(key) = @uploads.key?(key)

  def delete(key) = @uploads.delete(key)

  def url_for(key) = File.join(KantanPress::Config.media_base_url.to_s, key)

  def keys = @uploads.keys
end
