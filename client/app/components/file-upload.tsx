'use client';
import * as React from 'react';
import { Upload } from 'lucide-react';
import { Button } from '@/components/ui/button';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '';

const FileUploadComponent: React.FC = () => {
  const fileInputRef = React.useRef<HTMLInputElement | null>(null);
  const [status, setStatus] = React.useState<string>('No file uploaded yet.');
  const [statusType, setStatusType] = React.useState<'info' | 'success' | 'error'>('info');
  const [uploading, setUploading] = React.useState(false);
  const [fileName, setFileName] = React.useState<string>('');

  const handleFileSelect = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    setFileName(file.name);
    setUploading(true);
    setStatusType('info');
    setStatus('Uploading file...');

    try {
      const formData = new FormData();
      formData.append('pdf', file);

      const res = await fetch(`${API_BASE_URL}/upload/pdf`, {
        method: 'POST',
        body: formData,
      });

      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || 'Upload failed');
      }

      setStatusType('success');
      setStatus('PDF uploaded successfully. You can now ask questions.');
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Upload failed';
      setStatusType('error');
      setStatus(message);
    } finally {
      setUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  return (
    <div className="flex h-full flex-col justify-between rounded-3xl border border-slate-200/70 bg-slate-950/90 p-6 shadow-2xl shadow-slate-950/10 backdrop-blur-xl text-white">
      <div className="space-y-4">
        <div className="flex items-center gap-3">
          <div className="rounded-3xl bg-primary p-3 text-white shadow-lg shadow-primary/20">
            <Upload className="h-6 w-6" />
          </div>
          <div>
            <h2 className="text-2xl font-semibold">Upload PDF</h2>
            <p className="text-sm text-slate-300">Add your PDF and ask questions about its contents.</p>
          </div>
        </div>

        <div className="rounded-3xl border border-slate-800 bg-slate-900/80 p-4">
          <p className="text-sm text-slate-300">Selected file:</p>
          <p className="mt-2 text-base font-medium text-white">{fileName || 'No file selected'}</p>
        </div>

        <div className="space-y-3">
          <Button
            variant="default"
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
            className="w-full"
          >
            {uploading ? 'Uploading...' : 'Choose PDF'}
          </Button>

          <input
            ref={fileInputRef}
            type="file"
            accept="application/pdf"
            className="hidden"
            onChange={handleFileSelect}
          />
        </div>
      </div>

      <div
        className={`rounded-3xl border px-4 py-3 text-sm ${
          statusType === 'success'
            ? 'border-emerald-500/30 bg-emerald-500/10 text-emerald-100'
            : statusType === 'error'
            ? 'border-rose-500/30 bg-rose-500/10 text-rose-100'
            : 'border-slate-700/70 bg-slate-900/80 text-slate-300'
        }`}
      >
        {status}
      </div>
    </div>
  );
};

export default FileUploadComponent;
