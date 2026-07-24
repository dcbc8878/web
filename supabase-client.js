// Shared Supabase client for all DCBC pages.
// The publishable/anon key below is meant to be public — everything
// it can do is governed by Postgres Row Level Security, not secrecy.
const DCBC_SUPABASE_URL = 'https://dqegkyobclqqichhnxfm.supabase.co';
const DCBC_SUPABASE_ANON_KEY = 'sb_publishable_4U_v9BIrQjKppfchaevA6Q_zWj3zkxE';

window.dcbcSupabase = supabase.createClient(DCBC_SUPABASE_URL, DCBC_SUPABASE_ANON_KEY);

// Escapes user-submitted text before it's placed into innerHTML.
function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str ?? '';
    return div.innerHTML;
}

// Icon class + color pair based on file extension, used by both
// portal.html (document list) and adminupload.html (document list).
function dcbcFileIcon(fileName) {
    const ext = (fileName || '').split('.').pop().toLowerCase();
    if (ext === 'pdf') return { icon: 'fa-regular fa-file-pdf', bg: 'bg-red-50', text: 'text-red-500' };
    if (ext === 'xlsx' || ext === 'xls') return { icon: 'fa-regular fa-file-excel', bg: 'bg-green-50', text: 'text-green-600' };
    if (ext === 'doc' || ext === 'docx') return { icon: 'fa-regular fa-file-word', bg: 'bg-blue-50', text: 'text-blue-500' };
    return { icon: 'fa-regular fa-file-lines', bg: 'bg-gray-100', text: 'text-gray-500' };
}

function dcbcFormatBytes(bytes) {
    if (!bytes && bytes !== 0) return '';
    const mb = bytes / (1024 * 1024);
    return mb >= 1 ? `${mb.toFixed(2)} MB` : `${(bytes / 1024).toFixed(1)} KB`;
}
