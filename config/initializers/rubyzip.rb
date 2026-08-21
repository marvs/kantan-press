require "zip"

# Load-bearing for Themes::Installer's zip-bomb defence. The installer caps the
# *uncompressed* size an archive is allowed to unpack to, and reads that size
# from the zip's own central directory — so a crafted archive could understate
# it. This makes rubyzip check the extracted size against the declared one and
# raise when they disagree.
#
# It is rubyzip's default today; set explicitly so the guarantee survives a gem
# upgrade or another library changing the global.
Zip.validate_entry_sizes = true
