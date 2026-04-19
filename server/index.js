import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import multer from 'multer';
import { Queue } from 'bullmq';
import { OpenAIEmbeddings } from '@langchain/openai';
import { QdrantVectorStore } from '@langchain/qdrant';
import OpenAI from 'openai';

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});
const queue = new Queue('file-upload-queue', {
  connection: {
    host: process.env.REDIS_HOST || 'localhost',
    port: Number(process.env.REDIS_PORT || 6379),
  },
});

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/');
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    cb(null, `${uniqueSuffix}-${file.originalname}`);
  },
});

const upload = multer({ storage: storage });

const app = express();
app.use(cors());

app.get('/', (req, res) => {
  return res.json({ status: 'All Good!' });
});

app.post('/upload/pdf', upload.single('pdf'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    await queue.add('file-ready', {
      filename: req.file.originalname,
      destination: req.file.destination,
      path: req.file.path,
    });
    return res.json({ message: 'uploaded' });
  } catch (error) {
    console.error('Upload error:', error);
    return res.status(500).json({ error: 'File upload failed' });
  }
});

app.get('/chat', async (req, res) => {
  try {
    const userQuery = String(req.query.message || '');
    if (!userQuery.trim()) {
      return res.status(400).json({ error: 'message query is required' });
    }

    const embeddings = new OpenAIEmbeddings({
      model: 'text-embedding-3-small',
      apiKey: process.env.OPENAI_API_KEY,
    });
    const vectorStore = await QdrantVectorStore.fromExistingCollection(
      embeddings,
      {
        url: process.env.QDRANT_URL || 'http://localhost:6333',
        collectionName: process.env.QDRANT_COLLECTION_NAME || 'langchainjs-testing',
      }
    );
    const ret = vectorStore.asRetriever({
      k: 2,
    });
    const result = await ret.invoke(userQuery);

    const SYSTEM_PROMPT = `
  You are a helpful AI assistant who answers the user query based on the available context from the PDF file.
  Context:
  ${JSON.stringify(result)}
  `;

    const chatResult = await client.chat.completions.create({
      model: 'gpt-4.1',
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userQuery },
      ],
    });

    return res.json({
      message: chatResult.choices[0].message.content,
      docs: result,
    });
  } catch (error) {
    console.error('Chat error:', error);
    return res.status(500).json({
      error: 'Chat request failed',
      details: error?.message || 'Unknown error',
    });
  }
});

const PORT = Number(process.env.PORT || 8000);
app.listen(PORT, () => console.log(`Server started on PORT:${PORT}`));

process.on('unhandledRejection', (reason) => {
  console.error('Unhandled Rejection:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  process.exit(1);
});
