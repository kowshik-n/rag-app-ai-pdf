import FileUploadComponent from './components/file-upload';
import ChatComponent from './components/chat';
export default function Home() {
  return (
    <div className="min-h-screen w-screen bg-slate-950 text-slate-50">
      <main className="mx-auto flex min-h-screen max-w-[1600px] flex-col gap-6 px-4 py-6 md:px-8 lg:px-12">
        <header className="rounded-[2rem] border border-white/10 bg-white/5 p-6 shadow-2xl shadow-slate-950/20 backdrop-blur-xl">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <h1 className="text-3xl font-semibold sm:text-4xl">RAG AI PDF Chat</h1>
              <p className="mt-2 max-w-2xl text-slate-300">
                Upload a PDF, then ask questions and get answers backed by the document content.
              </p>
            </div>
            <div className="rounded-3xl bg-slate-900/80 px-4 py-3 text-sm text-slate-300">
              Use the left panel to upload your PDF and the right panel to chat.
            </div>
          </div>
        </header>

        <section className="grid min-h-[calc(100vh-160px)] gap-6 lg:grid-cols-[1fr_2fr]">
          <div className="flex min-h-[480px] flex-col">
            <FileUploadComponent />
          </div>
          <div className="flex min-h-[480px] flex-col">
            <ChatComponent />
          </div>
        </section>
      </main>
    </div>
  );
}
