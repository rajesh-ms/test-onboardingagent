import http from 'node:http';
import { evaluateClaimSubmission, buildReviewerHandoff } from './agent.js';

const port = Number(process.env.PORT ?? 8080);

const server = http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    return sendJson(res, 200, { status: 'ok' });
  }

  if (req.method === 'POST' && req.url === '/claims/evaluate') {
    try {
      const claim = await readJson(req);
      const evaluation = evaluateClaimSubmission(claim);
      return sendJson(res, 200, {
        evaluation,
        handoff: buildReviewerHandoff(claim, evaluation),
      });
    } catch (error) {
      return sendJson(res, 400, { error: error.message });
    }
  }

  sendJson(res, 404, { error: 'Not found' });
});

server.listen(port, () => {
  console.log(`claim management agent listening on ${port}`);
});

function sendJson(res, statusCode, body) {
  res.writeHead(statusCode, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      body += chunk;
    });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch {
        reject(new Error('Invalid JSON body'));
      }
    });
    req.on('error', reject);
  });
}