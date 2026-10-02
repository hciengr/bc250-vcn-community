# Runs from the trusted PR base, not the contributor's version of this file.
require 'json'
require 'open3'
require 'net/http'
require 'uri'
require_relative 'verification'

def base_file(path)
  out,status=Open3.capture2('git','show',"#{ENV.fetch('BASE_SHA')}:#{path}")
  abort "Cannot read trusted base #{path}" unless status.success?
  out
end

def github(path)
  uri=URI("https://api.github.com#{path}")
  req=Net::HTTP::Get.new(uri)
  req['Accept']='application/vnd.github+json'
  req['Authorization']="Bearer #{ENV.fetch('GITHUB_TOKEN')}"
  response=Net::HTTP.start(uri.host,uri.port,use_ssl:true,open_timeout:15,read_timeout:30){|http|http.request(req)}
  abort "GitHub review lookup failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)
  JSON.parse(response.body)
end

base=JSON.parse(base_file('data.json'))
current=JSON.parse(File.read('data.json'))
policy=JSON.parse(base_file('review-policy.json'))
# A contribution cannot lower its own validation rules. Governance changes need
# a separate maintainer-controlled change before evidence is considered.
%w[verification.rb check_review.rb review-policy.json legacy-claims.json .github/workflows/validate.yml].each do |path|
  abort "Protected governance changed: #{path}. Submit separately to maintainer." unless File.read(path)==base_file(path)
end
errors=Verification.check(current,Dir.pwd)
abort errors.join("\n") unless errors.empty?
old=base.fetch('verifications',[]).to_h{|v|[v['id'],v]}
base['claims'].each do |c|
  n=current['claims'].find{|x|x['id']==c['id']}
  if c['review']=='accepted' && n && n['review']=='accepted' && n!=c
    abort "#{c['id']}: changed accepted claim requires a new verification" if n['verification_id']==c['verification_id']
  end
end
current.fetch('verifications',[]).each do |v|
  abort "Verification records are immutable: #{v['id']}" if old[v['id']] && old[v['id']]!=v
end
fresh=current.fetch('verifications',[]).reject{|v|old.key?(v['id'])}
if fresh.empty?
  puts 'No new verified findings. Structural evidence checks passed.'
  exit
end
abort 'No trusted reviewers configured; verification remains blocked.' if policy['trusted_reviewers'].empty?
repo=ENV.fetch('GITHUB_REPOSITORY')
pr=ENV.fetch('PR_NUMBER')
head=ENV.fetch('HEAD_SHA')
info=github("/repos/#{repo}/pulls/#{pr}")
abort 'PR revision changed; rerun on current HEAD.' unless info.dig('head','sha')==head
reviews=[]
page=1
loop do
 batch=github("/repos/#{repo}/pulls/#{pr}/reviews?per_page=100&page=#{page}")
 reviews.concat(batch)
 break if batch.size<100
 page+=1
 abort 'Excessive review history; inspect manually.' if page>20
end
fresh.each do |v|
  reviewer=v['reviewer_principal']
  abort "Untrusted reviewer #{reviewer}" unless policy['trusted_reviewers'].include?(reviewer)
  abort 'PR author cannot independently approve their submission.' if reviewer.downcase==info.dig('user','login').downcase
  expected_prefix="https://github.com/#{repo}/pull/#{pr}#pullrequestreview-"
  abort 'Review must refer to this pull request.' unless v['review_url'].start_with?(expected_prefix)
  review_id=v['review_url'].delete_prefix(expected_prefix)
  abort 'Invalid review identity.' unless review_id.match?(/\A\d+\z/)
  review=github("/repos/#{repo}/pulls/#{pr}/reviews/#{review_id}")
  abort "Review #{review_id} not approved by declared reviewer." unless review['state']=='APPROVED' && review.dig('user','login')==reviewer
decisive=reviews.select{|r|r.dig('user','login')==reviewer && %w[APPROVED CHANGES_REQUESTED DISMISSED].include?(r['state'])}.max_by{|r|r['id']}
abort "#{reviewer}: current HEAD requires fresh approval." unless decisive && decisive['state']=='APPROVED' && decisive['commit_id']==head

end
puts "Validated #{fresh.size} new verification records against GitHub review identities."
