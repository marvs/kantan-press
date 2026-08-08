require "aws-sdk-s3"

class ObjectStore
  # Any S3-compatible endpoint. Cloudflare R2 needs region "auto" and
  # path-style addressing; AWS S3 and DigitalOcean Spaces work with the same
  # settings, so nothing here is R2-specific.
  class S3Backend
    attr_reader :bucket

    def initialize(endpoint:, bucket:, region:, access_key_id:, secret_access_key:)
      @bucket = bucket
      @client = Aws::S3::Client.new(
        endpoint: endpoint,
        region: region,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        force_path_style: true
      )
    end

    def upload(key:, io:, content_type: nil)
      @client.put_object(
        bucket: bucket,
        key: key,
        body: io,
        content_type: content_type.presence || "application/octet-stream"
      )
      key
    rescue Aws::S3::Errors::ServiceError => e
      raise ObjectStore::UploadError, "failed to upload #{key}: #{e.message}"
    end

    def exist?(key)
      @client.head_object(bucket: bucket, key: key)
      true
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      false
    end

    def delete(key)
      @client.delete_object(bucket: bucket, key: key)
    end

    def url_for(key) = File.join(KantanPress::Config.media_base_url, key)
  end
end
