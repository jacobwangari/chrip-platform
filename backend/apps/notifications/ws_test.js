// ws_test.js
const WebSocket = require('ws');

// Replace with your actual token
const TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzg3NjI4MDAyLCJpYXQiOjE3ODc2MjYyMDIsImp0aSI6IjgyMzM5NWQxYmI0ZjRlNmE4ZTY2Y2E1ZTVlOWYwNWE4IiwidXNlcl9pZCI6IjMifQ.v9YE9JIyTcStLuQtheCAq46OQQnOHeP2OJ0Bywp-X8Q';
function testWebSocket() {
    console.log('🔌 Connecting to WebSocket...');
    const ws = new WebSocket(`ws://127.0.0.1:8000/ws/notifications/?token=${TOKEN}`);

    ws.on('open', () => {
        console.log('✅ Connected successfully!');
        console.log('📡 Waiting for notifications...');
    });

    ws.on('message', (data) => {
        try {
            const notification = JSON.parse(data.toString());
            console.log('📨 Notification received:', JSON.stringify(notification, null, 2));
        } catch (e) {
            console.log('📨 Raw message:', data.toString());
        }
    });

    ws.on('close', (code, reason) => {
        console.log(`🔌 Connection closed - Code: ${code}, Reason: ${reason.toString()}`);
        if (code === 4001) {
            console.log('❌ Authentication failed - invalid token');
        }
    });

    ws.on('error', (error) => {
        console.error('❌ WebSocket error:', error.message);
    });

    // Keep the process running
    console.log('⏳ Press Ctrl+C to disconnect');
}

// Run the test
testWebSocket();