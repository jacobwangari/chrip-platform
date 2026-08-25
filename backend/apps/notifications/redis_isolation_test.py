"""
Standalone test — isolates whether the TimeoutError is a Redis/Docker
networking problem or something specific to channels_redis.

Run with: python redis_isolation_test.py

If this hangs/times out too, the problem is Redis connectivity itself
(Docker networking), not Channels. If this works fine, the problem is
specific to how channels_redis is using the connection.
"""
import asyncio
import redis.asyncio as redis


async def main():
    print("Connecting...")
    client = redis.Redis(host="127.0.0.1", port=6379, socket_timeout=5)

    print("PING...")
    pong = await client.ping()
    print(f"PING result: {pong}")

    print("Testing a blocking read (BLPOP with 3s timeout on a key nothing pushes to)...")
    result = await client.blpop(["test_key_nobody_pushes_to"], timeout=3)
    print(f"BLPOP result (should be None after ~3s, not an exception): {result}")

    print("SUCCESS — Redis connection and blocking reads work fine.")
    await client.aclose()


if __name__ == "__main__":
    asyncio.run(main())