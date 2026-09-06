module Branding
  # Validates an uploaded favicon and puts it in place.
  #
  # The shape of the check matters more than the checks themselves. Both the
  # filename extension and the browser's Content-Type are supplied by whoever is
  # uploading, so neither is evidence of anything. What the file actually *is*
  # comes from reading its first bytes, and the two have to agree — an HTML
  # document called logo.png, served back as image/png, is the shape of a stored
  # XSS bug.
  #
  # Nothing is written until every check has passed, and the last step is a
  # rename inside the destination directory, so a refused upload cannot damage
  # the favicon that was already working.
  class FaviconUploader
    MAX_BYTES = 512.kilobytes
    MAX_PIXELS = 1024

    PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
    EXTENSIONS = Favicon::CONTENT_TYPES.keys.freeze

    Result = Struct.new(:favicon, :errors, keyword_init: true) do
      def success? = errors.empty?
    end

    def self.call(file) = new(file).call

    def initialize(file)
      @file = file
      @errors = []
    end

    def call
      return failure("choose a PNG or an SVG file to upload") unless uploaded_file?

      extension = File.extname(@file.original_filename.to_s).downcase
      return failure("a favicon has to be a PNG or an SVG") unless EXTENSIONS.include?(extension)

      # Size before read. A cap that only applies once the file is already a
      # Ruby string is not a cap on anything that matters, and it is not how
      # Themes::Installer checks either.
      return failure("that file is larger than #{MAX_BYTES / 1.kilobyte}KB") if @file.size.to_i > MAX_BYTES

      bytes = @file.read.to_s.b

      problem = content_problem(extension, bytes)
      return failure(problem) if problem

      Result.new(favicon: store(extension, bytes), errors: [])
    end

    private
      # params[:favicon] is whatever the request carried, which is not
      # necessarily a file — a hand-made POST can put a string there.
      def uploaded_file?
        @file.respond_to?(:original_filename) && @file.respond_to?(:read) && @file.respond_to?(:size)
      end

      # Reads what the file is, rather than what it says it is.
      def content_problem(extension, bytes)
        extension == ".png" ? png_problem(bytes) : svg_problem(bytes)
      end

      def png_problem(bytes)
        return "that file is not a PNG, whatever it is named" unless bytes.start_with?(PNG_SIGNATURE)

        width, height = png_dimensions(bytes)
        return "that PNG's size could not be read" if width.nil?

        if width > MAX_PIXELS || height > MAX_PIXELS
          return "a favicon may not be larger than #{MAX_PIXELS}x#{MAX_PIXELS} pixels"
        end

        nil
      end

      # The IHDR chunk is always first and always at the same offset, so the
      # dimensions are two big-endian integers 16 bytes in. Reading them here is
      # what keeps an image-processing gem — and the native library it needs on
      # the Kamal host — out of this app entirely.
      def png_dimensions(bytes)
        return nil if bytes.bytesize < 24 || bytes[12, 4] != "IHDR"

        bytes[16, 8].unpack("N2")
      end

      # Parsed rather than pattern-matched: an SVG is executable content, and
      # "does it contain <svg" is satisfied by an HTML page that merely mentions
      # one. It is still served under a sandbox CSP, which is the real defence.
      def svg_problem(bytes)
        document = Nokogiri::XML(bytes) { |config| config.nonet.strict }
        return "that file is not an SVG, whatever it is named" if document.root&.name != "svg"

        nil
      rescue Nokogiri::XML::SyntaxError
        "that file is not an SVG, whatever it is named"
      end

      # Written under a temporary name in the destination directory so the final
      # step is a rename on the same filesystem, and the favicon is never half
      # written. Any file of the other extension goes at the same time, or a
      # PNG upload would leave an orphaned SVG behind it.
      def store(extension, bytes)
        FileUtils.mkdir_p(Favicon.root)
        staged = Favicon.root.join(".favicon-#{SecureRandom.hex(8)}#{extension}")
        staged.binwrite(bytes)

        FileUtils.mv(staged.to_s, Favicon.path_for(extension).to_s)
        (EXTENSIONS - [ extension ]).each { |other| FileUtils.rm_f(Favicon.path_for(other)) }

        SiteSetting.set(Favicon::SETTING, extension)
        Current.favicon = nil

        Favicon.current
      end

      def failure(message) = Result.new(favicon: nil, errors: [ message ])
  end
end
