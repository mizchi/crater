var net = require('net');

var server = net.createServer(function(socket) {
	socket.on('error', function (_) {});
	socket.pipe(socket);
});

server.listen(42001, '127.0.0.1');
