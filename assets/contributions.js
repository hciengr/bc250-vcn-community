'use strict';
(() => {
  const data=window.VCN_DATA, packets=window.VCN_TASK_PACKETS;
  const el=id=>document.getElementById(id);
  const repo=data.repository_url?.replace(/\/$/,'');
  if(!/^https:\/\/github\.com\/[\w.-]+\/[\w.-]+$/.test(repo||''))return;
  let submissionBody='', evidenceType='evidence';
  const snapshot=packets[0]?.ledger_sha256||'not available';
  const packetFor=id=>packets.find(p=>p.task.id===id);
  const issueSearch=id=>`${repo}/issues?q=${encodeURIComponent('is:issue '+id)}`;
  const saveFile=(name,body,type='text/markdown')=>{
    const url=URL.createObjectURL(new Blob([body],{type}));
    const a=document.createElement('a');a.href=url;a.download=name;a.click();
    setTimeout(()=>URL.revokeObjectURL(url),1000);
  };
  const option=(select,value,text)=>select.add(new Option(text,value));
  option(el('easy-topic'),'general','Unassigned task / claim');
  data.tasks.forEach(t=>option(el('easy-topic'),t.id,`${t.id} · ${t.title}`));
  data.stages.forEach(s=>option(el('easy-topic'),s.id,`${s.id} · ${s.title}`));
  data.claims.forEach(c=>option(el('easy-topic'),c.id,`${c.id} · ${c.title}`));
  data.contributions.forEach(r=>option(el('easy-topic'),r.id,`${r.id} · Review a community report`));
  [...data.tasks].sort((a,b)=>a.priority-b.priority).forEach(t=>{
    const dependencies=t.depends_on.filter(id=>data.tasks.find(x=>x.id===id).status!=='done');
    const state=t.status==='review'?'Needs reproduction':t.status==='done'?'Completed':t.owner?'Already claimed':dependencies.length?'Prerequisites pending':'Ready';
    option(el('worker-task'),t.id,`${t.id} · ${t.title} (${state})`);
  });
  const evidence= (ref='',type='evidence')=>{
    el('easy-evidence-form').reset();evidenceType=type;
    el('easy-topic').value=[...el('easy-topic').options].some(o=>o.value===ref)?ref:'general';
    el('evidence-title').textContent=type==='validation'?'Submit independent reproduction':type==='correction'?'Submit counterevidence':'Submit evidence';
    el('easy-error').textContent='';el('evidence-dialog').showModal();
  };
  function evidenceRecord(){
    if(!el('easy-evidence-form').reportValidity())return null;
    if(!el('easy-source').value.trim()&&!el('easy-attach').checked){
      el('easy-error').textContent='Add an evidence link, or check “I’ll attach logs or files on GitHub instead.”';
      el('easy-source').focus();return null;
    }
    return {title:el('easy-title').value.trim(),body:
`# ${el('easy-title').value.trim()}

Related task / finding: ${el('easy-topic').value==='general'?'Needs triage':el('easy-topic').value}
Contribution: ${evidenceType}
Evidence kind: ${el('easy-kind').value}
Credit: ${el('easy-author').value.trim()||'GitHub submitter; additional attribution not supplied'}
Ledger SHA-256: ${snapshot}

## Finding

${el('easy-finding').value.trim()}

## Raw evidence

${el('easy-source').value.trim()||'Contributor will attach files to this issue before posting.'}

## Reproduction

${el('easy-method').value.trim()||'Not supplied yet; required before verification.'}

## Environment and input hashes

${el('easy-environment').value.trim()||'Not supplied yet; required before verification.'}

Status: proposed, awaiting triage and independent review. This submission does not change verification or task ownership.
`};
  }
  function handoff(record,kind){
    submissionBody=record.body;
    const url=new URL(`${repo}/issues/new`);
    url.searchParams.set('template',kind==='worker'?'worker-link.md':'evidence.md');
    url.searchParams.set('title',record.title);
    url.searchParams.set('body',record.body);
    const long=url.href.length>6500;
    if(long)url.searchParams.delete('body');
    el('handoff-long').hidden=!long;
    el('handoff-open').href=url.href;
    el('handoff-preview').textContent=record.body;
    el('handoff-copy-status').textContent='';
    el('handoff-message').textContent=kind==='worker'?'Your worker registration is ready. It has not been shared yet.':'Your evidence draft is ready. It has not been shared yet.';
    el('handoff-dialog').showModal();
  }
  async function copy(text,status,fallback){
    try{await navigator.clipboard.writeText(text);status.textContent='Copied. Paste it where you need it.';}
    catch{
      const area=fallback||document.createElement('textarea');
      if(!fallback){area.value=text;el('handoff-dialog').appendChild(area);}
      const details=area.closest('details');if(details)details.open=true;
      area.focus();area.select();
      status.textContent='Select and copy the highlighted text using your browser or keyboard.';
    }
  }
  function workerPrompt(){
    const p=packetFor(el('worker-task').value);
    if(!p)return '';
    return `Help me work on BC250 VCN task ${p.task.id}: ${p.task.title}.

Human coordinator: ${el('worker-human').value.trim()||'[my GitHub username]'}
Worker name: ${el('worker-name').value.trim()||'[my worker name]'}
Purpose: ${el('worker-mode').value==='reproduce'?'independent reproduction':'bounded investigation'}
Repository: ${repo}
Instructions: ${repo}/blob/main/AGENTS.md
Verification rules: ${repo}/blob/main/VERIFICATION.md
Ledger SHA-256 for this task packet: ${p.ledger_sha256}

Read the project instructions, check existing issues for ${p.task.id}, and verify that your task packet and source hashes match this snapshot before starting. If the shared ledger changed, refresh the packet and recheck ownership. Do not silently mix revisions.

Question: ${p.task.question}
Completion criterion: ${p.task.done_when}
Dependencies: ${p.task.depends_on.join(', ')||'none'}
Plan: ${el('worker-plan').value.trim()||'Specify one bounded procedure, required inputs and stopping condition.'}

Preserve original authors and evidence type. Provide exact methods, input hashes, raw outputs, expected/actual results, controls and limitations. Report negative results. Stop and hand off when required inputs are missing; do not expand into a new investigation without a source-backed question and stopping condition. An AI explanation is not evidence. Do not invent missing evidence, mark your work accepted, run board writes without the owner\'s authorization, or approve work from the same human coordinator. Submit results through the community site for independent review.

Task packet (including claims and source hashes):
${JSON.stringify(p,null,2)}
`;
  }
  function updateWorker(){
    const p=packetFor(el('worker-task').value);if(!p)return;
    const box=el('worker-task-summary');box.replaceChildren();
    const strong=document.createElement('strong');strong.textContent=p.task.title;
    const question=document.createElement('p');question.textContent=p.task.question;
    const status=document.createElement('p');
    const pending=p.dependencies.filter(t=>t.status!=='done');
    status.textContent=p.task.status==='review'?'This task has a result awaiting reproduction.':p.task.owner?`Coordinate with ${p.task.owner} before starting.`:pending.length?`Prerequisites pending: ${pending.map(t=>t.id).join(', ')}. Coordinate before claiming downstream work.`:'No owner recorded in this snapshot. Check current issues before starting.';
    box.append(strong,question,status);
    el('worker-existing').href=issueSearch(p.task.id);
    el('worker-prompt').value=workerPrompt();
    el('worker-copy-status').textContent='';
  }
  function worker(ref=''){
    el('worker-form').reset();
    const p=packetFor(ref)||packets.find(p=>p.task.status==='open'&&!p.task.owner&&p.dependencies.every(t=>t.status==='done'))||packets[0];
    el('worker-task').value=p.task.id;
    if(['review','done'].includes(p.task.status))el('worker-mode').value='reproduce';
    el('worker-error').textContent='';updateWorker();el('worker-dialog').showModal();
  }
  window.ContributionFlow={evidence,worker};
  ['contribute','report-button','start-evidence'].forEach(id=>el(id).onclick=()=>evidence());
  ['link-worker','start-worker'].forEach(id=>el(id).onclick=()=>worker());
  document.addEventListener('click',event=>{
    const close=event.target.closest('[data-close]');if(close)el(close.dataset.close).close();
    const button=event.target.closest('[data-worker]');if(button)worker(button.dataset.worker);
  });
  el('easy-evidence-form').onsubmit=event=>{
    event.preventDefault();const record=evidenceRecord();if(!record)return;
    el('evidence-dialog').close();handoff(record,'evidence');
  };
  el('easy-download').onclick=()=>{const record=evidenceRecord();if(record)saveFile('vcn-evidence.md',record.body);};
  ['worker-task','worker-mode','worker-human','worker-name','worker-plan'].forEach(id=>el(id).addEventListener('input',()=>{
    if(id==='worker-task'&&['review','done'].includes(packetFor(el(id).value).task.status))el('worker-mode').value='reproduce';
    updateWorker();
  }));
  el('copy-worker-prompt').onclick=()=>copy(workerPrompt(),el('worker-copy-status'),el('worker-prompt'));
  el('download-worker-packet').onclick=()=>{
    const p=packetFor(el('worker-task').value);
    saveFile(`${p.task.id}-worker-task.json`,JSON.stringify({...p,worker:{id:el('worker-name').value.trim()||null,human_principal:el('worker-human').value.trim()||null}},null,2),'application/json');
  };
  el('worker-form').onsubmit=event=>{
    event.preventDefault();if(!el('worker-form').reportValidity())return;
    const p=packetFor(el('worker-task').value);
    if(['review','done'].includes(p.task.status)&&el('worker-mode').value!=='reproduce'){
      el('worker-error').textContent='This task needs independent reproduction. Choose that purpose to proceed.';return;
    }
    const name=el('worker-name').value.trim(),human=el('worker-human').value.trim();
    const record={title:`Link worker: ${name} · ${p.task.id}`,body:
`Task ID: ${p.task.id} — ${p.task.title}
Human coordinator: ${human}
Worker ID: ${name}
Purpose: ${el('worker-mode').value}
Ledger SHA-256: ${p.ledger_sha256}
Existing task issues: ${issueSearch(p.task.id)}
Recorded owner: ${p.task.owner||'none in this snapshot'}
Dependencies: ${p.task.depends_on.join(', ')||'none'}
Planned handoff: ${el('worker-until').value||'To agree with maintainer'}

## Bounded plan

${el('worker-plan').value.trim()||'To agree before claiming ownership.'}

## Completion criterion

${p.task.done_when}

This is a proposed worker link, not automatic execution, reserved ownership or verified evidence. Results require raw artifacts and review by a different accountable human. No AI credentials are requested.
`};
    el('worker-dialog').close();handoff(record,'worker');
  };
  el('handoff-copy').onclick=()=>copy(submissionBody,el('handoff-copy-status'));
})();
