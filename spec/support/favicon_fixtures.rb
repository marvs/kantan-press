require "zlib"

# Real image bytes for the favicon specs.
#
# The uploader validates by reading the file's own header rather than trusting
# the extension or the browser's content type, so the fixtures have to be
# genuine files — a stub of the right length would pass nothing worth passing.
# A PNG is small enough to assemble here, which also means the dimension cap
# can be tested at any size without an image library.
module FaviconFixtures
  def favicon_root
    @favicon_root ||= Pathname.new(Dir.mktmpdir("kantan-branding")).tap do |dir|
      allow(Branding::Favicon).to receive(:root).and_return(dir)
    end
  end

  # Puts a favicon in place the way a completed upload would.
  def install_favicon(extension: ".png", bytes: nil)
    bytes ||= extension == ".svg" ? svg_bytes : png_bytes
    path = favicon_root.join("favicon#{extension}")
    FileUtils.mkdir_p(path.dirname)
    path.binwrite(bytes)
    SiteSetting.set(Branding::Favicon::SETTING, extension)
    path
  end

  def png_bytes(width: 32, height: 32)
    ihdr = [ width, height ].pack("N2") + [ 8, 6, 0, 0, 0 ].pack("C5")
    row = [ 0 ].pack("C") + ([ 0, 0, 0, 0 ].pack("C4") * width) # filter byte, then RGBA
    idat = Zlib::Deflate.deflate(row * height)

    "\x89PNG\r\n\x1A\n".b + png_chunk("IHDR", ihdr) + png_chunk("IDAT", idat) + png_chunk("IEND", "")
  end

  def svg_bytes(body: '<rect width="32" height="32" fill="#1d4ed8"/>')
    %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">#{body}</svg>).b
  end

  def jpeg_bytes = "\xFF\xD8\xFF\xE0".b + ("\x00" * 128)

  # An uploaded file as the controller and the uploader see one.
  def uploaded(filename, bytes, type: nil)
    file = Tempfile.new([ "upload", File.extname(filename) ], binmode: true)
    file.write(bytes)
    file.rewind

    ActionDispatch::Http::UploadedFile.new(
      tempfile: file, filename: filename,
      type: type || Rack::Mime.mime_type(File.extname(filename))
    )
  end

  # The same bytes as a multipart form field, for request specs.
  def rack_upload(filename, bytes)
    file = Tempfile.new([ "upload", File.extname(filename) ], binmode: true)
    file.write(bytes)
    file.close

    Rack::Test::UploadedFile.new(file.path, Rack::Mime.mime_type(File.extname(filename)),
                                 original_filename: filename)
  end

  def cleanup_favicon_root
    FileUtils.remove_entry(@favicon_root, true) if @favicon_root
    @favicon_root = nil
  end

  private
    def png_chunk(type, data)
      [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N")
    end
end

RSpec.configure do |config|
  config.include FaviconFixtures
  config.after { cleanup_favicon_root }
end
