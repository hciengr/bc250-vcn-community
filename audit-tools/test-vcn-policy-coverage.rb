require_relative 'audit-vcn-policy-coverage'
def check(name)
 raise name unless yield
 puts "PASS #{name}"
end
def fixture(rows)
 body=[1].pack('V')+"\0"*0x3c+[0x201,rows.size].pack('V2')+rows.flatten.pack('V*')
 header="\0"*0x100;header[0x10,4]='$PS1';header[0x14,4]=[body.size].pack('V')
 header+body+"\0"*0x100
end
b=fixture([[0x0900c934,0x1d000],[0x0900c938,0x24000]])
p=VcnPolicyAudit.parse(b);a=VcnPolicyAudit.analyze(p)
check('Spanning interval detected even when neither endpoint lies inside VCN'){a[:vcn_numeric_value_rows].empty?&&a[:candidate_vcn_overlaps].size==1}
b=fixture([[0x0900e934,0x1f844],[0x0900e938,0x1f84f]])
a=VcnPolicyAudit.analyze(VcnPolicyAudit.parse(b))
check('Overlap scanning includes frames other than C'){a[:frame_c_rows].empty?&&a[:candidate_vcn_overlaps].first[:frame_index]==0xe}
b=fixture([[0x1f8a4,0xb],[0x0900c234,0]])
a=VcnPolicyAudit.analyze(VcnPolicyAudit.parse(b))
check('Preload distinguished from management descriptor'){a[:vcn_direct_target_rows].size==1&&a[:frame_c_rows].size==1&&a[:candidate_descriptors].empty?}
b=fixture([[0x0900c934,0x24000],[0x0900c938,0x1d000]])
check('Reversed pair does not become an aperture'){VcnPolicyAudit.analyze(VcnPolicyAudit.parse(b))[:candidate_descriptors].empty?}
b=fixture([[0x0900c934,0x1f844],[0x0900c938,0x1f84f]])
b[0x144,4]=[0xffff].pack('V')
rejected=false;begin;VcnPolicyAudit.parse(b);rescue;rejected=true;end
check('Truncated/oversized section rejected'){rejected}
b=fixture([]);b[0x100,4]=[2].pack('V');rejected=false;begin;VcnPolicyAudit.parse(b);rescue;rejected=true;end
check('Declared section count enforced'){rejected}
