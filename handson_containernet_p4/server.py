import socket

# Cria o socket
server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# Liga o socket ao endereço e porta
server_socket.bind(('0.0.0.0', 8080))  # O servidor escuta em todas as interfaces de rede na porta 8080
server_socket.listen(1)

print("Aguardando conexão de um cliente...")

# Aceita a conexão do cliente
client_socket, client_address = server_socket.accept()
print(f"Conexão estabelecida com {client_address}")

# Recebe dados do cliente
data = client_socket.recv(1024)
print(f"Recebido: {data.decode()}")

# Envia uma resposta
client_socket.sendall("Dados recebidos".encode())

# Fecha a conexão
client_socket.close()
server_socket.close()