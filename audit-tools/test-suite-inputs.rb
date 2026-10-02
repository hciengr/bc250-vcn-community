require 'tmpdir';require 'fileutils';require_relative 'check-suite-inputs'
Dir.mktmpdir('suite-preflight-') do |root|
  sha=Digest::SHA256.hexdigest('fixture')
  baseline={'checks'=>[{'name'=>'fixture','command'=>['ruby','tools/check.rb'],'script_sha256'=>sha,'scope'=>'synthetic fixture'}],'inputs'=>{'inputs/payload'=>sha}}
  FileUtils.mkdir_p(File.join(root,'tools'));FileUtils.mkdir_p(File.join(root,'inputs'))
  report=ContributionSuitePreflight.inspect(root,baseline)
  raise 'Missing files accepted' if report[:recorded_minimums_match]
  puts 'PASS missing prerequisites rejected'
  File.write(File.join(root,'tools/check.rb'),'fixture');File.write(File.join(root,'inputs/payload'),'fixture');File.write(File.join(root,'tools/run-vcn-contribution-checks.rb'),'fixture')
  raise 'Matching prerequisites rejected' unless ContributionSuitePreflight.inspect(root,baseline)[:recorded_minimums_match]
  puts 'PASS matching recorded minimums recognized without execution'
  File.write(File.join(root,'inputs/payload'),'changed')
  raise 'Changed firmware accepted' if ContributionSuitePreflight.inspect(root,baseline)[:recorded_minimums_match]
  puts 'PASS changed input hash rejected'
  File.write(File.join(root,'inputs/payload'),'fixture');File.write(File.join(root,'tools/check.rb'),'changed')
  raise 'Changed auditor accepted' if ContributionSuitePreflight.inspect(root,baseline)[:recorded_minimums_match]
  puts 'PASS changed script hash rejected'
  FileUtils.mkdir_p(File.join(root,'audit-tools'));File.write(File.join(root,'audit-tools/check.rb'),'fixture')
  raise 'Hash-matched bundled alias rejected' unless ContributionSuitePreflight.inspect(root,baseline)[:recorded_minimums_match]
  puts 'PASS exact bundled script alias recognized'
end
