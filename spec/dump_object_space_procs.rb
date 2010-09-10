require File.join(File.dirname(File.expand_path(__FILE__)), '..', 'lib', 'sourcify')
require 'benchmark'
require 'pp'

if RUBY_PLATFORM =~ /java/i
  require 'jruby'
  JRuby.objectspace = true
  reload! rescue nil
end

def dump_object_space_procs(debug = false)
  errors = []

  # Determine working dir
  name = [
    RUBY_DESCRIPTION =~ /enterprise/i ? 'ree' : (RUBY_PLATFORM =~ /java/i ? 'jruby' : 'mri'),
    RUBY_VERSION,
    Object.const_defined?(:ParseTree) ? 'parsetree' : nil
  ].compact.join('~')
  dump_dir = File.join(File.dirname(File.expand_path(__FILE__)), '..', 'tmp', name)
  Dir.mkdir(dump_dir) unless File.exists?(dump_dir)

  puts '',
    '== NOTE: dump files can be found at %s' % dump_dir

  # Core processing
  results = Benchmark.measure do
    ObjectSpace.each_object(Proc).to_a.
      group_by{|o| o.source_location[0] }.each do |ofile, objs|
        nfile = File.join(dump_dir, ofile.gsub('/','~'))
        File.open(nfile,'w') do |f|
          objs.sort_by{|o| o.source_location[1] }.map do |o|
            begin
              data = {
                :location => o.source_location,
                :sexp => o.to_sexp,
                :source => o.to_source
              }
              f.puts(data.pretty_inspect)
              print '.'
            rescue Exception
              data = {
                :location => o.source_location,
                :error => $!.inspect
              }
              errors << data
              f.puts(data.pretty_inspect)
              pp(data) if debug
              print 'x'
            end
          end
        end
      end
  end

  puts '',''
  unless errors.empty?
    puts '== OOPS, we have some erorrs :('
    errors.each_with_index{|e, i| print "#{i}). %s" % e.pretty_inspect }
  else
    puts '== YEAH, no errors :)'
  end
  puts '', '== Benchmark results:',
    results.to_s, ''
end

dump_object_space_procs
