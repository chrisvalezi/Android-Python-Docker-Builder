import socket
import ssl
import urllib.request


def main() -> None:
    host = "example.com"
    with socket.create_connection((host, 443), timeout=10) as sock:
        with ssl.create_default_context().wrap_socket(sock, server_hostname=host) as tls_sock:
            print("tls version:", tls_sock.version())
            print("peer:", tls_sock.getpeercert().get("subject", []))

    with urllib.request.urlopen("https://example.com/", timeout=10) as response:
        body = response.read(80)
        print("https status:", response.status)
        print("https bytes:", len(body))


if __name__ == "__main__":
    main()
