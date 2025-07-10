module.exports = async function(context) {
    return {
        status: 200,
        body: {
            message: "Hello from faas namespace!",
            timestamp: new Date().toISOString(),
            namespace: "faas",
            function: "hello-faas"
        }
    };
} 