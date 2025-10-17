#!/usr/bin/env node

import http from 'http'
import { join } from 'path'
import { statSync, createReadStream } from 'fs'
import { networkInterfaces } from 'node:os'

function getLocalIPV4() {
  const interfaces = networkInterfaces()
  for (const name in interfaces) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address
      }
    }
  }
  return ''
}

;(() => {
  const ipv4 = getLocalIPV4()
  const port = 4399
  const project = join(import.meta.dirname, "..")
  const ipaFile = join(project, "build/ios/iphoneos", "猫趣.ipa")
  const stats = statSync(ipaFile)
  const server = http.createServer((req, res) => {
    if (req.url == "/" || req.url == "/index.html") {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(`<div style="
    width: 100vw;
    height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
"><a href="apple-magnifier://install?url=http://${ipv4}:${port}/x.ipa" style="
    text-decoration: none;
    font-size: 42px;
    padding: 24px 66px;
    border-radius: 24px;
    margin-bottom: 12vh;
    border: 3px solid blue;
    background: none;
    color: blue;
">巨魔安装</a></div>`)
      return
    }
    if (req.url == "/x.ipa") {
      res.writeHead(200, {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': 'attachment; filename=x.ipa',
        'Content-Length': stats.size
      });
      const fileStream = createReadStream(ipaFile)
      fileStream.pipe(res)
      fileStream.on('error', (err) => {
        console.error('IPA文件读取错误:', err);
        if (!res.headersSent) {
          res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' })
        }
      })
    }
  })
  server.listen(port, '0.0.0.0', () => {
    console.log(`Server running at http://${ipv4}:${port}`);
  })
})()