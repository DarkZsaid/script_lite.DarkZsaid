#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import socket
import threading
import select
import sys
import time

# --- CONFIGURACIÓN ---
LISTEN_IP = '0.0.0.0'
BUFLEN = 8192
TIMEOUT = 60
SSH_HOST = '127.0.0.1'

# Respuesta de Sigilo (Redirección para engañar al DPI/Firewall)
RESPONSE_302 = b'HTTP/1.1 302 Found\r\nLocation: https://www.google.com\r\n\r\n'

def get_target_ssh(listen_port):
    """
    Define el destino según el puerto de entrada:
    90, 8080, 8082 -> OpenSSH (22)
    80, 8084, 8086     -> OpenSSH (44)
    """
    if listen_port in [80, 8084, 8086]:
        return 22  # Destino OpenSSH
    return 22      # Destino OpenSSH

def handle(client, addr, listen_port):
    ssh_target_port = get_target_ssh(listen_port)
    target = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    target.settimeout(10)
    
    try:
        # Recibir Payload inicial
        data = client.recv(BUFLEN)
        if not data: return

        # Si detecta tráfico HTTP/Payload, aplicamos la respuesta de sigilo
        if any(x in data.upper() for x in [b"GET", b"POST", b"CONNECT", b"UPGRADE"]):
            # Conexión interna al SSH que corresponda
            target.connect((SSH_HOST, ssh_target_port))
            
            # Respondemos con el 302
            client.sendall(RESPONSE_302)
            
            # Túnel de datos
            sockets = [client, target]
            while True:
                r, _, e = select.select(sockets, [], sockets, 3)
                if e or not r: break
                
                for sock in r:
                    chunk = sock.recv(BUFLEN)
                    if not chunk: return
                    if sock is client: target.sendall(chunk)
                    else: client.sendall(chunk)
    except:
        pass
    finally:
        client.close()
        target.close()

def start_proxy(port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind((LISTEN_IP, port))
        server.listen(500)
        print(f"✅ [Host-Pa] Puerto {port} activo -> Redirigiendo a SSH:{get_target_ssh(port)}")
        while True:
            c, a = server.accept()
            threading.Thread(target=handle, args=(c, a, port), daemon=True).start()
    except Exception as e:
        print(f"❌ Error en puerto {port}: {e}")

if __name__ == "__main__":
    # LISTA DE PUERTOS (Sin el 443 para evitar conflictos con Stunnel)
    puertos = [80, 90, 8080, 8082, 8084, 8086]
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🚀 MULTIPROXY HOST-PA - SISTEMA DE SIGILO 302")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    for p in puertos:
        t = threading.Thread(target=start_proxy, args=(p,), daemon=True)
        t.start()
        time.sleep(0.1)

    try:
        while True: time.sleep(1)
    except KeyboardInterrupt:
        print("\nDeteniendo Proxy...")