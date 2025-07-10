module.exports = async function(context) {
    const { request } = context;
    const url = new URL(request.url, `http://${request.headers.host}`);
    const a = parseInt(url.searchParams.get('a') || '0');
    const b = parseInt(url.searchParams.get('b') || '0');
    
    return {
        status: 200,
        body: {
            message: "Math operations from faas namespace",
            inputs: { a, b },
            results: {
                sum: a + b,
                difference: a - b,
                product: a * b,
                division: b !== 0 ? a / b : "Division by zero"
            },
            timestamp: new Date().toISOString(),
            namespace: "faas",
            function: "math-faas"
        }
    };
} 