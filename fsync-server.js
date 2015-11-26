'use strict';

let net = require('net');
let http = require('http');

let SERVER_PORT = 3000;
let CLIENT_PORT = 3001;
let ID_LENGTH = 8;

let serverClients = new Map();

class ServerClient {
  //socket;
  //id;
  //Note only one target! This is intentional!
  //target;

  constructor(socket, id) {
    this.socket = socket;
    this.id = id;
    this.socket.on('data', data => {
      if (this.target) {
        this.target.write(data);
      } else {
        console.log('Data recieve from client ' + this.id + ' without a target: """' + data + '"""');
      }
    });
  }
}

//Good variable name right here
let serverServer = net.createServer(function(socket) {
  let id = null;
  while (id == null || serverClients.has(id)) {
    id = Math.floor(Math.random() * Math.pow(10, ID_LENGTH));
  }
  console.log(`New client: ${id}`);
  let client = new ServerClient(socket, id);
  serverClients.set(id, client);
  writeHttpReq(client.socket, 'PUT', '/fsync.config/remoteUniqueIdentifier', '' + id);
});

serverServer.listen({port: SERVER_PORT}, () => {
  console.log(`Listening for 'servers' on port ${SERVER_PORT}`)
});

let clientServer = http.createServer();

clientServer.listen(CLIENT_PORT, () => {
  console.log(`Listening for 'clients' on port ${CLIENT_PORT}`)
});

clientServer.on('request', (req, res) => {
  res.statusCode = 400;
  res.end('Must provide Upgrade: header and /<targetID> as url');
});

clientServer.on('upgrade', (req, socket, head) => {
  let serverID = req.url.match(/^\/([0-9])+$/)[1];
  if (serverID) {
    let server = serverClients.get(serverID);
    if (server) {
      server.target = socket;
      writeHttpResp(socket, '200 OK', 'Connected');
      socket.on('data', data => {
        if (server.target != socket) {
          writeHttpResp(socket, '502 Bad Gateway', 'Another client has stolen your connection!')
          socket.end();
        } else {
          server.socket.write(data);
        }
      })
    } else {
      writeHttpResp(socket, '404 Not Found', 'Server not found');
      socket.end();
    }
  } else {
    writeHttpResp(socket, '400 Bad Request', 'Must provide ServerID');
    socket.end();
  }
});

function writeHttpResp(socket, code, body) {
  var resp = [
    `HTTP/1.1 ${code}`,
    `Content-Length: ${body.length}`,
    '',
    body
    ].join('\r\n');
  socket.write(resp);
}

function writeHttpReq(socket, method, url, body) {
  var req = [
    `${method} ${url} HTTP/1.1`,
    `Content-Length: ${body.length}`,
    '',
    body
    ].join('\r\n');
  socket.write(req);
}
