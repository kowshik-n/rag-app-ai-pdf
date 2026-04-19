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
    <div className="flex h-full flex-col justify-between rounded-2xl border border-slate-200 bg-white p-5 text-slate-950 shadow-sm">
      <div className="space-y-4">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-slate-200 bg-slate-50 text-slate-950">
            <Upload className="h-5 w-5" />
          </div>
          <div>
            <h2 className="text-xl font-semibold">Upload PDF</h2>
            <p className="text-sm text-slate-600">Choose a PDF and upload it for question answering.</p>
          </div>
        </div>

        <div className="rounded-xl border border-slate-200 bg-slate-50 p-4">
          <p className="text-sm text-slate-500">Selected file</p>
          <p className="mt-2 text-base font-medium text-slate-950">{fileName || 'No file selected'}</p>
        </div>

        <div className="space-y-3">
          <Button
            variant="outline"
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
            className="w-full"
          >
            {uploading ? 'Uploading…' : 'Choose PDF'}
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
        className={`rounded-xl border px-4 py-3 text-sm ${
          statusType === 'success'
            ? 'border-emerald-200 bg-emerald-50 text-emerald-700'
            : statusType === 'error'
            ? 'border-rose-200 bg-rose-50 text-rose-700'
            : 'border-slate-200 bg-slate-50 text-slate-600'
        }`}
      >
        {status}
      </div>
    </div>
  );
};

export default FileUploadComponent;
