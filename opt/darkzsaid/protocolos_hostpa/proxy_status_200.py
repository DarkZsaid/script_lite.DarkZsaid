#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import socket
import threading
import select
import sys

# --- CONFIGURACIÓN ---
LISTEN_IP = '0.0.0.0'
# El puerto se define al ejecutar: python3 proxy.py 8080
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
BUFLEN = 8192
TIMEOUT = 60
SSH_HOST = '127.0.0.1'

def get_target_ssh(listen_port):
    # MAPEO DARKZSAID SSH WS PURO
    # 90, 8080, 8082 -> OpenSSH 22
    # 80, 8084, 8086 -> OpenSSH 22
    if listen_port in [90, 8080, 8082]:
        return 22
    elif listen_port in [80, 8084, 8086]:
        return 22
    return 22

SSH_PORT = get_target_ssh(PORT)

# Respuesta con sello personal HostPa (Sigilo + Reconexión)
RESP_HOSTPA = b'HTTP/1.1 200 (By HostPa)\r\nContent-length: 0\r\n\r\nHTTP/1.1 200 conexion exitosa\r\n\r\n'
RESP_WS = b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n'

def handle(client, addr):
    target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    target.settimeout(10)
    
    try:
        # Recibimos el primer impacto (Payload)
        data = client.recv(BUFLEN)
        if not data: return

        req = data.lower()
        
        # --- LÓGICA DE RESPUESTA INTELIGENTE ---
        if b'upgrade: websocket' in req:
            # Respuesta pura para WebSocket (Máxima estabilidad)
            client.sendall(RESP_WS)
        elif b'connect' in req:
            # Para métodos CONNECT directos
            client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        else:
            # Respuesta clásica personalizada de Host-Pa para Inyectores
            client.sendall(RESP_HOSTPA)

        # Conexión al servicio SSH correspondiente (22 o 44)
        target.connect((SSH_HOST, SSH_PORT))
        
        # Puente de datos bidireccional
        sockets = [client, target]
        while True:
            # Mantiene la conexión abierta hasta que el cliente o el server cierren
            r, _, e = select.select(sockets, [], sockets, TIMEOUT)
            if e or not r: break
                
            for sock in r:
                chunk = sock.recv(BUFLEN)
                if not chunk:
                    return # Cierre de conexión limpia
                
                if sock is client:
                    target.sendall(chunk)
                else:
                    client.sendall(chunk)
                    
    except Exception:
        pass
    finally:
        client.close()
        target.close()

def main():
    # Creación del socket servidor
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind((LISTEN_IP, PORT))
    except Exception as e:
        print(f"Error: No se pudo abrir el puerto {PORT}. {e}")
        sys.exit(1)
        
    server.listen(500)
    print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"  🚀 PROXY HOST-PA ACTIVO")
    print(f"  Puerto Escucha: {PORT}")
    print(f"  Destino Final : SSH:{SSH_PORT}")
    print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    while True:
        try:
            c, a = server.accept()
            # Daemon=True para que no queden procesos colgados
            threading.Thread(target=handle, args=(c, a), daemon=True).start()
        except KeyboardInterrupt:
            print("\nDeteniendo Proxy...")
            break
        except Exception:
            break

if __name__ == "__main__":
    main()