# Checks recorded minimum prerequisites without executing auditor scripts.
require 'json'
require 'digest'
module ContributionSuitePreflight
  def self.inspect(root,baseline)
    root=File.expand_path(root)
    checks=baseline.fetch('checks').map do |c|
      relative=c.fetch('command').fetch(1)
      candidates=[relative,'audit-tools/'+File.basename(relative)]
      paths=candidates.map{|p|File.join(root,p)}.select{|p|File.file?(p)}
      matched=paths.find{|p|Digest::SHA256.file(p).hexdigest==c.fetch('script_sha256')}
      {name:c.fetch('name'),recorded_path:relative,expected_sha256:c.fetch('script_sha256'),
       status:matched ? 'matched' : paths.empty? ? 'missing' : 'changed',
       found_at:matched&.delete_prefix(root+'/'),scope:c.fetch('scope')}
    end
    inputs=baseline.fetch('inputs').map do |path,sha|
      actual=File.file?(File.join(root,path)) ? Digest::SHA256.file(File.join(root,path)).hexdigest : nil
      {path:path,expected_sha256:sha,actual_sha256:actual,status:sha.nil? ? 'unpinned' : actual.nil? ? 'missing' : actual==sha ? 'matched' : 'changed'}
    end
    runner='tools/run-vcn-contribution-checks.rb'
    {schema:1,kind:'offline_reproduction_prerequisite_inventory',
     auditor_scripts:checks,recorded_core_inputs:inputs,recorded_runner:{path:runner,present:File.file?(File.join(root,runner))},
     recorded_minimums_match:checks.all?{|x|x[:status]=='matched'}&&inputs.all?{|x|x[:status]=='matched'}&&File.file?(File.join(root,runner)),
     full_suite_execution_performed:false,hardware_operations:0,
     limitations:['The historical manifest records only six core inputs, not every transitive dependency.',
       'Matching these prerequisites is not proof that the full suite will execute or that any firmware runs on hardware.',
       'Bundled aliases identify the same script bytes; an auditor may still require the larger workspace working directory.']}
  end
end
if $PROGRAM_NAME==__FILE__
  abort 'Usage: ruby audit-tools/check-suite-inputs.rb INPUT_ROOT [BASELINE_MANIFEST]' unless (1..2).include?(ARGV.size)
  baseline=ARGV[1]||File.expand_path('../evidence/exports/vcn-clamp-boundary/community-review-2026-10-01/manifest.json',__dir__)
  report=ContributionSuitePreflight.inspect(ARGV[0],JSON.parse(File.read(baseline)))
  puts JSON.pretty_generate(report)
  exit(report[:recorded_minimums_match] ? 0 : 1)
end
