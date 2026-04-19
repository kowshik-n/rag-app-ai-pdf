'use client';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import * as React from 'react';

interface Doc {
  pageContent?: string;
  metadata?: {
    loc?: {
      pageNumber?: number;
    };
    source?: string;
    pageNumber?: number;
  };
}
interface IMessage {
  role: 'assistant' | 'user';
  content?: string;
  documents?: Doc[];
}

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '';

const getPageNumber = (doc: Doc): string => {
  // Try different possible metadata structures
  const pageNum = doc.metadata?.loc?.pageNumber ||
                  doc.metadata?.pageNumber;

  if (pageNum !== undefined && pageNum !== null) {
    // PDF pages are already 1-indexed, no need to add 1
    const num = typeof pageNum === 'string' ? parseInt(pageNum, 10) : pageNum;
    return isNaN(num) ? 'N/A' : num.toString();
  }

  return 'N/A';
};

const ChatComponent: React.FC = () => {
  const [message, setMessage] = React.useState<string>('');
  const [messages, setMessages] = React.useState<IMessage[]>([]);
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  const uniqueDocuments = (docs: Doc[]) => {
    const seen = new Set<string>();
    return docs.filter((doc) => {
      const key = `${doc.pageContent?.slice(0, 120)}|${doc.metadata?.source || ''}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  };

  const handleSendChatMessage = async () => {
    if (!message.trim() || loading) return;

    const userMessage = { role: 'user' as const, content: message.trim() };
    setMessages((prev) => [...prev, userMessage]);
    setLoading(true);
    setError(null);
    setMessage('');

    try {
      const res = await fetch(`${API_BASE_URL}/chat?message=${encodeURIComponent(message.trim())}`);
      if (!res.ok) {
        const body = await res.text();
        throw new Error(body || 'Failed to get response from the server');
      }

      const data = await res.json();
      setMessages((prev) => [
        ...prev,
        {
          role: 'assistant',
          content: data?.message || 'No response received.',
          documents: Array.isArray(data?.docs) ? uniqueDocuments(data.docs) : [],
        },
      ]);
    } catch (err) {
      const messageText = err instanceof Error ? err.message : 'Unknown error';
      setError(messageText);
      setMessages((prev) => [
        ...prev,
        {
          role: 'assistant',
          content: `Error: ${messageText}`,
        },
      ]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex h-full flex-col gap-4 p-4 md:p-6">
      <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
        <div className="mb-4 space-y-2">
          <h2 className="text-xl font-semibold">Chat</h2>
          <p className="text-sm text-slate-600">
            Ask a question about your uploaded PDF.
          </p>
        </div>

        <div className="mb-4 max-h-[60vh] overflow-y-auto space-y-4">
          {messages.length === 0 ? (
            <div className="rounded-xl border border-dashed border-slate-300 bg-slate-50/50 p-8 text-center">
              <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full border border-slate-200 bg-white">
                💬
              </div>
              <h3 className="mb-2 text-sm font-medium text-slate-900">Start a conversation</h3>
              <p className="text-sm text-slate-500">
                Upload a PDF first, then ask questions about its content. The AI will reference specific pages from your document.
              </p>
            </div>
          ) : (
            messages.map((messageObj, index) => (
              <div
                key={index}
                className={`flex ${messageObj.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div
                  className={`max-w-[80%] rounded-2xl border px-4 py-3 ${
                    messageObj.role === 'user'
                      ? 'border-slate-300 bg-slate-100 text-slate-900'
                      : 'border-slate-200 bg-white text-slate-950'
                  }`}
                >
                  <div className="text-sm leading-7 whitespace-pre-wrap">
                    {messageObj.content}
                  </div>

                  {messageObj.documents && messageObj.documents.length > 0 ? (
                    <div className="mt-4 space-y-3 rounded-xl border border-slate-200 bg-slate-50/50 p-4">
                      <div className="flex items-center gap-2 text-xs font-medium text-slate-700">
                        <div className="h-1.5 w-1.5 rounded-full bg-slate-400"></div>
                        Context Sources ({messageObj.documents.length})
                      </div>
                      <div className="space-y-3">
                        {messageObj.documents.map((doc, docIndex) => (
                          <div key={docIndex} className="rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
                            <div className="flex items-start justify-between gap-3 mb-2">
                              <div className="flex items-center gap-2 text-xs text-slate-500">
                                <div className="flex h-5 w-5 items-center justify-center rounded border border-slate-200 bg-slate-50">
                                  📄
                                </div>
                                <span className="font-medium">
                                  Page {getPageNumber(doc)}
                                </span>
                              </div>
                              {doc.metadata?.source && (
                                <div className="text-xs text-slate-400 truncate max-w-[120px]">
                                  {doc.metadata.source}
                                </div>
                              )}
                            </div>
                            <p className="text-sm leading-6 text-slate-700">
                              {doc.pageContent?.slice(0, 300) || 'No document text available.'}
                              {doc.pageContent && doc.pageContent.length > 300 ? '...' : ''}
                            </p>
                          </div>
                        ))}
                      </div>
                    </div>
                  ) : null}
                </div>
              </div>
            ))
          )}
        </div>

        {error ? (
          <div className="rounded-2xl border border-rose-300/80 bg-rose-50 px-4 py-3 text-sm text-rose-700 dark:border-rose-500/20 dark:bg-rose-900/30 dark:text-rose-200">
            {error}
          </div>
        ) : null}
      </div>

      <div className="sticky bottom-0 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm">
        <div className="flex flex-col gap-3 md:flex-row">
          <Input
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="Ask about the PDF content..."
            disabled={loading}
          />
          <Button variant="outline" onClick={handleSendChatMessage} disabled={!message.trim() || loading} className="w-full md:w-auto">
            {loading ? 'Sending…' : 'Send'}
          </Button>
        </div>
      </div>
    </div>
  );
};
export default ChatComponent;
