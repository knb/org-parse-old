
module OrgParse

  # :stopdoc:
  VERSION = '0.0.2'
  LIBPATH = ::File.expand_path(::File.dirname(__FILE__)) + ::File::SEPARATOR
  PATH = ::File.dirname(LIBPATH) + ::File::SEPARATOR
  # :startdoc:



  # Returns the version string for the library.
  #
  def self.version
    VERSION
  end

  # Returns the library path for the module. If any arguments are given,
  # they will be joined to the end of the libray path using
  # <tt>File.join</tt>.
  #
  def self.libpath( *args )
    args.empty? ? LIBPATH : ::File.join(LIBPATH, args.flatten)
  end

  # Returns the lpath for the module. If any arguments are given,
  # they will be joined to the end of the path using
  # <tt>File.join</tt>.
  #
  def self.path( *args )
    args.empty? ? PATH : ::File.join(PATH, args.flatten)
  end

  def self.to_html(fname)
    parser = StructParser.new(fname)
  end

end  # module OrgParse

require ::File.join(OrgParse::LIBPATH , 'org-parse', 'utils.rb')
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'node.rb')
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'struct-scanner.rb')
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'struct-parser.rb')
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'visitor.rb')

