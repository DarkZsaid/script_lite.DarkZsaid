#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import socket
import threading
import select
import sys
import time

# --- CONFIGURACIÓN HOST-PA ---
LISTEN_IP = '0.0.0.0'
# El puerto se define al ejecutar: python3 proxy.py 8080
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
BUFLEN = 8192  # Optimizado para Py3
TIMEOUT = 60
SSH_HOST = '127.0.0.1'

# Respuesta exacta para sigilo
RESPONSE = b'HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n'

def get_target_ssh(listen_port):
    """
    MAPEÓ DE PUERTOS HOST-PA ESTRICTO
    """
    # Si entran por 80, 8080, 8082 -> Van al OpenSSH (22)
    if listen_port in [90, 8080, 8082]:
        return 22
    # Si entran por 8084, 8086 -> Van al OpenSSH (44)
    elif listen_port in [80, 8084, 8086]:
        return 22
    # Por defecto siempre SSH estándar
    return 22

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
            print(f"🚀 Proxy Host-Pa en puerto {self.port} -> Dirigido a SSH:{SSH_PORT}")
            
            while True:
                client, addr = self.soc.accept()
                threading.Thread(target=self.handler, args=(client, addr), daemon=True).start()
        except Exception as e:
            print(f"❌ Error al iniciar: {e}")
            sys.exit(1)

    def handler(self, client, addr):
        target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            # Recibimos el Payload inicial para limpiar el buffer
            data = client.recv(BUFLEN)
            
            if not data:
                return

            # Verificamos si es una petición válida (sigilo)
            data_str = data.decode('utf-8', errors='ignore').upper()
            if any(x in data_str for x in ["GET", "POST", "CONNECT", "UPGRADE"]):
                # Conectamos al SSH local según el puerto definido
                target.connect((SSH_HOST, SSH_PORT))
                
                # Enviamos la respuesta 400 Bad Request para el bypass
                client.sendall(RESPONSE)
                
                # Iniciamos el puente de datos (Bridge)
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
            if count >= (TIMEOUT / 3):
                break

if __name__ == '__main__':
    server = Server(LISTEN_IP, PORT)
    try:
        server.start()
    except KeyboardInterrupt:
        print("\nDeteniendo Proxy...")
        sys.exit(0)