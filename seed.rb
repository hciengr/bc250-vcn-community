require 'json'
root = File.expand_path('../..', __dir__)
sources = %w[notes/driver-to-bc250-enablement.md notes/vcn-startup-dependencies.md notes/vcn-cold-start-and-acknowledgments.md notes/psp-service-chain.md notes/domain-identity-and-psp-handoffs.md notes/power-acknowledgment.md notes/isa-cross-reference.md notes/harvest-runtime-producer-resume.md notes/runtime-section-namespace-correction.md notes/analysis-progress.md notes/vcn-psp-load-contract.md exports/vcn-kdb-provenance/README.md exports/navi10-vcn-auth-check/README.md exports/navi10-vcn-key/README.md exports/vcn-kdb-association/README.md analysis/steamdeck-comparison/signature/README.md analysis/steamdeck-comparison/vangogh-candidate.json]
require 'fileutils'
sources.each { |s| FileUtils.mkdir_p(File.dirname("#{__dir__}/evidence/#{s}")); FileUtils.cp("#{root}/#{s}", "#{__dir__}/evidence/#{s}") }
def claim(id, title, state, kind, scope, source)
  {id:id,title:title,state:state,kind:kind,scope:scope,sources:["evidence/#{source}"],review:'seeded',reviewers:[]}
end
claims = [
 claim('C01','P2/P3 discovery advertises VCN 2.0.3 without harvest entries','proven','static','ROM advertisement only; not physical availability.','notes/driver-to-bc250-enablement.md'),
 claim('C02','Examined driver skips 2.0.3; custom driver admission is unresolved','partial','static','Saved source snapshot, not the installed community kernel.','notes/driver-to-bc250-enablement.md'),
 claim('C03','Firmware fallback and software harvest guard are traced','proven','static','Reference fallback vcn_2_0_3.bin; registration may skip a harvested instance.','notes/vcn-startup-dependencies.md'),
 claim('C04','BC250-compatible candidate firmware is not established','partial','static','Navi10 and Van Gogh packages exist; valid packaging does not prove compatibility.','analysis/steamdeck-comparison/vangogh-candidate.json'),
 claim('C05','Ordinary command 6 / type 13 loader route exists','proven','static','t02 → F2 service 1 / 0x1007 → t28 loader; live success unobserved.','notes/vcn-cold-start-and-acknowledgments.md'),
 claim('C06','PSP object/service binding and invocation chain is recovered','proven','static','Successful static path; staged object identity and runtime success remain conditional.','notes/psp-service-chain.md'),
 claim('C07','Type 13 requests usage 6; missing ID precedes usage enforcement','proven','static','Missing ID returns ffff0008; matched enforced usage mismatch returns 80000205.','exports/vcn-kdb-association/README.md'),
 claim('C08','Both candidates fail ID lookup in extracted P3 KDB fixtures','proven','model','BL/TOS offline fixtures only; not a captured PSP completion.','exports/navi10-vcn-auth-check/README.md'),
 claim('C09','Both candidate signatures verify with matching reference keys','proven','offline-crypto','Actual OpenSSL results and corruption controls; not BC250 trust or execution.','exports/navi10-vcn-auth-check/README.md'),
 claim('C10','Staging-to-runtime KDB copy is traced; earlier producer is open','partial','static','staging base + 784000 → analysis VA e25834; live byte identity unresolved.','exports/vcn-kdb-provenance/README.md'),
 claim('C11','Examined Cyan table lacks VCN-enable callback','proven','static','No proof that the actual community kernel uses this callback table.','notes/driver-to-bc250-enablement.md'),
 claim('C12','Row-6 children 23/22 are VCLK/DCLK','proven','static','Independent metrics ABI link identifies software clock roles, not measured clocks.','notes/domain-identity-and-psp-handoffs.md'),
 claim('C13','Row-6 parent/child protocols and cache bypasses are recovered','proven','static','Ordered polls, not required edges; f714 cache can bypass. Physical bit meanings open.','notes/power-acknowledgment.md'),
 claim('C14','SSIP is preferred policy-copy inference; runtime semantics open','partial','static','Identical SSIP/SSIU bits. Two layouts + CONST.S favor SSIP; retain both mappings.','notes/isa-cross-reference.md'),
 claim('C15','Reference memory windows and reset sequence are mapped','partial','static','No demonstrated accepted image/address or successful BC250 programming.','notes/driver-to-bc250-enablement.md'),
 claim('C16','Actual BC250 VCPU-ready result is not established','unknown','hardware','Known reference UVD_STATUS & 2; no valid ready capture in seeded evidence.','notes/driver-to-bc250-enablement.md'),
 claim('C17','Actual VCN-executed ring result is not established','unknown','hardware','Known scratch9 CAFEDEAD → submitted DEADBEEF criterion; no execution result.','notes/vcn-startup-dependencies.md'),
 claim('C18','Hardware media output is not established','unknown','hardware','Decode without software fallback and validate output; encode separately.','notes/driver-to-bc250-enablement.md'),
 claim('C19','Section/pair table is distinct from the authentication KDB','proven','static','B=e5cbdc / E1177C; its ffff0008 cannot identify LOAD_IP_FW failure.','notes/runtime-section-namespace-correction.md'),
 claim('C20','Neighboring record paths do not normally populate section table B','partial','static','Bounded negative result; producer, enable byte and configuration writers remain open.','notes/harvest-runtime-producer-resume.md')
]
def stage(id,title,column,row,state,claims,need)
 {id:id,title:title,column:column,row:row,state:state,claims:claims,next_evidence:need}
