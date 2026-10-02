const upstream = window.VCN_UPSTREAM;
if (upstream) {
  const panel = document.getElementById('upstream-status');
  const link = document.createElement('a');
  link.href = upstream.repository + '/commit/' + upstream.commit;
  link.textContent = 'Shalasere · ' + upstream.commit.slice(0, 12);
  panel.append(link, document.createElement('br'));
  panel.append(document.createTextNode('Last checked: ' + upstream.checked_at + ' · ' + upstream.pending_revisions + ' revision(s) awaiting review. Tracking does not change evidence colors. Reload after refresh.'));
}
