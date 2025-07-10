module.exports = async function(context) {
    const { name = 'World' } = context.request.query;
    
    return {
        status: 200,
        body: `Hello, ${name}! 🚀 Function created with coder-faas repo.`,
        headers: {
            'Content-Type': 'text/plain'
        }
    };
}; 