require 'tmpdir'
require 'open3'
require 'cgi'
require 'uri'
root=File.expand_path('..',__dir__)
Dir.mktmpdir('vcn-browser-') do |temp|
 html=File.read(File.join(root,'map.html')).sub('<head>',"<head><base href=\"file://#{URI::DEFAULT_PARSER.escape(root)}/\">")
 html=html.sub('</body>',"<script>#{File.read(File.join(__dir__,'contributions.js'))}</script></body>")
 path=File.join(temp,'test.html');File.write(path,html)
 dom,err,status=Open3.capture3(ENV.fetch('CHROMIUM','chromium'),'--headless','--no-sandbox','--disable-gpu','--disable-dev-shm-usage','--virtual-time-budget=3000','--dump-dom',"file://#{path}")
 abort "Browser failed: #{err}" unless status.success?
 result=dom[/<pre id="browser-test-results">(.*?)<\/pre>/m,1]
 abort 'Browser harness did not run' unless result
 puts CGI.unescapeHTML(result)
 abort 'Browser test failed' unless dom.include?('data-browser-test="passed"')
end
