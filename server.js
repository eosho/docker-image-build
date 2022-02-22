import { createServer } from 'http'

const port = 80

const server = createServer((request, response) => {
  response.writeHead(200, {'Content-Type': 'text/plain'})
  response.write('Hello World\n')
})

server.listen(port)

console.log(`Server running at http://localhost:${port}`)
