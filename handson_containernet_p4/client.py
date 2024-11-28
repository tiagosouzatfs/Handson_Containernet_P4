import socket

# Cria o socket
client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# Conecta ao servidor na IP e porta especificados
client_socket.connect(('10.0.0.3', 8080))  # IP do servidor e porta

# Envia dados para o servidor
client_socket.sendall("Olá, Servidor!".encode())

# Recebe a resposta do servidor
response = client_socket.recv(1024)
print(f"Resposta do servidor: {response.decode()}")

# Fecha a conexão
client_socket.close()