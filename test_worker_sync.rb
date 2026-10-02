require 'tmpdir'
require 'fileutils'
require 'open3'
require 'json'
require 'digest'
def run(*args,env:{})
 out,err,status=Open3.capture3(env,*args)
 [out+err,status.success?]
end
def must(*args)
 out,ok=run(*args);abort out unless ok
end
Dir.mktmpdir('vcn-worker-sync-') do |temp|
 origin=File.join(temp,'origin');clone=File.join(temp,'clone');FileUtils.mkdir_p(origin)
 %w[data.json agent-tasks.json AGENTS.md CONTRIBUTING.md VERIFICATION.md sync_worker.rb].each{|p|FileUtils.cp(File.join(__dir__,p),origin)}
 FileUtils.cp_r(File.join(__dir__,'evidence'),origin)
 must('git','init','-b','main',origin)
 must('git','-C',origin,'add','.')
 must('git','-C',origin,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-m','Synthetic worker synchronization fixture')
 must('git','clone',origin,clone)
 must('git','-C',clone,'remote','set-url','origin','https://github.com/example/vcn-fixture.git')
 env={'GIT_CONFIG_COUNT'=>'1','GIT_CONFIG_KEY_0'=>"url.#{origin}.insteadOf",'GIT_CONFIG_VALUE_0'=>'https://github.com/example/vcn-fixture.git'}
 dest=File.join(temp,'snapshot')
 out,ok=run('ruby',File.join(clone,'sync_worker.rb'),'T23','worker-one','alice',dest,env:env)
 abort out unless ok
 packet=JSON.parse(File.read(File.join(dest,'task.json')))
 abort 'Worker linkage missing' unless packet.dig('worker','id')=='worker-one' && packet.dig('worker','human_principal')=='alice'
 packet['sources'].each{|p,h|abort 'Snapshot hash mismatch' unless Digest::SHA256.file(File.join(dest,p)).hexdigest==h}
 puts 'PASS exact-revision worker snapshot and source hashes'
 out,ok=run('ruby',File.join(clone,'sync_worker.rb'),'T23','worker-one','alice',dest,env:env)
 abort 'Existing snapshot overwritten' if ok
 puts 'PASS old snapshot preserved'
 d=JSON.parse(File.read(File.join(origin,'data.json')));d['prepared_date']='stale-packet-fixture'
 File.write(File.join(origin,'data.json'),JSON.pretty_generate(d)+"\n")
 must('git','-C',origin,'add','data.json')
 must('git','-C',origin,'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-m','Synthetic stale packet')
 out,ok=run('ruby',File.join(clone,'sync_worker.rb'),'T23','worker-two','bob',File.join(temp,'stale'),env:env)
 abort 'Stale ledger packet accepted' if ok || File.exist?(File.join(temp,'stale'))
 puts 'PASS stale ledger packet rejected before snapshot creation'
end
