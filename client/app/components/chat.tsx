'use client';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import * as React from 'react';

interface Doc {
  pageContent?: string;
  metdata?: {
    loc?: {
      pageNumber?: number;
    };
    source?: string;
  };
}
interface IMessage {
  role: 'assistant' | 'user';
  content?: string;
  documents?: Doc[];
}

const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || '';

const ChatComponent: React.FC = () => {
  const [message, setMessage] = React.useState<string>('');
  const [messages, setMessages] = React.useState<IMessage[]>([]);
  const [loading, setLoading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

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
          documents: data?.docs,
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
    <div className="flex h-full flex-col gap-6 p-4 md:p-6">
      <div className="rounded-3xl border border-slate-200/70 bg-white/80 p-5 shadow-xl shadow-slate-900/5 backdrop-blur-xl dark:border-slate-700/80 dark:bg-slate-950/80">
        <div className="mb-4 space-y-2">
          <h2 className="text-2xl font-semibold">Chat with your PDF</h2>
          <p className="text-sm text-slate-600 dark:text-slate-400">
            Ask questions and see the document context in one place.
          </p>
        </div>

        <div className="mb-4 max-h-[60vh] overflow-y-auto space-y-4 px-1 py-2">
          {messages.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-slate-300/80 bg-slate-50 p-6 text-center text-slate-500 dark:border-slate-700/80 dark:bg-slate-900/60 dark:text-slate-400">
              Start by asking a question about the uploaded PDF.
            </div>
          ) : (
            messages.map((messageObj, index) => (
              <div
                key={index}
                className={`flex ${messageObj.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div
                  className={`max-w-[80%] rounded-3xl px-4 py-3 shadow-sm ${
                    messageObj.role === 'user'
                      ? 'bg-slate-900 text-white'
                      : 'bg-slate-100 text-slate-900 dark:bg-slate-800 dark:text-slate-100'
                  }`}
                >
                  <div className="text-sm leading-7">
                    {messageObj.content}
                  </div>
                  {messageObj.documents && messageObj.documents.length > 0 ? (
                    <div className="mt-3 space-y-2 rounded-2xl border border-slate-200/80 bg-slate-50 p-3 text-xs text-slate-600 dark:border-slate-700/80 dark:bg-slate-900/80 dark:text-slate-300">
                      <div className="mb-2 font-medium">Context sources</div>
                      {messageObj.documents.map((doc, docIndex) => (
                        <div key={docIndex} className="rounded-xl bg-white/80 p-2 shadow-sm dark:bg-slate-950/70">
                          <div>{doc.pageContent || 'No document content available.'}</div>
                          {doc.metdata?.source ? (
                            <div className="mt-2 text-xs text-slate-500 dark:text-slate-400">Source: {doc.metdata.source}</div>
                          ) : null}
                        </div>
                      ))}
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

      <div className="sticky bottom-0 rounded-3xl border border-slate-200/70 bg-white/90 p-4 shadow-xl shadow-slate-900/5 backdrop-blur-xl dark:border-slate-700/80 dark:bg-slate-950/90">
        <div className="flex flex-col gap-3 md:flex-row">
          <Input
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="Type your message here"
            disabled={loading}
          />
          <Button onClick={handleSendChatMessage} disabled={!message.trim() || loading} className="w-full md:w-auto">
            {loading ? 'Sending...' : 'Send'}
          </Button>
        </div>
      </div>
    </div>
  );
};
export default ChatComponent;
