const WebSocket = require('ws');
const server = new WebSocket.Server({ port: 8080 });

const rooms = new Map();

console.log('Сигнальный сервер запущен на порту 8080');
console.log('Ожидание подключений...');

server.on('connection', (ws) => {
  console.log('Новый клиент подключился');
  
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log('Получено сообщение:', data.type);
      
      switch(data.type) {
        case 'create_room':
          handleCreateRoom(ws, data);
          break;
        case 'join_room':
          handleJoinRoom(ws, data);
          break;
        case 'offer':
        case 'answer':
        case 'candidate':
          forwardToPeer(ws, data);
          break;
        case 'leave':
          handleLeave(ws, data);
          break;
        default:
          console.log('Неизвестный тип сообщения:', data.type);
      }
    } catch (e) {
      console.log('Ошибка обработки сообщения:', e);
    }
  });
  
  ws.on('close', () => {
    console.log('Клиент отключился');
    handleDisconnect(ws);
  });
});

function handleCreateRoom(ws, data) {
  const roomId = generateRoomId();
  rooms.set(roomId, {
    id: roomId,
    creator: ws,
    participants: [ws]
  });
  
  ws.roomId = roomId;
  
  ws.send(JSON.stringify({
    type: 'room_created',
    roomId: roomId
  }));
  
  console.log('Создана комната:', roomId);
}

function handleJoinRoom(ws, data) {
  const room = rooms.get(data.roomId);
  
  if (room && room.participants.length < 2) {
    room.participants.push(ws);
    ws.roomId = data.roomId;
    
    // Уведомляем создателя комнаты
    if (room.creator && room.creator !== ws) {
      room.creator.send(JSON.stringify({
        type: 'peer_joined'
      }));
    }
    
    ws.send(JSON.stringify({
      type: 'room_joined',
      isInitiator: false
    }));
    
    console.log('Участник присоединился к комнате:', data.roomId);
  } else {
    ws.send(JSON.stringify({
      type: 'error',
      message: 'Комната не найдена или уже заполнена'
    }));
  }
}

function forwardToPeer(ws, data) {
  const room = rooms.get(ws.roomId);
  if (room) {
    const peer = room.participants.find(p => p !== ws);
    if (peer && peer.readyState === WebSocket.OPEN) {
      peer.send(JSON.stringify(data));
      console.log('Переслано сообщение типа:', data.type);
    }
  }
}

function handleLeave(ws, data) {
  const room = rooms.get(ws.roomId);
  if (room) {
    const peer = room.participants.find(p => p !== ws);
    if (peer && peer.readyState === WebSocket.OPEN) {
      peer.send(JSON.stringify({ type: 'peer_left' }));
    }
    rooms.delete(ws.roomId);
    console.log('Комната удалена:', ws.roomId);
  }
}

function handleDisconnect(ws) {
  if (ws.roomId) {
    handleLeave(ws, {});
  }
}

function generateRoomId() {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
}