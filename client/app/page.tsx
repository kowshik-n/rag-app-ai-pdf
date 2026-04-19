import FileUploadComponent from './components/file-upload';
import ChatComponent from './components/chat';
export default function Home() {
  return (
    <div className="min-h-screen w-screen bg-slate-50 text-slate-950">
      <main className="mx-auto min-h-screen max-w-[1200px] flex flex-col gap-6 px-4 py-6 md:px-8 lg:px-10">
        <header className="space-y-4 border-b border-slate-200 pb-6">
          <div>
            <h1 className="text-3xl font-semibold sm:text-4xl">RAG AI PDF Chat</h1>
            <p className="mt-2 max-w-2xl text-base text-slate-600">
              Upload a PDF and ask questions about its content with a clean, minimal interface.
            </p>
          </div>
          <p className="text-sm text-slate-500">Upload the document first, then ask a question in the chat panel.</p>
        </header>

        <section className="grid min-h-[calc(100vh-180px)] gap-6 lg:grid-cols-[1fr_2fr]">
          <div className="flex min-h-[420px] flex-col">
            <FileUploadComponent />
          </div>
          <div className="flex min-h-[420px] flex-col">
            <ChatComponent />
          </div>
        </section>
      </main>
    </div>
  );
}
