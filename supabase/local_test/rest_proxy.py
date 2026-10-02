"""Proxy mínimo: /rest/v1/* -> PostgREST en :3000 (lo que hace Kong en Supabase)."""
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def _fwd(self):
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n) if n else None
        path = self.path
        if path.startswith("/rest/v1"):
            path = path[len("/rest/v1"):] or "/"
        c = http.client.HTTPConnection("127.0.0.1", 3000, timeout=30)
        hdrs = {k: v for k, v in self.headers.items() if k.lower() not in ("host", "connection", "accept-encoding")}
        c.request(self.command, path, body=body, headers=hdrs)
        r = c.getresponse(); data = r.read()
        self.send_response(r.status)
        for k, v in r.getheaders():
            if k.lower() not in ("transfer-encoding", "connection", "content-length"):
                self.send_header(k, v)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers(); self.wfile.write(data)
    do_GET = do_POST = do_PATCH = do_PUT = do_DELETE = do_HEAD = _fwd
    def log_message(self, *a): pass

ThreadingHTTPServer(("127.0.0.1", 3001), H).serve_forever()
