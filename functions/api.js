module.exports = async function(context) {
    const { request } = context;
    const { method, body, query } = request;
    
    // Log the request for debugging
    console.log(`${method} request received:`, { query, body });
    
    switch (method) {
        case 'GET':
            return {
                status: 200,
                body: JSON.stringify({
                    message: '🚀 Coder FaaS API is running!',
                    timestamp: new Date().toISOString(),
                    query: query,
                    method: method
                }),
                headers: {
                    'Content-Type': 'application/json'
                }
            };
            
        case 'POST':
            const data = typeof body === 'string' ? JSON.parse(body) : body;
            return {
                status: 200,
                body: JSON.stringify({
                    message: '✅ Data processed successfully',
                    received: data,
                    processed_at: new Date().toISOString()
                }),
                headers: {
                    'Content-Type': 'application/json'
                }
            };
            
        default:
            return {
                status: 405,
                body: JSON.stringify({
                    error: 'Method not allowed',
                    allowed_methods: ['GET', 'POST']
                }),
                headers: {
                    'Content-Type': 'application/json'
                }
            };
    }
}; 