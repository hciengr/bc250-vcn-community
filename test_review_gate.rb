# Synthetic GitHub API responses exercise identity and current-HEAD enforcement.
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'json'
require 'digest'
Dir.mktmpdir('vcn-review-gate-') do |root|
 %w[check_review.rb verification.rb legacy-claims.json review-policy.json data.json].each{|p|FileUtils.cp(File.join(__dir__,p),root)}
 FileUtils.mkdir_p(File.join(root,'.github/workflows'))
 FileUtils.cp(File.join(__dir__,'.github/workflows/validate.yml'),File.join(root,'.github/workflows'))
 FileUtils.cp_r(File.join(__dir__,'evidence'),root)
 policy=JSON.parse(File.read(File.join(root,'review-policy.json')));policy['trusted_reviewers']=['bob'];File.write(File.join(root,'review-policy.json'),JSON.generate(policy))
 Dir.chdir(root) do
  [['init','-b','main'],['add','.'],['-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-m','Synthetic trusted base']].each do |args|
   out,err,status=Open3.capture3('git',*args);abort out+err unless status.success?
  end
  base,status=Open3.capture2('git','rev-parse','HEAD');abort 'Fixture git failed' unless status.success?
  d=JSON.parse(File.read('data.json'));c=d['claims'].find{|x|x['id']=='C32'}
  File.write('evidence/review-fixture.txt','synthetic API fixture')
  artifact={'path'=>'evidence/review-fixture.txt','sha256'=>Digest::SHA256.file('evidence/review-fixture.txt').hexdigest}
  c.merge!('state'=>'proven','review'=>'accepted','verification_id'=>'V-fixture','reviewers'=>['bob'])
  d['verifications']=[{'id'=>'V-fixture','supports'=>['C32'],'author_principal'=>'alice','reviewer_principal'=>'bob','kind'=>'static','scope'=>c['scope'],'method'=>'fixture','expected'=>'fixture','actual'=>'fixture','controls'=>'fixture','limitations'=>'synthetic API only','environment'=>{'inputs'=>'fixture'},'artifacts'=>[artifact],'independent_reproduction'=>{'principal'=>'bob','method'=>'fixture','actual'=>'fixture','artifacts'=>[artifact]},'review_url'=>'https://github.com/example/research/pull/1#pullrequestreview-7'}]
  File.write('data.json',JSON.generate(d))
  stub=File.join(root,'api_fixture.rb')
  File.write(stub,<<~'CODE')
   require 'net/http';require 'json'
   module Net
    class HTTP
     def self.start(*)
      fake=Object.new
      def fake.request(req)
       head='a'*40
       mode=ENV.fetch('FIXTURE_MODE')
       body=if req.path.end_with?('/reviews/7')
        {'state'=>'APPROVED','user'=>{'login'=>mode=='wrong_identity' ? 'mallory' : 'bob'}}
       elsif req.path.include?('/reviews?')
        [{'id'=>8,'state'=>mode=='revoked' ? 'CHANGES_REQUESTED' : 'APPROVED','commit_id'=>mode=='stale' ? 'b'*40 : head,'user'=>{'login'=>'bob'}}]
       else
        {'head'=>{'sha'=>head},'user'=>{'login'=>mode=='self_author' ? 'bob' : 'alice'}}
       end
       result=Net::HTTPOK.new('1.1','200','OK');result.instance_variable_set(:@read,true);result.body=JSON.generate(body);result
      end
      yield fake
     end
    end
   end
  CODE
  {'valid'=>true,'wrong_identity'=>false,'stale'=>false,'revoked'=>false,'self_author'=>false}.each do |mode,expected|
   env={'BASE_SHA'=>base.strip,'GITHUB_REPOSITORY'=>'example/research','PR_NUMBER'=>'1','HEAD_SHA'=>'a'*40,'GITHUB_TOKEN'=>'synthetic-fixture','FIXTURE_MODE'=>mode}
   out,err,status=Open3.capture3(env,'ruby','-r',stub,'check_review.rb')
   abort "FAIL #{mode}: #{out}#{err}" unless status.success? == expected
   puts "PASS review identity gate: #{mode}"
  end
 end
end
