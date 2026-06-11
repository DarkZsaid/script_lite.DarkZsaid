#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import socket
import threading
import select
import sys
import time

# --- CONFIGURACIÓN HOST-PA 9X ---
LISTEN_IP = '0.0.0.0'
# Selección de puerto por argumento (ej: python3 proxy.py 8080)
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
BUFLEN = 8192
TIMEOUT = 60
SSH_HOST = '127.0.0.1'

# Respuesta exacta solicitada (WebSocket + 200 OK)
RESPONSE = b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n'

def get_target_ssh(listen_port):
    """
    MAPEÓ DE PUERTOS HOST-PA ESTRICTO
    """
    if listen_port in [90, 8080, 8082]:
        return 22  # OpenSSH
    elif listen_port in [80, 8084, 8086]:
        return 22  # OpenSSH
    return 22

# Determinar puerto destino antes de iniciar
SSH_PORT = get_target_ssh(PORT)

class Server:
    def __init__(self, host, port):
        self.host = host
        self.port = port

    def start(self):
        self.soc = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.soc.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            self.soc.bind((self.host, self.port))
            self.soc.listen(128)
            print(f"🚀 Iniciando Proxy Host-Pa en puerto {self.port}")
            print(f"🎯 Destino fijo configurado: {SSH_HOST}:{SSH_PORT}")
            
            while True:
                client, addr = self.soc.accept()
                # threading.Thread reemplaza al antiguo thread.start_new_thread
                threading.Thread(target=self.handler, args=(client, addr), daemon=True).start()
        except Exception as e:
            print(f"❌ Error al iniciar: {e}")
            sys.exit(1)

    def handler(self, client, addr):
        target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            # Recibir Payload inicial para limpiar buffer
            data = client.recv(BUFLEN)
            if not data:
                return

            # Verificación de protocolo (sigilo)
            data_upper = data.upper()
            if any(x in data_upper for x in [b"GET", b"POST", b"CONNECT", b"UPGRADE"]):
                # Conexión al puerto SSH correspondiente según el mapeo
                target.connect((SSH_HOST, SSH_PORT))
                
                # Enviar la respuesta de doble cabecera solicitada
                client.sendall(RESPONSE)
                
                # Iniciar el puente bidireccional (Bridge)
                self.do_proxy(client, target)
        except:
            pass
        finally:
            client.close()
            target.close()

    def do_proxy(self, client, target):
        socs = [client, target]
        count = 0
        while True:
            count += 1
            (recv, _, err) = select.select(socs, [], socs, 3)
            if err:
                break
            if recv:
                for in_ in recv:
                    try:
                        data = in_.recv(BUFLEN)
                        if data:
                            if in_ is target:
                                client.sendall(data)
                            else:
                                target.sendall(data)
                            count = 0
                        else:
                            return
                    except:
                        break
            # Control de timeout para cerrar conexiones inactivas
            if count >= (TIMEOUT / 3):
                break

if __name__ == '__main__':
    server = Server(LISTEN_IP, PORT)
    try:
        server.start()
    except KeyboardInterrupt:
        print("\n🛑 Deteniendo Proxy Host-Pa...")
        sys.exit(0)