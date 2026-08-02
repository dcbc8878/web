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
// the portal document list and the admin document list.
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

// Unique-ID generator for storage file paths. crypto.randomUUID() only
// exists in secure contexts (HTTPS) on newer browsers, so it can throw
// "crypto.randomUUID is not a function" elsewhere — fall back gracefully.
function dcbcRandomId() {
    if (window.crypto && typeof crypto.randomUUID === 'function') {
        return crypto.randomUUID();
    }
    if (window.crypto && typeof crypto.getRandomValues === 'function') {
        const bytes = crypto.getRandomValues(new Uint8Array(16));
        return Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
    }
    return Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2);
}

// Supabase Storage rejects object keys containing non-ASCII characters,
// which every Thai-named file would hit. The real filename is kept in the
// documents.file_name column (used for display and the download attribute);
// this only sanitizes the storage key itself.
function dcbcSafeStorageKey(fileName) {
    const name = fileName || 'file';
    const lastDot = name.lastIndexOf('.');
    const hasExt = lastDot > 0;

    const ext = hasExt
        ? name.slice(lastDot + 1).replace(/[^A-Za-z0-9]/g, '').toLowerCase()
        : '';

    const base = (hasExt ? name.slice(0, lastDot) : name)
        .replace(/[^A-Za-z0-9._-]/g, '-')  // anything outside the safe set (incl. Thai) -> dash
        .replace(/-+/g, '-')
        .replace(/^[-.]+|[-.]+$/g, '')
        .slice(0, 60) || 'file';

    return ext ? `${base}.${ext}` : base;
}

// Full storage path for a newly uploaded file: unique prefix + safe key.
function dcbcStoragePath(fileName) {
    return `${Date.now()}-${dcbcRandomId()}-${dcbcSafeStorageKey(fileName)}`;
}
