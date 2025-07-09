module.exports = async function(context) {
    return {
        status: 200,
        body: {
            message: "Hello from Node.js in Fission!",
            timestamp: new Date().toISOString(),
            headers: context.request.headers
        }
    };
}
