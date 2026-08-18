import { IncomingMessage, ServerResponse } from 'http';
import { handleApiRequest, RequestLike } from './handler.js';

export default async function handler(req: IncomingMessage, res: ServerResponse) {
  let body: any = null;
  if (req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH') {
    const buffers: Buffer[] = [];
    for await (const chunk of req) {
      buffers.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
    }
    const raw = Buffer.concat(buffers).toString('utf-8');
    if (raw) {
      try {
        body = JSON.parse(raw);
      } catch {
        body = raw;
      }
    }
  }

  const reqLike: RequestLike = {
    method: req.method,
    url: req.url,
    headers: req.headers as Record<string, string | string[] | undefined>,
    body,
  };

  const response = await handleApiRequest(reqLike);

  res.statusCode = response.statusCode;
  for (const [key, value] of Object.entries(response.headers)) {
    res.setHeader(key, value);
  }
  res.end(JSON.stringify(response.body));
}
