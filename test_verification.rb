require 'json'
require 'tmpdir'
require 'fileutils'
require_relative 'verification'
data=JSON.parse(File.read(File.join(__dir__,'data.json')))
count=0
check=lambda do |name,should_pass,&mutate|
 Dir.mktmpdir('vcn-verification-') do |root|
  FileUtils.cp(File.join(__dir__,'legacy-claims.json'),root)
  FileUtils.cp_r(File.join(__dir__,'evidence'),root)
  d=Marshal.load(Marshal.dump(data));mutate.call(d,root)
  errors=Verification.check(d,root)
  abort "FAIL #{name}: #{errors.join('; ')}" unless errors.empty? == should_pass
  count+=1;puts "PASS #{name}"
 end
end
valid=lambda do |d,root|
 p='evidence/test-verification.txt';File.write(File.join(root,p),'synthetic fixture, not board evidence')
 a={path:p,sha256:Digest::SHA256.file(File.join(root,p)).hexdigest}
 c=d['claims'].find{|x|x['id']=='C32'}
 c.merge!('state'=>'proven','review'=>'accepted','kind'=>'static','reviewers'=>['reviewer'],'verification_id'=>'V-test')
 d['verifications']=[{'id'=>'V-test','supports'=>['C32','T23'],'author_principal'=>'author','reviewer_principal'=>'reviewer','kind'=>'static','scope'=>c['scope'],'method'=>'bounded static inspection','expected'=>'fixture result','actual'=>'fixture result','controls'=>'changed-input fixture','limitations'=>'synthetic record shape only','environment'=>{'inputs'=>'fixture'},'artifacts'=>[a.transform_keys(&:to_s)],'independent_reproduction'=>{'principal'=>'reviewer','method'=>'separate inspection','actual'=>'fixture result','artifacts'=>[a.transform_keys(&:to_s)]},'review_url'=>'https://github.com/example/research/pull/1#pullrequestreview-1'}]
end
check.call('current baseline remains valid',true){|d,r|}
check.call('pending proof cannot be green',false){|d,r|d['claims'].find{|c|c['id']=='C32'}['state']='proven'}
check.call('forged seeded proof rejected',false){|d,r|d['claims'].find{|c|c['id']=='C32'}.merge!('review'=>'seeded','state'=>'proven')}
check.call('changed legacy statement rejected',false){|d,r|d['claims'][0]['scope']='all hardware proven'}
check.call('valid independent record shape',true){|d,r|valid.call(d,r)}
check.call('accepted completion with exact criterion',true){|d,r|valid.call(d,r);t=d['tasks'].find{|x|x['id']=='T23'};d['verifications'][0]['task_criteria']={'T23'=>t['done_when']};t.merge!('status'=>'done','attempts'=>[{'review'=>'accepted','verification_id'=>'V-test','author_principal'=>'author'}])}
check.call('changed completion criterion rejected',false){|d,r|valid.call(d,r);t=d['tasks'].find{|x|x['id']=='T23'};d['verifications'][0]['task_criteria']={'T23'=>'different criterion'};t.merge!('status'=>'done','attempts'=>[{'review'=>'accepted','verification_id'=>'V-test','author_principal'=>'author'}])}
check.call('self review rejected',false){|d,r|valid.call(d,r);d['verifications'][0]['reviewer_principal']='author'}
check.call('missing reproduction rejected',false){|d,r|valid.call(d,r);d['verifications'][0].delete('independent_reproduction')}
check.call('changed artifact rejected',false){|d,r|valid.call(d,r);File.write(File.join(r,'evidence/test-verification.txt'),'changed')}
check.call('fabricated accepted attempt rejected',false){|d,r|d['tasks'][0].merge!('status'=>'done','attempts'=>[{'review'=>'accepted'}])}
check.call('hardware without boot provenance rejected',false){|d,r|valid.call(d,r);d['verifications'][0]['kind']='hardware';d['claims'].find{|c|c['id']=='C32'}['kind']='hardware'}
check.call('green stage with unresolved claims rejected',false){|d,r|d['stages'].find{|s|s['id']=='S14'}['state']='proven'}
check.call('arbitrary review URL rejected',false){|d,r|valid.call(d,r);d['verifications'][0]['review_url']='https://example.org/approved'}
puts "#{count} verification controls passed; no hardware validation claimed."