end
stages=[
 stage('S01','Driver admission','center',0,'partial',%w[C01 C02],'Exact installed kernel/patches, admission trace and BIOS hash.'),
 stage('S02','Platform enable dispatch','left',1,'partial',%w[C11],'Actual callback, arguments, return and hardware effect.'),
 stage('S03','Select + register firmware','right',1,'partial',%w[C03 C04],'Submitted filename/hash, software harvest variable and setup_ucode trace.'),
 stage('S04','Video domain + clocks','left',2,'partial',%w[C12 C13 C14],'Validated access, fresh parent/child observations and physical clock/power meaning.'),
 stage('S05','PSP LOAD_IP_FW route','right',2,'proven',%w[C05 C06],'Independent instruction validation; then actual request/return trace.'),
 stage('S06','Key ID → usage → signature','right',3,'partial',%w[C07 C08 C09 C10],'Live KDB during the exact request and rejecting instruction path.'),
 stage('S07','Accepted image + TMR address','right',4,'partial',%w[C04 C15],'Raw PSP success, valid returned extent, image identity and destination.'),
 stage('S08','Firmware / stack / context windows','left',3,'partial',%w[C15],'Runtime windows consistent with accepted image and GPU allocations.'),
 stage('S09','Release VCPU / memory resets','left',4,'partial',%w[C15],'Actual reset/control observations and PSP/PMFW ordering.'),
 stage('S10','VCPU ready','left',5,'unknown',%w[C16],'Valid UVD_STATUS ready observation tied to the same boot.'),
 stage('S11','VCN executes ring test','left',6,'unknown',%w[C17],'Packet submission and device-produced scratch result; preserve first failure.'),
 stage('S12','Hardware decode / encode','left',7,'unknown',%w[C18],'Hardware-only workload, output comparison and separate encode evidence.')
]
def task(id,title,stage,skills,priority,deps,question,done)
 {id:id,title:title,stage:stage,skills:skills,priority:priority,depends_on:deps,status:'open',owner:nil,claimed_at:nil,last_update:nil,claim_until:nil,question:question,done_when:done,attempts:[],issue_url:nil}
