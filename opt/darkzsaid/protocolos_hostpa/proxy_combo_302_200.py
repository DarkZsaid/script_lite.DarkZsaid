#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import socket
import threading
import select
import sys
import time

# --- CONFIGURACIÓN HOST-PA 9X ---
LISTEN_IP = '0.0.0.0'
# El puerto se define al ejecutar: python3 proxy6.py 8080
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
BUFLEN = 16384  # 4096 * 4
TIMEOUT = 60
SSH_HOST = '127.0.0.1'

# Respuesta exacta solicitada: 302 Found (Redirección de sigilo) + 200 OK
RESPONSE = b'HTTP/1.1 302 Found\r\nLocation: https://www.google.com\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n'

def get_target_ssh(listen_port):
    """
    MAPEÓ DE PUERTOS HOST-PA ESTRICTO:
    - 80, 8080, 8082 -> OpenSSH (22)
    - 8084, 8086     -> OpenSSH (44)
    """
    if listen_port in [90, 8080, 8082]:
        return 22
    elif listen_port in [80, 8084, 8086]:
        return 22
    return 22

# Determinar puerto destino antes de iniciar el servidor
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
            print(f"🎯 Redirigiendo estrictamente a SSH:{SSH_PORT}")
            
            while True:
                client, addr = self.soc.accept()
                # threading.Thread con daemon=True para manejo eficiente en Py3
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

            # Verificación de protocolo para aplicar el sigilo
            data_upper = data.upper()
            if any(x in data_upper for x in [b"GET", b"POST", b"CONNECT", b"UPGRADE"]):
                # Conexión al puerto SSH correspondiente (22 o 44)
                target.connect((SSH_HOST, SSH_PORT))
                
                # Enviamos la respuesta de redirección configurada
                client.sendall(RESPONSE)
                
                # Puente bidireccional (Tunneling)
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
            # Control de inactividad
            if count >= (TIMEOUT / 3):
                break

if __name__ == '__main__':
    server = Server(LISTEN_IP, PORT)
    try:
        server.start()
    except KeyboardInterrupt:
        print("\n🛑 Deteniendo Proxy...")
        sys.exit(0)