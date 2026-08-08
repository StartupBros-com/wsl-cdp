#!/usr/bin/env python3
"""wsl-cdp-forward: byte-blind TCP relay, 127.0.0.1:<listen-port> -> <target>:<port>.

The load-bearing piece of the wsl-cdp bridge: Chromium echoes the request Host
header into webSocketDebuggerUrl, so CDP clients in WSL are handed
ws://127.0.0.1:<port>/... — which only resolves if this relay listens on that
exact local port. It must relay raw bytes (not HTTP-parse) so WebSocket
upgrades and multi-megabyte screenshot frames pass through untouched.

Stdlib-only on purpose: no socat/npm dependency to install or rot.
Managed by `wsl-cdp up|down`.
"""
import argparse
import asyncio
import sys


async def pipe(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    try:
        while True:
            data = await reader.read(65536)
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except (ConnectionResetError, BrokenPipeError, TimeoutError, OSError):
        pass
    finally:
        try:
            writer.close()
        except Exception:
            pass


async def handle(client_r, client_w, host: str, port: int) -> None:
    try:
        remote_r, remote_w = await asyncio.open_connection(host, port)
    except OSError as e:
        # Visible in ~/.local/state/wsl-cdp/forwarder.log; `wsl-cdp status` is
        # the honest reporter (it probes the Windows side directly, never us).
        print(f"connect {host}:{port} failed: {e}", file=sys.stderr, flush=True)
        client_w.close()
        return
    await asyncio.gather(pipe(client_r, remote_w), pipe(remote_r, client_w))


async def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--listen-port", type=int, required=True)
    ap.add_argument("--target-host", required=True)
    ap.add_argument("--target-port", type=int, required=True)
    args = ap.parse_args()

    server = await asyncio.start_server(
        lambda r, w: handle(r, w, args.target_host, args.target_port),
        "127.0.0.1",
        args.listen_port,
    )
    print(
        f"wsl-cdp-forward: 127.0.0.1:{args.listen_port} -> "
        f"{args.target_host}:{args.target_port}",
        flush=True,
    )
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