end
tasks=[
 task('T01','Pin down one reproducible board baseline','S01',['board access','Linux'],1,[],'Which BIOS, kernel, candidate and startup route produce the failure?','Attach BIOS/candidate hashes, exact kernel/patches, firmware filename, admission and harvest trace, full timestamped log.'),
 task('T02','Locate the exact live PSP rejecting stage','S06',['board access','PSP reversing'],1,['T01'],'Does the failing request stop at key-ID lookup, an earlier prerequisite or another lookup?','Correlate command/type/length, raw response/address and stage-specific trace from the same request.'),
 task('T03','Trace the earlier KDB staging producer','S06',['PSP reversing'],1,[],'Who fills staging base + 0x784000 and how is it accepted?','Instruction-backed producer → staging object → copy → consumer chain, with exact input hashes and unresolved edges named.'),
 task('T04','Identify actual platform enable dispatch','S02',['Linux','board access','PMFW reversing'],1,['T01'],'Which driver operation really reaches BC250 power/clock control?','Actual callback/dispatch and arguments traced through firmware, distinguishing cached/no-op returns.'),
 task('T05','Validate candidate authentication independently','S06',['cryptography'],2,[],'Can both reference signatures and negative controls be reproduced?','Run both family checks; preserve hashes, signed extents, OpenSSL positive/corruption results and lookup-model scope.'),
 task('T06','Establish a compatible cold-start image','S03',['firmware analysis','board access'],1,[],'Which image targets this VCN implementation and can be accepted?','Provide target/ABI evidence; acceptance and execution remain separate milestones, with exact image hash.'),
 task('T07','Validate row-6 physical semantics and accessibility','S04',['PMFW reversing','board access'],2,['T01'],'What do the parent bits physically acknowledge and are clocks running?','Validate address-space translation; distinguish cache bypass, parent/child predicates and independently measured hardware state.'),
 task('T08','Connect flash-fetch work to the consumed KDB','S06',['FPGA / SPI','PSP reversing'],2,['T03'],'Does the fetch under study supply the exact KDB object used by lookup?','Provide transaction/object provenance through staging and copy; a flash-cache success alone does not close authentication.'),
 task('T09','Trace section-table / configuration producers','S02',['PSP reversing'],2,[],'Who populates B=e5cbdc, enables it and writes original +41c/+4b8 fields?','Recover real producer/activation instructions; preserve retained source versus snapshot and separate section IDs from directory identities.'),
 task('T10','Validate SSIP policy mapping independently','S04',['Xtensa ISA','PMFW reversing'],2,[],'Can policy consumers/layouts and configuration evidence be checked independently?','Verify both layouts against local Cadence reference and raw bytes; never label static SSIP inference runtime-validated.'),
 task('T11','Observe accepted image and programmed windows','S08',['Linux','board access'],3,['T02','T04','T06'],'Does a real accepted image reach the windows used by VCPU?','Raw PSP result, usable returned TMR extent, actual windows, reset ordering and same-boot image identity.'),
 task('T12','Demonstrate VCPU and ring execution','S11',['Linux','board access'],3,['T11','T07'],'Does firmware run and execute the ring packet?','Valid readiness plus submitted packet/device-produced response, with original status and startup errors preserved.'),
 task('T13','Validate real decode and encode','S12',['media testing','board access'],3,['T12'],'Does hardware produce correct video output?','Decode known sample with fallback disabled and compare output; provide separate encode run and logs.')
]
data={schema_version:1,title:'BC250 VCN community lab',baseline_date:'2026-09-29',prepared_date:'2026-10-01',repository_url:nil,claims:claims,stages:stages,tasks:tasks,edges:[%w[S01 S02],%w[S01 S03],%w[S02 S04],%w[S03 S05],%w[S05 S06],%w[S06 S07],%w[S04 S08],%w[S07 S08],%w[S08 S09],%w[S09 S10],%w[S10 S11],%w[S11 S12]],contributions:[]}
File.write("#{__dir__}/data.json",JSON.pretty_generate(data)+"\n")
